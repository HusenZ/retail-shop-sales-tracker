from httpx import AsyncClient
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncEngine

from tests.conftest import create_shop, register


async def test_create_shop(client: AsyncClient, auth_headers: dict[str, str]) -> None:
    response = await client.post(
        "/api/v1/shop",
        headers=auth_headers,
        json={
            "name": "Ravi Mobiles",
            "owner_name": "Ravi Kumar",
            "phone": "+91 98765-43210",
            "address": "MG Road, Pune",
        },
    )

    assert response.status_code == 201
    body = response.json()
    assert body["name"] == "Ravi Mobiles"
    assert body["phone"] == "+919876543210"
    assert body["address"] == "MG Road, Pune"


async def test_create_shop_address_is_optional(
    client: AsyncClient, auth_headers: dict[str, str]
) -> None:
    shop = await create_shop(client, auth_headers)

    assert shop["address"] is None


async def test_create_shop_rejects_invalid_phone(
    client: AsyncClient, auth_headers: dict[str, str]
) -> None:
    response = await client.post(
        "/api/v1/shop",
        headers=auth_headers,
        json={"name": "Ravi Mobiles", "owner_name": "Ravi", "phone": "12345"},
    )

    assert response.status_code == 422


async def test_user_can_have_only_one_shop(
    client: AsyncClient, shop_headers: dict[str, str]
) -> None:
    response = await client.post(
        "/api/v1/shop",
        headers=shop_headers,
        json={"name": "Second Shop", "owner_name": "Ravi", "phone": "9876543210"},
    )

    assert response.status_code == 409


async def test_create_shop_requires_login(client: AsyncClient) -> None:
    response = await client.post(
        "/api/v1/shop", json={"name": "Shop", "owner_name": "Ravi", "phone": "9876543210"}
    )

    assert response.status_code == 401


async def test_create_shop_adds_default_categories_and_sale_types(
    client: AsyncClient, auth_headers: dict[str, str], engine: AsyncEngine
) -> None:
    shop = await create_shop(client, auth_headers)

    async with engine.connect() as conn:
        categories = (
            await conn.scalars(
                text("SELECT name FROM categories WHERE shop_id = :id"), {"id": shop["id"]}
            )
        ).all()
        sale_types = (
            await conn.execute(
                text("SELECT name, is_default, is_exchange FROM sale_types WHERE shop_id = :id"),
                {"id": shop["id"]},
            )
        ).all()

    assert "Mobile Phones" in categories
    assert [name for name, is_default, _ in sale_types if is_default] == ["New Phone"]
    assert [name for name, _, is_exchange in sale_types if is_exchange] == ["Exchange"]


async def test_get_shop(client: AsyncClient, shop_headers: dict[str, str]) -> None:
    response = await client.get("/api/v1/shop", headers=shop_headers)

    assert response.status_code == 200
    assert response.json()["name"] == "Ravi Mobiles"


async def test_get_shop_before_setup_returns_404(
    client: AsyncClient, auth_headers: dict[str, str]
) -> None:
    response = await client.get("/api/v1/shop", headers=auth_headers)

    assert response.status_code == 404


async def test_update_shop_changes_only_sent_fields(
    client: AsyncClient, shop_headers: dict[str, str]
) -> None:
    response = await client.patch(
        "/api/v1/shop", headers=shop_headers, json={"address": "Station Road"}
    )

    assert response.status_code == 200
    body = response.json()
    assert body["address"] == "Station Road"
    assert body["name"] == "Ravi Mobiles"


async def test_update_shop_can_clear_address(
    client: AsyncClient, shop_headers: dict[str, str]
) -> None:
    await client.patch("/api/v1/shop", headers=shop_headers, json={"address": "Station Road"})

    response = await client.patch("/api/v1/shop", headers=shop_headers, json={"address": None})

    assert response.json()["address"] is None


async def test_update_shop_rejects_clearing_required_field(
    client: AsyncClient, shop_headers: dict[str, str]
) -> None:
    response = await client.patch("/api/v1/shop", headers=shop_headers, json={"name": None})

    assert response.status_code == 422


async def test_update_shop_rejects_unknown_fields(
    client: AsyncClient, shop_headers: dict[str, str]
) -> None:
    response = await client.patch(
        "/api/v1/shop", headers=shop_headers, json={"owner_user_id": "someone-else"}
    )

    assert response.status_code == 422


async def test_each_user_sees_only_their_own_shop(client: AsyncClient) -> None:
    ravi = await register(client, "ravi@example.com")
    await create_shop(client, ravi, name="Ravi Mobiles")
    priya = await register(client, "priya@example.com")
    await create_shop(client, priya, name="Priya Telecom")

    await client.patch("/api/v1/shop", headers=priya, json={"name": "Priya Mobile World"})

    assert (await client.get("/api/v1/shop", headers=ravi)).json()["name"] == "Ravi Mobiles"
    assert (await client.get("/api/v1/shop", headers=priya)).json()["name"] == (
        "Priya Mobile World"
    )
