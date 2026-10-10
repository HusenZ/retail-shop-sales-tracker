# Retail Shop Sales Tracker

A simple mobile app for small mobile-phone shops in India to record sales fast, track stock,
customer credit and expenses, and see sales and profit. See [`PRD.md`](PRD.md) for the product
requirements.

## Architecture

```text
mobile/   Flutter app (BLoC, GoRouter, Dio; Drift for offline in Phase 7)
   │  HTTPS + JSON, Bearer token
   ▼
backend/  FastAPI + SQLAlchemy (async) + Alembic
   │
   ▼
PostgreSQL
```

- **All money and profit calculations happen on the backend.** Money is stored as
  `NUMERIC(12,2)` and sent in JSON as strings (e.g. `"15499.00"`), never as floats.
- Every shop-owned row has a `shop_id`; the API always scopes queries to the logged-in user's shop.
- One user owns one shop (MVP).

## Requirements

- Python 3.11+
- PostgreSQL 16 (or Docker to run it)
- Flutter 3.24+ (stable)

## Quick start (backend)

```bash
# 1. Database (creates shop_tracker and shop_tracker_test)
docker compose up -d db

# 2. Python environment
cd backend
python -m venv .venv && source .venv/bin/activate
pip install -r requirements-dev.txt

# 3. Configuration
cp .env.example .env        # then set SECRET_KEY

# 4. Migrations
alembic upgrade head

# 5. Run the API
uvicorn app.main:app --reload
```

API docs: http://localhost:8000/docs

See [`backend/README.md`](backend/README.md) for environment variables, migrations and tests.

## Quick start (mobile)

```bash
cd mobile
flutter create . --project-name retail_shop --org in.shopsales --platforms=android,ios  # once
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

See [`mobile/README.md`](mobile/README.md) for Android network settings and running on a phone.

## Running tests

```bash
cd backend
pytest              # needs the shop_tracker_test database
ruff check . && ruff format --check . && mypy app

cd ../mobile
flutter analyze && flutter test
```

## Project status

| Phase | Scope | Status |
|---|---|---|
| 1 | Project setup, database, authentication, shop | Done |
| 2 | Categories, sale types, products | Done |
| 3 | Sales, payments, inventory | Done |
| 4 | Customers, credit, expenses | Done |
| 5 | Dashboard, reports | Done |
| 6 | Flutter app connected to backend | Done |
| 7 | Offline support | |
| 8 | Subscription foundation | |
| 9 | Polish and testing | |
