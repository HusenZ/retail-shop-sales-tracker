from fastapi import APIRouter

from app.api import auth, categories, payments, products, sale_types, sales, shop

api_router = APIRouter(prefix="/api/v1")
api_router.include_router(auth.router)
api_router.include_router(shop.router)
api_router.include_router(categories.router)
api_router.include_router(sale_types.router)
api_router.include_router(products.router)
api_router.include_router(sales.router)
api_router.include_router(payments.router)
