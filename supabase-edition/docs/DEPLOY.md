# Deploy and verify

## 1. Project

Create the project on the **Pro** plan if it must never pause — free projects are
paused after about a week of low activity, which is exactly the cold-start problem
this edition is meant to end.

```bash
supabase link --project-ref <ref>
supabase db push
```

`db push` applies every migration in order and then `seed.sql`. The seed only
touches the plan catalogue, so re-running it is safe.

## 2. Auth

1. Providers → Google: paste the Web client ID/secret. The app's Android build
   keeps using `serverClientId`; nothing else changes.
2. Authentication → Hooks → **Custom access token** → `public.custom_access_token_hook`.
   *Skip this and every staff action returns 403 — the JWT will have no `app_role`.*
3. URL configuration → add `https://<your-web-domain>` and the deep link
   `adoptmatch://auth-callback`.
4. Phone provider, if OTP is wanted. Without SMS credentials the OTP screen
   fails with a clear error; it never pretends an SMS was sent.

## 3. Functions

```bash
supabase functions deploy payments --no-verify-jwt   # gateway callbacks have no session
supabase functions deploy admin
supabase functions deploy notify

supabase secrets set --env-file .env.production
```

`payments` is deployed without JWT verification because SSLCommerz cannot present
one. It compensates by validating every callback against the gateway's
`validationserverAPI` and matching `tran_id`, amount and currency.

## 4. First admin

```bash
SUPABASE_URL=https://<ref>.supabase.co \
SUPABASE_SERVICE_ROLE_KEY=<service-role-key> \
ADMIN_EMAIL=you@example.com ADMIN_PASSWORD='<strong-password>' \
node scripts/bootstrap-admin.mjs
```

Refuses to run if a super admin already exists.

## 5. Gateway webhooks

In the SSLCommerz merchant panel set:

- IPN: `https://<ref>.supabase.co/functions/v1/payments/sslcommerz/ipn`
- Success/Fail/Cancel are sent in each session request and need no panel entry.

Keep `SSLCOMMERZ_SANDBOX=true` until a real ৳1 transaction is verified end to end,
then flip it and redeploy.

## 6. Verification checklist

Run these against the hosted project before pointing the app at it. Each one
either proves a rule or produces a message you can show a user.

**Auth**
- [ ] Sign up with email → `profiles` row exists with `role = adopter`.
- [ ] Sign up with metadata `{"role":"admin"}` → role is still `adopter`.
- [ ] Google sign-in returns a session and the JWT contains `app_role`.

**RLS (use the anon key and a normal user token)**
- [ ] `select * from profiles` → only your own row (403/empty for others).
- [ ] `select * from payments` → only your own rows; `insert` is rejected.
- [ ] `update pets set moderation_status='approved'` on someone else's listing → 0 rows.
- [ ] `update profiles set role='admin'` → role unchanged after re-read.
- [ ] Reading another user's `messages` rows returns nothing.

**Money**
- [ ] `payments/initiate-sslcommerz` returns a `gateway_url` and a `pending` row.
- [ ] Tampering `total_amount` in the browser form does not change the stored amount
      (validation compares against `payments.amount`).
- [ ] Replaying the success callback does not extend the subscription twice.
- [ ] Manual bKash with a TrxID already used → 409.
- [ ] Admin approve → `subscriptions` row created, `payments.applied_at` set.

**Admin**
- [ ] Non-staff token → `admin/stats` returns 403.
- [ ] Staff token → stats numbers match `count(*)` in SQL.
- [ ] Every mutation appears in `audit_logs`.

## 7. Known gaps to close before launch

- `delete-account` function (client method exists, endpoint does not).
- Schedule `expire_subscriptions()` hourly (pg_cron or a scheduled function).
- Load-test the feed with `explain analyze` once there are real rows; the current
  indexes cover moderation + created_at, species, city and owner.
