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
| 4b | **Android Release/Upload Key SHA-1** | from your keystore or Play Console | Google Cloud Console (second Android client, required for release builds) |
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
   - the exact production origin of the web build, e.g. `https://adoptmatch.app`
   - `https://wgztdhabgedhkaippkpd.supabase.co`
4. Under **Authorized redirect URIs**, add:
   - `https://wgztdhabgedhkaippkpd.supabase.co/auth/v1/callback` (Supabase exchanges the code here)
   - `http://localhost:5000`
   - the production origin, e.g. `https://adoptmatch.app`
5. Save the configuration.

> The app never talks to Google's token endpoint directly on web. Supabase
> redirects to `/auth/v1/callback`, then back to the app on `/auth-callback`
> with `?code=`. That second URL is registered in Supabase (step 2 below), not
> in Google Cloud Console.

### 2. Android OAuth Client Registration
On Android, Google Play Services requires an **Android-specific OAuth client** linked to the keystore certificate:
1. In Google Cloud Console Credentials, click **+ CREATE CREDENTIALS** → **OAuth client ID**.
2. Select Application type: **Android**.
3. Set Name: `AdoptMatch Android Debug`.
4. Set Package name: `com.adoptmatch.adoptmatch`.
5. Enter SHA-1 certificate fingerprint:
   `88:60:0E:C9:44:D9:F7:FE:5B:DC:53:74:3C:BA:B1:25:32:0C:09:7B`
6. Click **CREATE**.

> This fingerprint belongs to the debug keystore. A Play Store build is signed
> with your upload key and **needs its own Android OAuth client** (same package
> name, different SHA-1). Get it with:
>
> ```bash
> keytool -list -v -keystore <your-upload-keystore.jks> -alias <keyAlias>
> ```
>
> If Play App Signing is enabled, use the SHA-1 shown in Play Console →
> App integrity → App signing key certificate. Without it, Google sign-in works
> in debug builds and fails with `ApiException 10` in release builds.
   *(Note: The Flutter code continues to use the **Web Client ID** as `serverClientId` so the issued ID token has the audience verified by Supabase).*

---

## ⚡ Supabase Dashboard Configuration

### 1. Google Provider
1. Go to Supabase Dashboard → **Authentication** → **Providers** → **Google**.
2. Ensure Google is **Enabled**.
3. Set **Client ID**: `<YOUR_GOOGLE_WEB_CLIENT_ID>`.
4. Set **Client Secret**: `<YOUR_GOOGLE_CLIENT_SECRET>`.
5. Ensure Callback URL matches: `https://wgztdhabgedhkaippkpd.supabase.co/auth/v1/callback`.

### 2. URL Configuration (required for every login method that redirects)
Supabase Dashboard → **Authentication** → **URL Configuration**.

Set **Site URL** to the origin the app is served from, and add every redirect
the client can send. `AuthConfig` builds these values at runtime:

| Client | Value |
|---|---|
| Web OAuth / confirmation | `<current origin>/auth-callback` |
| Web password recovery | `<current origin>/auth/reset-password` |
| Android / iOS OAuth + confirmation | `adoptmatch://auth-callback` |
| Android / iOS password recovery | `adoptmatch://auth-callback?type=recovery` |

For local development that means at least:

```
http://localhost:5000
http://localhost:5000/auth-callback
http://localhost:5000/auth/reset-password
adoptmatch://auth-callback
adoptmatch://auth-callback?type=recovery
```

A missing entry is what produces `requested path is invalid` or sends the
browser to a blank page after Google sign-in. The local
`supabase-edition/supabase/config.toml` already lists them for `supabase start`.

### 3. Custom Access Token Hook
In Supabase Dashboard → **Authentication** → **Hooks**:
- Select **Custom Access Token**.
- Point it to schema function: `public.custom_access_token_hook`.
- This ensures the user's verified role from `public.profiles` is injected into the JWT claims as `app_role`.

---

### 4. Email (confirmation and recovery links)
Dashboard → **Authentication** → **Email**.
- With confirmations **on**, sign-up returns no session and the app shows
  "check your inbox" instead of an error. Nothing is broken; the user has to
  click the link, then sign in.
- Custom SMTP is required for real inboxes. The built-in sender is rate limited
  and often lands in spam during development.
- Email templates → **Confirm signup** / **Reset password** should use
  `{{ .ConfirmationURL }}`, which carries the redirect configured above.

---

## 🛡️ Error Handling & Troubleshooting

- **"Google did not return an ID token"**:
  - **Android**: Ensure the Android client with package `com.adoptmatch.adoptmatch` and SHA-1 `88:60:0E:C9:44:D9:F7:FE:5B:DC:53:74:3C:BA:B1:25:32:0C:09:7B` is created in Google Cloud Console.
  - **Web**: Ensure the active port (e.g. `http://localhost:5000`) is listed in Authorized JavaScript origins.
- **"ApiException 10"**: Package name or SHA-1 fingerprint mismatch in Google Cloud Console.
- **"Error 400: origin_mismatch"**: The browser origin does not match any entry in Authorized JavaScript origins.
- **"Invalid email or password"**: The credentials provided did not match any verified record in Supabase Auth.
- **Sign-up says "check your email" instead of signing you in**: That is the
  expected path when email confirmations are enabled. Use the *Resend email*
  action if the message never arrives.
- **Password reset link opens but there is no form**: The link must come back to
  `/auth/reset-password` (web) or `adoptmatch://auth-callback?type=recovery`.
  Check that both are in the redirect allowlist and that the email template
  forwards `{{ .RedirectTo }}`.
- **Profile photo upload fails**: Objects must be stored under
  `{user_id}/...` in the `avatars` bucket. A path outside that prefix is
  rejected by the storage policy.
- **"403 Forbidden: Access Denied"**: The account does not have staff privileges (`admin`, `super_admin`, `moderator`).
