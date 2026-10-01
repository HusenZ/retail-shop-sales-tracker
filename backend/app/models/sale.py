import uuid
from datetime import datetime
from decimal import Decimal
from enum import StrEnum

from sqlalchemy import CheckConstraint, Enum, ForeignKey, Index, String, Text, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base, IdMixin, TimestampMixin, utc_now


class PaymentMethod(StrEnum):
    CASH = "cash"
    UPI = "upi"
    CARD = "card"
    CREDIT = "credit"
    OTHER = "other"


# Stored as VARCHAR so adding a method later needs no Postgres enum migration.
payment_method_type = Enum(
    PaymentMethod,
    native_enum=False,
    length=20,
    values_callable=lambda methods: [method.value for method in methods],
)


class Sale(IdMixin, TimestampMixin, Base):
    """One customer transaction.

    Money columns are totals of the sale items, stored so history and reports never
    change when product prices are edited later.
    """

    __tablename__ = "sales"
    __table_args__ = (
        # Lets the offline sync queue retry a sale without creating duplicates.
        UniqueConstraint("shop_id", "client_ref"),
        Index("ix_sales_shop_id_sold_at", "shop_id", "sold_at"),
        CheckConstraint("discount >= 0", name="discount_non_negative"),
        CheckConstraint("exchange_value >= 0", name="exchange_value_non_negative"),
        CheckConstraint("amount_due >= 0", name="amount_due_non_negative"),
        CheckConstraint(
            "amount_paid >= 0 AND amount_paid <= amount_due", name="amount_paid_within_due"
        ),
    )

    shop_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("shops.id", ondelete="CASCADE"))
    sale_type_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("sale_types.id", ondelete="RESTRICT"), index=True
    )
    customer_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("customers.id", ondelete="SET NULL"), index=True
    )
    sold_at: Mapped[datetime] = mapped_column(default=utc_now)

    subtotal: Mapped[Decimal]
    discount: Mapped[Decimal] = mapped_column(default=Decimal("0"))
    # Revenue after discount.
    total: Mapped[Decimal]
    total_cost: Mapped[Decimal]
    profit: Mapped[Decimal]
    # Value given for the customer's old phone; reduces what they pay, not revenue.
    exchange_value: Mapped[Decimal] = mapped_column(default=Decimal("0"))
    amount_due: Mapped[Decimal]
    # Sum of payments, kept on the sale so pending amounts are a cheap query.
    amount_paid: Mapped[Decimal] = mapped_column(default=Decimal("0"))

    payment_method: Mapped[PaymentMethod] = mapped_column(payment_method_type)
    notes: Mapped[str | None] = mapped_column(Text)
    exchange_device_name: Mapped[str | None] = mapped_column(String(120))
    exchange_device_imei: Mapped[str | None] = mapped_column(String(20))
    client_ref: Mapped[str | None] = mapped_column(String(64))

    items: Mapped[list["SaleItem"]] = relationship(
        back_populates="sale", cascade="all, delete-orphan", lazy="raise"
    )
    payments: Mapped[list["Payment"]] = relationship(
        back_populates="sale", cascade="all, delete-orphan", lazy="raise"
    )


class SaleItem(IdMixin, TimestampMixin, Base):
    __tablename__ = "sale_items"
    __table_args__ = (
        CheckConstraint("quantity > 0", name="quantity_positive"),
        CheckConstraint("discount >= 0", name="discount_non_negative"),
    )

    sale_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("sales.id", ondelete="CASCADE"), index=True
    )
    product_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("products.id", ondelete="RESTRICT"), index=True
    )
    product_name: Mapped[str] = mapped_column(String(120))
    quantity: Mapped[int]
    unit_price: Mapped[Decimal]
    unit_cost: Mapped[Decimal]
    # Share of the sale discount, stored per item so category reports stay exact.
    discount: Mapped[Decimal] = mapped_column(default=Decimal("0"))
    revenue: Mapped[Decimal]
    cost: Mapped[Decimal]
    profit: Mapped[Decimal]

    sale: Mapped[Sale] = relationship(back_populates="items", lazy="raise")


class Payment(IdMixin, TimestampMixin, Base):
    __tablename__ = "payments"
    __table_args__ = (CheckConstraint("amount > 0", name="amount_positive"),)

    shop_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("shops.id", ondelete="CASCADE"), index=True
    )
    sale_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("sales.id", ondelete="CASCADE"), index=True
    )
    amount: Mapped[Decimal]
    method: Mapped[PaymentMethod] = mapped_column(payment_method_type)
    paid_at: Mapped[datetime] = mapped_column(default=utc_now)

    sale: Mapped[Sale] = relationship(back_populates="payments", lazy="raise")
