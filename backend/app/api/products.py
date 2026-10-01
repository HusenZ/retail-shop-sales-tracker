import uuid

from fastapi import APIRouter, status

from app.api.deps import CurrentShop, DbSession
from app.models import StockStatus
from app.schemas.product import ProductCreate, ProductRead, ProductUpdate, StockAdjustment
from app.services import product_service

router = APIRouter(prefix="/products", tags=["products"])


@router.get("")
async def list_products(
    shop: CurrentShop,
    db: DbSession,
    search: str | None = None,
    category_id: uuid.UUID | None = None,
    stock_status: StockStatus | None = None,
    include_inactive: bool = False,
) -> list[ProductRead]:
    products = await product_service.list_products(
        db,
        shop.id,
        search=search,
        category_id=category_id,
        stock_status=stock_status,
        include_inactive=include_inactive,
    )
    return [ProductRead.model_validate(product) for product in products]


@router.post("", status_code=status.HTTP_201_CREATED)
async def create_product(data: ProductCreate, shop: CurrentShop, db: DbSession) -> ProductRead:
    product = await product_service.create_product(db, shop.id, data)
    return ProductRead.model_validate(product)


@router.get("/{product_id}")
async def get_product(product_id: uuid.UUID, shop: CurrentShop, db: DbSession) -> ProductRead:
    product = await product_service.get_product(db, shop.id, product_id)
    return ProductRead.model_validate(product)


@router.patch("/{product_id}")
async def update_product(
    product_id: uuid.UUID, data: ProductUpdate, shop: CurrentShop, db: DbSession
) -> ProductRead:
    product = await product_service.update_product(db, shop.id, product_id, data)
    return ProductRead.model_validate(product)


@router.post("/{product_id}/stock-adjustment")
async def adjust_stock(
    product_id: uuid.UUID, data: StockAdjustment, shop: CurrentShop, db: DbSession
) -> ProductRead:
    product = await product_service.adjust_stock(db, shop.id, product_id, data.change)
    return ProductRead.model_validate(product)
