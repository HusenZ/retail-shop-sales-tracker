from datetime import date
from decimal import Decimal

from app.schemas.common import OutputModel


class PeriodTotals(OutputModel):
    first_day: date
    sales_total: Decimal
    sale_count: int
    profit: Decimal


class Dashboard(OutputModel):
    """Everything the home screen shows; periods use the shop's timezone."""

    today: PeriodTotals
    this_week: PeriodTotals
    this_month: PeriodTotals
    pending_total: Decimal
    pending_sale_count: int


class ReportTotals(OutputModel):
    sale_count: int
    revenue: Decimal
    cost: Decimal
    gross_profit: Decimal
    discount: Decimal
    expenses: Decimal
    net_profit: Decimal


class GroupRow(OutputModel):
    id: str
    name: str
    revenue: Decimal
    profit: Decimal
    quantity: int


class MoneyRow(OutputModel):
    # cash / upi / card / other = money received, credit = still pending,
    # exchange = value given for old phones. Together they add up to revenue.
    method: str
    amount: Decimal


class ReportSummary(OutputModel):
    date_from: date
    date_to: date
    totals: ReportTotals
    by_category: list[GroupRow]
    by_sale_type: list[GroupRow]
    by_payment_method: list[MoneyRow]
