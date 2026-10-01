from fastapi import APIRouter, HTTPException, status

from app.api.deps import CurrentUser, DbSession
from app.core.security import create_access_token
from app.models import User
from app.schemas.auth import AuthResponse, LoginRequest, RegisterRequest, UserRead
from app.services import auth_service

router = APIRouter(prefix="/auth", tags=["auth"])


def _auth_response(user: User) -> AuthResponse:
    return AuthResponse(
        access_token=create_access_token(user.id), user=UserRead.model_validate(user)
    )


@router.post("/register", status_code=status.HTTP_201_CREATED)
async def register(data: RegisterRequest, db: DbSession) -> AuthResponse:
    user = await auth_service.register_user(db, data)
    return _auth_response(user)


@router.post("/login")
async def login(data: LoginRequest, db: DbSession) -> AuthResponse:
    user = await auth_service.authenticate(db, data.email, data.password)
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="Wrong email or password"
        )
    return _auth_response(user)


@router.get("/me")
async def me(user: CurrentUser) -> UserRead:
    return UserRead.model_validate(user)
