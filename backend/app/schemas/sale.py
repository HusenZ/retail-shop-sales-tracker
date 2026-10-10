import uuid
from datetime import datetime
from decimal import Decimal
from typing import Annotated

from pydantic import AwareDatetime, Field, StringConstraints, field_validator

from app.models import PaymentMethod
from app.schemas.common import InputModel, LongText, Money, OutputModel, ShortText
from app.schemas.product import Imei

# Guards against typos such as 1000 instead of 1; no small shop sells this many in one bill.
MAX_ITEM_QUANTITY = 999
MAX_ITEMS_PER_SALE = 50

ClientRef = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=64)]


class SaleItemInput(InputModel):
    product_id: uuid.UUID
    quantity: Annotated[int, Field(gt=0, le=MAX_ITEM_QUANTITY)] = 1
    # Defaults to the product's selling price; sent only when the shopkeeper changes it.
    unit_price: Money | None = None


class ExchangeInput(InputModel):
    device_name: ShortText
    imei: Imei | None = None
    value: Money


class SaleCreate(InputModel):
    sale_type_id: uuid.UUID
    items: Annotated[list[SaleItemInput], Field(min_length=1, max_length=MAX_ITEMS_PER_SALE)]
    payment_method: PaymentMethod
    discount: Money = Decimal("0")
    # Defaults to the full amount due, or nothing for credit sales.
    amount_paid: Money | None = None
    customer_id: uuid.UUID | None = None
    notes: LongText | None = None
    exchange: ExchangeInput | None = None
    # Set by the offline queue to keep the time the sale really happened.
    sold_at: AwareDatetime | None = None
    # Generated once per sale by the app so a retried upload is not saved twice.
    client_ref: ClientRef | None = None

    @field_validator("items")
    @classmethod
    def reject_repeated_products(cls, items: list[SaleItemInput]) -> list[SaleItemInput]:
        product_ids = [item.product_id for item in items]
        if len(product_ids) != len(set(product_ids)):
            raise ValueError("Each product can appear only once; increase its quantity instead")
        return items


class PaymentCreate(InputModel):
    amount: Annotated[Money, Field(gt=0)]
    method: PaymentMethod
    paid_at: AwareDatetime | None = None

    @field_validator("method")
    @classmethod
    def reject_credit(cls, method: PaymentMethod) -> PaymentMethod:
        if method is PaymentMethod.CREDIT:
            raise ValueError("A payment must be cash, UPI, card or other")
        return method


class SaleItemRead(OutputModel):
    id: uuid.UUID
    product_id: uuid.UUID
    product_name: str
    quantity: int
    unit_price: Decimal
    unit_cost: Decimal
    discount: Decimal
    revenue: Decimal
    cost: Decimal
    profit: Decimal


class PaymentRead(OutputModel):
    id: uuid.UUID
    amount: Decimal
    method: PaymentMethod
    paid_at: datetime


class SaleSummary(OutputModel):
    id: uuid.UUID
    sold_at: datetime
    sale_type_id: uuid.UUID
    sale_type_name: str
    customer_id: uuid.UUID | None
    customer_name: str | None
    product_names: list[str]
    payment_method: PaymentMethod
    total: Decimal
    profit: Decimal
    amount_due: Decimal
    amount_paid: Decimal
    pending_amount: Decimal


class SaleDetail(SaleSummary):
    subtotal: Decimal
    discount: Decimal
    total_cost: Decimal
    exchange_value: Decimal
    exchange_device_name: str | None
    exchange_device_imei: str | None
    notes: str | None
    client_ref: str | None
    items: list[SaleItemRead]
    payments: list[PaymentRead]
    created_at: datetime


class PendingPayments(OutputModel):
    total_pending: Decimal
    sale_count: int
    sales: list[SaleSummary]
