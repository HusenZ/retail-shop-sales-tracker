# CLAUDE.md

Guidance for working in this repository. Product requirements: `PRD.md`.

## Principles

- MVP for small mobile-shop owners in India. Do not over-engineer; do not build features the PRD
  does not ask for (no Redis, queues, microservices, staff accounts, Razorpay, AI yet).
- Business logic and all money/profit calculations live in the backend. The app displays them.
- Money: `Decimal` in Python, `NUMERIC(12,2)` in Postgres, strings in JSON. Never floats.
- Every shop-owned query must filter by the current shop (`CurrentShop` dependency).
  Another shop's record must look like it does not exist (404).
- Comments explain *why*, not *what*.

## Backend (`backend/`)

- Layers: `api/` (thin routes) → `services/` (business logic) → `models/` (SQLAlchemy).
  Simple CRUD does not need its own service function per operation if it is trivial.
- Raise `NotFoundError` / `ConflictError` / `BusinessRuleError` from `app/core/errors.py`
  in services; they become HTTP responses in one place.
- Partial updates use `PatchModel` (`model_dump(exclude_unset=True)`).
- Timestamps use Python-side defaults (`TimestampMixin`) because async sessions cannot lazily
  refetch server-generated values.
- After changing models: `alembic revision --autogenerate -m "..."`, review the file,
  then `alembic check` must pass.

### Commands (run inside `backend/` with the venv active)

```bash
pytest
ruff check . && ruff format --check .
mypy app
alembic upgrade head && alembic check
uvicorn app.main:app --reload
```

## Mobile (`mobile/`)

- Flutter + flutter_bloc (Cubits) + go_router + Dio. Features under `lib/features/<name>/`
  with `domain/` (entities), `data/` (repositories), `presentation/` (cubits + screens).
- Money is `Decimal` (package `decimal`), parsed from API strings; never `double`, except
  to size a chart bar.
- The app never computes saved figures. Add Sale shows a preview total only; the saved sale,
  profit, dashboard and reports come from the API.
- Every sale sends a `client_ref` created once per sale and reused on retry.
- Repositories that change data mix in `DataChanges`; screens subscribe to refresh.
- Checks: `flutter analyze && flutter test` (CI: `.github/workflows/mobile.yml`).

## Workflow

Work in phases (see README status table). After each phase: tests, lint, type check,
compare against `PRD.md`, then summarize changes and how to run them.
