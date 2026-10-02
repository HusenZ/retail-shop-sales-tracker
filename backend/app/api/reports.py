from datetime import date

from fastapi import APIRouter

from app.api.deps import CurrentShop, DbSession
from app.core.time import shop_today
from app.schemas.report import Dashboard, ReportSummary
from app.services import report_service

router = APIRouter(tags=["reports"])


@router.get("/dashboard")
async def dashboard(shop: CurrentShop, db: DbSession) -> Dashboard:
    return await report_service.dashboard(db, shop.id, shop_today())


@router.get("/reports/summary")
async def report_summary(
    date_from: date, date_to: date, shop: CurrentShop, db: DbSession
) -> ReportSummary:
    """Both dates are required and inclusive, as shop-local days."""
    return await report_service.summary(db, shop.id, date_from, date_to)
