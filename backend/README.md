# Backend

FastAPI + SQLAlchemy 2 (async, asyncpg) + Alembic + PostgreSQL.

## Layout

```text
app/
  api/        HTTP routes; thin — validate, resolve the current shop, call a service
  core/       settings, security (hashing, JWT), domain errors
  db/         declarative base, session
  models/     SQLAlchemy tables
  schemas/    Pydantic request/response models
  services/   business logic (shop setup, sales, reports, ...)
  main.py
alembic/      migrations
tests/        pytest, runs against a real PostgreSQL database
```

## Environment variables

Copy `.env.example` to `.env`.

| Variable | Required | Description |
|---|---|---|
| `DATABASE_URL` | yes | `postgresql+asyncpg://user:pass@host:5432/db` |
| `SECRET_KEY` | yes | JWT signing key. `python -c "import secrets; print(secrets.token_urlsafe(48))"` |
| `ACCESS_TOKEN_EXPIRE_MINUTES` | no | Default 43200 (30 days) |
| `SHOP_TIMEZONE` | no | Default `Asia/Kolkata`; defines "today"/"this week" in reports |
| `CORS_ORIGINS` | no | Comma-separated; only for browser clients |
| `TEST_DATABASE_URL` | tests | Database the test suite wipes and recreates |

## Migrations

```bash
alembic upgrade head                                   # apply
alembic revision --autogenerate -m "describe change"   # after changing models; review the file
alembic check                                          # fails if models and migrations differ
```

## Tests and checks

```bash
pytest
ruff check . && ruff format --check .
mypy app
```

Tests create the schema from the models in `TEST_DATABASE_URL` and truncate all tables after
each test. CI additionally runs `alembic upgrade head && alembic check`.

## Authentication

- `POST /api/v1/auth/register` and `POST /api/v1/auth/login` return `{access_token, user}`.
- Send `Authorization: Bearer <token>` on every other request.
- Logout is client-side: the app deletes its stored token.
- Passwords are hashed with Argon2. Everything auth-specific lives in `app/core/security.py` and
  `app/api/deps.py` so it can be replaced with Supabase Auth later.

## API

| Method | Path | Notes |
|---|---|---|
| POST | `/api/v1/auth/register` | |
| POST | `/api/v1/auth/login` | |
| GET | `/api/v1/auth/me` | |
| POST | `/api/v1/shop` | One shop per user; seeds default categories and sale types |
| GET | `/api/v1/shop` | 404 means the user still needs to set up their shop |
| PATCH | `/api/v1/shop` | Partial update |
| GET | `/api/v1/categories` | `?include_inactive=true` to include disabled |
| POST | `/api/v1/categories` | Names are unique per shop, ignoring case |
| PATCH | `/api/v1/categories/{id}` | Rename; `is_active: false` disables |
| GET | `/api/v1/sale-types` | Default first; `?include_inactive=true` |
| POST | `/api/v1/sale-types` | `is_exchange` shows old-phone fields in Add Sale |
| PATCH | `/api/v1/sale-types/{id}` | Rename, disable, `is_default: true` replaces the old default |
| GET | `/api/v1/products` | Filters: `search`, `category_id`, `stock_status` (`in_stock`/`low`/`out`/`not_tracked`), `include_inactive` |
| POST | `/api/v1/products` | Category must belong to the shop and be active |
| GET | `/api/v1/products/{id}` | |
| PATCH | `/api/v1/products/{id}` | Cannot change stock; `is_active: false` disables |
| POST | `/api/v1/products/{id}/stock-adjustment` | `{"change": 5}` or `{"change": -2}`; never below zero |
| POST | `/api/v1/sales` | Normal or exchange sale; see below. 201 new, 200 if `client_ref` was already saved |
| GET | `/api/v1/sales` | Newest first. Filters: `date_from`, `date_to` (shop-local days, inclusive), `sale_type_id`, `category_id`, `payment_method`, `customer_id`, `pending_only`; `limit`/`offset` |
| GET | `/api/v1/sales/{id}` | Items and payments included |
| POST | `/api/v1/sales/{id}/payments` | Collect pending money; cannot exceed what is pending |
| GET | `/api/v1/payments/pending` | Total pending plus the unpaid sales, oldest first |
| GET | `/api/v1/customers` | With purchases, transaction count and pending amount. `search` (name/phone), `pending_only` |
| POST | `/api/v1/customers` | Only `name` required; phone unique per shop |
| GET | `/api/v1/customers/{id}` | Customer's sales: `GET /sales?customer_id=…` |
| PATCH | `/api/v1/customers/{id}` | |
| GET | `/api/v1/expenses` | `date_from`, `date_to`, `limit`; returns `{total, expenses}` (total covers the whole period) |
| POST | `/api/v1/expenses` | `spent_on` defaults to today (shop timezone), cannot be in the future |
| DELETE | `/api/v1/expenses/{id}` | |
| GET | `/api/v1/dashboard` | Today / this week (from Monday) / this month: sales total, count, profit; plus pending payments |
| GET | `/api/v1/reports/summary` | `date_from` and `date_to` required (inclusive, shop-local days) |
| GET | `/health` | |

Money is sent and returned as strings with two decimals, e.g. `"15999.00"`.
Times are returned in UTC; send them with a timezone offset.

## Reports

`GET /reports/summary?date_from=2026-09-01&date_to=2026-09-30` returns:

- `totals`: sale count, revenue (after discounts), cost, gross profit, discount given,
  expenses (by expense date) and net profit = gross profit − expenses.
- `by_category` and `by_sale_type`: revenue, profit and quantity (items sold per category,
  sales per sale type), largest first.
- `by_payment_method`: how the period's revenue was settled — money received per method
  (`cash`, `upi`, `card`, `other`), `credit` still pending, and `exchange` value of old
  phones taken in. These rows add up to revenue. A later payment for a credit sale counts
  toward the period of the original sale.

All figures are aggregated in PostgreSQL (`app/services/report_service.py`).

## Recording a sale

```json
POST /api/v1/sales
{
  "sale_type_id": "…",
  "items": [{"product_id": "…", "quantity": 1}],
  "payment_method": "upi",
  "discount": "500",
  "customer_id": null,
  "client_ref": "uuid-generated-by-the-app"
}
```

Optional: `unit_price` per item (defaults to the product's selling price), `amount_paid`,
`notes`, `sold_at`, and for exchange sale types
`"exchange": {"device_name": "iPhone 12", "imei": null, "value": "18000"}`.

The server, in one transaction: locks the products, checks they are active and in stock,
calculates subtotal → discount → revenue, cost and profit (`app/services/sale_math.py`),
subtracts the exchange value to get the amount due, records the payment, reduces stock and
saves everything. If any step fails nothing is saved.

Payment rules:
- `amount_paid` defaults to the full amount due (or 0 when `payment_method` is `credit`).
- Anything left unpaid needs a `customer_id`, so the shop knows who owes it.
- A credit sale with money paid upfront is recorded as e.g. `cash` with `amount_paid` lower
  than the total, so every rupee received has a real payment method.
