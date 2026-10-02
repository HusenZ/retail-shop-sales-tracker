from httpx import AsyncClient

from tests.conftest import create_customer, create_product, post_sale

URL = "/api/v1/customers"


async def test_create_customer(client: AsyncClient, shop_headers: dict[str, str]) -> None:
    response = await client.post(
        URL,
        headers=shop_headers,
        json={"name": " Rahul ", "phone": "98765 43210", "notes": "Prefers UPI"},
    )

    body = response.json()
    assert response.status_code == 201
    assert body["name"] == "Rahul"
    assert body["phone"] == "9876543210"
    assert body["notes"] == "Prefers UPI"
    assert body["total_purchases"] == "0.00"
    assert body["transaction_count"] == 0
    assert body["pending_amount"] == "0.00"


async def test_only_name_is_required(client: AsyncClient, shop_headers: dict[str, str]) -> None:
    response = await client.post(URL, headers=shop_headers, json={"name": "Walk-in Rahul"})

    assert response.status_code == 201
    assert response.json()["phone"] is None


async def test_duplicate_phone_in_same_shop_is_rejected(
    client: AsyncClient, shop_headers: dict[str, str]
) -> None:
    await create_customer(client, shop_headers, phone="9876543210")

    response = await client.post(
        URL, headers=shop_headers, json={"name": "Someone", "phone": "98765-43210"}
    )

    assert response.status_code == 409
    assert "Rahul" in response.json()["detail"]


async def test_same_phone_is_allowed_in_different_shops(
    client: AsyncClient, shop_headers: dict[str, str], other_shop_headers: dict[str, str]
) -> None:
    await create_customer(client, shop_headers, phone="9876543210")

    response = await client.post(
        URL, headers=other_shop_headers, json={"name": "Rahul", "phone": "9876543210"}
    )

    assert response.status_code == 201


async def test_customer_shows_purchases_transactions_and_pending(
    client: AsyncClient, shop_headers: dict[str, str]
) -> None:
    phone = await create_product(client, shop_headers, selling_price="20000")
    charger = await create_product(client, shop_headers, name="Charger", selling_price="15999")
    rahul = await create_customer(client, shop_headers)
    priya = await create_customer(client, shop_headers, name="Priya")
    await post_sale(client, shop_headers, charger["id"], customer_id=rahul)
    await post_sale(
        client,
        shop_headers,
        phone["id"],
        customer_id=rahul,
        payment_method="cash",
        amount_paid="15000",
    )
    await post_sale(client, shop_headers, charger["id"], customer_id=priya)
    await post_sale(client, shop_headers, charger["id"])  # walk-in, no customer

    body = (await client.get(f"{URL}/{rahul}", headers=shop_headers)).json()

    assert body["total_purchases"] == "35999.00"
    assert body["transaction_count"] == 2
    assert body["pending_amount"] == "5000.00"


async def test_payment_reduces_customer_pending(
    client: AsyncClient, shop_headers: dict[str, str]
) -> None:
    product = await create_product(client, shop_headers, selling_price="20000")
    rahul = await create_customer(client, shop_headers)
    sale = (
        await post_sale(
            client, shop_headers, product["id"], customer_id=rahul, payment_method="credit"
        )
    ).json()

    await client.post(
        f"/api/v1/sales/{sale['id']}/payments",
        headers=shop_headers,
        json={"amount": "12000", "method": "cash"},
    )
    body = (await client.get(f"{URL}/{rahul}", headers=shop_headers)).json()

    assert body["pending_amount"] == "8000.00"
    assert body["total_purchases"] == "20000.00"


async def test_list_search_and_pending_filter(
    client: AsyncClient, shop_headers: dict[str, str]
) -> None:
    product = await create_product(client, shop_headers)
    rahul = await create_customer(client, shop_headers, phone="9876543210")
    await create_customer(client, shop_headers, name="Priya", phone="9123456780")
    await create_customer(client, shop_headers, name="Amit")
    await post_sale(client, shop_headers, product["id"], customer_id=rahul, payment_method="credit")

    async def names(**params: str | bool) -> list[str]:
        response = await client.get(URL, headers=shop_headers, params=params)
        return [c["name"] for c in response.json()]

    assert await names() == ["Amit", "Priya", "Rahul"]
    assert await names(search="pri") == ["Priya"]
    assert await names(search="43210") == ["Rahul"]
    assert await names(pending_only=True) == ["Rahul"]


async def test_update_customer(client: AsyncClient, shop_headers: dict[str, str]) -> None:
    rahul = await create_customer(client, shop_headers, phone="9876543210")

    response = await client.patch(
        f"{URL}/{rahul}", headers=shop_headers, json={"name": "Rahul Sharma", "phone": None}
    )

    assert response.status_code == 200
    assert response.json()["name"] == "Rahul Sharma"
    assert response.json()["phone"] is None


async def test_update_keeps_own_phone_but_rejects_anothers(
    client: AsyncClient, shop_headers: dict[str, str]
) -> None:
    rahul = await create_customer(client, shop_headers, phone="9876543210")
    await create_customer(client, shop_headers, name="Priya", phone="9123456780")

    same = await client.patch(f"{URL}/{rahul}", headers=shop_headers, json={"phone": "9876543210"})
    taken = await client.patch(f"{URL}/{rahul}", headers=shop_headers, json={"phone": "9123456780"})

    assert same.status_code == 200
    assert taken.status_code == 409


async def test_name_cannot_be_cleared(client: AsyncClient, shop_headers: dict[str, str]) -> None:
    rahul = await create_customer(client, shop_headers)

    response = await client.patch(f"{URL}/{rahul}", headers=shop_headers, json={"name": None})

    assert response.status_code == 422


async def test_shops_cannot_see_or_change_each_others_customers(
    client: AsyncClient, shop_headers: dict[str, str], other_shop_headers: dict[str, str]
) -> None:
    rahul = await create_customer(client, shop_headers)

    get = await client.get(f"{URL}/{rahul}", headers=other_shop_headers)
    patch = await client.patch(
        f"{URL}/{rahul}", headers=other_shop_headers, json={"name": "Hacked"}
    )
    listed = (await client.get(URL, headers=other_shop_headers)).json()

    assert (get.status_code, patch.status_code) == (404, 404)
    assert listed == []
    assert (await client.get(f"{URL}/{rahul}", headers=shop_headers)).json()["name"] == "Rahul"


async def test_another_shop_cannot_add_sales_to_my_customer(
    client: AsyncClient, shop_headers: dict[str, str], other_shop_headers: dict[str, str]
) -> None:
    rahul = await create_customer(client, shop_headers)
    their_product = await create_product(client, other_shop_headers)

    response = await post_sale(client, other_shop_headers, their_product["id"], customer_id=rahul)
    body = (await client.get(f"{URL}/{rahul}", headers=shop_headers)).json()

    assert response.status_code == 422
    assert body["transaction_count"] == 0
