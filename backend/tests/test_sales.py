import asyncio

from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncEngine

from tests.conftest import (
    category_id,
    create_customer,
    create_product,
    post_sale,
    sale_type_id,
    stock_of,
)

URL = "/api/v1/sales"


async def test_sale_reduces_stock(client: AsyncClient, shop_headers: dict[str, str]) -> None:
    product = await create_product(client, shop_headers, stock_qty=5)

    response = await post_sale(client, shop_headers, product["id"])

    assert response.status_code == 201, response.text
    assert await stock_of(client, shop_headers, product["id"]) == 4


async def test_sale_calculates_revenue_cost_and_profit(
    client: AsyncClient, shop_headers: dict[str, str]
) -> None:
    product = await create_product(client, shop_headers, purchase_price="800", selling_price="1000")

    sale = (await post_sale(client, shop_headers, product["id"], discount="100")).json()

    assert sale["subtotal"] == "1000.00"
    assert sale["discount"] == "100.00"
    assert sale["total"] == "900.00"
    assert sale["total_cost"] == "800.00"
    assert sale["profit"] == "100.00"
    assert sale["items"][0]["unit_cost"] == "800.00"


async def test_prd_example_sale(client: AsyncClient, shop_headers: dict[str, str]) -> None:
    product = await create_product(client, shop_headers)  # ₹14,200 cost, ₹15,999 price

    sale = (await post_sale(client, shop_headers, product["id"], discount="500")).json()

    assert (sale["total"], sale["total_cost"], sale["profit"]) == (
        "15499.00",
        "14200.00",
        "1299.00",
    )


async def test_quantity_and_changed_price(
    client: AsyncClient, shop_headers: dict[str, str]
) -> None:
    product = await create_product(
        client, shop_headers, purchase_price="300", selling_price="499", stock_qty=10
    )

    sale = (
        await post_sale(
            client,
            shop_headers,
            product["id"],
            items=[{"product_id": product["id"], "quantity": 3, "unit_price": "450"}],
        )
    ).json()

    assert sale["total"] == "1350.00"
    assert sale["profit"] == "450.00"
    assert await stock_of(client, shop_headers, product["id"]) == 7


async def test_sale_keeps_prices_from_the_time_of_sale(
    client: AsyncClient, shop_headers: dict[str, str]
) -> None:
    product = await create_product(client, shop_headers)
    sale = (await post_sale(client, shop_headers, product["id"])).json()

    await client.patch(
        f"/api/v1/products/{product['id']}",
        headers=shop_headers,
        json={"purchase_price": "1", "selling_price": "2", "name": "Renamed"},
    )
    again = (await client.get(f"{URL}/{sale['id']}", headers=shop_headers)).json()

    assert again["profit"] == "1799.00"
    assert again["items"][0]["product_name"] == "Samsung A16"


async def test_full_payment_is_recorded_by_default(
    client: AsyncClient, shop_headers: dict[str, str]
) -> None:
    product = await create_product(client, shop_headers)

    sale = (await post_sale(client, shop_headers, product["id"], payment_method="cash")).json()

    assert sale["amount_paid"] == "15999.00"
    assert sale["pending_amount"] == "0.00"
    assert [(p["amount"], p["method"]) for p in sale["payments"]] == [("15999.00", "cash")]


async def test_not_enough_stock_is_rejected_and_nothing_changes(
    client: AsyncClient, shop_headers: dict[str, str]
) -> None:
    product = await create_product(client, shop_headers, stock_qty=1)

    response = await post_sale(
        client,
        shop_headers,
        product["id"],
        items=[{"product_id": product["id"], "quantity": 2}],
    )

    assert response.status_code == 422
    assert "Only 1" in response.json()["detail"]
    assert await stock_of(client, shop_headers, product["id"]) == 1
    assert (await client.get(URL, headers=shop_headers)).json() == []


