import uuid
from datetime import datetime

from app.schemas.common import InputModel, LongText, OutputModel, PatchModel, PhoneNumber, ShortText


class ShopCreate(InputModel):
    name: ShortText
    owner_name: ShortText
    phone: PhoneNumber
    address: LongText | None = None


class ShopUpdate(PatchModel):
    required_fields = ("name", "owner_name", "phone")

    name: ShortText | None = None
    owner_name: ShortText | None = None
    phone: PhoneNumber | None = None
    address: LongText | None = None


class ShopRead(OutputModel):
    id: uuid.UUID
    name: str
    owner_name: str
    phone: str
    address: str | None
    created_at: datetime
    updated_at: datetime
