# Authentication & Configuration Guide (Supabase Edition)

AdoptMatch authentication is powered 100% by **Supabase Auth**. This eliminates sleeping containers, Render cold-start timeouts, and dual-token synchronization failures.

---

## 🔑 Required Credentials

| # | Credential | Where to Obtain | Destination |
|---|---|---|---|
| 1 | **Supabase Project URL & Anon Key** | Supabase Dashboard → Project Settings → API | Flutter app (`--dart-define=SUPABASE_URL=...`, `--dart-define=SUPABASE_ANON_KEY=...`) |
| 2 | **Web OAuth Client ID** (`...apps.googleusercontent.com`) | Google Cloud Console → APIs & Services → Credentials → OAuth Client ID (Web Application) | Supabase Dashboard (Auth → Providers → Google) and `lib/core/config/auth_config.dart` |
| 3 | **Android Keystore SHA-1** | `keytool -list -v -keystore ~/.android/debug.keystore` | Google Cloud Console (Android Client Registration) |
| 4 | **iOS Bundle Identifier** | `com.adoptmatch.adoptmatch` | Google Cloud Console (iOS Client Registration) & `ios/Flutter/GoogleAuth.xcconfig` |
| 5 | **SSLCommerz Store ID & Password** | SSLCommerz Merchant Portal | `supabase-edition/.env.production` (Edge Function Secrets) |

---

## 🛠️ Step-by-Step Setup

### 1. Google OAuth
1. Create a **Web Application** client in Google Cloud Console.
2. In Supabase Dashboard → **Authentication** → **Providers** → **Google**:
   - Enable the Google provider.
   - Enter your Client ID and Client Secret.
   - Add the Authorized Redirect URI:
     `https://<YOUR_PROJECT_REF>.supabase.co/auth/v1/callback`
3. Add the same redirect URI to Authorized Redirect URIs in the Google Cloud Console.

### 2. Custom Access Token Hook
In Supabase Dashboard → **Authentication** → **Hooks**:
- Select **Custom Access Token**.
- Point it to schema function: `public.custom_access_token_hook`.
- This ensures the user's verified role from `public.profiles` is injected into the JWT claims as `app_role`.

### 3. Bootstrap Super Admin
To grant the initial administrative access, run:

```bash
cd supabase-edition
SUPABASE_URL=https://<YOUR_PROJECT_REF>.supabase.co \
SUPABASE_SERVICE_ROLE_KEY=<YOUR_SERVICE_ROLE_KEY> \
ADMIN_EMAIL=admin@adoptmatch.org \
ADMIN_PASSWORD='StrongPassword123' \
node scripts/bootstrap-admin.mjs
```

---

## 🛡️ Error Handling & Troubleshooting

- **"Invalid email or password"**: The credentials provided did not match any verified record in Supabase Auth.
- **"403 Forbidden: Access Denied"**: The account does not have staff privileges (`admin`, `super_admin`, `moderator`). Ensure `custom_access_token_hook` is active.
- **"Check your email to confirm the account"**: Supabase Email Confirmations are enabled in your project; the user must click the verification link before signing in.
