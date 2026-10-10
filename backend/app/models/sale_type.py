import uuid

from sqlalchemy import ForeignKey, Index, String, UniqueConstraint, text
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base, IdMixin, TimestampMixin


class SaleType(IdMixin, TimestampMixin, Base):
    __tablename__ = "sale_types"
    __table_args__ = (
        UniqueConstraint("shop_id", "name"),
        Index(
            "uq_sale_types_one_default_per_shop",
            "shop_id",
            unique=True,
            postgresql_where=text("is_default"),
        ),
    )

    shop_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("shops.id", ondelete="CASCADE"))
    name: Mapped[str] = mapped_column(String(80))
    is_active: Mapped[bool] = mapped_column(default=True)
    is_default: Mapped[bool] = mapped_column(default=False)
    # Exchange sale types show the old-phone fields when recording a sale.
    is_exchange: Mapped[bool] = mapped_column(default=False)
