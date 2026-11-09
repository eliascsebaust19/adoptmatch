# One-prompt migration brief

Copy everything between the lines into a coding agent that has this repository
checked out. Fill the two `<...>` placeholders first.

---

You are migrating **AdoptMatch** (Flutter app + Laravel API + Node admin API) to a
**100% Supabase backend**. When you are done there is no Laravel, no Node, no
MySQL and no Render service in the request path: the app talks to Supabase
(Auth, Postgres, Storage, Edge Functions) and nothing else.

## Starting point

`supabase-edition/` already contains a working scaffold. Do not rebuild it —
read it, apply it, then move the app onto it.

- `supabase/migrations/` — 12 files: 22 tables, RLS on all of them, guard
  triggers, the `app_role` JWT hook, geo RPC, dashboard aggregates, storage buckets
- `supabase/functions/` — `payments`, `admin`, `notify` (strict TypeScript)
- `client/lib/adoptmatch_supabase.dart` — Dart data layer, one method per screen action
- `docs/RLS_MATRIX.md`, `docs/MIGRATION_FROM_LARAVEL.md`, `docs/DEPLOY.md`

## Non-negotiable rules

These come from the project's own audit. Breaking one is a failed task, not a
trade-off:

1. **One auth authority.** Supabase Auth owns the session. Delete Sanctum token
   storage. Never keep two token stores — that split caused the 401s and the
   misleading "server unreachable" dialogs this migration is fixing.
2. **Fail closed.** No session, no premium status, no payment success, no upload
   URL, no admin action may be simulated. Missing configuration returns an error.
3. **Money is server-decided.** The client sends `plan_id` only. Amount and
   currency come from `subscription_plans`. Every SSLCommerz callback is
   re-validated against the gateway and compared with the stored row. Entitlement
   is granted exactly once per `tran_id`. A used bKash TrxID stays consumed even
   after rejection.
4. **Roles come from the JWT.** `app_role` is injected by
   `public.custom_access_token_hook`. Never trust a role sent by the client, and
   never accept a role from sign-up metadata.
5. **No automatic retries of mutating requests.** Waking the backend is fine;
   replaying a register, application or payment call is not.
6. **Secrets stay server-side.** Only the anon key ships in the app.
7. **Do not weaken a policy, delete a test, or add `|| true`** to make CI green.

## Phase 0 — read before writing

`AGENTS.md`, `README.md`, `docs/AUTH_SETUP.md`, `supabase-edition/README.md`,
`supabase-edition/docs/RLS_MATRIX.md`,
`supabase-edition/docs/MIGRATION_FROM_LARAVEL.md`, then
`lib/core/repositories/*.dart`, `lib/core/services/laravel_*.dart`,
`lib/features/auth/bloc/auth_bloc.dart`, `lib/main.dart`.

## Phase 1 — bring the backend up

```bash
cd supabase-edition
supabase link --project-ref <SUPABASE_PROJECT_REF>
supabase db push
supabase functions deploy payments --no-verify-jwt
supabase functions deploy admin notify
supabase secrets set --env-file .env.production
```

Then, in the dashboard:

- Authentication → Providers → Google: client ID + secret, redirect
  `https://<ref>.supabase.co/auth/v1/callback`, and the same origin added in
  Google Cloud Console.
- Authentication → Hooks → Custom access token →
  `public.custom_access_token_hook`. Without this every staff call returns 403.
- Phone provider + SMS credentials if OTP sign-in is kept.

Create the first super admin:

```bash
SUPABASE_URL=https://<ref>.supabase.co SUPABASE_SERVICE_ROLE_KEY=<key> \
ADMIN_EMAIL=... ADMIN_PASSWORD='...' node scripts/bootstrap-admin.mjs
```

## Phase 2 — port the Flutter data layer

1. Copy `client/lib/adoptmatch_supabase.dart` to `lib/core/supabase/`.
2. `lib/main.dart`: `await Supabase.initialize(url: const String.fromEnvironment('SUPABASE_URL'), anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'))`.
3. Replace calls repository by repository, using the mapping table in
   `docs/MIGRATION_FROM_LARAVEL.md`. Keep every interface and model intact so no
   screen needs rewriting:
   - `auth_repository` → `signInWithEmail`, `signUpWithEmail`
   - `google_auth_service` → `google_sign_in` ID token → `signInWithIdToken`
   - `laravel_pet_service`, `pet_repository` → `from('pets_feed')`, `rpc('pets_nearby')`, Storage uploads
   - `application_repository` → `adoption_requests`
   - `chat_repository` → `conversations` / `messages` (+ `.stream()` for live)
   - `subscription_repository` → `functions.invoke('payments/...')`
   - `admin_repository` → `functions.invoke('admin/...')`
4. `AuthBloc`: states and events stay. Swap the internals. Delete the comment
   claiming Supabase must not mint sessions — it is now the only issuer.
5. `SecureStorageService`: stop writing bearer tokens; keep the legacy purge so
   upgrading users lose their old plaintext copies.
6. Splash: decide from `auth.currentSession` instead of `GET /auth/me`, and
   refresh the session once after a role change so the new claim applies.
7. Error copy: keep the wording rules from `lib/core/network/network_error.dart`
   — a timeout says the server did not answer, a validation message keeps the
   server's text, never leak Dart internals.

## Phase 3 — payments UI

`go_premium_screen` → `backend.plans()`; SSLCommerz → `startSslcommerz()` and
open `gateway_url`; on return poll `mySubscription()`. Manual bKash →
`submitManualBkash()` and show "pending admin verification" until approved.
Remove any local premium activation path.

## Phase 4 — admin screens

Point `AdminRepository` at `admin/*` Edge Functions. Drop the Node base URL and
its JWT. After changing a role, call `auth.refreshSession()` before relying on
the new permissions.

## Phase 5 — delete the old stacks

Only after the app works end to end: remove `backend/`, `backend_laravel/`,
`server/`, `src-frontend/`, `render.yaml`, and the Laravel/Node sections of the
README. Update `docs/AUTH_SETUP.md` to describe Supabase-only setup.

## Verification you must actually run

- `flutter analyze --no-fatal-infos` and `flutter test`
- `supabase test db` with pgTAP tests for at least: a user cannot read another
  profile; `payments` insert is denied to authenticated; a listing owner cannot
  self-approve; a non-participant cannot read a conversation
- The manual checklist in `docs/DEPLOY.md` §6, including the negative cases:
  tampered `total_amount`, replayed success callback, reused bKash TrxID,
  non-staff token against `admin/stats`
- `node --check scripts/*.mjs`, `npx tsc --noEmit` for the functions if you
  changed them

## Report format

| Area | What changed | Proof (command + result) | Still unverified |
|---|---|---|---|

Say "not run" when you did not run it. If Docker, Flutter or the Supabase CLI is
missing in your environment, say so and list the exact commands the reviewer has
to run — do not claim success you did not observe.
