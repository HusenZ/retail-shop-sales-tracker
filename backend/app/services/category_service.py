import uuid

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Category
from app.schemas.category import CategoryCreate, CategoryUpdate
from app.services.common import commit_or_conflict, ensure_name_available, get_owned_or_404

LABEL = "Category"


async def list_categories(
    db: AsyncSession, shop_id: uuid.UUID, include_inactive: bool
) -> list[Category]:
    query = select(Category).where(Category.shop_id == shop_id).order_by(Category.name)
    if not include_inactive:
        query = query.where(Category.is_active)
    return list(await db.scalars(query))


async def create_category(db: AsyncSession, shop_id: uuid.UUID, data: CategoryCreate) -> Category:
    await ensure_name_available(db, Category, shop_id, data.name, LABEL)
    category = Category(shop_id=shop_id, name=data.name)
    db.add(category)
    await commit_or_conflict(db, f'{LABEL} "{data.name}" already exists')
    return category


async def update_category(
    db: AsyncSession, shop_id: uuid.UUID, category_id: uuid.UUID, data: CategoryUpdate
) -> Category:
    category = await get_owned_or_404(db, Category, category_id, shop_id, LABEL)
    if data.name is not None:
        await ensure_name_available(db, Category, shop_id, data.name, LABEL, category.id)
    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(category, field, value)
    await commit_or_conflict(db, f'{LABEL} "{category.name}" already exists')
    return category
