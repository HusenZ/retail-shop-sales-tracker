from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import ConflictError
from app.core.security import hash_password, verify_password
from app.models import User
from app.schemas.auth import RegisterRequest

# Verified against when the email is unknown so login takes the same time either way.
_DUMMY_PASSWORD_HASH = hash_password("not-a-real-password")


def _normalize_email(email: str) -> str:
    return email.strip().lower()


async def register_user(db: AsyncSession, data: RegisterRequest) -> User:
    email = _normalize_email(data.email)
    if await _get_user_by_email(db, email) is not None:
        raise ConflictError("An account with this email already exists")

    user = User(email=email, password_hash=hash_password(data.password), full_name=data.full_name)
    db.add(user)
    try:
        await db.commit()
    except IntegrityError as exc:
        await db.rollback()
        raise ConflictError("An account with this email already exists") from exc
    return user


async def authenticate(db: AsyncSession, email: str, password: str) -> User | None:
    user = await _get_user_by_email(db, _normalize_email(email))
    if user is None:
        verify_password(password, _DUMMY_PASSWORD_HASH)
        return None
    return user if verify_password(password, user.password_hash) else None


async def _get_user_by_email(db: AsyncSession, email: str) -> User | None:
    return await db.scalar(select(User).where(User.email == email))
