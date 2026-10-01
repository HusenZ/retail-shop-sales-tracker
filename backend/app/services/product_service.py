import uuid

from sqlalchemy import ColumnElement, or_, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import BusinessRuleError
from app.models import Category, Product, StockStatus
from app.schemas.product import ProductCreate, ProductUpdate
from app.services.common import get_owned_or_404

LABEL = "Product"


async def list_products(
    db: AsyncSession,
    shop_id: uuid.UUID,
    *,
    search: str | None = None,
    category_id: uuid.UUID | None = None,
    stock_status: StockStatus | None = None,
    include_inactive: bool = False,
) -> list[Product]:
    query = select(Product).where(Product.shop_id == shop_id).order_by(Product.name)
    if not include_inactive:
        query = query.where(Product.is_active)
    if category_id is not None:
        query = query.where(Product.category_id == category_id)
    if search:
        query = query.where(_matches_search(search.strip()))
    if stock_status is not None:
        query = query.where(_has_stock_status(stock_status))
    return list(await db.scalars(query))


async def get_product(db: AsyncSession, shop_id: uuid.UUID, product_id: uuid.UUID) -> Product:
    return await get_owned_or_404(db, Product, product_id, shop_id, LABEL)


async def create_product(db: AsyncSession, shop_id: uuid.UUID, data: ProductCreate) -> Product:
    await _ensure_usable_category(db, shop_id, data.category_id)
    product = Product(shop_id=shop_id, **data.model_dump())
    db.add(product)
    await db.commit()
    return product


async def update_product(
    db: AsyncSession, shop_id: uuid.UUID, product_id: uuid.UUID, data: ProductUpdate
) -> Product:
    product = await get_product(db, shop_id, product_id)
    changes = data.model_dump(exclude_unset=True)
    if "category_id" in changes and changes["category_id"] != product.category_id:
        await _ensure_usable_category(db, shop_id, changes["category_id"])
    for field, value in changes.items():
        setattr(product, field, value)
    await db.commit()
    return product


async def adjust_stock(
    db: AsyncSession, shop_id: uuid.UUID, product_id: uuid.UUID, change: int
) -> Product:
    product = await get_product(db, shop_id, product_id)
    if not product.track_stock:
        raise BusinessRuleError("Stock is not tracked for this product")

    # A single conditional UPDATE so a sale running at the same time cannot be overwritten.
    updated_id = await db.scalar(
        update(Product)
        .where(
            Product.id == product.id,
            Product.shop_id == shop_id,
            Product.stock_qty + change >= 0,
        )
        .values(stock_qty=Product.stock_qty + change)
        .returning(Product.id)
        .execution_options(synchronize_session=False)
    )
    if updated_id is None:
        raise BusinessRuleError(f"Only {product.stock_qty} in stock; cannot remove {-change}")

    await db.commit()
    await db.refresh(product)
    return product


async def _ensure_usable_category(
    db: AsyncSession, shop_id: uuid.UUID, category_id: uuid.UUID
) -> None:
    category = await db.get(Category, category_id)
    if category is None or category.shop_id != shop_id:
        raise BusinessRuleError("Category not found")
    if not category.is_active:
        raise BusinessRuleError(f'Category "{category.name}" is disabled')


def _matches_search(term: str) -> ColumnElement[bool]:
    columns = (Product.name, Product.brand, Product.model, Product.sku, Product.imei)
    return or_(*(column.icontains(term, autoescape=True) for column in columns))


def _has_stock_status(status: StockStatus) -> ColumnElement[bool]:
    if status is StockStatus.OUT:
        return Product.is_out_of_stock()
    if status is StockStatus.LOW:
        return Product.is_low_stock()
    if status is StockStatus.NOT_TRACKED:
        return ~Product.track_stock
    return Product.track_stock & ~Product.is_out_of_stock() & ~Product.is_low_stock()
