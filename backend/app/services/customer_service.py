import uuid
from dataclasses import dataclass
from decimal import Decimal

from sqlalchemy import ColumnElement, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import ConflictError, NotFoundError
from app.core.money import ZERO
from app.models import Customer, Sale
from app.schemas.customer import CustomerCreate, CustomerUpdate
from app.services.common import get_owned_or_404

LABEL = "Customer"


@dataclass(frozen=True)
class CustomerWithStats:
    customer: Customer
    total_purchases: Decimal
    transaction_count: int
    pending_amount: Decimal


async def list_customers(
    db: AsyncSession, shop_id: uuid.UUID, *, search: str | None, pending_only: bool
) -> list[CustomerWithStats]:
    conditions: list[ColumnElement[bool]] = []
    if search and search.strip():
        term = search.strip()
        conditions.append(
            or_(
                Customer.name.icontains(term, autoescape=True),
                Customer.phone.contains(term, autoescape=True),
            )
        )
    return await _with_stats(db, shop_id, conditions, pending_only=pending_only)


async def get_customer(
    db: AsyncSession, shop_id: uuid.UUID, customer_id: uuid.UUID
) -> CustomerWithStats:
    rows = await _with_stats(db, shop_id, [Customer.id == customer_id])
    if not rows:
        raise NotFoundError(f"{LABEL} not found")
    return rows[0]


async def create_customer(
    db: AsyncSession, shop_id: uuid.UUID, data: CustomerCreate
) -> CustomerWithStats:
    if data.phone is not None:
        await _ensure_phone_available(db, shop_id, data.phone)
    customer = Customer(shop_id=shop_id, **data.model_dump())
    db.add(customer)
    await db.commit()
    return CustomerWithStats(customer, ZERO, 0, ZERO)


async def update_customer(
    db: AsyncSession, shop_id: uuid.UUID, customer_id: uuid.UUID, data: CustomerUpdate
) -> CustomerWithStats:
    customer = await get_owned_or_404(db, Customer, customer_id, shop_id, LABEL)
    changes = data.model_dump(exclude_unset=True)
    if changes.get("phone") is not None:
        await _ensure_phone_available(db, shop_id, changes["phone"], exclude_id=customer.id)
    for field, value in changes.items():
        setattr(customer, field, value)
    await db.commit()
    return await get_customer(db, shop_id, customer_id)


async def _with_stats(
    db: AsyncSession,
    shop_id: uuid.UUID,
    conditions: list[ColumnElement[bool]],
    *,
    pending_only: bool = False,
) -> list[CustomerWithStats]:
    # One grouped query instead of loading every sale of every customer into Python.
    stats = (
        select(
            Sale.customer_id,
            func.sum(Sale.total).label("total_purchases"),
            func.count().label("transaction_count"),
            func.sum(Sale.amount_due - Sale.amount_paid).label("pending_amount"),
        )
        .where(Sale.shop_id == shop_id, Sale.customer_id.is_not(None))
        .group_by(Sale.customer_id)
        .subquery()
    )
    pending = func.coalesce(stats.c.pending_amount, ZERO)
    query = (
        select(
            Customer,
            func.coalesce(stats.c.total_purchases, ZERO),
            func.coalesce(stats.c.transaction_count, 0),
            pending,
        )
        .outerjoin(stats, stats.c.customer_id == Customer.id)
        .where(Customer.shop_id == shop_id, *conditions)
        .order_by(Customer.name, Customer.id)
    )
    if pending_only:
        query = query.where(pending > ZERO)

    rows = await db.execute(query)
    return [CustomerWithStats(*row) for row in rows]


async def _ensure_phone_available(
    db: AsyncSession, shop_id: uuid.UUID, phone: str, exclude_id: uuid.UUID | None = None
) -> None:
    query = select(Customer.name).where(Customer.shop_id == shop_id, Customer.phone == phone)
    if exclude_id is not None:
        query = query.where(Customer.id != exclude_id)
    existing_name = await db.scalar(query)
    if existing_name is not None:
        raise ConflictError(f"{existing_name} already has this phone number")
