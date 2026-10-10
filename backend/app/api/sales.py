import uuid
from datetime import date
from typing import Annotated

from fastapi import APIRouter, Query, Response, status

from app.api.deps import CurrentShop, DbSession
from app.models import PaymentMethod
from app.schemas.sale import PaymentCreate, SaleCreate, SaleDetail, SaleSummary
from app.services import sale_service
from app.services.sale_service import SaleFilters

router = APIRouter(prefix="/sales", tags=["sales"])

DEFAULT_PAGE_SIZE = 50
MAX_PAGE_SIZE = 200


@router.post("", status_code=status.HTTP_201_CREATED)
async def create_sale(
    data: SaleCreate, shop: CurrentShop, db: DbSession, response: Response
) -> SaleDetail:
    sale, created = await sale_service.create_sale(db, shop.id, data)
    if not created:
        response.status_code = status.HTTP_200_OK
    return SaleDetail.model_validate(sale)


@router.get("")
async def list_sales(
    shop: CurrentShop,
    db: DbSession,
    date_from: Annotated[date | None, Query(description="First day, shop timezone")] = None,
    date_to: Annotated[date | None, Query(description="Last day (inclusive)")] = None,
    sale_type_id: uuid.UUID | None = None,
    category_id: uuid.UUID | None = None,
    payment_method: PaymentMethod | None = None,
    customer_id: uuid.UUID | None = None,
    pending_only: bool = False,
    limit: Annotated[int, Query(ge=1, le=MAX_PAGE_SIZE)] = DEFAULT_PAGE_SIZE,
    offset: Annotated[int, Query(ge=0)] = 0,
) -> list[SaleSummary]:
    filters = SaleFilters(
        first_day=date_from,
        last_day=date_to,
        sale_type_id=sale_type_id,
        category_id=category_id,
        payment_method=payment_method,
        customer_id=customer_id,
        pending_only=pending_only,
    )
    sales = await sale_service.list_sales(db, shop.id, filters, limit=limit, offset=offset)
    return [SaleSummary.model_validate(sale) for sale in sales]


@router.get("/{sale_id}")
async def get_sale(sale_id: uuid.UUID, shop: CurrentShop, db: DbSession) -> SaleDetail:
    sale = await sale_service.get_sale(db, shop.id, sale_id)
    return SaleDetail.model_validate(sale)


@router.post("/{sale_id}/payments", status_code=status.HTTP_201_CREATED)
async def record_payment(
    sale_id: uuid.UUID, data: PaymentCreate, shop: CurrentShop, db: DbSession
) -> SaleDetail:
    sale = await sale_service.record_payment(db, shop.id, sale_id, data)
    return SaleDetail.model_validate(sale)
