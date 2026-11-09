# Authentication & Configuration Guide (Supabase Edition)

AdoptMatch authentication is powered 100% by **Supabase Auth**. This eliminates sleeping containers, Render cold-start timeouts, and dual-token synchronization failures.

---

## 🔑 Required Credentials & Platform Identifiers

| # | Credential | Value / Source | Destination |
|---|---|---|---|
| 1 | **Supabase Project URL & Anon Key** | `https://wgztdhabgedhkaippkpd.supabase.co` | `lib/main.dart` & build `--dart-define` |
| 2 | **Web OAuth Client ID** | Google Cloud Console (Web Client) | Supabase Auth Provider, `lib/core/config/auth_config.dart`, `web/index.html` |
| 3 | **Android Package Name** | `com.adoptmatch.adoptmatch` | `android/app/build.gradle` & Google Cloud Console (Android Client) |
| 4 | **Android Debug Keystore SHA-1** | `88:60:0E:C9:44:D9:F7:FE:5B:DC:53:74:3C:BA:B1:25:32:0C:09:7B` | Google Cloud Console (Android Client Registration) |
| 5 | **Android Debug Keystore SHA-256** | `25:DC:13:41:C1:91:DA:44:A7:FB:00:1B:33:FD:47:6F:73:A6:2F:39:90:FB:1D:2B:80:AB:A7:33:6D:40:E6:39` | Google Cloud Console (App Integrity / Asset Links) |
| 6 | **iOS Bundle Identifier** | `com.adoptmatch.adoptmatch` | Google Cloud Console (iOS Client) & `ios/Flutter/GoogleAuth.xcconfig` |

---

## 🛠️ Step-by-Step Google Cloud Console Setup

### 1. Web Application OAuth Client
1. Go to [Google Cloud Console Credentials](https://console.cloud.google.com/apis/credentials).
2. Create or select the **Web application** OAuth client ID.
3. Under **Authorized JavaScript origins**, add:
   - `http://localhost`
   - `http://localhost:5000` (for local development via `flutter run -d chrome --web-port=5000`)
   - `https://wgztdhabgedhkaippkpd.supabase.co`
4. Under **Authorized redirect URIs**, add:
   - `https://wgztdhabgedhkaippkpd.supabase.co/auth/v1/callback`
   - `http://localhost:5000`
5. Save the configuration.

### 2. Android OAuth Client Registration
On Android, Google Play Services requires an **Android-specific OAuth client** linked to the keystore certificate:
1. In Google Cloud Console Credentials, click **+ CREATE CREDENTIALS** → **OAuth client ID**.
2. Select Application type: **Android**.
3. Set Name: `AdoptMatch Android Debug`.
4. Set Package name: `com.adoptmatch.adoptmatch`.
5. Enter SHA-1 certificate fingerprint:
   `88:60:0E:C9:44:D9:F7:FE:5B:DC:53:74:3C:BA:B1:25:32:0C:09:7B`
6. Click **CREATE**.
   *(Note: The Flutter code continues to use the **Web Client ID** as `serverClientId` so the issued ID token has the audience verified by Supabase).*

---

## ⚡ Supabase Dashboard Configuration

### 1. Google Provider
1. Go to Supabase Dashboard → **Authentication** → **Providers** → **Google**.
2. Ensure Google is **Enabled**.
3. Set **Client ID**: `<YOUR_GOOGLE_WEB_CLIENT_ID>`.
4. Set **Client Secret**: `<YOUR_GOOGLE_CLIENT_SECRET>`.
5. Ensure Callback URL matches: `https://wgztdhabgedhkaippkpd.supabase.co/auth/v1/callback`.

### 2. Custom Access Token Hook
In Supabase Dashboard → **Authentication** → **Hooks**:
- Select **Custom Access Token**.
- Point it to schema function: `public.custom_access_token_hook`.
- This ensures the user's verified role from `public.profiles` is injected into the JWT claims as `app_role`.

---

## 🛡️ Error Handling & Troubleshooting

- **"Google did not return an ID token"**:
  - **Android**: Ensure the Android client with package `com.adoptmatch.adoptmatch` and SHA-1 `88:60:0E:C9:44:D9:F7:FE:5B:DC:53:74:3C:BA:B1:25:32:0C:09:7B` is created in Google Cloud Console.
  - **Web**: Ensure the active port (e.g. `http://localhost:5000`) is listed in Authorized JavaScript origins.
- **"ApiException 10"**: Package name or SHA-1 fingerprint mismatch in Google Cloud Console.
- **"Error 400: origin_mismatch"**: The browser origin does not match any entry in Authorized JavaScript origins.
- **"Invalid email or password"**: The credentials provided did not match any verified record in Supabase Auth.
- **"403 Forbidden: Access Denied"**: The account does not have staff privileges (`admin`, `super_admin`, `moderator`).
