from datetime import date
from decimal import Decimal

import pytest
from httpx import AsyncClient

from app.api import reports
from app.core.time import month_start, start_of_day, week_start
from tests.conftest import category_id, create_customer, create_product, post_sale, sale_type_id

WEDNESDAY = date(2026, 9, 16)


def ist(day: str, clock: str = "12:00") -> str:
    return f"{day}T{clock}:00+05:30"


@pytest.fixture
def frozen_today(monkeypatch: pytest.MonkeyPatch) -> date:
    monkeypatch.setattr(reports, "shop_today", lambda: WEDNESDAY)
    return WEDNESDAY


def test_week_starts_on_monday() -> None:
    assert week_start(date(2026, 9, 16)) == date(2026, 9, 14)  # Wednesday
    assert week_start(date(2026, 9, 14)) == date(2026, 9, 14)  # Monday
    assert week_start(date(2026, 9, 20)) == date(2026, 9, 14)  # Sunday
    assert month_start(date(2026, 9, 16)) == date(2026, 9, 1)


def test_start_of_day_rejects_datetimes() -> None:
    with pytest.raises(TypeError):
        start_of_day(start_of_day(date(2026, 9, 1)))  # type: ignore[arg-type]


# --- Dashboard ----------------------------------------------------------------------------


async def test_dashboard_periods(
    client: AsyncClient, shop_headers: dict[str, str], frozen_today: date
) -> None:
    phone = await create_product(client, shop_headers)  # ₹15,999, profit ₹1,799
    charger = await create_product(
        client,
        shop_headers,
        name="Charger",
        purchase_price="200",
        selling_price="499",
        stock_qty=20,
    )  # profit ₹299
    await post_sale(client, shop_headers, phone["id"], sold_at=ist("2026-09-16", "10:00"))
    await post_sale(client, shop_headers, charger["id"], sold_at=ist("2026-09-16", "00:05"))
    await post_sale(client, shop_headers, charger["id"], sold_at=ist("2026-09-14"))  # Monday
    await post_sale(client, shop_headers, charger["id"], sold_at=ist("2026-09-13"))  # last week
    await post_sale(client, shop_headers, charger["id"], sold_at=ist("2026-08-31", "23:59"))
    await post_sale(client, shop_headers, charger["id"], sold_at=ist("2026-09-17", "00:00"))

    body = (await client.get("/api/v1/dashboard", headers=shop_headers)).json()

    assert body["today"] == {
        "first_day": "2026-09-16",
        "sales_total": "16498.00",
        "sale_count": 2,
        "profit": "2098.00",
    }
    assert body["this_week"] == {
        "first_day": "2026-09-14",
        "sales_total": "16997.00",
        "sale_count": 3,
        "profit": "2397.00",
    }
    assert body["this_month"] == {
        "first_day": "2026-09-01",
        "sales_total": "17496.00",
        "sale_count": 4,
        "profit": "2696.00",
    }


async def test_dashboard_pending_payments(
    client: AsyncClient, shop_headers: dict[str, str], frozen_today: date
) -> None:
    product = await create_product(client, shop_headers, selling_price="20000")
    rahul = await create_customer(client, shop_headers)
    await post_sale(
        client,
        shop_headers,
        product["id"],
        customer_id=rahul,
        payment_method="cash",
        amount_paid="15000",
        sold_at=ist("2026-07-01"),
    )

    body = (await client.get("/api/v1/dashboard", headers=shop_headers)).json()

    assert body["pending_total"] == "5000.00"
    assert body["pending_sale_count"] == 1
    assert body["this_month"]["sale_count"] == 0


async def test_dashboard_for_a_new_shop(
    client: AsyncClient, shop_headers: dict[str, str], frozen_today: date
) -> None:
    body = (await client.get("/api/v1/dashboard", headers=shop_headers)).json()

    assert body["today"] == {
        "first_day": "2026-09-16",
        "sales_total": "0.00",
        "sale_count": 0,
        "profit": "0.00",
    }
    assert body["pending_total"] == "0.00"


