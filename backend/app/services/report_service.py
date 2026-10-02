"""Dashboard and report figures, aggregated in PostgreSQL rather than in Python."""

import uuid
from datetime import date, timedelta
from decimal import Decimal
from typing import Any

from sqlalchemy import ColumnElement, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import BusinessRuleError
from app.core.money import ZERO
from app.core.time import month_start, start_of_day, week_start
from app.models import Category, Expense, Payment, Product, Sale, SaleItem, SaleType
from app.schemas.report import (
    Dashboard,
    GroupRow,
    MoneyRow,
    PeriodTotals,
    ReportSummary,
    ReportTotals,
)
from app.services import sale_service

PENDING_ROW = "credit"
EXCHANGE_ROW = "exchange"


async def dashboard(db: AsyncSession, shop_id: uuid.UUID, today: date) -> Dashboard:
    first_days = {
        "today": today,
        "this_week": week_start(today),
        "this_month": month_start(today),
    }
    end = start_of_day(today + timedelta(days=1))

    # One scan of the sales since the earliest period start, split with FILTER clauses.
    columns: list[ColumnElement[Any]] = []
    for first_day in first_days.values():
        in_period = Sale.sold_at >= start_of_day(first_day)
        columns += [
            func.coalesce(func.sum(Sale.total).filter(in_period), ZERO),
            func.count().filter(in_period),
            func.coalesce(func.sum(Sale.profit).filter(in_period), ZERO),
        ]
    earliest = start_of_day(min(first_days.values()))
    row = (
        await db.execute(
            select(*columns).where(
                Sale.shop_id == shop_id, Sale.sold_at >= earliest, Sale.sold_at < end
            )
        )
    ).one()

    periods = {
        name: PeriodTotals(
            first_day=first_day,
            sales_total=row[index * 3],
            sale_count=row[index * 3 + 1],
            profit=row[index * 3 + 2],
        )
        for index, (name, first_day) in enumerate(first_days.items())
    }
    pending_total, pending_count = await sale_service.pending_totals(db, shop_id)
    return Dashboard(**periods, pending_total=pending_total, pending_sale_count=pending_count)


async def summary(
    db: AsyncSession, shop_id: uuid.UUID, first_day: date, last_day: date
) -> ReportSummary:
    if first_day > last_day:
        raise BusinessRuleError("Start date must be on or before end date")

    in_range = _sales_in_range(shop_id, first_day, last_day)
    sale_count, revenue, cost, profit, discount, exchange, pending = (
        await db.execute(
            select(
                func.count(),
                func.coalesce(func.sum(Sale.total), ZERO),
                func.coalesce(func.sum(Sale.total_cost), ZERO),
                func.coalesce(func.sum(Sale.profit), ZERO),
                func.coalesce(func.sum(Sale.discount), ZERO),
                func.coalesce(func.sum(Sale.exchange_value), ZERO),
                func.coalesce(func.sum(Sale.amount_due - Sale.amount_paid), ZERO),
            ).where(*in_range)
        )
    ).one()
    expenses = await _expenses_total(db, shop_id, first_day, last_day)

    return ReportSummary(
        date_from=first_day,
        date_to=last_day,
        totals=ReportTotals(
            sale_count=sale_count,
            revenue=revenue,
            cost=cost,
            gross_profit=profit,
            discount=discount,
            expenses=expenses,
            net_profit=profit - expenses,
        ),
        by_category=await _by_category(db, in_range),
        by_sale_type=await _by_sale_type(db, in_range),
        by_payment_method=await _by_payment_method(db, in_range, pending, exchange),
    )


def _sales_in_range(
    shop_id: uuid.UUID, first_day: date, last_day: date
) -> list[ColumnElement[bool]]:
    return [
        Sale.shop_id == shop_id,
        Sale.sold_at >= start_of_day(first_day),
        Sale.sold_at < start_of_day(last_day + timedelta(days=1)),
    ]


async def _by_category(db: AsyncSession, in_range: list[ColumnElement[bool]]) -> list[GroupRow]:
    revenue = func.sum(SaleItem.revenue)
    rows = await db.execute(
        select(
            Category.id,
            Category.name,
            revenue,
            func.sum(SaleItem.profit),
            func.sum(SaleItem.quantity),
        )
        .select_from(SaleItem)
        .join(Sale, Sale.id == SaleItem.sale_id)
        .join(Product, Product.id == SaleItem.product_id)
        .join(Category, Category.id == Product.category_id)
        .where(*in_range)
        .group_by(Category.id, Category.name)
        .order_by(revenue.desc(), Category.name)
    )
    return [_group_row(*row) for row in rows]


async def _by_sale_type(db: AsyncSession, in_range: list[ColumnElement[bool]]) -> list[GroupRow]:
    revenue = func.sum(Sale.total)
    rows = await db.execute(
        select(SaleType.id, SaleType.name, revenue, func.sum(Sale.profit), func.count())
        .join(SaleType, SaleType.id == Sale.sale_type_id)
        .where(*in_range)
        .group_by(SaleType.id, SaleType.name)
        .order_by(revenue.desc(), SaleType.name)
    )
    return [_group_row(*row) for row in rows]


async def _by_payment_method(
    db: AsyncSession,
    in_range: list[ColumnElement[bool]],
    pending: Decimal,
    exchange: Decimal,
) -> list[MoneyRow]:
    """How the revenue of these sales was settled.

    Payments count toward the sale they belong to, so money collected later for a
    credit sale moves from "credit" to its real method within the sale's period.
    """
    received = await db.execute(
        select(Payment.method, func.sum(Payment.amount))
        .join(Sale, Sale.id == Payment.sale_id)
        .where(*in_range)
        .group_by(Payment.method)
    )
    rows = [MoneyRow(method=method.value, amount=amount) for method, amount in received]
    rows += [
        MoneyRow(method=name, amount=amount)
        for name, amount in ((PENDING_ROW, pending), (EXCHANGE_ROW, exchange))
        if amount > ZERO
    ]
    return sorted(rows, key=lambda row: (-row.amount, row.method))


async def _expenses_total(
    db: AsyncSession, shop_id: uuid.UUID, first_day: date, last_day: date
) -> Decimal:
    total = await db.scalar(
        select(func.coalesce(func.sum(Expense.amount), ZERO)).where(
            Expense.shop_id == shop_id,
            Expense.spent_on >= first_day,
            Expense.spent_on <= last_day,
        )
    )
    return total or ZERO


def _group_row(
    group_id: uuid.UUID, name: str, revenue: Decimal, profit: Decimal, quantity: int
) -> GroupRow:
    return GroupRow(id=str(group_id), name=name, revenue=revenue, profit=profit, quantity=quantity)
