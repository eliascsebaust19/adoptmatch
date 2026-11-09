# AdoptMatch Supabase Backend Configuration & Security Guide

This document details the configuration, security invariants, storage policies, Edge Functions, and dashboard requirements for the 100% Supabase backend of AdoptMatch.

---

## 1. Architecture Overview

AdoptMatch operates without legacy Laravel, Node backend, or MySQL in the request path:
```
[Flutter Client] ────► [Supabase Auth] (Tokens & Sessions)
       │         ────► [Supabase Postgres + RLS] (Data layer via PostgREST)
       │         ────► [Supabase Storage] (Avatars, Pets, Encrypted Attachments)
       │         ────► [Supabase Edge Functions] (Payments, Moderation, Push)
       └─────────────► [FastAPI AI Service] (Independent 7-Dimension Matching)
```

---

## 2. Authentication & Authorization

### Session & Token Rules
- **Single Auth Issuer**: Only Supabase Auth mints sessions and tokens.
- **Fail Closed**: No simulated sessions, mock roles, or local promotion.
- **Role Invariant**: Roles (`adopter`, `foster`, `pet_owner`, `shelter`, `moderator`, `admin`, `super_admin`) are injected server-side by `public.custom_access_token_hook` into the JWT claim `app_role`.
- **Client Metadata Immunity**: User metadata sent during signup is never trusted for authorization.
- **Profile Role Guard**: The trigger `profiles_guard_role` (`private.enforce_profile_role`) strictly freezes `role`, `is_verified`, and `status` against self-service updates by non-admin users.

### Dashboard Configuration Required:
1. **Authentication → Hooks**:
   - Enable **Custom Access Token (JWT)** hook.
   - Set function to: `public.custom_access_token_hook`.
2. **Authentication → Providers → Google**:
   - Client ID: `<YOUR_GOOGLE_CLIENT_ID>`
   - Client Secret: `<YOUR_GOOGLE_CLIENT_SECRET>`
   - Authorized Redirect URI: `https://<PROJECT_REF>.supabase.co/auth/v1/callback`
3. **Authentication → Settings**:
   - Ensure **Email Confirmations** are configured with your custom SMTP (or auto-confirm for sandbox testing).

---

## 3. Storage Security & Policies

Four buckets are provisioned in Supabase Storage:

| Bucket | Public? | Max Size | Allowed MIME | Read Policy | Upload / Write Policy |
|---|---|---|---|---|---|
| `pet-images` | **Yes** | 5 MB | JPEG, PNG, WEBP | Public (anyone can read) | Listing owner (`{user_id}/*`) or staff |
| `avatars` | **Yes** | 2 MB | JPEG, PNG, WEBP | Public | Profile owner (`{user_id}/*`) |
| `chat-attachments` | **No** (Private) | 10 MB | JPEG, PNG, WEBP, PDF | Only conversation members or staff | Only message sender (`{conv_id}/{user_id}/*`) |
| `application-docs` | **No** (Private) | 10 MB | PDF, JPEG, PNG | Applicant, pet owner, or staff | Applicant only (`{app_id}/{user_id}/*`) |

> **Privacy Guarantee**: Adoption documents (salaries, ID proofs, rental agreements) and private chat files are in private buckets with row-level security checks and are **never** publicly accessible.

---

## 4. Row Level Security (RLS) Matrix Summary

RLS is enabled on **100% of public tables**:
- `profiles`: Users read and update their own profile. Staff read/update all. Role/status protected by trigger.
- `shelters`: Public reads approved shelters. Shelter owners create and update their shelter. Verification status protected by trigger.
- `pets`: Public reads approved & available/foster pets. Listing owners update non-moderation fields. Staff approves/rejects.
- `adoption_requests`: Applicant reads own. Pet owner reads applications for their pets. Transitions guarded by `enforce_application_transitions`.
- `appointments`: Parties read own. Requester creates and can only cancel. Pet owner confirms/completes. Immutable relations enforced by `enforce_appointment_guards`.
- `community_posts`: Public reads approved. Author cannot modify `likes_count`, `comments_count`, or `moderation_status`. Counter triggers run with `SECURITY DEFINER`.
- `payments`: Insert/update denied to clients; written exclusively by Edge Functions using the service role. Users can only select their own payment records.
- `subscriptions`: Client read-only. Entitlements granted idempotently by `apply_paid_payment`.

---

## 5. Edge Functions & Required Secrets

Three Edge Functions run in the Deno runtime under `supabase-edition/supabase/functions/`:

### 1. `payments`
- **JWT Verification**: Disabled (`--no-verify-jwt`) to allow gateway callbacks from SSLCommerz.
- **Pricing Authority**: Prices are loaded directly from `subscription_plans` in Postgres.
- **Gateway Validation**: Every callback is verified against SSLCommerz validation API before granting entitlement.
- **Idempotency**: Subscriptions are granted exactly once per `tran_id`.

### 2. `admin`
- **JWT Verification**: Enabled (`verify_jwt: true`).
- **Authorization**: Re-checks `profiles.role` using `requireStaff()`.
- **Auditing**: Every mutation (moderation, refund, role change) logs to `audit_logs`.

### 3. `notify`
- **JWT Verification**: Enabled (`verify_jwt: true`).
- **Delivery**: Dispatches push notifications via FCM HTTP v1 API.

### Required Edge Function Secrets (Set via `supabase secrets set`):
```bash
# Payments (SSLCommerz)
SSLCOMMERZ_STORE_ID=your_store_id
SSLCOMMERZ_STORE_PASSWORD=your_store_password
SSLCOMMERZ_SANDBOX=true # or false for live production
PAYMENT_RETURN_URL=https://adoptmatch.app/payments/result

# Push Notifications (Firebase Cloud Messaging)
FCM_SERVICE_ACCOUNT_JSON={"project_id":"...","client_email":"...","private_key":"..."}

# Official bKash Number for Manual Verification
OFFICIAL_BKASH_NUMBER=017XXXXXXXX
```

---

## 6. AI Matching Microservice Integration

- **Decoupled Architecture**: Supabase does **not** run matching algorithms.
- **Flow**:
  1. Flutter fetches available pet profiles from Supabase (`pets` feed / `pets_nearby`).
  2. Flutter collects the user's 28-field lifestyle assessment.
  3. Flutter sends both to the FastAPI AI service (`POST /api/v1/match`).
  4. AI service computes 7-dimensional weighted scoring, enforces hard welfare constraints, normalizes exercise requirements, and evaluates existing household pet compatibility.
  5. Ranked results and transparent reasoning are presented to the adopter.
