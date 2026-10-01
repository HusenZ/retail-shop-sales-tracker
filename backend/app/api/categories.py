import uuid

from fastapi import APIRouter, status

from app.api.deps import CurrentShop, DbSession
from app.schemas.category import CategoryCreate, CategoryRead, CategoryUpdate
from app.services import category_service

router = APIRouter(prefix="/categories", tags=["categories"])


@router.get("")
async def list_categories(
    shop: CurrentShop, db: DbSession, include_inactive: bool = False
) -> list[CategoryRead]:
    categories = await category_service.list_categories(db, shop.id, include_inactive)
    return [CategoryRead.model_validate(category) for category in categories]


@router.post("", status_code=status.HTTP_201_CREATED)
async def create_category(data: CategoryCreate, shop: CurrentShop, db: DbSession) -> CategoryRead:
    category = await category_service.create_category(db, shop.id, data)
    return CategoryRead.model_validate(category)


@router.patch("/{category_id}")
async def update_category(
    category_id: uuid.UUID, data: CategoryUpdate, shop: CurrentShop, db: DbSession
) -> CategoryRead:
    category = await category_service.update_category(db, shop.id, category_id, data)
    return CategoryRead.model_validate(category)
