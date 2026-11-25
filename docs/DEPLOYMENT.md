# AdoptMatch — Production Deployment & Operations Guide

## 1. Production Endpoints & Distribution

| Component | Platform | Production URL / Artifact |
| :--- | :--- | :--- |
| **Frontend Web (User & Admin)** | Vercel (`adoptmatch-app`) | `https://adoptmatch-app.vercel.app` |
| **Admin Portal Route** | Vercel SPA | `https://adoptmatch-app.vercel.app/admin/dashboard` |
| **Android Mobile App** | Release APK | `build/app/outputs/flutter-apk/app-release.apk` |
| **Primary Backend & Database** | Supabase (PostgreSQL 15 + GoTrue + Storage + Realtime + Edge Functions) | `https://wgztdhabgedhkaippkpd.supabase.co` |
| **Secondary / Legacy REST API** | Render (Laravel 11 Docker) | `https://adoptmatch-api.onrender.com` |

---

## 2. Database, Real-Time Sync & Storage Configuration

- **Primary Database**: Supabase PostgreSQL (`wgztdhabgedhkaippkpd`) configured via SQL migrations in `supabase-edition/supabase/migrations/`.
- **Real-Time Pet Synchronization**:
  - `PetRepository.startRealtimeSync()` subscribes to `public.pets` via Supabase Realtime (`postgres_changes`) and pairs it with a 25-second catch-up sync + automatic channel reconnect handler.
  - `PetMatchBloc` subscribes to `PetRepository.petsStream` and re-applies active filters live whenever an admin creates, edits, archives, restores, deletes, or re-uploads pet photos.
  - Migration `20261125100000_realtime_pets_and_admin_sync.sql` adds `public.pets` and `public.pet_images` to `supabase_realtime`, sets `replica identity full`, and exposes `gallery_urls` + active-only filtering on `public.pets_feed`.
- **Cloud Image Storage (`pet-images` bucket)**:
  - Public read, authenticated owner/staff write & delete (`20261109091200_storage_buckets.sql`).
  - Client-side validation in `StorageService.validateAndDetectPetImage`: enforces JPG, JPEG, PNG, and WebP formats (checked via magic bytes + extension) and a 5 MB max limit.
  - Obsolete cloud images are deleted via `StorageService.deletePetImageByUrl()` when replaced or removed.

---

## 3. Environment Variables (Do Not Commit Secrets)

### Flutter Build / Runtime (`--dart-define` or `.env`)
- `SUPABASE_URL` — Hosted Supabase project URL.
- `SUPABASE_ANON_KEY` — Public anonymous key (protected by Row-Level Security).
- `GOOGLE_CLIENT_ID` — Google Web OAuth Client ID.
- `API_BASE_URL` — Secondary Laravel REST base URL (`https://adoptmatch-api.onrender.com`).
- `GEMINI_API_KEY` — Optional live Gemini AI key (keep out of public web builds; omit to use the built-in local AdoptMatch AI assistant).
- `ENABLE_VIVA_DEMO` — Keep `false` in production (`true` enables academic demo login shortcuts only).

### Supabase Edge Functions (`supabase secrets set`)
- `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`
- `SSLCOMMERZ_STORE_ID`, `SSLCOMMERZ_STORE_PASSWD`, `SSLCOMMERZ_SANDBOX`
- `PAYMENT_CALLBACK_BASE`, `FCM_SERVICE_ACCOUNT_JSON`

---

## 4. Build & Deployment Commands

### Deploy Flutter Web to Vercel
```bash
flutter build web --release
cp web/vercel.json build/web/vercel.json
vercel deploy build/web --prod --yes
```

### Build Release Android APK
```bash
flutter build apk --release
```

### Apply Supabase Migrations & Edge Functions (Requires `supabase login`)
```bash
cd supabase-edition
supabase login
supabase link --project-ref wgztdhabgedhkaippkpd
supabase db push
supabase functions deploy admin
supabase functions deploy notify
supabase functions deploy payments --no-verify-jwt
```

---

## 5. Required Dashboard Configurations & Remaining Limitations

1. **Supabase Auth Redirect URLs** (Supabase Dashboard → Authentication → URL Configuration):
   - Add `https://adoptmatch-app.vercel.app/auth-callback`
   - Add `https://adoptmatch-app.vercel.app/auth/reset-password`
   - Add `adoptmatch://auth-callback`
2. **Supabase Custom Access Token Hook** (Authentication → Hooks → Custom Access Token):
   - Enable `public.custom_access_token_hook` so `app_role` is included in JWTs for direct RLS staff policies.
3. **Pending Supabase CLI Push**:
   - `20261125100000_realtime_pets_and_admin_sync.sql` and the updated `supabase/functions/admin/index.ts` are committed locally and must be pushed with `supabase db push` and `supabase functions deploy admin` once `supabase login` is authenticated on the deployment host. Until then, `PetRepository` uses its 25-second catch-up poll alongside WebSocket listeners to propagate updates across devices.
4. **Gemini API Key on Public Web**:
   - Intentionally omitted from the public Vercel web bundle (`flutter build web --release`) so no private AI key is exposed in client JavaScript; the web AI assistant runs via the local `AiAssistantService` fallback unless proxied through a server endpoint.
