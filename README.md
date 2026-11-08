# AdoptMatch

AdoptMatch is a non-commercial pet adoption and foster platform. This repository contains several stacks that are **not interchangeable**:

| Directory | Purpose | Status in this checkout |
|---|---|---|
| `lib/`, `test/` | Flutter consumer/admin/shelter app | Source updated; Flutter analyze/test/device checks are still pending in CI or a provisioned SDK. |
| `backend/` | Node 22 admin, payment, auth and upload API with SQLite persistence | Local security/persistence suite passes. |
| `backend_laravel/` | Laravel consumer API: pets, adoption applications, messages, uploads, phone OTP | Feature tests added; PHP/Composer were unavailable here, so they must run in CI. |
| `server/`, `src-frontend/` | Legacy Node/MySQL API and React demo frontend | Legacy auth regression test and React production build pass. Do not deploy the legacy API as the production consumer backend. |
| `ai-service/` | FastAPI matching service | Matching regression tests pass. |

The Flutter app uses one configured root, `ApiClient.rootUrl` (`--dart-define=API_BASE_URL=...`, legacy alias `BACKEND_URL`), defaulting to `https://adoptmatch-api.onrender.com`. Consumer calls append `/api/v1`; Node admin/payment calls use the same root. Deploy the stacks behind a gateway that routes those paths, or change the client configuration before pointing at separate hosts. Do not point browser or device builds at `localhost`.

## Security and configuration notes

- **No demo admin credentials.** Bootstrap the first Node superadministrator with a verified Google subject:
  ```bash
  cd backend
  DATABASE_PATH=/var/lib/adoptmatch/adoptmatch.sqlite \
    npm run bootstrap:admin -- --google-sub <google-sub> --email <email> --name <name>
  ```
  The command is one-time and fails if a superadministrator already exists.
- Node production startup requires a durable `DATABASE_PATH`, a `JWT_SECRET` of at least 32 characters, `GOOGLE_CLIENT_ID`, and configured payment/storage secrets for the features being enabled. Run **one Node process per SQLite file**; use a server database before horizontal scaling.
- Google sign-in requires a verified ID token, audience/issuer/expiry checks, and a server-issued session. Public registration cannot assign admin/shelter roles.
- SSLCommerz activation validates the gateway response and matches transaction, store, amount, currency and status. Simulation is disabled in production. Manual bKash TrxIDs are unique across all payment statuses and bound to the authenticated payer.
- Phone OTP is delegated to Supabase Auth from the Laravel server (`SUPABASE_URL`, `SUPABASE_ANON_KEY`). Without those values the endpoints return 503; they do not fabricate success.
- Uploads require authentication and real image bytes. Configure Laravel Cloudinary/public storage or Node Vercel Blob; unavailable storage returns an error.
- Flutter tokens/profiles and sensitive application drafts are written only through secure storage. Secure-storage write failures fail closed. Logout clears private local indexes and chat/application caches.
- Android release builds require `android/key.properties`; missing release signing fails the build instead of using debug signing.

Features that are **not configured** are reported as unavailable rather than simulated: voice relay, SOS device broadcast, PDF report export, push delivery without FCM credentials, and revenue/dispute/adoption-ledger KPIs that the Node service does not measure. Digital signatures are application records, not a claim of legally binding e-contract execution.

## Local verification commands

```bash
# Node admin/payment API (Node >= 22.13)
cd backend && npm ci && npm test

# Legacy API auth regressions (isolated non-production memory provider)
cd server && npm ci && npm test

# React frontend
cd src-frontend && npm ci && npm run build

# AI matching
cd ai-service && pip install -r requirements.txt pytest && pytest -q

# Flutter (requires a provisioned Flutter SDK)
flutter pub get && flutter analyze && flutter test

# Laravel (requires PHP 8.3+, Composer, SQLite/PDO)
cd backend_laravel && composer install && cp .env.example .env && vendor/bin/phpunit
```

The CI definition lives at **`docs/ci/ci.yml`** and is **not installed yet**: the push credential used for this branch lacks GitHub's `workflows` permission, so `.github/workflows/` could not be created. A maintainer must copy it to `.github/workflows/ci.yml` (see `docs/ci/README.md`) before any hosted run happens. A workflow file is not evidence that a hosted run has passed; check the run for the exact commit before quoting CI results.

## Verified in this workspace (2026-11-08)

| Check | Result |
|---|---|
| `backend npm test` | Exit 0: 30 security regression checks, Google/storage/admin/subscription suites, 6 persistence/concurrency checks. |
| `server npm test` | Exit 0: 4 legacy auth checks plus production MySQL fail-closed check. |
| AI direct regression runner | 9/9 matching tests passed. |
| `src-frontend npm run build` | Exit 0; Vite warns the main chunk exceeds 500 kB. |
| `npm audit` (backend/server/src-frontend) | 0 reported vulnerabilities at audit time. |
| Dart/PHP source parse | 73 changed Dart/PHP files, 0 syntax errors. **Syntax parsing is not Flutter analyze, PHPUnit, type checking, or runtime verification.** |
| Flutter analyze/test/device builds | **Not run here** (SDK unavailable). |
| Laravel PHPUnit / live OAuth, SMS, gateway, storage | **Not run here** (PHP/Composer and live credentials unavailable). |

See `BUG_REPORT.md` for the original AM-01..AM-20 findings and `audit-resolution-report.md` for the current verified-vs-pending mapping. Do not describe the audit as “20/20 production verified” until the pending runtime checks and credential rotation/history review are complete.
