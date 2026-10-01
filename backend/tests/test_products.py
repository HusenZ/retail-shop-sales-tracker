from httpx import AsyncClient

from tests.conftest import category_id, create_product

URL = "/api/v1/products"


async def test_create_product_keeps_exact_money_values(
    client: AsyncClient, shop_headers: dict[str, str]
) -> None:
    product = await create_product(
        client, shop_headers, purchase_price="14200.10", selling_price=15999.99
    )

    assert product["purchase_price"] == "14200.10"
    assert product["selling_price"] == "15999.99"
    assert product["stock_qty"] == 5
    assert product["stock_status"] == "in_stock"


async def test_optional_fields_can_be_omitted(
    client: AsyncClient, shop_headers: dict[str, str]
) -> None:
    product = await create_product(client, shop_headers)

    assert product["brand"] is None
    assert product["imei"] is None


async def test_money_with_more_than_two_decimals_is_rejected(
    client: AsyncClient, shop_headers: dict[str, str]
) -> None:
    response = await client.post(
        URL,
        headers=shop_headers,
        json={
            "name": "Cable",
            "category_id": await category_id(client, shop_headers),
            "purchase_price": "10.123",
            "selling_price": "20",
        },
    )

    assert response.status_code == 422


async def test_negative_price_or_stock_is_rejected(
    client: AsyncClient, shop_headers: dict[str, str]
) -> None:
    phones = await category_id(client, shop_headers)
    base = {"name": "Cable", "category_id": phones, "purchase_price": "10"}

    negative_price = await client.post(
        URL, headers=shop_headers, json={**base, "selling_price": "-1"}
    )
    negative_stock = await client.post(
        URL, headers=shop_headers, json={**base, "selling_price": "20", "stock_qty": -1}
    )

    assert negative_price.status_code == 422
    assert negative_stock.status_code == 422


async def test_product_cannot_use_another_shops_category(
    client: AsyncClient, shop_headers: dict[str, str], other_shop_headers: dict[str, str]
) -> None:
    others_category = await category_id(client, other_shop_headers)

    response = await client.post(
        URL,
        headers=shop_headers,
        json={
            "name": "Cable",
            "category_id": others_category,
            "purchase_price": "10",
            "selling_price": "20",
        },
    )

    assert response.status_code == 422


async def test_product_cannot_use_a_disabled_category(
    client: AsyncClient, shop_headers: dict[str, str]
) -> None:
    phones = await category_id(client, shop_headers)
    await client.patch(
        f"/api/v1/categories/{phones}", headers=shop_headers, json={"is_active": False}
    )

    response = await client.post(
        URL,
        headers=shop_headers,
        json={
            "name": "Cable",
            "category_id": phones,
            "purchase_price": "10",
            "selling_price": "20",
        },
    )

    assert response.status_code == 422


async def test_get_product(client: AsyncClient, shop_headers: dict[str, str]) -> None:
    product = await create_product(client, shop_headers)

    response = await client.get(f"{URL}/{product['id']}", headers=shop_headers)

    assert response.status_code == 200
    assert response.json()["name"] == "Samsung A16"


async def test_update_product(client: AsyncClient, shop_headers: dict[str, str]) -> None:
    product = await create_product(client, shop_headers)

    response = await client.patch(
        f"{URL}/{product['id']}",
        headers=shop_headers,
        json={"selling_price": "15499.00", "brand": "Samsung"},
    )

    assert response.status_code == 200
    assert response.json()["selling_price"] == "15499.00"
    assert response.json()["brand"] == "Samsung"
    assert response.json()["purchase_price"] == "14200.00"


async def test_stock_cannot_be_set_through_update(
    client: AsyncClient, shop_headers: dict[str, str]
) -> None:
    product = await create_product(client, shop_headers)

    response = await client.patch(
        f"{URL}/{product['id']}", headers=shop_headers, json={"stock_qty": 100}
    )

    assert response.status_code == 422


async def test_disabled_products_are_hidden_from_list(
    client: AsyncClient, shop_headers: dict[str, str]
) -> None:
    product = await create_product(client, shop_headers)
    await client.patch(f"{URL}/{product['id']}", headers=shop_headers, json={"is_active": False})

    active = (await client.get(URL, headers=shop_headers)).json()
    everything = (
        await client.get(URL, headers=shop_headers, params={"include_inactive": True})
    ).json()

    assert active == []
    assert [p["id"] for p in everything] == [product["id"]]


