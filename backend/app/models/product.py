import uuid
from decimal import Decimal

from sqlalchemy import CheckConstraint, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base, IdMixin, TimestampMixin

DEFAULT_LOW_STOCK_THRESHOLD = 2


class Product(IdMixin, TimestampMixin, Base):
    __tablename__ = "products"
    __table_args__ = (
        CheckConstraint("stock_qty >= 0", name="stock_qty_non_negative"),
        CheckConstraint("purchase_price >= 0", name="purchase_price_non_negative"),
        CheckConstraint("selling_price >= 0", name="selling_price_non_negative"),
        CheckConstraint("low_stock_threshold >= 0", name="low_stock_threshold_non_negative"),
    )

    shop_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("shops.id", ondelete="CASCADE"), index=True
    )
    category_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("categories.id", ondelete="RESTRICT"), index=True
    )
    name: Mapped[str] = mapped_column(String(120))
    brand: Mapped[str | None] = mapped_column(String(80))
    model: Mapped[str | None] = mapped_column(String(80))
    sku: Mapped[str | None] = mapped_column(String(64))
    imei: Mapped[str | None] = mapped_column(String(20))
    purchase_price: Mapped[Decimal]
    selling_price: Mapped[Decimal]
    # Services such as repairs have no stock to count.
    track_stock: Mapped[bool] = mapped_column(default=True)
    stock_qty: Mapped[int] = mapped_column(default=0)
    low_stock_threshold: Mapped[int] = mapped_column(default=DEFAULT_LOW_STOCK_THRESHOLD)
    is_active: Mapped[bool] = mapped_column(default=True)
