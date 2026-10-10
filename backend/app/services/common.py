"""Helpers shared by services that manage shop-owned records."""

import uuid
from typing import Protocol, TypeVar

from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import BusinessRuleError, ConflictError, NotFoundError
from app.models import Category, SaleType


class ShopOwned(Protocol):
    id: uuid.UUID
    shop_id: uuid.UUID


T = TypeVar("T", bound=ShopOwned)


async def get_owned_or_404(
    db: AsyncSession, model: type[T], record_id: uuid.UUID, shop_id: uuid.UUID, label: str
) -> T:
    """Fetch a record of the given shop; other shops' records are reported as not found."""
    record = await db.get(model, record_id)
    if record is None or record.shop_id != shop_id:
        raise NotFoundError(f"{label} not found")
    return record


async def get_referenced(
    db: AsyncSession, model: type[T], record_id: uuid.UUID, shop_id: uuid.UUID, label: str
) -> T:
    """Like get_owned_or_404, for ids sent inside a request body (a 422, not a 404)."""
    record = await db.get(model, record_id)
    if record is None or record.shop_id != shop_id:
        raise BusinessRuleError(f"{label} not found")
    return record


async def ensure_name_available(
    db: AsyncSession,
    model: type[Category] | type[SaleType],
    shop_id: uuid.UUID,
    name: str,
    label: str,
    exclude_id: uuid.UUID | None = None,
) -> None:
    """Case-insensitive, so "accessories" cannot sit next to "Accessories"."""
    query = select(model.id).where(model.shop_id == shop_id, func.lower(model.name) == name.lower())
    if exclude_id is not None:
        query = query.where(model.id != exclude_id)
    if await db.scalar(query) is not None:
        raise ConflictError(f'{label} "{name}" already exists')


async def commit_or_conflict(db: AsyncSession, message: str) -> None:
    """Commit, reporting a unique-constraint race with another request as a conflict."""
    try:
        await db.commit()
    except IntegrityError as exc:
        await db.rollback()
        raise ConflictError(message) from exc
