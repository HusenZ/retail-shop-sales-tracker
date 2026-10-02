import uuid
from dataclasses import dataclass
from datetime import UTC, date, datetime, timedelta
from decimal import Decimal

from sqlalchemy import ColumnElement, Select, func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import joinedload, selectinload

from app.core.errors import BusinessRuleError, NotFoundError
from app.core.money import ZERO
from app.core.time import day_range
from app.db.base import utc_now
from app.models import (
    Customer,
    Payment,
    PaymentMethod,
    Product,
    Sale,
    SaleItem,
    SaleType,
)
from app.schemas.sale import PaymentCreate, SaleCreate
from app.services.common import get_referenced
from app.services.sale_math import LineInput, calculate_sale

# Phones' clocks drift; anything further ahead than this is a wrong date, not drift.
ALLOWED_CLOCK_SKEW = timedelta(minutes=5)


@dataclass(frozen=True)
class SaleFilters:
    first_day: date | None = None
    last_day: date | None = None
    sale_type_id: uuid.UUID | None = None
    category_id: uuid.UUID | None = None
    payment_method: PaymentMethod | None = None
    customer_id: uuid.UUID | None = None
    pending_only: bool = False


async def create_sale(db: AsyncSession, shop_id: uuid.UUID, data: SaleCreate) -> tuple[Sale, bool]:
    """Record a sale, its payment and the stock change in one transaction.

    Returns the sale and whether it was newly created. Re-sending a sale with a
    client_ref that was already saved returns the original sale instead of a duplicate.
    """
    if data.client_ref is not None:
        existing = await _find_by_client_ref(db, shop_id, data.client_ref)
        if existing is not None:
            return existing, False

    sold_at = _not_in_future(data.sold_at, "Sale date")
    sale_type = await _usable_sale_type(db, shop_id, data)
    customer = await _optional_customer(db, shop_id, data.customer_id)
    products = await _lock_products(db, shop_id, [item.product_id for item in data.items])

    lines = []
    for item in data.items:
        product = products[item.product_id]
        _ensure_can_sell(product, item.quantity)
        unit_price = item.unit_price if item.unit_price is not None else product.selling_price
        lines.append(LineInput(item.quantity, unit_price, product.purchase_price))

    exchange_value = data.exchange.value if data.exchange else ZERO
    totals = calculate_sale(lines, data.discount, exchange_value)
    amount_paid = _amount_paid(data, totals.amount_due)
    if amount_paid < totals.amount_due and customer is None:
        raise BusinessRuleError("Choose a customer to record a pending payment")

    sale = Sale(
        shop_id=shop_id,
        sale_type_id=sale_type.id,
        customer_id=customer.id if customer else None,
        sold_at=sold_at,
        subtotal=totals.subtotal,
        discount=totals.discount,
        total=totals.total,
        total_cost=totals.total_cost,
        profit=totals.profit,
        exchange_value=totals.exchange_value,
        amount_due=totals.amount_due,
        amount_paid=amount_paid,
        payment_method=data.payment_method,
        notes=data.notes,
        exchange_device_name=data.exchange.device_name if data.exchange else None,
        exchange_device_imei=data.exchange.imei if data.exchange else None,
        client_ref=data.client_ref,
    )
    for item, line, result in zip(data.items, lines, totals.lines, strict=True):
        product = products[item.product_id]
        sale.items.append(
            SaleItem(
                product_id=product.id,
                product_name=product.name,
                quantity=line.quantity,
                unit_price=line.unit_price,
                unit_cost=line.unit_cost,
                discount=result.discount,
                revenue=result.revenue,
                cost=result.cost,
                profit=result.profit,
            )
        )
        if product.track_stock:
            product.stock_qty -= line.quantity
    if amount_paid > ZERO:
        sale.payments.append(
            Payment(
                shop_id=shop_id, amount=amount_paid, method=data.payment_method, paid_at=sold_at
            )
        )

    db.add(sale)
    try:
        await db.commit()
    except IntegrityError:
        await db.rollback()
        # The same offline sale arrived twice at once; the other request saved it.
        if data.client_ref is not None:
            existing = await _find_by_client_ref(db, shop_id, data.client_ref)
            if existing is not None:
                return existing, False
        raise
    return await get_sale(db, shop_id, sale.id), True


async def get_sale(db: AsyncSession, shop_id: uuid.UUID, sale_id: uuid.UUID) -> Sale:
    sale = await db.scalar(
        _with_details(select(Sale)).where(Sale.id == sale_id, Sale.shop_id == shop_id)
    )
    if sale is None:
        raise NotFoundError("Sale not found")
    return sale


async def list_sales(
    db: AsyncSession,
    shop_id: uuid.UUID,
    filters: SaleFilters,
    *,
    limit: int,
    offset: int = 0,
    oldest_first: bool = False,
) -> list[Sale]:
    order = (Sale.sold_at, Sale.id) if oldest_first else (Sale.sold_at.desc(), Sale.id.desc())
    query = (
        select(Sale)
        .where(*_conditions(shop_id, filters))
        .order_by(*order)
        .limit(limit)
        .offset(offset)
    )
    return list(await db.scalars(_with_summary(query)))


async def pending_totals(db: AsyncSession, shop_id: uuid.UUID) -> tuple[Decimal, int]:
    query = select(
        func.coalesce(func.sum(Sale.amount_due - Sale.amount_paid), ZERO), func.count()
    ).where(*_conditions(shop_id, SaleFilters(pending_only=True)))
    total, count = (await db.execute(query)).one()
    return total, count