async def test_search_matches_name_brand_and_imei(
    client: AsyncClient, shop_headers: dict[str, str]
) -> None:
    await create_product(client, shop_headers, name="Galaxy A16", brand="Samsung")
    await create_product(client, shop_headers, name="iPhone 13", imei="356789012345678")
    await create_product(client, shop_headers, name="Fast Charger 100%")

    async def search(term: str) -> list[str]:
        response = await client.get(URL, headers=shop_headers, params={"search": term})
        return [p["name"] for p in response.json()]

    assert await search("samsung") == ["Galaxy A16"]
    assert await search("iphone") == ["iPhone 13"]
    assert await search("90123") == ["iPhone 13"]
    assert await search("100%") == ["Fast Charger 100%"]
    assert await search("%") == ["Fast Charger 100%"]


async def test_filter_by_category(client: AsyncClient, shop_headers: dict[str, str]) -> None:
    accessories = await category_id(client, shop_headers, "Accessories")
    await create_product(client, shop_headers, name="Samsung A16")
    await create_product(client, shop_headers, name="Charger", category_id=accessories)

    response = await client.get(URL, headers=shop_headers, params={"category_id": accessories})

    assert [p["name"] for p in response.json()] == ["Charger"]


async def test_stock_status_and_filters(client: AsyncClient, shop_headers: dict[str, str]) -> None:
    await create_product(client, shop_headers, name="Plenty", stock_qty=10)
    await create_product(client, shop_headers, name="Low", stock_qty=2, low_stock_threshold=2)
    await create_product(client, shop_headers, name="Out", stock_qty=0)
    await create_product(client, shop_headers, name="Repair Service", track_stock=False)

    async def names(status: str) -> list[str]:
        response = await client.get(URL, headers=shop_headers, params={"stock_status": status})
        return [p["name"] for p in response.json()]

    statuses = {
        p["name"]: p["stock_status"] for p in (await client.get(URL, headers=shop_headers)).json()
    }
    assert statuses == {
        "Plenty": "in_stock",
        "Low": "low",
        "Out": "out",
        "Repair Service": "not_tracked",
    }
    assert await names("in_stock") == ["Plenty"]
    assert await names("low") == ["Low"]
    assert await names("out") == ["Out"]
    assert await names("not_tracked") == ["Repair Service"]


async def test_stock_adjustment_adds_and_removes(
    client: AsyncClient, shop_headers: dict[str, str]
) -> None:
    product = await create_product(client, shop_headers, stock_qty=5)
    url = f"{URL}/{product['id']}/stock-adjustment"

    added = await client.post(url, headers=shop_headers, json={"change": 3})
    removed = await client.post(url, headers=shop_headers, json={"change": -8})

    assert added.json()["stock_qty"] == 8
    assert removed.json()["stock_qty"] == 0
    assert removed.json()["stock_status"] == "out"


async def test_stock_adjustment_cannot_go_below_zero(
    client: AsyncClient, shop_headers: dict[str, str]
) -> None:
    product = await create_product(client, shop_headers, stock_qty=2)

    response = await client.post(
        f"{URL}/{product['id']}/stock-adjustment", headers=shop_headers, json={"change": -3}
    )
    after = await client.get(f"{URL}/{product['id']}", headers=shop_headers)

    assert response.status_code == 422
    assert after.json()["stock_qty"] == 2


async def test_stock_adjustment_of_zero_is_rejected(
    client: AsyncClient, shop_headers: dict[str, str]
) -> None:
    product = await create_product(client, shop_headers)

    response = await client.post(
        f"{URL}/{product['id']}/stock-adjustment", headers=shop_headers, json={"change": 0}
    )

    assert response.status_code == 422


async def test_stock_adjustment_requires_tracked_stock(
    client: AsyncClient, shop_headers: dict[str, str]
) -> None:
    product = await create_product(client, shop_headers, track_stock=False)

    response = await client.post(
        f"{URL}/{product['id']}/stock-adjustment", headers=shop_headers, json={"change": 1}
    )

    assert response.status_code == 422


async def test_shops_cannot_access_each_others_products(
    client: AsyncClient, shop_headers: dict[str, str], other_shop_headers: dict[str, str]
) -> None:
    product = await create_product(client, shop_headers)
    url = f"{URL}/{product['id']}"

    get = await client.get(url, headers=other_shop_headers)
    patch = await client.patch(url, headers=other_shop_headers, json={"name": "Hacked"})
    adjust = await client.post(
        f"{url}/stock-adjustment", headers=other_shop_headers, json={"change": -5}
    )
    listed = (await client.get(URL, headers=other_shop_headers)).json()
    mine = (await client.get(url, headers=shop_headers)).json()

    assert (get.status_code, patch.status_code, adjust.status_code) == (404, 404, 404)
    assert listed == []
    assert mine["name"] == "Samsung A16"
    assert mine["stock_qty"] == 5
