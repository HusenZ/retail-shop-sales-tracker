import uuid
from datetime import date
from decimal import Decimal

from sqlalchemy import ColumnElement, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import BusinessRuleError
from app.core.money import ZERO
from app.core.time import shop_today
from app.models import Expense
from app.schemas.expense import ExpenseCreate
from app.services.common import get_owned_or_404


async def list_expenses(
    db: AsyncSession,
    shop_id: uuid.UUID,
    first_day: date | None,
    last_day: date | None,
    limit: int,
) -> tuple[Decimal, list[Expense]]:
    """Expenses in the period (newest first) and their total, which covers every match."""
    conditions = _conditions(shop_id, first_day, last_day)
    total = await db.scalar(
        select(func.coalesce(func.sum(Expense.amount), ZERO)).where(*conditions)
    )
    expenses = await db.scalars(
        select(Expense)
        .where(*conditions)
        .order_by(Expense.spent_on.desc(), Expense.created_at.desc())
        .limit(limit)
    )
    return total or ZERO, list(expenses)


async def create_expense(db: AsyncSession, shop_id: uuid.UUID, data: ExpenseCreate) -> Expense:
    today = shop_today()
    spent_on = data.spent_on or today
    if spent_on > today:
        raise BusinessRuleError("Expense date cannot be in the future")
    expense = Expense(
        shop_id=shop_id, name=data.name, amount=data.amount, spent_on=spent_on, note=data.note
    )
    db.add(expense)
    await db.commit()
    return expense


async def delete_expense(db: AsyncSession, shop_id: uuid.UUID, expense_id: uuid.UUID) -> None:
    expense = await get_owned_or_404(db, Expense, expense_id, shop_id, "Expense")
    await db.delete(expense)
    await db.commit()


def _conditions(
    shop_id: uuid.UUID, first_day: date | None, last_day: date | None
) -> list[ColumnElement[bool]]:
    conditions = [Expense.shop_id == shop_id]
    if first_day is not None:
        conditions.append(Expense.spent_on >= first_day)
    if last_day is not None:
        conditions.append(Expense.spent_on <= last_day)
    return conditions
