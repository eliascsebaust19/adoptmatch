# AdoptMatch — Supabase edition

The whole backend on Supabase: Postgres + Row Level Security for the domain,
Supabase Auth for identity (Google, email, phone OTP), Storage for media, and
Edge Functions for the two things that must not run in the client — payments and
admin actions.

No Laravel, no Node.js, no MySQL, no server to keep awake.

```
Flutter app ──► Supabase Auth (JWT with app_role)
            ├─► PostgREST  → tables + views + RPCs, filtered by RLS
            ├─► Storage    → pet images, avatars, chat attachments
            └─► Edge Functions
                  payments  (SSLCommerz, manual bKash, entitlement)
                  admin     (users, moderation, shelters, stats, audit trail)
                  notify    (FCM HTTP v1)
```

## What is in here

| Path | Contents |
|---|---|
| `supabase/migrations/` | Schema, guard triggers, JWT hook, RPCs, RLS policies, storage buckets |
| `supabase/functions/` | `payments`, `admin`, `notify` + shared modules |
| `supabase/seed.sql` | Plan catalogue (safe to ship) |
| `client/lib/adoptmatch_supabase.dart` | Flutter data layer that replaces the Laravel repositories |
| `scripts/bootstrap-admin.mjs` | Creates the first super admin, once |
| `scripts/seed-demo.mjs` | Optional demo shelter + listings |
| `docs/` | RLS matrix, migration map, deploy steps |

## Local setup

```bash
# 1. Tooling
brew install supabase/tap/supabase        # or: npm i -g supabase
docker --version                          # supabase start needs Docker

# 2. Boot the stack (Postgres, Auth, Storage, Studio, Edge runtime)
supabase start

# 3. Apply migrations + seed plans
supabase db reset

# 4. Edge Function secrets (local values live in .env by default)
cp .env.example .env
supabase functions serve payments admin notify --env-file .env
```

`supabase status` prints the local API URL and the anon/service keys. Point the
Flutter app at those while developing.

## Hosted setup

```bash
supabase link --project-ref <your-project-ref>
supabase db push                     # migrations + seed
supabase functions deploy payments --no-verify-jwt   # gateway callbacks
supabase functions deploy admin
supabase functions deploy notify

supabase secrets set --env-file .env.production
```

Then, in the dashboard:

1. **Authentication → Providers → Google** — paste the Web client ID and secret.
   Authorised redirect: `https://<ref>.supabase.co/auth/v1/callback`. Add the
   same origin to Google Cloud Console.
2. **Authentication → Hooks → Custom access token** — choose
   `public.custom_access_token_hook`. Without this, `app_role` never reaches the
   JWT and every staff policy denies.
3. **Authentication → Phone** — enable the SMS provider (Twilio/MessageBird) if
   OTP sign-in is wanted.
4. **Storage** — buckets are created by the migration; nothing to click.

## Environment

Server-side (Edge Function secrets):

| Name | Used by | Notes |
|---|---|---|
| `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY` | all functions | injected automatically on hosted projects |
| `SSLCOMMERZ_STORE_ID`, `SSLCOMMERZ_STORE_PASSWORD` | payments | 503 when missing |
| `SSLCOMMERZ_SANDBOX` | payments | `false` switches to the live gateway |
| `PAYMENT_CALLBACK_BASE` | payments | defaults to `<project>/functions/v1/payments` |
| `PAYMENT_RETURN_URL` | payments | where the browser lands after checkout |
| `FCM_SERVICE_ACCOUNT_JSON` | notify | full service-account JSON, one line |

Client-side (dart-define): `SUPABASE_URL`, `SUPABASE_ANON_KEY`.

## Authentication model

- **One authority.** Supabase issues the session. The app stores nothing except
  the session that `supabase_flutter` manages.
- **Roles live in the JWT.** `custom_access_token_hook` copies
  `profiles.role` into the `app_role` claim, so RLS reads it without querying
  `profiles` per row. A revoked role takes effect on the next token refresh
  (≤ 1 hour with the default `jwt_expiry`).
- **Sign-up cannot self-promote.** The `on_auth_user_created` trigger ignores
  user metadata and always creates an `adopter`; the profile guard trigger
  reverts any role change made without an admin claim.
- **Phone-only accounts** get a synthetic email so the profile stays unique.

## Money model

1. The client sends only `plan_id`.
2. The function reads the price from `subscription_plans` — the client cannot
   choose an amount.
3. SSLCommerz responds; the function re-validates with the gateway's
   `validationserverAPI` and compares `tran_id`, amount and currency.
4. `payments.status` becomes `paid` exactly once; `apply_paid_payment` grants
   entitlement and is idempotent per `tran_id`.
5. Manual bKash needs an admin approval; a used TrxID can never be reused, even
   after rejection (partial unique index on `upper(trx_id)`).

No simulation path exists. Missing credentials produce a 503, not a fake receipt.

## What is implemented vs. not

Implemented: schema for all app domains, RLS on 22 tables, storage policies, auth
hook, geo RPC, dashboard aggregates, SSLCommerz + bKash flows, admin
moderation/RBAC/audit, FCM push, first-admin bootstrap.

Not implemented yet (honest list):

- `delete-account` Edge Function — the client method exists and will fail
  clearly rather than pretend.
- PDF export of the health passport.
- pg_cron wiring for `expire_subscriptions()` (the function exists; schedule it
  in the dashboard or call it from an Edge cron).
- Call/SOS voice relay — same "not configured" stance as the original app.
- End-to-end tests against a live project; see `docs/DEPLOY.md` for the manual
  verification checklist.

## Cost

Supabase Pro is required for a project that must never pause (free projects pause
after about a week of low activity): **$25/month**, which covers Postgres, Auth,
Storage, Edge Functions and daily backups. There is no second service to pay for.

## Extracting this folder into its own repository

The edition lives in a subfolder so it can be split out in one command:

```bash
./scripts/publish-edition.sh adoptmatch-supabase
```

It runs `git subtree split`, creates the new repository with `gh`, and pushes the
split branch as `main`. Run it from the parent repository root.
