from httpx import AsyncClient

URL = "/api/v1/sale-types"


async def _list(client: AsyncClient, headers: dict[str, str], **params):
    return (await client.get(URL, headers=headers, params=params)).json()


async def _by_name(client: AsyncClient, headers: dict[str, str], name: str):
    sale_types = await _list(client, headers, include_inactive=True)
    return next(t for t in sale_types if t["name"] == name)


async def _default_names(client: AsyncClient, headers: dict[str, str]) -> list[str]:
    sale_types = await _list(client, headers, include_inactive=True)
    return [t["name"] for t in sale_types if t["is_default"]]


async def test_create_sale_type(client: AsyncClient, shop_headers: dict[str, str]) -> None:
    response = await client.post(URL, headers=shop_headers, json={"name": "Corporate Sale"})

    assert response.status_code == 201
    body = response.json()
    assert body["is_active"] is True
    assert body["is_default"] is False
    assert body["is_exchange"] is False


async def test_default_sale_type_is_listed_first(
    client: AsyncClient, shop_headers: dict[str, str]
) -> None:
    sale_types = await _list(client, shop_headers)

    assert sale_types[0]["name"] == "New Phone"
    assert sale_types[0]["is_default"] is True


async def test_creating_a_new_default_replaces_the_old_one(
    client: AsyncClient, shop_headers: dict[str, str]
) -> None:
    await client.post(URL, headers=shop_headers, json={"name": "Retailer", "is_default": True})

    assert await _default_names(client, shop_headers) == ["Retailer"]


async def test_selecting_a_default_replaces_the_old_one(
    client: AsyncClient, shop_headers: dict[str, str]
) -> None:
    repair = await _by_name(client, shop_headers, "Repair")

    response = await client.patch(
        f"{URL}/{repair['id']}", headers=shop_headers, json={"is_default": True}
    )

    assert response.status_code == 200
    assert await _default_names(client, shop_headers) == ["Repair"]


async def test_rename_sale_type(client: AsyncClient, shop_headers: dict[str, str]) -> None:
    exchange = await _by_name(client, shop_headers, "Exchange")

    response = await client.patch(
        f"{URL}/{exchange['id']}", headers=shop_headers, json={"name": "Old Phone Exchange"}
    )

    assert response.json()["name"] == "Old Phone Exchange"
    assert response.json()["is_exchange"] is True


async def test_rename_to_existing_name_is_rejected(
    client: AsyncClient, shop_headers: dict[str, str]
) -> None:
    repair = await _by_name(client, shop_headers, "Repair")

    response = await client.patch(
        f"{URL}/{repair['id']}", headers=shop_headers, json={"name": "wholesale"}
    )

    assert response.status_code == 409


async def test_disabled_sale_types_are_hidden_by_default(
    client: AsyncClient, shop_headers: dict[str, str]
) -> None:
    wholesale = await _by_name(client, shop_headers, "Wholesale")

    await client.patch(f"{URL}/{wholesale['id']}", headers=shop_headers, json={"is_active": False})

    assert "Wholesale" not in [t["name"] for t in await _list(client, shop_headers)]


async def test_disabling_the_default_clears_it(
    client: AsyncClient, shop_headers: dict[str, str]
) -> None:
    new_phone = await _by_name(client, shop_headers, "New Phone")

    response = await client.patch(
        f"{URL}/{new_phone['id']}", headers=shop_headers, json={"is_active": False}
    )

    assert response.json()["is_default"] is False
    assert await _default_names(client, shop_headers) == []


async def test_disabled_sale_type_cannot_become_default(
    client: AsyncClient, shop_headers: dict[str, str]
) -> None:
    wholesale = await _by_name(client, shop_headers, "Wholesale")
    url = f"{URL}/{wholesale['id']}"
    await client.patch(url, headers=shop_headers, json={"is_active": False})

    response = await client.patch(url, headers=shop_headers, json={"is_default": True})

    assert response.status_code == 422
    assert await _default_names(client, shop_headers) == ["New Phone"]


async def test_shops_cannot_change_each_others_sale_types(
    client: AsyncClient, shop_headers: dict[str, str], other_shop_headers: dict[str, str]
) -> None:
    mine = await _by_name(client, shop_headers, "Repair")

    response = await client.patch(
        f"{URL}/{mine['id']}", headers=other_shop_headers, json={"is_default": True}
    )

    assert response.status_code == 404
    assert await _default_names(client, shop_headers) == ["New Phone"]
    assert await _default_names(client, other_shop_headers) == ["New Phone"]