async def test_failed_multi_item_sale_changes_no_stock(
    client: AsyncClient, shop_headers: dict[str, str]
) -> None:
    plenty = await create_product(client, shop_headers, name="Charger", stock_qty=10)
    scarce = await create_product(client, shop_headers, name="Phone", stock_qty=0)

    response = await post_sale(
        client,
        shop_headers,
        plenty["id"],
        items=[
            {"product_id": plenty["id"], "quantity": 2},
            {"product_id": scarce["id"], "quantity": 1},
        ],
    )

    assert response.status_code == 422
    assert await stock_of(client, shop_headers, plenty["id"]) == 10
    assert (await client.get(URL, headers=shop_headers)).json() == []


async def test_product_without_stock_tracking_can_always_be_sold(
    client: AsyncClient, shop_headers: dict[str, str]
) -> None:
    repair = await create_product(
        client, shop_headers, name="Screen Repair", track_stock=False, stock_qty=0
    )

    response = await post_sale(client, shop_headers, repair["id"])

    assert response.status_code == 201
    assert await stock_of(client, shop_headers, repair["id"]) == 0


async def test_last_unit_cannot_be_sold_twice_at_the_same_time(
    client: AsyncClient, shop_headers: dict[str, str]
) -> None:
    product = await create_product(client, shop_headers, stock_qty=1)

    responses = await asyncio.gather(
        post_sale(client, shop_headers, product["id"]),
        post_sale(client, shop_headers, product["id"]),
    )

    assert sorted(r.status_code for r in responses) == [201, 422]
    assert await stock_of(client, shop_headers, product["id"]) == 0


async def test_disabled_product_cannot_be_sold(
    client: AsyncClient, shop_headers: dict[str, str]
) -> None:
    product = await create_product(client, shop_headers)
    await client.patch(
        f"/api/v1/products/{product['id']}", headers=shop_headers, json={"is_active": False}
    )

    response = await post_sale(client, shop_headers, product["id"])

    assert response.status_code == 422


async def test_disabled_sale_type_cannot_be_used(
    client: AsyncClient, shop_headers: dict[str, str]
) -> None:
    product = await create_product(client, shop_headers)
    repair = await sale_type_id(client, shop_headers, "Repair")
    await client.patch(
        f"/api/v1/sale-types/{repair}", headers=shop_headers, json={"is_active": False}
    )

    response = await post_sale(client, shop_headers, product["id"], sale_type_id=repair)

    assert response.status_code == 422


async def test_same_product_twice_in_one_sale_is_rejected(
    client: AsyncClient, shop_headers: dict[str, str]
) -> None:
    product = await create_product(client, shop_headers)
    item = {"product_id": product["id"], "quantity": 1}

    response = await post_sale(client, shop_headers, product["id"], items=[item, item])

    assert response.status_code == 422


async def test_discount_larger_than_sale_is_rejected(
    client: AsyncClient, shop_headers: dict[str, str]
) -> None:
    product = await create_product(client, shop_headers)

    response = await post_sale(client, shop_headers, product["id"], discount="20000")

    assert response.status_code == 422
    assert await stock_of(client, shop_headers, product["id"]) == 5


async def test_another_shops_product_or_sale_type_cannot_be_used(
    client: AsyncClient, shop_headers: dict[str, str], other_shop_headers: dict[str, str]
) -> None:
    mine = await create_product(client, shop_headers)
    theirs = await create_product(client, other_shop_headers)

    with_their_product = await post_sale(client, shop_headers, theirs["id"])
    with_their_sale_type = await post_sale(
        client,
        shop_headers,
        mine["id"],
        sale_type_id=await sale_type_id(client, other_shop_headers),
    )

    assert with_their_product.status_code == 422
    assert with_their_sale_type.status_code == 422
    assert await stock_of(client, other_shop_headers, theirs["id"]) == 5


# --- Credit and part payments ---------------------------------------------------------


