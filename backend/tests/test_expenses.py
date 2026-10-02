from datetime import timedelta

from httpx import AsyncClient

from app.core.time import shop_today

URL = "/api/v1/expenses"


async def _create(client: AsyncClient, headers: dict[str, str], **fields: str):
    payload = {"name": "Rent", "amount": "15000", **fields}
    response = await client.post(URL, headers=headers, json=payload)
    assert response.status_code == 201, response.text
    return response.json()


async def test_create_expense(client: AsyncClient, shop_headers: dict[str, str]) -> None:
    expense = await _create(
        client,
        shop_headers,
        name="Electricity",
        amount="2350.5",
        spent_on="2026-09-15",
        note="September bill",
    )

    assert expense["name"] == "Electricity"
    assert expense["amount"] == "2350.50"
    assert expense["spent_on"] == "2026-09-15"
    assert expense["note"] == "September bill"


async def test_date_defaults_to_today_in_shop_timezone(
    client: AsyncClient, shop_headers: dict[str, str]
) -> None:
    expense = await _create(client, shop_headers)

    assert expense["spent_on"] == shop_today().isoformat()


async def test_future_date_is_rejected(client: AsyncClient, shop_headers: dict[str, str]) -> None:
    tomorrow = (shop_today() + timedelta(days=1)).isoformat()

    response = await client.post(
        URL, headers=shop_headers, json={"name": "Rent", "amount": "100", "spent_on": tomorrow}
    )

    assert response.status_code == 422


async def test_amount_must_be_positive(client: AsyncClient, shop_headers: dict[str, str]) -> None:
    zero = await client.post(URL, headers=shop_headers, json={"name": "Rent", "amount": "0"})
    negative = await client.post(URL, headers=shop_headers, json={"name": "Rent", "amount": "-5"})

    assert (zero.status_code, negative.status_code) == (422, 422)


async def test_list_filters_by_date_and_totals(
    client: AsyncClient, shop_headers: dict[str, str]
) -> None:
    await _create(client, shop_headers, name="Rent", amount="15000", spent_on="2026-09-01")
    await _create(client, shop_headers, name="Salary", amount="8000", spent_on="2026-09-30")
    await _create(client, shop_headers, name="Transport", amount="500", spent_on="2026-08-31")

    body = (
        await client.get(
            URL, headers=shop_headers, params={"date_from": "2026-09-01", "date_to": "2026-09-30"}
        )
    ).json()

    assert body["total"] == "23000.00"
    assert [e["name"] for e in body["expenses"]] == ["Salary", "Rent"]


async def test_total_covers_expenses_beyond_the_page(
    client: AsyncClient, shop_headers: dict[str, str]
) -> None:
    for day in ("2026-09-01", "2026-09-02", "2026-09-03"):
        await _create(client, shop_headers, amount="100", spent_on=day)

    body = (await client.get(URL, headers=shop_headers, params={"limit": 1})).json()

    assert body["total"] == "300.00"
    assert [e["spent_on"] for e in body["expenses"]] == ["2026-09-03"]


async def test_empty_list(client: AsyncClient, shop_headers: dict[str, str]) -> None:
    body = (await client.get(URL, headers=shop_headers)).json()

    assert body == {"total": "0.00", "expenses": []}


async def test_delete_expense(client: AsyncClient, shop_headers: dict[str, str]) -> None:
    expense = await _create(client, shop_headers)

    deleted = await client.delete(f"{URL}/{expense['id']}", headers=shop_headers)
    again = await client.delete(f"{URL}/{expense['id']}", headers=shop_headers)

    assert deleted.status_code == 204
    assert again.status_code == 404
    assert (await client.get(URL, headers=shop_headers)).json()["expenses"] == []


async def test_shops_cannot_see_or_delete_each_others_expenses(
    client: AsyncClient, shop_headers: dict[str, str], other_shop_headers: dict[str, str]
) -> None:
    expense = await _create(client, shop_headers)

    deleted = await client.delete(f"{URL}/{expense['id']}", headers=other_shop_headers)
    theirs = (await client.get(URL, headers=other_shop_headers)).json()
    mine = (await client.get(URL, headers=shop_headers)).json()

    assert deleted.status_code == 404
    assert theirs == {"total": "0.00", "expenses": []}
    assert len(mine["expenses"]) == 1
