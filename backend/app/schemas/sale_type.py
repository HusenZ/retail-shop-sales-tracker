import uuid
from datetime import datetime

from app.schemas.common import InputModel, LabelText, OutputModel, PatchModel


class SaleTypeCreate(InputModel):
    name: LabelText
    is_exchange: bool = False
    is_default: bool = False


class SaleTypeUpdate(PatchModel):
    required_fields = ("name", "is_active", "is_exchange", "is_default")

    name: LabelText | None = None
    is_active: bool | None = None
    is_exchange: bool | None = None
    is_default: bool | None = None


class SaleTypeRead(OutputModel):
    id: uuid.UUID
    name: str
    is_active: bool
    is_default: bool
    is_exchange: bool
    created_at: datetime
    updated_at: datetime