async def test_credit_sale_requires_a_customer(
    client: AsyncClient, shop_headers: dict[str, str]
) -> None:
    product = await create_product(client, shop_headers)

    response = await post_sale(client, shop_headers, product["id"], payment_method="credit")

    assert response.status_code == 422
    assert await stock_of(client, shop_headers, product["id"]) == 5


async def test_credit_sale_leaves_full_amount_pending(
    client: AsyncClient, shop_headers: dict[str, str], engine: AsyncEngine
) -> None:
    product = await create_product(client, shop_headers)
    customer_id = await create_customer(engine, client, shop_headers)

    sale = (
        await post_sale(
            client, shop_headers, product["id"], payment_method="credit", customer_id=customer_id
        )
    ).json()

    assert sale["amount_paid"] == "0.00"
    assert sale["pending_amount"] == "15999.00"
    assert sale["payments"] == []
    assert sale["customer_name"] == "Rahul"


async def test_part_payment_leaves_the_rest_pending(
    client: AsyncClient, shop_headers: dict[str, str], engine: AsyncEngine
) -> None:
    product = await create_product(client, shop_headers, selling_price="20000")
    customer_id = await create_customer(engine, client, shop_headers)

    sale = (
        await post_sale(
            client,
            shop_headers,
            product["id"],
            payment_method="cash",
            amount_paid="15000",
            customer_id=customer_id,
        )
    ).json()

    assert sale["amount_paid"] == "15000.00"
    assert sale["pending_amount"] == "5000.00"


async def test_credit_with_upfront_amount_is_rejected(
    client: AsyncClient, shop_headers: dict[str, str], engine: AsyncEngine
) -> None:
    product = await create_product(client, shop_headers)
    customer_id = await create_customer(engine, client, shop_headers)

    response = await post_sale(
        client,
        shop_headers,
        product["id"],
        payment_method="credit",
        amount_paid="100",
        customer_id=customer_id,
    )

    assert response.status_code == 422


async def test_paying_more_than_due_is_rejected(
    client: AsyncClient, shop_headers: dict[str, str]
) -> None:
    product = await create_product(client, shop_headers)

    response = await post_sale(client, shop_headers, product["id"], amount_paid="16000")

    assert response.status_code == 422


async def test_another_shops_customer_cannot_be_used(
    client: AsyncClient,
    shop_headers: dict[str, str],
    other_shop_headers: dict[str, str],
    engine: AsyncEngine,
) -> None:
    product = await create_product(client, shop_headers)
    their_customer = await create_customer(engine, client, other_shop_headers)

    response = await post_sale(client, shop_headers, product["id"], customer_id=their_customer)

    assert response.status_code == 422


# --- Exchange ---------------------------------------------------------------------------


async def test_exchange_sale(client: AsyncClient, shop_headers: dict[str, str]) -> None:
    iphone = await create_product(
        client,
        shop_headers,
        name="iPhone 15",
        purchase_price="50000",
        selling_price="55000",
        stock_qty=2,
    )

    response = await post_sale(
        client,
        shop_headers,
        iphone["id"],
        sale_type_id=await sale_type_id(client, shop_headers, "Exchange"),
        payment_method="cash",
        exchange={"device_name": "iPhone 12", "imei": "356789012345678", "value": "18000"},
    )

    sale = response.json()
    assert response.status_code == 201, response.text
    assert sale["total"] == "55000.00"
    assert sale["profit"] == "5000.00"
    assert sale["exchange_value"] == "18000.00"
    assert sale["amount_due"] == "37000.00"
    assert sale["amount_paid"] == "37000.00"
    assert sale["pending_amount"] == "0.00"
    assert sale["exchange_device_name"] == "iPhone 12"
    assert sale["exchange_device_imei"] == "356789012345678"
    assert await stock_of(client, shop_headers, iphone["id"]) == 1


async def test_exchange_imei_is_optional(client: AsyncClient, shop_headers: dict[str, str]) -> None:
    product = await create_product(client, shop_headers)

    response = await post_sale(
        client,
        shop_headers,
        product["id"],
        sale_type_id=await sale_type_id(client, shop_headers, "Exchange"),
        exchange={"device_name": "Redmi Note 10", "value": "4000"},
    )

    assert response.status_code == 201
    assert response.json()["exchange_device_imei"] is None


