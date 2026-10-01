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

## API (Phase 1)

| Method | Path | Notes |
|---|---|---|
| POST | `/api/v1/auth/register` | |
| POST | `/api/v1/auth/login` | |
| GET | `/api/v1/auth/me` | |
| POST | `/api/v1/shop` | One shop per user; seeds default categories and sale types |
| GET | `/api/v1/shop` | 404 means the user still needs to set up their shop |
| PATCH | `/api/v1/shop` | Partial update |
| GET | `/health` | |
