import uuid

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import ConflictError
from app.models import Category, SaleType, Shop, User
from app.schemas.shop import ShopCreate, ShopUpdate

# Starting points so the owner can record a sale right after setup; all are editable.
DEFAULT_CATEGORIES = ("Mobile Phones", "Accessories", "Used Phones", "Repairs")
DEFAULT_SALE_TYPE = "New Phone"
EXCHANGE_SALE_TYPE = "Exchange"
OTHER_DEFAULT_SALE_TYPES = ("Accessories", "Repair", "Wholesale")


async def get_shop_for_user(db: AsyncSession, user_id: uuid.UUID) -> Shop | None:
    return await db.scalar(select(Shop).where(Shop.owner_user_id == user_id))


async def create_shop(db: AsyncSession, owner: User, data: ShopCreate) -> Shop:
    if await get_shop_for_user(db, owner.id) is not None:
        raise ConflictError("You already have a shop")

    shop = Shop(owner_user_id=owner.id, **data.model_dump())
    db.add(shop)
    try:
        await db.flush()
    except IntegrityError as exc:
        # Two simultaneous setup requests; the unique owner constraint stops the second.
        await db.rollback()
        raise ConflictError("You already have a shop") from exc

    db.add_all(_default_categories(shop.id))
    db.add_all(_default_sale_types(shop.id))
    await db.commit()
    return shop


async def update_shop(db: AsyncSession, shop: Shop, data: ShopUpdate) -> Shop:
    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(shop, field, value)
    await db.commit()
    return shop


def _default_categories(shop_id: uuid.UUID) -> list[Category]:
    return [Category(shop_id=shop_id, name=name) for name in DEFAULT_CATEGORIES]


def _default_sale_types(shop_id: uuid.UUID) -> list[SaleType]:
    return [
        SaleType(shop_id=shop_id, name=DEFAULT_SALE_TYPE, is_default=True),
        SaleType(shop_id=shop_id, name=EXCHANGE_SALE_TYPE, is_exchange=True),
        *(SaleType(shop_id=shop_id, name=name) for name in OTHER_DEFAULT_SALE_TYPES),
    ]
