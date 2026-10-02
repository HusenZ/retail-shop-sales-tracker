from typing import Annotated

from fastapi import APIRouter, Query

from app.api.deps import CurrentShop, DbSession
from app.schemas.sale import PendingPayments, SaleSummary
from app.services import sale_service
from app.services.sale_service import SaleFilters

router = APIRouter(prefix="/payments", tags=["payments"])

MAX_PENDING_SALES = 200


@router.get("/pending")
async def pending_payments(
    shop: CurrentShop,
    db: DbSession,
    limit: Annotated[int, Query(ge=1, le=MAX_PENDING_SALES)] = MAX_PENDING_SALES,
) -> PendingPayments:
    """Sales with money still to collect, oldest first, plus the overall total."""
    total, count = await sale_service.pending_totals(db, shop.id)
    sales = await sale_service.list_sales(
        db, shop.id, SaleFilters(pending_only=True), limit=limit, oldest_first=True
    )
    return PendingPayments(
        total_pending=total,
        sale_count=count,
        sales=[SaleSummary.model_validate(sale) for sale in sales],
    )
