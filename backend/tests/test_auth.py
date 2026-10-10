from datetime import UTC, datetime, timedelta

import jwt
from httpx import AsyncClient

from app.core.config import get_settings
from tests.conftest import PASSWORD, register


async def test_register_returns_token_and_user(client: AsyncClient) -> None:
    response = await client.post(
        "/api/v1/auth/register",
        json={"email": "Owner@Example.com", "password": PASSWORD, "full_name": " Ravi "},
    )

    assert response.status_code == 201
    body = response.json()
    assert body["access_token"]
    assert body["token_type"] == "bearer"
    assert body["user"]["email"] == "owner@example.com"
    assert body["user"]["full_name"] == "Ravi"
    assert "password_hash" not in body["user"]


async def test_register_rejects_duplicate_email_case_insensitively(client: AsyncClient) -> None:
    await register(client, "owner@example.com")

    response = await client.post(
        "/api/v1/auth/register",
        json={"email": "OWNER@example.com", "password": PASSWORD, "full_name": "Someone"},
    )

    assert response.status_code == 409


async def test_register_rejects_short_password(client: AsyncClient) -> None:
    response = await client.post(
        "/api/v1/auth/register",
        json={"email": "owner@example.com", "password": "short", "full_name": "Ravi"},
    )

    assert response.status_code == 422


async def test_login_with_correct_password(client: AsyncClient) -> None:
    await register(client)

    response = await client.post(
        "/api/v1/auth/login", json={"email": "OWNER@example.com", "password": PASSWORD}
    )

    assert response.status_code == 200
    assert response.json()["access_token"]


async def test_login_with_wrong_password(client: AsyncClient) -> None:
    await register(client)

    response = await client.post(
        "/api/v1/auth/login", json={"email": "owner@example.com", "password": "wrong-password"}
    )

    assert response.status_code == 401


async def test_login_with_unknown_email(client: AsyncClient) -> None:
    response = await client.post(
        "/api/v1/auth/login", json={"email": "nobody@example.com", "password": PASSWORD}
    )

    assert response.status_code == 401


async def test_me_returns_current_user(client: AsyncClient, auth_headers: dict[str, str]) -> None:
    response = await client.get("/api/v1/auth/me", headers=auth_headers)

    assert response.status_code == 200
    assert response.json()["email"] == "owner@example.com"


async def test_me_requires_token(client: AsyncClient) -> None:
    response = await client.get("/api/v1/auth/me")

    assert response.status_code == 401


async def test_me_rejects_tampered_token(client: AsyncClient) -> None:
    response = await client.get(
        "/api/v1/auth/me", headers={"Authorization": "Bearer not-a-valid-token"}
    )

    assert response.status_code == 401


async def test_me_rejects_expired_token(client: AsyncClient, auth_headers: dict[str, str]) -> None:
    me = (await client.get("/api/v1/auth/me", headers=auth_headers)).json()
    settings = get_settings()
    expired = jwt.encode(
        {"sub": me["id"], "exp": datetime.now(UTC) - timedelta(minutes=1)},
        settings.secret_key,
        algorithm=settings.jwt_algorithm,
    )

    response = await client.get("/api/v1/auth/me", headers={"Authorization": f"Bearer {expired}"})

    assert response.status_code == 401


async def test_password_is_stored_hashed(client: AsyncClient, engine) -> None:  # type: ignore[no-untyped-def]
    from sqlalchemy import text

    await register(client)
    async with engine.connect() as conn:
        stored = await conn.scalar(text("SELECT password_hash FROM users"))

    assert stored != PASSWORD
    assert stored.startswith("$argon2")