async def test_dashboard_ignores_other_shops(
    client: AsyncClient,
    shop_headers: dict[str, str],
    other_shop_headers: dict[str, str],
    frozen_today: date,
) -> None:
    theirs = await create_product(client, other_shop_headers)
    await post_sale(client, other_shop_headers, theirs["id"], sold_at=ist("2026-09-16"))

    body = (await client.get("/api/v1/dashboard", headers=shop_headers)).json()

    assert body["today"]["sale_count"] == 0


async def test_dashboard_uses_the_real_date_by_default(
    client: AsyncClient, shop_headers: dict[str, str]
) -> None:
    product = await create_product(client, shop_headers)
    await post_sale(client, shop_headers, product["id"])

    body = (await client.get("/api/v1/dashboard", headers=shop_headers)).json()

    assert body["today"]["sale_count"] == 1
    assert body["today"]["sales_total"] == "15999.00"


# --- Report summary ----------------------------------------------------------------------


async def _september_shop(client: AsyncClient, headers: dict[str, str]) -> None:
    """A month of mixed sales whose figures are worked out by hand in the test below."""
    accessories = await category_id(client, headers, "Accessories")
    phone = await create_product(client, headers)  # cost ₹14,200, price ₹15,999
    iphone = await create_product(
        client, headers, name="iPhone 15", purchase_price="50000", selling_price="55000"
    )
    charger = await create_product(
        client,
        headers,
        name="Charger",
        category_id=accessories,
        purchase_price="200",
        selling_price="499",
        stock_qty=20,
    )
    accessories_type = await sale_type_id(client, headers, "Accessories")
    rahul = await create_customer(client, headers)

    # Revenue 15,499, cost 14,200, paid by UPI.
    await post_sale(
        client,
        headers,
        phone["id"],
        discount="500",
        payment_method="upi",
        sold_at=ist("2026-09-01", "00:00"),
    )
    # Revenue 998, cost 400, cash.
    await post_sale(
        client,
        headers,
        charger["id"],
        sale_type_id=accessories_type,
        payment_method="cash",
        items=[{"product_id": charger["id"], "quantity": 2}],
        sold_at=ist("2026-09-10"),
    )
    # Revenue 55,000, cost 50,000; old phone ₹18,000, customer pays ₹37,000 cash.
    await post_sale(
        client,
        headers,
        iphone["id"],
        sale_type_id=await sale_type_id(client, headers, "Exchange"),
        payment_method="cash",
        exchange={"device_name": "iPhone 12", "value": "18000"},
        sold_at=ist("2026-09-20"),
    )
    # Revenue 499, cost 200, on credit; ₹200 collected later by UPI.
    credit = await post_sale(
        client,
        headers,
        charger["id"],
        sale_type_id=accessories_type,
        payment_method="credit",
        customer_id=rahul,
        sold_at=ist("2026-09-30", "23:30"),
    )
    await client.post(
        f"/api/v1/sales/{credit.json()['id']}/payments",
        headers=headers,
        json={"amount": "200", "method": "upi"},
    )
    # Outside September in India time.
    await post_sale(client, headers, charger["id"], sold_at=ist("2026-08-31", "23:59"))
    await post_sale(client, headers, charger["id"], sold_at=ist("2026-10-01", "00:30"))

    for name, amount, day in (
        ("Rent", "15000", "2026-09-01"),
        ("Electricity", "2500", "2026-09-30"),
        ("Salary", "8000", "2026-10-01"),
    ):
        await client.post(
            "/api/v1/expenses",
            headers=headers,
            json={"name": name, "amount": amount, "spent_on": day},
        )


async def _september_report(client: AsyncClient, headers: dict[str, str]) -> dict:
    response = await client.get(
        "/api/v1/reports/summary",
        headers=headers,
        params={"date_from": "2026-09-01", "date_to": "2026-09-30"},
    )
    assert response.status_code == 200, response.text
    return response.json()


async def test_report_totals(client: AsyncClient, shop_headers: dict[str, str]) -> None:
    await _september_shop(client, shop_headers)

    report = await _september_report(client, shop_headers)

    assert report["totals"] == {
        "sale_count": 4,
        "revenue": "71996.00",
        "cost": "64800.00",
        "gross_profit": "7196.00",
        "discount": "500.00",
        "expenses": "17500.00",
        "net_profit": "-10304.00",
    }


