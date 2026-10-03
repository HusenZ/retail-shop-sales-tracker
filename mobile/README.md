# Mobile app

Flutter app for recording sales, managing products and customers, and viewing reports.
All money figures (totals, profit, pending amounts, reports) come from the backend; the app
only shows them.

## Structure

```text
lib/
  core/        API client, token storage, money/date formatting, router, theme, shared widgets
  features/
    auth/      login, register, session (AuthCubit drives the router)
    shop/      shop setup and editing
    dashboard/ home screen
    sales/     Add Sale, sale history, sale details, payments, sale types
    products/  products, stock adjustment, categories, product picker
    customers/ customers, customer picker, credit
    reports/   sales, profit, categories, sale types, payments
    expenses/  expenses
    settings/
```

Each feature has `domain/` (entities), `data/` (repository calling the API) and
`presentation/` (cubits and screens). Screens get repositories with `context.read`, create
their cubit, and refresh when another screen changes data (repositories expose a `changes`
stream, e.g. the dashboard reloads after a sale).

## First-time setup

The platform folders (`android/`, `ios/`) are not committed yet. Generate them once:

```bash
cd mobile
flutter create . --project-name retail_shop --org in.shopsales --platforms=android,ios
flutter pub get
```

`flutter create` keeps the existing `lib/`, `test/` and `pubspec.yaml`.

For Android, in `android/app/src/main/AndroidManifest.xml`:

- add `<uses-permission android:name="android.permission.INTERNET"/>` above `<application>`
  (needed for release builds);
- while developing against a local `http://` backend, add
  `android:usesCleartextTraffic="true"` to the `<application>` tag. Remove it once the API
  is served over HTTPS.

## Run

Start the backend first (see `../backend/README.md`), then:

```bash
# Android emulator (10.0.2.2 is the host machine)
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000

# Real phone on the same Wi-Fi: use your computer's LAN IP
flutter run --dart-define=API_BASE_URL=http://192.168.1.20:8000
```

The backend must listen on all interfaces for a real phone:
`uvicorn app.main:app --host 0.0.0.0 --reload`.

## Tests and checks

```bash
flutter analyze
flutter test
```

| Test | Covers |
|---|---|
| `test/features/sales/add_sale_cubit_test.dart` | Add Sale rules, request sent to the API, retry keeps the same `client_ref`, credit, part payment, exchange |
| `test/features/sales/add_sale_view_test.dart` | Add Sale screen: default sale type, Save enabled only when valid, saved sheet shows server profit |
| `test/features/auth/auth_cubit_test.dart` | Login, shop setup routing, expired session, offline start |
| `test/features/dashboard/dashboard_view_test.dart` | Dashboard figures and retry |
| `test/features/reports/report_cubit_test.dart` | Report date ranges (today / week from Monday / month / custom) |
| `test/core/*` | ₹ formatting with Indian grouping, input parsing, API error messages, dates |
