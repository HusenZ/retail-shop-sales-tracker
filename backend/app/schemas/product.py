import uuid
from datetime import datetime
from decimal import Decimal
from typing import Annotated

from pydantic import Field, StringConstraints, field_validator

from app.models.product import DEFAULT_LOW_STOCK_THRESHOLD, StockStatus
from app.schemas.common import InputModel, Money, OutputModel, PatchModel, ShortText

Brand = Annotated[str, StringConstraints(strip_whitespace=True, max_length=80)]
Sku = Annotated[str, StringConstraints(strip_whitespace=True, max_length=64)]
Imei = Annotated[str, StringConstraints(strip_whitespace=True, max_length=20)]
Quantity = Annotated[int, Field(ge=0)]


class ProductCreate(InputModel):
    name: ShortText
    category_id: uuid.UUID
    purchase_price: Money
    selling_price: Money
    stock_qty: Quantity = 0
    track_stock: bool = True
    low_stock_threshold: Quantity = DEFAULT_LOW_STOCK_THRESHOLD
    brand: Brand | None = None
    model: Brand | None = None
    sku: Sku | None = None
    imei: Imei | None = None


class ProductUpdate(PatchModel):
    """Stock is changed only through stock adjustments and sales, never here."""

    required_fields = (
        "name",
        "category_id",
        "purchase_price",
        "selling_price",
        "track_stock",
        "low_stock_threshold",
        "is_active",
    )

    name: ShortText | None = None
    category_id: uuid.UUID | None = None
    purchase_price: Money | None = None
    selling_price: Money | None = None
    track_stock: bool | None = None
    low_stock_threshold: Quantity | None = None
    is_active: bool | None = None
    brand: Brand | None = None
    model: Brand | None = None
    sku: Sku | None = None
    imei: Imei | None = None


class StockAdjustment(InputModel):
    """Positive to add received stock, negative to remove damaged or miscounted items."""

    change: int

    @field_validator("change")
    @classmethod
    def reject_zero(cls, value: int) -> int:
        if value == 0:
            raise ValueError("change must not be zero")
        return value


class ProductRead(OutputModel):
    id: uuid.UUID
    name: str
    category_id: uuid.UUID
    purchase_price: Decimal
    selling_price: Decimal
    track_stock: bool
    stock_qty: int
    low_stock_threshold: int
    stock_status: StockStatus
    is_active: bool
    brand: str | None
    model: str | None
    sku: str | None
    imei: str | None
    created_at: datetime
    updated_at: datetime
