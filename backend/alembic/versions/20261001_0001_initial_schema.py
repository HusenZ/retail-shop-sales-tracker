"""initial schema

Revision ID: 0001
Revises:
Create Date: 2026-10-01 05:11:24.662221
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0001"
down_revision: str | None = None
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "users",
        sa.Column("email", sa.String(length=255), nullable=False),
        sa.Column("password_hash", sa.String(length=255), nullable=False),
        sa.Column("full_name", sa.String(length=120), nullable=False),
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_users")),
        sa.UniqueConstraint("email", name=op.f("uq_users_email")),
    )
    op.create_table(
        "shops",
        sa.Column("owner_user_id", sa.Uuid(), nullable=False),
        sa.Column("name", sa.String(length=120), nullable=False),
        sa.Column("owner_name", sa.String(length=120), nullable=False),
        sa.Column("phone", sa.String(length=20), nullable=False),
        sa.Column("address", sa.Text(), nullable=True),
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(
            ["owner_user_id"],
            ["users.id"],
            name=op.f("fk_shops_owner_user_id_users"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_shops")),
        sa.UniqueConstraint("owner_user_id", name=op.f("uq_shops_owner_user_id")),
    )
    op.create_table(
        "categories",
        sa.Column("shop_id", sa.Uuid(), nullable=False),
        sa.Column("name", sa.String(length=80), nullable=False),
        sa.Column("is_active", sa.Boolean(), nullable=False),
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(
            ["shop_id"], ["shops.id"], name=op.f("fk_categories_shop_id_shops"), ondelete="CASCADE"
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_categories")),
        sa.UniqueConstraint("shop_id", "name", name=op.f("uq_categories_shop_id_name")),
    )
    op.create_table(
        "customers",
        sa.Column("shop_id", sa.Uuid(), nullable=False),
        sa.Column("name", sa.String(length=120), nullable=False),
        sa.Column("phone", sa.String(length=20), nullable=True),
        sa.Column("notes", sa.Text(), nullable=True),
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(
            ["shop_id"], ["shops.id"], name=op.f("fk_customers_shop_id_shops"), ondelete="CASCADE"
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_customers")),
    )
    op.create_index("ix_customers_shop_id_phone", "customers", ["shop_id", "phone"], unique=False)
    op.create_table(
        "expenses",
        sa.Column("shop_id", sa.Uuid(), nullable=False),
        sa.Column("name", sa.String(length=120), nullable=False),
        sa.Column("amount", sa.Numeric(precision=12, scale=2), nullable=False),
        sa.Column("spent_on", sa.Date(), nullable=False),
        sa.Column("note", sa.Text(), nullable=True),
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.CheckConstraint("amount > 0", name=op.f("ck_expenses_amount_positive")),
        sa.ForeignKeyConstraint(
            ["shop_id"], ["shops.id"], name=op.f("fk_expenses_shop_id_shops"), ondelete="CASCADE"
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_expenses")),
    )
    op.create_index(
        "ix_expenses_shop_id_spent_on", "expenses", ["shop_id", "spent_on"], unique=False
    )
    op.create_table(
        "sale_types",
        sa.Column("shop_id", sa.Uuid(), nullable=False),
        sa.Column("name", sa.String(length=80), nullable=False),
        sa.Column("is_active", sa.Boolean(), nullable=False),
        sa.Column("is_default", sa.Boolean(), nullable=False),
        sa.Column("is_exchange", sa.Boolean(), nullable=False),
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(
            ["shop_id"], ["shops.id"], name=op.f("fk_sale_types_shop_id_shops"), ondelete="CASCADE"
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_sale_types")),
        sa.UniqueConstraint("shop_id", "name", name=op.f("uq_sale_types_shop_id_name")),
    )
    op.create_index(
        "uq_sale_types_one_default_per_shop",
        "sale_types",
        ["shop_id"],
        unique=True,
        postgresql_where=sa.text("is_default"),
    )
    op.create_table(
        "products",
        sa.Column("shop_id", sa.Uuid(), nullable=False),
        sa.Column("category_id", sa.Uuid(), nullable=False),
        sa.Column("name", sa.String(length=120), nullable=False),
        sa.Column("brand", sa.String(length=80), nullable=True),
        sa.Column("model", sa.String(length=80), nullable=True),
        sa.Column("sku", sa.String(length=64), nullable=True),
        sa.Column("imei", sa.String(length=20), nullable=True),
        sa.Column("purchase_price", sa.Numeric(precision=12, scale=2), nullable=False),
        sa.Column("selling_price", sa.Numeric(precision=12, scale=2), nullable=False),
        sa.Column("track_stock", sa.Boolean(), nullable=False),
        sa.Column("stock_qty", sa.Integer(), nullable=False),
        sa.Column("low_stock_threshold", sa.Integer(), nullable=False),
        sa.Column("is_active", sa.Boolean(), nullable=False),
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.CheckConstraint(
            "low_stock_threshold >= 0", name=op.f("ck_products_low_stock_threshold_non_negative")
        ),
        sa.CheckConstraint(
            "purchase_price >= 0", name=op.f("ck_products_purchase_price_non_negative")
        ),
        sa.CheckConstraint(
            "selling_price >= 0", name=op.f("ck_products_selling_price_non_negative")
        ),
        sa.CheckConstraint("stock_qty >= 0", name=op.f("ck_products_stock_qty_non_negative")),
        sa.ForeignKeyConstraint(
            ["category_id"],
            ["categories.id"],
            name=op.f("fk_products_category_id_categories"),
            ondelete="RESTRICT",
        ),
        sa.ForeignKeyConstraint(
            ["shop_id"], ["shops.id"], name=op.f("fk_products_shop_id_shops"), ondelete="CASCADE"
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_products")),
    )
    op.create_index(op.f("ix_products_category_id"), "products", ["category_id"], unique=False)
    op.create_index(op.f("ix_products_shop_id"), "products", ["shop_id"], unique=False)
    op.create_table(
        "sales",
        sa.Column("shop_id", sa.Uuid(), nullable=False),
        sa.Column("sale_type_id", sa.Uuid(), nullable=False),
        sa.Column("customer_id", sa.Uuid(), nullable=True),
        sa.Column("sold_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("subtotal", sa.Numeric(precision=12, scale=2), nullable=False),
        sa.Column("discount", sa.Numeric(precision=12, scale=2), nullable=False),
        sa.Column("total", sa.Numeric(precision=12, scale=2), nullable=False),
        sa.Column("total_cost", sa.Numeric(precision=12, scale=2), nullable=False),
        sa.Column("profit", sa.Numeric(precision=12, scale=2), nullable=False),
        sa.Column("exchange_value", sa.Numeric(precision=12, scale=2), nullable=False),
        sa.Column("amount_due", sa.Numeric(precision=12, scale=2), nullable=False),
        sa.Column("amount_paid", sa.Numeric(precision=12, scale=2), nullable=False),
        sa.Column(
            "payment_method",
            sa.Enum(
                "cash",
                "upi",
                "card",
                "credit",
                "other",
                name="paymentmethod",
                native_enum=False,
                length=20,
            ),
            nullable=False,
        ),
        sa.Column("notes", sa.Text(), nullable=True),
        sa.Column("exchange_device_name", sa.String(length=120), nullable=True),
        sa.Column("exchange_device_imei", sa.String(length=20), nullable=True),
        sa.Column("client_ref", sa.String(length=64), nullable=True),
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.CheckConstraint("amount_due >= 0", name=op.f("ck_sales_amount_due_non_negative")),
        sa.CheckConstraint(
            "amount_paid >= 0 AND amount_paid <= amount_due",
            name=op.f("ck_sales_amount_paid_within_due"),
        ),
        sa.CheckConstraint("discount >= 0", name=op.f("ck_sales_discount_non_negative")),
        sa.CheckConstraint(
            "exchange_value >= 0", name=op.f("ck_sales_exchange_value_non_negative")
        ),
        sa.ForeignKeyConstraint(
            ["customer_id"],
            ["customers.id"],
            name=op.f("fk_sales_customer_id_customers"),
            ondelete="SET NULL",
        ),
        sa.ForeignKeyConstraint(
            ["sale_type_id"],
            ["sale_types.id"],
            name=op.f("fk_sales_sale_type_id_sale_types"),
            ondelete="RESTRICT",
        ),
        sa.ForeignKeyConstraint(
            ["shop_id"], ["shops.id"], name=op.f("fk_sales_shop_id_shops"), ondelete="CASCADE"
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_sales")),
        sa.UniqueConstraint("shop_id", "client_ref", name=op.f("uq_sales_shop_id_client_ref")),
    )
    op.create_index(op.f("ix_sales_customer_id"), "sales", ["customer_id"], unique=False)
    op.create_index(op.f("ix_sales_sale_type_id"), "sales", ["sale_type_id"], unique=False)
    op.create_index("ix_sales_shop_id_sold_at", "sales", ["shop_id", "sold_at"], unique=False)
    op.create_table(
        "payments",
        sa.Column("shop_id", sa.Uuid(), nullable=False),
        sa.Column("sale_id", sa.Uuid(), nullable=False),
        sa.Column("amount", sa.Numeric(precision=12, scale=2), nullable=False),
        sa.Column(
            "method",
            sa.Enum(
                "cash",
                "upi",
                "card",
                "credit",
                "other",
                name="paymentmethod",
                native_enum=False,
                length=20,
            ),
            nullable=False,
        ),
        sa.Column("paid_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.CheckConstraint("amount > 0", name=op.f("ck_payments_amount_positive")),
        sa.ForeignKeyConstraint(
            ["sale_id"], ["sales.id"], name=op.f("fk_payments_sale_id_sales"), ondelete="CASCADE"
        ),
        sa.ForeignKeyConstraint(
            ["shop_id"], ["shops.id"], name=op.f("fk_payments_shop_id_shops"), ondelete="CASCADE"
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_payments")),
    )
    op.create_index(op.f("ix_payments_sale_id"), "payments", ["sale_id"], unique=False)
    op.create_index(op.f("ix_payments_shop_id"), "payments", ["shop_id"], unique=False)
    op.create_table(
        "sale_items",
        sa.Column("sale_id", sa.Uuid(), nullable=False),
        sa.Column("product_id", sa.Uuid(), nullable=False),
        sa.Column("product_name", sa.String(length=120), nullable=False),
        sa.Column("quantity", sa.Integer(), nullable=False),
        sa.Column("unit_price", sa.Numeric(precision=12, scale=2), nullable=False),
        sa.Column("unit_cost", sa.Numeric(precision=12, scale=2), nullable=False),
        sa.Column("discount", sa.Numeric(precision=12, scale=2), nullable=False),
        sa.Column("revenue", sa.Numeric(precision=12, scale=2), nullable=False),
        sa.Column("cost", sa.Numeric(precision=12, scale=2), nullable=False),
        sa.Column("profit", sa.Numeric(precision=12, scale=2), nullable=False),
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.CheckConstraint("discount >= 0", name=op.f("ck_sale_items_discount_non_negative")),
        sa.CheckConstraint("quantity > 0", name=op.f("ck_sale_items_quantity_positive")),
        sa.ForeignKeyConstraint(
            ["product_id"],
            ["products.id"],
            name=op.f("fk_sale_items_product_id_products"),
            ondelete="RESTRICT",
        ),
        sa.ForeignKeyConstraint(
            ["sale_id"], ["sales.id"], name=op.f("fk_sale_items_sale_id_sales"), ondelete="CASCADE"
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_sale_items")),
    )
    op.create_index(op.f("ix_sale_items_product_id"), "sale_items", ["product_id"], unique=False)
    op.create_index(op.f("ix_sale_items_sale_id"), "sale_items", ["sale_id"], unique=False)


def downgrade() -> None:
    op.drop_index(op.f("ix_sale_items_sale_id"), table_name="sale_items")
    op.drop_index(op.f("ix_sale_items_product_id"), table_name="sale_items")
    op.drop_table("sale_items")
    op.drop_index(op.f("ix_payments_shop_id"), table_name="payments")
    op.drop_index(op.f("ix_payments_sale_id"), table_name="payments")
    op.drop_table("payments")
    op.drop_index("ix_sales_shop_id_sold_at", table_name="sales")
    op.drop_index(op.f("ix_sales_sale_type_id"), table_name="sales")
    op.drop_index(op.f("ix_sales_customer_id"), table_name="sales")
    op.drop_table("sales")
    op.drop_index(op.f("ix_products_shop_id"), table_name="products")
    op.drop_index(op.f("ix_products_category_id"), table_name="products")
    op.drop_table("products")
    op.drop_index(
        "uq_sale_types_one_default_per_shop",
        table_name="sale_types",
        postgresql_where=sa.text("is_default"),
    )
    op.drop_table("sale_types")
    op.drop_index("ix_expenses_shop_id_spent_on", table_name="expenses")
    op.drop_table("expenses")
    op.drop_index("ix_customers_shop_id_phone", table_name="customers")
    op.drop_table("customers")
    op.drop_table("categories")
    op.drop_table("shops")
    op.drop_table("users")
