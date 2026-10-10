import uuid
from datetime import date
from decimal import Decimal

from sqlalchemy import CheckConstraint, ForeignKey, Index, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base, IdMixin, TimestampMixin


class Expense(IdMixin, TimestampMixin, Base):
    __tablename__ = "expenses"
    __table_args__ = (
        Index("ix_expenses_shop_id_spent_on", "shop_id", "spent_on"),
        CheckConstraint("amount > 0", name="amount_positive"),
    )

    shop_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("shops.id", ondelete="CASCADE"))
    name: Mapped[str] = mapped_column(String(120))
    amount: Mapped[Decimal]
    spent_on: Mapped[date]
    note: Mapped[str | None] = mapped_column(Text)
