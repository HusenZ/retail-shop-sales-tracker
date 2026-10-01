"""Import every model so Alembic and the test suite see the full schema."""

from app.models.category import Category
from app.models.customer import Customer
from app.models.expense import Expense
from app.models.product import Product
from app.models.sale import Payment, PaymentMethod, Sale, SaleItem
from app.models.sale_type import SaleType
from app.models.shop import Shop
from app.models.user import User

__all__ = [
    "Category",
    "Customer",
    "Expense",
    "Payment",
    "PaymentMethod",
    "Product",
    "Sale",
    "SaleItem",
    "SaleType",
    "Shop",
    "User",
]
