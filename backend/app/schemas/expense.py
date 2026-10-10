import uuid
from datetime import date, datetime
from decimal import Decimal
from typing import Annotated

from pydantic import Field

from app.schemas.common import InputModel, LongText, Money, OutputModel, ShortText


class ExpenseCreate(InputModel):
    name: ShortText
    amount: Annotated[Money, Field(gt=0)]
    # Defaults to today in the shop's timezone.
    spent_on: date | None = None
    note: LongText | None = None


class ExpenseRead(OutputModel):
    id: uuid.UUID
    name: str
    amount: Decimal
    spent_on: date
    note: str | None
    created_at: datetime


class ExpenseList(OutputModel):
    total: Decimal
    expenses: list[ExpenseRead]
