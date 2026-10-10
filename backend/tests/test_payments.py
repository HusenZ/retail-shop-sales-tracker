from httpx import AsyncClient

from tests.conftest import create_customer, create_product, post_sale


async def _credit_sale(client: AsyncClient, headers: dict[str, str], price: str = "20000"):
    product = await create_product(client, headers, selling_price=price)
    customer_id = await create_customer(client, headers)
    response = await post_sale(
        client, headers, product["id"], payment_method="credit", customer_id=customer_id
    )
    return response.json()


def _payments_url(sale_id: str) -> str:
    return f"/api/v1/sales/{sale_id}/payments"


async def test_record_payment_reduces_pending(
    client: AsyncClient, shop_headers: dict[str, str]
) -> None:
    sale = await _credit_sale(client, shop_headers)

    response = await client.post(
        _payments_url(sale["id"]), headers=shop_headers, json={"amount": "15000", "method": "upi"}
    )

    body = response.json()
    assert response.status_code == 201
    assert body["amount_paid"] == "15000.00"
    assert body["pending_amount"] == "5000.00"
    assert [(p["amount"], p["method"]) for p in body["payments"]] == [("15000.00", "upi")]


async def test_payments_can_settle_the_sale(
    client: AsyncClient, shop_headers: dict[str, str]
) -> None:
    sale = await _credit_sale(client, shop_headers)
    url = _payments_url(sale["id"])

    await client.post(url, headers=shop_headers, json={"amount": "15000", "method": "cash"})
    settled = await client.post(url, headers=shop_headers, json={"amount": "5000", "method": "upi"})
    again = await client.post(url, headers=shop_headers, json={"amount": "1", "method": "cash"})

    assert settled.json()["pending_amount"] == "0.00"
    assert len(settled.json()["payments"]) == 2
    assert again.status_code == 422


async def test_overpayment_is_rejected(client: AsyncClient, shop_headers: dict[str, str]) -> None:
    sale = await _credit_sale(client, shop_headers)

    response = await client.post(
        _payments_url(sale["id"]),
        headers=shop_headers,
        json={"amount": "20000.01", "method": "cash"},
    )

    assert response.status_code == 422
    assert "20000.00" in response.json()["detail"]


async def test_payment_amount_must_be_positive(
    client: AsyncClient, shop_headers: dict[str, str]
) -> None:
    sale = await _credit_sale(client, shop_headers)

    response = await client.post(
        _payments_url(sale["id"]), headers=shop_headers, json={"amount": "0", "method": "cash"}
    )

    assert response.status_code == 422


async def test_payment_cannot_be_credit(client: AsyncClient, shop_headers: dict[str, str]) -> None:
    sale = await _credit_sale(client, shop_headers)

    response = await client.post(
        _payments_url(sale["id"]), headers=shop_headers, json={"amount": "10", "method": "credit"}
    )

    assert response.status_code == 422


async def test_other_shops_cannot_record_payments(
    client: AsyncClient,
    shop_headers: dict[str, str],
    other_shop_headers: dict[str, str],
) -> None:
    sale = await _credit_sale(client, shop_headers)

    response = await client.post(
        _payments_url(sale["id"]),
        headers=other_shop_headers,
        json={"amount": "100", "method": "cash"},
    )
    mine = await client.get(f"/api/v1/sales/{sale['id']}", headers=shop_headers)

    assert response.status_code == 404
    assert mine.json()["amount_paid"] == "0.00"


async def test_pending_payments_summary(
    client: AsyncClient,
    shop_headers: dict[str, str],
    other_shop_headers: dict[str, str],
) -> None:
    first = await _credit_sale(client, shop_headers, price="20000")
    second = await _credit_sale(client, shop_headers, price="3000")
    settled = await _credit_sale(client, shop_headers, price="500")
    await _credit_sale(client, other_shop_headers, price="999")
    await client.post(
        _payments_url(first["id"]), headers=shop_headers, json={"amount": "15000", "method": "upi"}
    )
    await client.post(
        _payments_url(settled["id"]), headers=shop_headers, json={"amount": "500", "method": "cash"}
    )

    response = await client.get("/api/v1/payments/pending", headers=shop_headers)

    body = response.json()
    assert response.status_code == 200
    assert body["total_pending"] == "8000.00"
    assert body["sale_count"] == 2
    assert [s["id"] for s in body["sales"]] == [first["id"], second["id"]]
    assert [s["pending_amount"] for s in body["sales"]] == ["5000.00", "3000.00"]


async def test_no_pending_payments(client: AsyncClient, shop_headers: dict[str, str]) -> None:
    body = (await client.get("/api/v1/payments/pending", headers=shop_headers)).json()

    assert body == {"total_pending": "0.00", "sale_count": 0, "sales": []}
