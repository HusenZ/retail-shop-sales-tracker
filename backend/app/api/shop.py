from fastapi import APIRouter, status

from app.api.deps import CurrentShop, CurrentUser, DbSession
from app.schemas.shop import ShopCreate, ShopRead, ShopUpdate
from app.services import shop_service

router = APIRouter(prefix="/shop", tags=["shop"])


@router.post("", status_code=status.HTTP_201_CREATED)
async def create_shop(data: ShopCreate, user: CurrentUser, db: DbSession) -> ShopRead:
    shop = await shop_service.create_shop(db, user, data)
    return ShopRead.model_validate(shop)


@router.get("")
async def get_shop(shop: CurrentShop) -> ShopRead:
    return ShopRead.model_validate(shop)


@router.patch("")
async def update_shop(data: ShopUpdate, shop: CurrentShop, db: DbSession) -> ShopRead:
    shop = await shop_service.update_shop(db, shop, data)
    return ShopRead.model_validate(shop)
