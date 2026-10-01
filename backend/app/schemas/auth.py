import uuid
from datetime import datetime
from typing import Annotated, Literal

from pydantic import EmailStr, StringConstraints

from app.schemas.common import InputModel, OutputModel, ShortText

MIN_PASSWORD_LENGTH = 8
MAX_PASSWORD_LENGTH = 128

Password = Annotated[
    str, StringConstraints(min_length=MIN_PASSWORD_LENGTH, max_length=MAX_PASSWORD_LENGTH)
]


class RegisterRequest(InputModel):
    email: EmailStr
    password: Password
    full_name: ShortText


class LoginRequest(InputModel):
    email: EmailStr
    password: Annotated[str, StringConstraints(max_length=MAX_PASSWORD_LENGTH)]


class UserRead(OutputModel):
    id: uuid.UUID
    email: str
    full_name: str
    created_at: datetime


class AuthResponse(OutputModel):
    access_token: str
    token_type: Literal["bearer"] = "bearer"
    user: UserRead