async def test_exchange_sale_type_needs_old_phone_details(
    client: AsyncClient, shop_headers: dict[str, str]
) -> None:
    product = await create_product(client, shop_headers)

    response = await post_sale(
        client,
        shop_headers,
        product["id"],
        sale_type_id=await sale_type_id(client, shop_headers, "Exchange"),
    )

    assert response.status_code == 422


async def test_old_phone_details_need_an_exchange_sale_type(
    client: AsyncClient, shop_headers: dict[str, str]
) -> None:
    product = await create_product(client, shop_headers)

    response = await post_sale(
        client,
        shop_headers,
        product["id"],
        exchange={"device_name": "iPhone 12", "value": "18000"},
    )

    assert response.status_code == 422


async def test_exchange_value_above_sale_amount_is_rejected(
    client: AsyncClient, shop_headers: dict[str, str]
) -> None:
    product = await create_product(client, shop_headers)

    response = await post_sale(
        client,
        shop_headers,
        product["id"],
        sale_type_id=await sale_type_id(client, shop_headers, "Exchange"),
        exchange={"device_name": "iPhone 15 Pro", "value": "90000"},
    )

    assert response.status_code == 422


# --- Offline sync support -----------------------------------------------------------------


async def test_resending_a_sale_with_the_same_client_ref_does_not_duplicate_it(
    client: AsyncClient, shop_headers: dict[str, str]
) -> None:
    product = await create_product(client, shop_headers, stock_qty=5)

    first = await post_sale(client, shop_headers, product["id"], client_ref="phone-1-sale-42")
    second = await post_sale(client, shop_headers, product["id"], client_ref="phone-1-sale-42")

    assert (first.status_code, second.status_code) == (201, 200)
    assert first.json()["id"] == second.json()["id"]
    assert await stock_of(client, shop_headers, product["id"]) == 4
    assert len((await client.get(URL, headers=shop_headers)).json()) == 1


async def test_simultaneous_resends_save_the_sale_once(
    client: AsyncClient, shop_headers: dict[str, str]
) -> None:
    product = await create_product(client, shop_headers, stock_qty=5)

    responses = await asyncio.gather(
        *(post_sale(client, shop_headers, product["id"], client_ref="dup") for _ in range(3))
    )

    assert {r.json()["id"] for r in responses} != set()
    assert len({r.json()["id"] for r in responses}) == 1
    assert await stock_of(client, shop_headers, product["id"]) == 4


async def test_offline_sale_keeps_its_original_time(
    client: AsyncClient, shop_headers: dict[str, str]
) -> None:
    product = await create_product(client, shop_headers)

    sale = (
        await post_sale(client, shop_headers, product["id"], sold_at="2026-09-30T18:45:00+05:30")
    ).json()

    assert sale["sold_at"] == "2026-09-30T13:15:00Z"
    assert sale["payments"][0]["paid_at"] == "2026-09-30T13:15:00Z"


async def test_sale_date_in_the_future_is_rejected(
    client: AsyncClient, shop_headers: dict[str, str]
) -> None:
    product = await create_product(client, shop_headers)

    response = await post_sale(client, shop_headers, product["id"], sold_at="2099-01-01T10:00:00Z")

    assert response.status_code == 422


async def test_sale_time_without_timezone_is_rejected(
    client: AsyncClient, shop_headers: dict[str, str]
) -> None:
    product = await create_product(client, shop_headers)

    response = await post_sale(client, shop_headers, product["id"], sold_at="2026-09-30T18:45:00")

    assert response.status_code == 422


# --- Reading sales ------------------------------------------------------------------------


