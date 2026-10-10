import uuid
from datetime import date
from typing import Annotated

from fastapi import APIRouter, Query, status

from app.api.deps import CurrentShop, DbSession
from app.schemas.expense import ExpenseCreate, ExpenseList, ExpenseRead
from app.services import expense_service

router = APIRouter(prefix="/expenses", tags=["expenses"])

DEFAULT_PAGE_SIZE = 100
MAX_PAGE_SIZE = 500


@router.get("")
async def list_expenses(
    shop: CurrentShop,
    db: DbSession,
    date_from: date | None = None,
    date_to: date | None = None,
    limit: Annotated[int, Query(ge=1, le=MAX_PAGE_SIZE)] = DEFAULT_PAGE_SIZE,
) -> ExpenseList:
    total, expenses = await expense_service.list_expenses(db, shop.id, date_from, date_to, limit)
    return ExpenseList(
        total=total, expenses=[ExpenseRead.model_validate(expense) for expense in expenses]
    )


@router.post("", status_code=status.HTTP_201_CREATED)
async def create_expense(data: ExpenseCreate, shop: CurrentShop, db: DbSession) -> ExpenseRead:
    expense = await expense_service.create_expense(db, shop.id, data)
    return ExpenseRead.model_validate(expense)


@router.delete("/{expense_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_expense(expense_id: uuid.UUID, shop: CurrentShop, db: DbSession) -> None:
    await expense_service.delete_expense(db, shop.id, expense_id)
