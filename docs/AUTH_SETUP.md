# Authentication Setup — what you must provide

কোডের দিকটা ঠিক করা আছে (fail-closed, verified tokens only)। নিচের **৫টা জিনিস** না দিলে Google/OTP login চলবে না — এগুলো secret/registration, কোড দিয়ে বানানো যায় না।

## 1. What I need from you

| # | Value | Where to get it | Where it goes |
|---|---|---|---|
| 1 | **Web OAuth client ID** (`...apps.googleusercontent.com`) | Google Cloud Console → APIs & Services → Credentials → Create OAuth client → **Web application** | `backend/.env` → `GOOGLE_CLIENT_ID`; `backend_laravel/.env` → `GOOGLE_CLIENT_ID`; Flutter build → `--dart-define=GOOGLE_CLIENT_ID=`; `web/index.html` meta; `ios/Flutter/GoogleAuth.xcconfig` → `GOOGLE_WEB_CLIENT_ID` |
| 2 | **Android OAuth client** (package + SHA-1) | Same console → Create OAuth client → **Android**. Package `com.adoptmatch.adoptmatch`, SHA-1 of **debug AND release** keystores | Registered in Google Cloud (nothing to paste in code) |
| 3 | **iOS OAuth client ID** + reversed URL scheme | Same console → Create OAuth client → **iOS**, bundle id `com.adoptmatch.adoptmatch` | `ios/Flutter/GoogleAuth.xcconfig` → `GOOGLE_IOS_CLIENT_ID`, `GOOGLE_IOS_URL_SCHEME` |
| 4 | **Supabase project URL + anon key** (phone OTP) | Supabase dashboard → Project Settings → API. Enable **Phone** provider + SMS provider (Twilio/MessageBird) credentials | `backend_laravel/.env` → `SUPABASE_URL`, `SUPABASE_ANON_KEY` |
| 5 | **Strong `JWT_SECRET`** (≥ 32 chars) + durable `DATABASE_PATH` | Generate: `openssl rand -hex 32` | `backend/.env` |

Already-present default in code: web client `94403915199-c47hcn9ols70b1gikoamlrgkbqqdmag6...`. **Confirm you own this Google Cloud project** — otherwise replace it everywhere with yours.

### Also needed for a real release (not auth-blocking)
- SSLCommerz `STORE_ID` / `STORE_PASSWORD` + HTTPS callback domain, bKash merchant number
- Cloudinary (`CLOUD_NAME`, `API_KEY`, `API_SECRET`) **or** Vercel Blob `BLOB_READ_WRITE_TOKEN`
- FCM server key (push), Android `key.properties` + keystore (release signing)
- First admin: your **Google account email** (to read its `sub`) for `npm run bootstrap:admin`

> Secret গুলো chat-এ দিও না। সার্ভারের `.env` ফাইলে বসাও (git-ignored)। শুধু client ID গুলো public — সেগুলো chat-এ দিলেও সমস্যা নেই।

## 2. Google Cloud Console steps

1. Create/select project → **OAuth consent screen**: External, app name, support email, scopes `email`, `profile`, `openid`. Add yourself as a test user while in "Testing".
2. **Credentials → Create OAuth client → Web application**
   - Authorized JavaScript origins: `https://<your-web-domain>`, and `http://localhost:<port>` for dev
   - Copy the client ID → item 1 above
3. **Create OAuth client → Android**: package `com.adoptmatch.adoptmatch` + SHA-1:
   ```bash
   # debug
   keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android | grep SHA1
   # release (uses your upload/release keystore)
   keytool -list -v -keystore <your-release.keystore> -alias <alias> | grep SHA1
   ```
   Register **both** fingerprints (Play App Signing SHA-1 too if you use Play signing).
4. **Create OAuth client → iOS**: bundle id `com.adoptmatch.adoptmatch`. Copy the client ID and the "iOS URL scheme" (reversed client ID) into `GoogleAuth.xcconfig`.

## 3. Wire it up

```bash
# Node admin/payment API
cd backend
cp .env.example .env            # fill GOOGLE_CLIENT_ID, JWT_SECRET, DATABASE_PATH
npm run check:config            # preflight: exits 1 if auth config is unusable
npm test

# Laravel consumer API
cd ../backend_laravel
cp .env.example .env            # fill GOOGLE_CLIENT_ID, SUPABASE_URL, SUPABASE_ANON_KEY
php artisan key:generate && php artisan migrate
vendor/bin/phpunit

# Flutter
flutter pub get
flutter run --dart-define=GOOGLE_CLIENT_ID=<web-client-id> \
            --dart-define=API_BASE_URL=https://<your-api-host>
```

**One client ID everywhere.** The app sends Google's ID token with `aud = <web client id>` (it is passed as `serverClientId` on mobile). Both APIs verify that audience; a different ID → HTTP 401.

## 4. What the code now guarantees

- **Single source of truth**: `lib/core/config/auth_config.dart` holds the client ID for Google Sign-In, Supabase and the token exchange. The divergent Node dev-only default was removed.
- **Fail closed**: no client ID → Node `503 GOOGLE_AUTH_NOT_CONFIGURED`, Laravel `503`; no ID token from Google → actionable error, never an empty-token request; no server session → no signed-in user.
- **Verification**: signature + audience allow-list (`GOOGLE_CLIENT_ID` + optional `GOOGLE_CLIENT_IDS`) + issuer + expiry + subject + verified email. Privileged accounts are never auto-linked by email.
- **One session authority**: Supabase email login/signup fallbacks and the Supabase auth-state listener were removed from `AuthBloc` — a Supabase JWT is not accepted by the Laravel/Node APIs, so it must not create an app session. Supabase is used server-side for phone OTP only.
- **Password change is real**: `POST /api/v1/auth/password` verifies the current password, requires ≥ 8 chars + confirmation, re-hashes, and revokes other sessions. The dialog no longer has an offline "success" path.
- **iOS is configurable**: `GIDClientID` / `GIDServerClientID` / URL scheme come from `ios/Flutter/GoogleAuth.xcconfig` instead of being missing entirely.

## 5. Verification status

| Check | Status |
|---|---|
| Node Google suite (missing token 400, forged token 401, unconfigured 503, session revoke, banned 403) | **Passing locally** (`node test_google_auth.js`) |
| `npm run check:config` | **Passing locally** (fails closed when unset) |
| Dart/PHP syntax parse of the whole repo | **0 errors** (syntax only — not analysis) |
| Laravel password-change + Google audience tests | **Written, not executed here** (no PHP/Composer) |
| `flutter analyze` / `flutter test` after this change | **Not run here** (no Flutter SDK) — CI runs them |
| Real Google account sign-in on Android/iOS/web | **Not done** — needs items 1–3 above |
| Real SMS OTP delivery | **Not done** — needs item 4 above |
