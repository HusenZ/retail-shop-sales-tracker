import uuid

from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import BusinessRuleError
from app.models import SaleType
from app.schemas.sale_type import SaleTypeCreate, SaleTypeUpdate
from app.services.common import commit_or_conflict, ensure_name_available, get_owned_or_404

LABEL = "Sale type"


async def list_sale_types(
    db: AsyncSession, shop_id: uuid.UUID, include_inactive: bool
) -> list[SaleType]:
    query = (
        select(SaleType)
        .where(SaleType.shop_id == shop_id)
        # Default first so the app can show it as the preselected chip.
        .order_by(SaleType.is_default.desc(), SaleType.name)
    )
    if not include_inactive:
        query = query.where(SaleType.is_active)
    return list(await db.scalars(query))


async def create_sale_type(db: AsyncSession, shop_id: uuid.UUID, data: SaleTypeCreate) -> SaleType:
    await ensure_name_available(db, SaleType, shop_id, data.name, LABEL)
    if data.is_default:
        await _clear_default(db, shop_id)
    sale_type = SaleType(shop_id=shop_id, **data.model_dump())
    db.add(sale_type)
    await commit_or_conflict(db, f'{LABEL} "{data.name}" already exists')
    return sale_type


async def update_sale_type(
    db: AsyncSession, shop_id: uuid.UUID, sale_type_id: uuid.UUID, data: SaleTypeUpdate
) -> SaleType:
    sale_type = await get_owned_or_404(db, SaleType, sale_type_id, shop_id, LABEL)
    changes = data.model_dump(exclude_unset=True)

    if "name" in changes:
        await ensure_name_available(db, SaleType, shop_id, changes["name"], LABEL, sale_type.id)

    will_be_active = changes.get("is_active", sale_type.is_active)
    if changes.get("is_default") and not will_be_active:
        raise BusinessRuleError("A disabled sale type cannot be the default")
    if not will_be_active:
        # Disabling the default leaves the shop with no default rather than a hidden one.
        changes["is_default"] = False
    if changes.get("is_default") and not sale_type.is_default:
        # Must run before this row is flushed or the one-default-per-shop index rejects it.
        await _clear_default(db, shop_id)

    for field, value in changes.items():
        setattr(sale_type, field, value)
    await commit_or_conflict(db, f'{LABEL} "{sale_type.name}" already exists')
    return sale_type


async def _clear_default(db: AsyncSession, shop_id: uuid.UUID) -> None:
    await db.execute(
        update(SaleType)
        .where(SaleType.shop_id == shop_id, SaleType.is_default)
        .values(is_default=False)
    )
