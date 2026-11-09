# AdoptMatch

AdoptMatch is a non-commercial pet adoption, foster, and rescue community platform. The backend has been completely migrated to a **100% Supabase** infrastructure (Auth, Postgres with Row-Level Security, Storage, and Edge Functions). There is no Laravel, no Node backend, no MySQL, and no Render service in the request path.

---

## 🏛 Architecture Overview

| Component | Responsibility | Implementation |
|---|---|---|
| **Client** (`lib/`, `test/`) | Flutter mobile/web application | Dart data layer via `AdoptMatchBackend` (`lib/core/supabase/adoptmatch_supabase.dart`) and Supabase Flutter SDK |
| **Authentication** | Identity, OAuth, OTP, and session management | Supabase Auth (Email/Password, Google OAuth, Phone SMS OTP) |
| **Database & Security** | Data persistence, role-based access control, relational integrity | Supabase Postgres (22 tables, RLS enabled on 100%, guard triggers, `custom_access_token_hook`) |
| **Edge Functions** (`supabase-edition/supabase/functions/`) | Trusted server operations, payment verification, staff moderation | TypeScript / Deno runtime (`payments`, `admin`, `notify`) |
| **Storage** | Pet pictures, adoption documents, avatars | Supabase Storage (`pets`, `avatars`, `attachments`) with RLS upload policies |
| **AI Matching** (`ai-service/`) | Standalone pet-to-adopter compatibility scoring | FastAPI microservice |

---

## 🔒 Security Invariants & Rules

1. **One Auth Authority**: Supabase Auth owns the session. No legacy Sanctum or secondary token stores.
2. **Fail Closed**: No simulated sessions, premium statuses, payment successes, or admin actions.
3. **Server-Decided Money**: The client specifies only `plan_id`. Pricing and currency come from `subscription_plans`. SSLCommerz callbacks are re-validated against the gateway. A used bKash TrxID stays permanently consumed.
4. **JWT-Decided Roles**: `app_role` is injected by `public.custom_access_token_hook`. Client claims or user metadata are never trusted for privileges.
5. **No Mutating Retries**: Mutating requests are never automatically retried to prevent duplicate actions.
6. **Secrets Stay Server-Side**: Only `SUPABASE_URL` and the public `SUPABASE_ANON_KEY` ship inside the Flutter app.

---

## 🚀 Getting Started

### 1. Supabase Backend Deployment

The database migrations, RLS policies, and Edge Functions live under `supabase-edition/`:

```bash
cd supabase-edition

# 1. Link your Supabase project
supabase link --project-ref <YOUR_SUPABASE_PROJECT_REF>

# 2. Push database schema, RLS policies, and hooks
supabase db push

# 3. Deploy Edge Functions
supabase functions deploy payments --no-verify-jwt
supabase functions deploy admin notify

# 4. Set Edge Function secrets
supabase secrets set --env-file .env.production

# 5. Bootstrap the initial super administrator
SUPABASE_URL=https://<YOUR_SUPABASE_PROJECT_REF>.supabase.co \
SUPABASE_SERVICE_ROLE_KEY=<YOUR_SERVICE_ROLE_KEY> \
ADMIN_EMAIL=<ADMIN_EMAIL> \
ADMIN_PASSWORD='<ADMIN_PASSWORD>' \
node scripts/bootstrap-admin.mjs
```

### 2. Dashboard Configurations

In the [Supabase Dashboard](https://app.supabase.com):
- **Authentication → Providers → Google**: Enter Google Web Client ID and Secret. Redirect URI: `https://<YOUR_SUPABASE_PROJECT_REF>.supabase.co/auth/v1/callback`.
- **Authentication → Hooks → Custom Access Token**: Enable and assign `public.custom_access_token_hook`. *(Essential for admin and moderator role authorization).*
- **Authentication → Phone**: Configure SMS provider if Phone OTP is active.

### 3. Flutter Application

Run the Flutter app pointing to your Supabase project:

```bash
flutter pub get
flutter run \
  --dart-define=SUPABASE_URL=https://<YOUR_SUPABASE_PROJECT_REF>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<YOUR_SUPABASE_ANON_KEY>
```

---

## 🧪 Local Verification

```bash
# Static analysis (zero errors, warnings clean)
flutter analyze --no-fatal-infos

# Run full test suite (59 unit and widget tests)
flutter test

# Syntax verification of bootstrap and seed scripts
node --check supabase-edition/scripts/bootstrap-admin.mjs
node --check supabase-edition/scripts/seed-demo.mjs
```