async def test_report_by_category(client: AsyncClient, shop_headers: dict[str, str]) -> None:
    await _september_shop(client, shop_headers)

    report = await _september_report(client, shop_headers)

    assert [
        (row["name"], row["revenue"], row["profit"], row["quantity"])
        for row in report["by_category"]
    ] == [
        ("Mobile Phones", "70499.00", "6299.00", 2),
        ("Accessories", "1497.00", "897.00", 3),
    ]


async def test_report_by_sale_type(client: AsyncClient, shop_headers: dict[str, str]) -> None:
    await _september_shop(client, shop_headers)

    report = await _september_report(client, shop_headers)

    assert [
        (row["name"], row["revenue"], row["profit"], row["quantity"])
        for row in report["by_sale_type"]
    ] == [
        ("Exchange", "55000.00", "5000.00", 1),
        ("New Phone", "15499.00", "1299.00", 1),
        ("Accessories", "1497.00", "897.00", 2),
    ]


async def test_report_by_payment_method(client: AsyncClient, shop_headers: dict[str, str]) -> None:
    await _september_shop(client, shop_headers)

    report = await _september_report(client, shop_headers)

    assert report["by_payment_method"] == [
        {"method": "cash", "amount": "37998.00"},
        {"method": "exchange", "amount": "18000.00"},
        {"method": "upi", "amount": "15699.00"},
        {"method": "credit", "amount": "299.00"},
    ]


async def test_report_breakdowns_add_up_to_revenue(
    client: AsyncClient, shop_headers: dict[str, str]
) -> None:
    await _september_shop(client, shop_headers)

    report = await _september_report(client, shop_headers)
    revenue = Decimal(report["totals"]["revenue"])

    def total(rows: list[dict], key: str) -> Decimal:
        return sum((Decimal(row[key]) for row in rows), Decimal(0))

    assert total(report["by_category"], "revenue") == revenue
    assert total(report["by_sale_type"], "revenue") == revenue
    assert total(report["by_payment_method"], "amount") == revenue
    assert total(report["by_category"], "profit") == Decimal(report["totals"]["gross_profit"])


async def test_report_ignores_other_shops(
    client: AsyncClient, shop_headers: dict[str, str], other_shop_headers: dict[str, str]
) -> None:
    await _september_shop(client, other_shop_headers)

    report = await _september_report(client, shop_headers)

    assert report["totals"]["sale_count"] == 0
    assert report["totals"]["expenses"] == "0.00"
    assert report["by_category"] == []
    assert report["by_sale_type"] == []
    assert report["by_payment_method"] == []


async def test_single_day_report(client: AsyncClient, shop_headers: dict[str, str]) -> None:
    product = await create_product(client, shop_headers)
    await post_sale(client, shop_headers, product["id"], sold_at=ist("2026-09-10", "23:59"))
    await post_sale(client, shop_headers, product["id"], sold_at=ist("2026-09-11", "00:00"))

    response = await client.get(
        "/api/v1/reports/summary",
        headers=shop_headers,
        params={"date_from": "2026-09-10", "date_to": "2026-09-10"},
    )

    assert response.json()["totals"]["sale_count"] == 1


async def test_report_requires_a_valid_date_range(
    client: AsyncClient, shop_headers: dict[str, str]
) -> None:
    url = "/api/v1/reports/summary"

    missing = await client.get(url, headers=shop_headers, params={"date_from": "2026-09-01"})
    reversed_range = await client.get(
        url, headers=shop_headers, params={"date_from": "2026-09-30", "date_to": "2026-09-01"}
    )

    assert missing.status_code == 422
    assert reversed_range.status_code == 422


async def test_reports_require_login(client: AsyncClient) -> None:
    dashboard = await client.get("/api/v1/dashboard")
    summary = await client.get(
        "/api/v1/reports/summary", params={"date_from": "2026-09-01", "date_to": "2026-09-30"}
    )

    assert (dashboard.status_code, summary.status_code) == (401, 401)