async def record_payment(
    db: AsyncSession, shop_id: uuid.UUID, sale_id: uuid.UUID, data: PaymentCreate
) -> Sale:
    # Locked so two payments recorded at the same moment cannot overpay the sale.
    sale = await db.scalar(
        select(Sale).where(Sale.id == sale_id, Sale.shop_id == shop_id).with_for_update()
    )
    if sale is None:
        raise NotFoundError("Sale not found")

    pending = sale.pending_amount
    if pending == ZERO:
        raise BusinessRuleError("This sale is already fully paid")
    if data.amount > pending:
        raise BusinessRuleError(f"Only ₹{pending} is pending on this sale")

    sale.amount_paid += data.amount
    db.add(
        Payment(
            shop_id=shop_id,
            sale_id=sale.id,
            amount=data.amount,
            method=data.method,
            paid_at=_not_in_future(data.paid_at, "Payment date"),
        )
    )
    await db.commit()
    # Detach so the reload below includes the payment just added.
    db.expunge(sale)
    return await get_sale(db, shop_id, sale_id)


def _conditions(shop_id: uuid.UUID, filters: SaleFilters) -> list[ColumnElement[bool]]:
    conditions = [Sale.shop_id == shop_id]
    start, end = day_range(filters.first_day, filters.last_day)
    if start is not None:
        conditions.append(Sale.sold_at >= start)
    if end is not None:
        conditions.append(Sale.sold_at < end)
    if filters.sale_type_id is not None:
        conditions.append(Sale.sale_type_id == filters.sale_type_id)
    if filters.payment_method is not None:
        conditions.append(Sale.payment_method == filters.payment_method)
    if filters.customer_id is not None:
        conditions.append(Sale.customer_id == filters.customer_id)
    if filters.category_id is not None:
        in_category = (
            select(SaleItem.sale_id)
            .join(Product, Product.id == SaleItem.product_id)
            .where(Product.category_id == filters.category_id)
        )
        conditions.append(Sale.id.in_(in_category))
    if filters.pending_only:
        conditions.append(Sale.amount_paid < Sale.amount_due)
    return conditions


def _with_summary(query: Select[Sale]) -> Select[Sale]:
    return query.options(
        selectinload(Sale.items), joinedload(Sale.sale_type), joinedload(Sale.customer)
    )


def _with_details(query: Select[Sale]) -> Select[Sale]:
    return _with_summary(query).options(selectinload(Sale.payments))


async def _find_by_client_ref(db: AsyncSession, shop_id: uuid.UUID, client_ref: str) -> Sale | None:
    return await db.scalar(
        _with_details(select(Sale)).where(Sale.shop_id == shop_id, Sale.client_ref == client_ref)
    )


async def _usable_sale_type(db: AsyncSession, shop_id: uuid.UUID, data: SaleCreate) -> SaleType:
    sale_type = await get_referenced(db, SaleType, data.sale_type_id, shop_id, "Sale type")
    if not sale_type.is_active:
        raise BusinessRuleError(f'Sale type "{sale_type.name}" is disabled')
    if sale_type.is_exchange and data.exchange is None:
        raise BusinessRuleError("Enter the old phone details for an exchange sale")
    if not sale_type.is_exchange and data.exchange is not None:
        raise BusinessRuleError(f'"{sale_type.name}" is not an exchange sale type')
    return sale_type


async def _optional_customer(
    db: AsyncSession, shop_id: uuid.UUID, customer_id: uuid.UUID | None
) -> Customer | None:
    if customer_id is None:
        return None
    return await get_referenced(db, Customer, customer_id, shop_id, "Customer")


async def _lock_products(
    db: AsyncSession, shop_id: uuid.UUID, product_ids: list[uuid.UUID]
) -> dict[uuid.UUID, Product]:
    # FOR UPDATE makes concurrent sales of the same product wait instead of both
    # selling the last unit; ordering by id keeps lock order consistent (no deadlocks).
    rows = await db.scalars(
        select(Product)
        .where(Product.id.in_(product_ids), Product.shop_id == shop_id)
        .order_by(Product.id)
        .with_for_update()
    )
    products = {product.id: product for product in rows}
    if len(products) != len(product_ids):
        raise BusinessRuleError("Product not found")
    return products


def _ensure_can_sell(product: Product, quantity: int) -> None:
    if not product.is_active:
        raise BusinessRuleError(f'"{product.name}" is disabled')
    if product.track_stock and product.stock_qty < quantity:
        raise BusinessRuleError(f'Only {product.stock_qty} of "{product.name}" in stock')


def _amount_paid(data: SaleCreate, amount_due: Decimal) -> Decimal:
    if data.payment_method is PaymentMethod.CREDIT:
        if data.amount_paid:
            # Upfront money must say how it was paid; pick cash/UPI/card and enter less.
            raise BusinessRuleError("For a part payment, choose how the customer paid now")
        return ZERO
    if data.amount_paid is None:
        return amount_due
    if data.amount_paid > amount_due:
        raise BusinessRuleError(f"Amount paid cannot be more than ₹{amount_due}")
    return data.amount_paid


def _not_in_future(moment: datetime | None, label: str) -> datetime:
    now = utc_now()
    if moment is None:
        return now
    if moment > now + ALLOWED_CLOCK_SKEW:
        raise BusinessRuleError(f"{label} cannot be in the future")
    return moment.astimezone(UTC)
