import uuid
from datetime import datetime
from decimal import Decimal

from app.schemas.common import InputModel, LongText, OutputModel, PatchModel, PhoneNumber, ShortText


class CustomerCreate(InputModel):
    name: ShortText
    phone: PhoneNumber | None = None
    notes: LongText | None = None


class CustomerUpdate(PatchModel):
    required_fields = ("name",)

    name: ShortText | None = None
    phone: PhoneNumber | None = None
    notes: LongText | None = None


class CustomerRead(OutputModel):
    id: uuid.UUID
    name: str
    phone: str | None
    notes: str | None
    total_purchases: Decimal
    transaction_count: int
    pending_amount: Decimal
    created_at: datetime
    updated_at: datetime
