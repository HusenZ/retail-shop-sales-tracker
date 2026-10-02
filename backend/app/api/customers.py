import uuid

from fastapi import APIRouter, status

from app.api.deps import CurrentShop, DbSession
from app.schemas.customer import CustomerCreate, CustomerRead, CustomerUpdate
from app.services import customer_service
from app.services.customer_service import CustomerWithStats

router = APIRouter(prefix="/customers", tags=["customers"])


def _to_read(row: CustomerWithStats) -> CustomerRead:
    customer = row.customer
    return CustomerRead(
        id=customer.id,
        name=customer.name,
        phone=customer.phone,
        notes=customer.notes,
        total_purchases=row.total_purchases,
        transaction_count=row.transaction_count,
        pending_amount=row.pending_amount,
        created_at=customer.created_at,
        updated_at=customer.updated_at,
    )


@router.get("")
async def list_customers(
    shop: CurrentShop, db: DbSession, search: str | None = None, pending_only: bool = False
) -> list[CustomerRead]:
    rows = await customer_service.list_customers(
        db, shop.id, search=search, pending_only=pending_only
    )
    return [_to_read(row) for row in rows]


@router.post("", status_code=status.HTTP_201_CREATED)
async def create_customer(data: CustomerCreate, shop: CurrentShop, db: DbSession) -> CustomerRead:
    return _to_read(await customer_service.create_customer(db, shop.id, data))


@router.get("/{customer_id}")
async def get_customer(customer_id: uuid.UUID, shop: CurrentShop, db: DbSession) -> CustomerRead:
    return _to_read(await customer_service.get_customer(db, shop.id, customer_id))


@router.patch("/{customer_id}")
async def update_customer(
    customer_id: uuid.UUID, data: CustomerUpdate, shop: CurrentShop, db: DbSession
) -> CustomerRead:
    return _to_read(await customer_service.update_customer(db, shop.id, customer_id, data))
