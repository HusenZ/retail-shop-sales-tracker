import uuid

from fastapi import APIRouter, status

from app.api.deps import CurrentShop, DbSession
from app.schemas.sale_type import SaleTypeCreate, SaleTypeRead, SaleTypeUpdate
from app.services import sale_type_service

router = APIRouter(prefix="/sale-types", tags=["sale types"])


@router.get("")
async def list_sale_types(
    shop: CurrentShop, db: DbSession, include_inactive: bool = False
) -> list[SaleTypeRead]:
    sale_types = await sale_type_service.list_sale_types(db, shop.id, include_inactive)
    return [SaleTypeRead.model_validate(sale_type) for sale_type in sale_types]


@router.post("", status_code=status.HTTP_201_CREATED)
async def create_sale_type(data: SaleTypeCreate, shop: CurrentShop, db: DbSession) -> SaleTypeRead:
    sale_type = await sale_type_service.create_sale_type(db, shop.id, data)
    return SaleTypeRead.model_validate(sale_type)


@router.patch("/{sale_type_id}")
async def update_sale_type(
    sale_type_id: uuid.UUID, data: SaleTypeUpdate, shop: CurrentShop, db: DbSession
) -> SaleTypeRead:
    sale_type = await sale_type_service.update_sale_type(db, shop.id, sale_type_id, data)
    return SaleTypeRead.model_validate(sale_type)
