import os

TEST_DATABASE_URL = os.environ.get(
    "TEST_DATABASE_URL", "postgresql+asyncpg://shop:shop@localhost:5432/shop_tracker_test"
)
# Point the app at the test database before any app module creates its engine.
os.environ["DATABASE_URL"] = TEST_DATABASE_URL
os.environ.setdefault("SECRET_KEY", "test-secret-key-that-is-long-enough-for-hs256")

from collections.abc import AsyncIterator

import pytest
from httpx import ASGITransport, AsyncClient
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncEngine, async_sessionmaker, create_async_engine
from sqlalchemy.pool import NullPool

from app.db.base import Base
from app.db.session import get_db
from app.main import app

PASSWORD = "secret-password"


@pytest.fixture(scope="session")
async def engine() -> AsyncIterator[AsyncEngine]:
    engine = create_async_engine(TEST_DATABASE_URL, poolclass=NullPool)
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
        await conn.run_sync(Base.metadata.create_all)
    yield engine
    await engine.dispose()


@pytest.fixture(autouse=True)
async def clean_tables(engine: AsyncEngine) -> AsyncIterator[None]:
    yield
    tables = ", ".join(table.name for table in Base.metadata.sorted_tables)
    async with engine.begin() as conn:
        await conn.execute(text(f"TRUNCATE {tables} CASCADE"))


@pytest.fixture
async def client(engine: AsyncEngine) -> AsyncIterator[AsyncClient]:
    session_factory = async_sessionmaker(engine, expire_on_commit=False)

    async def override_get_db():  # type: ignore[no-untyped-def]
        async with session_factory() as session:
            yield session

    app.dependency_overrides[get_db] = override_get_db
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        yield client
    app.dependency_overrides.clear()


async def register(client: AsyncClient, email: str = "owner@example.com") -> dict[str, str]:
    response = await client.post(
        "/api/v1/auth/register",
        json={"email": email, "password": PASSWORD, "full_name": "Ravi Kumar"},
    )
    assert response.status_code == 201, response.text
    return {"Authorization": f"Bearer {response.json()['access_token']}"}


async def create_shop(client: AsyncClient, headers: dict[str, str], name: str = "Ravi Mobiles"):
    response = await client.post(
        "/api/v1/shop",
        headers=headers,
        json={"name": name, "owner_name": "Ravi Kumar", "phone": "9876543210"},
    )
    assert response.status_code == 201, response.text
    return response.json()


@pytest.fixture
async def auth_headers(client: AsyncClient) -> dict[str, str]:
    return await register(client)


@pytest.fixture
async def shop_headers(client: AsyncClient, auth_headers: dict[str, str]) -> dict[str, str]:
    await create_shop(client, auth_headers)
    return auth_headers


@pytest.fixture
async def other_shop_headers(client: AsyncClient) -> dict[str, str]:
    """A second, unrelated shop for isolation tests."""
    headers = await register(client, "other@example.com")
    await create_shop(client, headers, name="Other Mobiles")
    return headers


async def category_id(
    client: AsyncClient, headers: dict[str, str], name: str = "Mobile Phones"
) -> str:
    response = await client.get("/api/v1/categories", headers=headers)
    return str(next(c["id"] for c in response.json() if c["name"] == name))


async def create_product(client: AsyncClient, headers: dict[str, str], **overrides):
    payload = {
        "name": "Samsung A16",
        "category_id": await category_id(client, headers),
        "purchase_price": "14200.00",
        "selling_price": "15999.00",
        "stock_qty": 5,
    }
    payload.update(overrides)
    response = await client.post("/api/v1/products", headers=headers, json=payload)
    assert response.status_code == 201, response.text
    return response.json()


async def sale_type_id(
    client: AsyncClient, headers: dict[str, str], name: str = "New Phone"
) -> str:
    response = await client.get(
        "/api/v1/sale-types", headers=headers, params={"include_inactive": True}
    )
    return str(next(t["id"] for t in response.json() if t["name"] == name))


async def create_customer(
    client: AsyncClient, headers: dict[str, str], name: str = "Rahul", **fields: str
) -> str:
    response = await client.post(
        "/api/v1/customers", headers=headers, json={"name": name, **fields}
    )
    assert response.status_code == 201, response.text
    return str(response.json()["id"])


async def post_sale(client: AsyncClient, headers: dict[str, str], product_id: str, **overrides):
    payload = {
        "sale_type_id": await sale_type_id(client, headers),
        "items": [{"product_id": product_id, "quantity": 1}],
        "payment_method": "upi",
    }
    payload.update(overrides)
    return await client.post("/api/v1/sales", headers=headers, json=payload)


async def stock_of(client: AsyncClient, headers: dict[str, str], product_id: str) -> int:
    response = await client.get(f"/api/v1/products/{product_id}", headers=headers)
    return int(response.json()["stock_qty"])