async def test_get_sale_details(client: AsyncClient, shop_headers: dict[str, str]) -> None:
    product = await create_product(client, shop_headers)
    created = (await post_sale(client, shop_headers, product["id"], notes="Gift wrap")).json()

    response = await client.get(f"{URL}/{created['id']}", headers=shop_headers)

    sale = response.json()
    assert response.status_code == 200
    assert sale["sale_type_name"] == "New Phone"
    assert sale["product_names"] == ["Samsung A16"]
    assert sale["notes"] == "Gift wrap"
    assert len(sale["items"]) == 1


async def test_other_shops_cannot_see_a_sale(
    client: AsyncClient, shop_headers: dict[str, str], other_shop_headers: dict[str, str]
) -> None:
    product = await create_product(client, shop_headers)
    sale = (await post_sale(client, shop_headers, product["id"])).json()

    response = await client.get(f"{URL}/{sale['id']}", headers=other_shop_headers)
    listed = (await client.get(URL, headers=other_shop_headers)).json()

    assert response.status_code == 404
    assert listed == []


async def test_list_is_newest_first_and_paginated(
    client: AsyncClient, shop_headers: dict[str, str]
) -> None:
    product = await create_product(client, shop_headers, stock_qty=10)
    for day in ("2026-09-01", "2026-09-03", "2026-09-02"):
        await post_sale(client, shop_headers, product["id"], sold_at=f"{day}T12:00:00+05:30")

    page_one = (await client.get(URL, headers=shop_headers, params={"limit": 2})).json()
    page_two = (
        await client.get(URL, headers=shop_headers, params={"limit": 2, "offset": 2})
    ).json()

    assert [s["sold_at"][:10] for s in page_one] == ["2026-09-03", "2026-09-02"]
    assert [s["sold_at"][:10] for s in page_two] == ["2026-09-01"]


async def test_date_filter_uses_shop_local_days(
    client: AsyncClient, shop_headers: dict[str, str]
) -> None:
    product = await create_product(client, shop_headers)
    # 11:30 pm and 12:30 am India time, both on 30 Sep in UTC.
    late = await post_sale(client, shop_headers, product["id"], sold_at="2026-09-30T23:30:00+05:30")
    early = await post_sale(
        client, shop_headers, product["id"], sold_at="2026-10-01T00:30:00+05:30"
    )

    response = await client.get(
        URL, headers=shop_headers, params={"date_from": "2026-10-01", "date_to": "2026-10-01"}
    )

    assert [s["id"] for s in response.json()] == [early.json()["id"]]
    assert late.json()["id"] not in [s["id"] for s in response.json()]


async def test_filters_by_type_category_payment_method_and_pending(
    client: AsyncClient, shop_headers: dict[str, str], engine: AsyncEngine
) -> None:
    phone = await create_product(client, shop_headers, name="Phone")
    charger = await create_product(
        client,
        shop_headers,
        name="Charger",
        category_id=await category_id(client, shop_headers, "Accessories"),
        purchase_price="200",
        selling_price="499",
    )
    customer_id = await create_customer(engine, client, shop_headers)
    accessories_type = await sale_type_id(client, shop_headers, "Accessories")

    await post_sale(client, shop_headers, phone["id"], payment_method="upi")
    await post_sale(
        client,
        shop_headers,
        charger["id"],
        payment_method="cash",
        sale_type_id=accessories_type,
    )
    await post_sale(
        client, shop_headers, phone["id"], payment_method="credit", customer_id=customer_id
    )

    async def products_for(**params: str | bool) -> list[list[str]]:
        response = await client.get(URL, headers=shop_headers, params=params)
        return [s["product_names"] for s in response.json()]

    assert await products_for(payment_method="cash") == [["Charger"]]
    assert await products_for(sale_type_id=accessories_type) == [["Charger"]]
    phones_category = await category_id(client, shop_headers, "Mobile Phones")
    assert await products_for(category_id=phones_category) == [["Phone"], ["Phone"]]
    assert await products_for(pending_only=True) == [["Phone"]]
    assert await products_for(customer_id=customer_id) == [["Phone"]]
