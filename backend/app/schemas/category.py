import uuid
from datetime import datetime

from app.schemas.common import InputModel, LabelText, OutputModel, PatchModel


class CategoryCreate(InputModel):
    name: LabelText


class CategoryUpdate(PatchModel):
    required_fields = ("name", "is_active")

    name: LabelText | None = None
    is_active: bool | None = None


class CategoryRead(OutputModel):
    id: uuid.UUID
    name: str
    is_active: bool
    created_at: datetime
    updated_at: datetime
