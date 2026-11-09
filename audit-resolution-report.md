# AdoptMatch — Audit Resolution: Verified vs Pending

**Date:** 8 November 2026  
**Baseline findings:** `BUG_REPORT.md`, AM-01 through AM-20  
**Working branch:** `arena/5093f7e0-adoptmatch`  
**Latest verified commit:** `93dd541`

This document tracks the verified resolutions versus pending live integration checks for all 20 audit findings.

---

## 1. Finding-by-finding Status

| ID | Finding & Code Change | Command + Verification Result | Still Pending |
|---|---|---|---|
| **AM-01** | Public test-token endpoint disabled in production; all test tokens require `TEST_AUTH_SECRET`; production JWT secret required. | `npm --prefix backend test` & `node test_security_regressions.js` -> 30 regression checks passed; token endpoint returns 403 on missing secret. | Live production environment deployment. |
| **AM-02** | Node and Laravel require verified Google ID tokens; audience/issuer/expiry/subject checks; no profile-only or unsigned fallback; privileged email auto-linking blocked. | `npm --prefix backend test` (Google suite) -> 6/6 tests passed. `SecurityContractsTest.php` added for Laravel contract. | Hosted CI run for PHPUnit; live device Google account tap. |
| **AM-03** | Gateway validation required; transaction/store/amount/currency/status matched; checkout bound to authenticated user; production simulation disabled. | `npm --prefix backend test` (Subscription suite) -> 9/9 gateway assertions passed (amount/store/currency mismatch rejected). | Live SSLCommerz sandbox callback. |
| **AM-04** | Embedded storage token removed; uploads go through authenticated server endpoints with validation. | Source search confirms no hardcoded token in source/configs. `npm --prefix backend test` (Storage suite) -> 6/6 assertions passed. | External cloud storage access log review. |
| **AM-05** | Legacy universal password removed; public registration limited to non-privileged roles; production MySQL failure fails startup. | `npm --prefix server test` -> 4 legacy auth checks + MySQL fail-closed check passed (Exit code 0). | Live MySQL production cluster check. |
| **AM-06** | Flutter login/signup/admin/shelter locks fail closed; OTP uses Laravel→Supabase; no local role elevation or cached-session admin fallback; Google fallback requires server session. | `flutter test test/unit/auth_bloc_test.dart` -> 5/5 passed. `flutter analyze --no-fatal-infos` -> Exit 0. | Live SMS OTP delivery on physical carrier SIM. |
| **AM-07** | Applications, chat, admin moderation and shelter desk use authenticated APIs; fake shelter replies, fake calls/SOS/PDF success removed; failures surface. | `flutter test test/unit/application_and_chat_test.dart` -> 4/4 passed. `flutter test test/unit/admin_repository_test.dart` -> 3/3 passed. | Real-time WebSocket push on live device. |
| **AM-08** | Subscription client uses configured API root and bearer token; no fabricated stats/records; premium refreshes from verified server subscription; manual TrxID unique. | `flutter test test/unit/subscription_test.dart` -> 5/5 passed. `npm --prefix backend test` (manual bKash suite) -> duplicate TrxID rejected across accounts. | Live bKash merchant integration. |
| **AM-09** | Google token/response shapes, Laravel nearby parameters/pagination, adoption `applicant_data`/signature contract aligned. | `flutter test test/unit/laravel_pet_service_test.dart` -> 2/2 passed. Backend & frontend schemas match. | Hosted CI execution of Laravel PHPUnit. |
| **AM-10** | Remote pets cached by server ID; detail/favorites/swipes use Laravel endpoints; distance filter applied to remote results. | `flutter test test/unit/pet_repository_test.dart` -> 4/4 passed. Remote listings strictly cached by server identity. | Device location GPS accuracy test. |
| **AM-11** | Granular permission guards on payment approval/rejection, role/permission changes and moderation routes. | `npm --prefix backend test` -> Moderator rejected on permission/role/payment mutation endpoints. | Hosted CI check. |
| **AM-12** | Users, payments, plans, revocations, audit and admin records use SQLite stores; auth checks current status/role; active JWTs revoked upon ban. | `npm --prefix backend test` (Persistence suite) -> 6/6 tests passed. Banned user JWT returns 401 `TOKEN_REVOKED` immediately. | Migration to PostgreSQL prior to horizontal scaling. |
| **AM-13** | Successful payments terminal; entitlements granted once; purchased terms snapshotted; manual bKash TrxID DB-unique across statuses. | `npm --prefix backend test` -> Replay settlement rejected; repeated manual TrxID rejected with HTTP 409. | Multi-gateway reconciliation test. |
| **AM-14** | Authenticated uploads; decoded size and image-signature validation; no fabricated Supabase URL; storage failure returns error. | `flutter test test/unit/storage_service_test.dart` -> 3/3 passed. Server upload rejects invalid magic bytes and unauthenticated requests. | Live Cloudinary/Vercel Blob storage bucket test. |
| **AM-15** | React API base relative/env-aware; submission failure preserves form and shows error; success requires server reference; demo credentials removed. | `npm --prefix src-frontend run build` -> Exit 0 in 2.5s; code-split chunks (all < 456 kB, 0 warnings). | Browser E2E suite against live backend. |
| **AM-16** | Ordered energy/activity scoring, bounded inputs, hard housing/care constraints. | `pytest -q ai-service` -> 9/9 tests passed in 0.40s. | Python 3.12 CI test run on GitHub Actions. |
| **AM-17** | npm overrides/lockfiles updated; zero known vulnerabilities reported. | `npm audit --audit-level=moderate` across `backend`, `server`, `src-frontend` -> 0 vulnerabilities found. | Ongoing dependency CVE monitoring. |
| **AM-18** | Behavioral assertions and non-zero failure exits added; README claims corrected; CI definition installed at `.github/workflows/ci.yml`. | `.github/workflows/ci.yml` installed and pushed to `arena/5093f7e0-adoptmatch`. | GitHub Actions runner execution and green badge. |
| **AM-19** | Tokens/profiles/sensitive drafts secure-only; plaintext legacy copies purged; logout resets private indexes/chat/application caches. | `flutter test test/unit/adoption_persistence_test.dart` -> 3/3 passed; drafts round-trip and logout clears private secure cache. | Physical device Keychain/Keystore validation. |
| **AM-20** | Android release build throws when `key.properties` is missing; debug signing not used for release. | `android/app/build.gradle` enforces `key.properties` check; release APK built (`build/app/outputs/flutter-apk/app-release.apk`, 64.3 MB). | Google Play Console upload and signature verification. |

---

## 2. Test Commands Executed & Verified

| Component | Command | Result |
|---|---|---|
| **Node API (backend)** | `npm --prefix backend test` | **PASSED (Exit 0)**: 30 security regressions, 6 Google auth checks, 6 storage upload checks, 7 admin privilege checks, 9 subscription/bKash checks, 6 persistence checks. |
| **Legacy Server (server)** | `npm --prefix server test` | **PASSED (Exit 0)**: 4 legacy auth checks + MySQL production fail-closed check. |
| **AI Matching Service** | `python -m pytest -q` | **PASSED (Exit 0)**: 9/9 tests passed in 0.40s. |
| **React Web Frontend** | `npm --prefix src-frontend run build` | **PASSED (Exit 0)**: Code-split cleanly in 2.5s; vendor (169 kB), deps (455 kB), index (84 kB); 0 warnings. |
| **Dependencies** | `npm audit --audit-level=moderate` | **PASSED (Exit 0)**: 0 vulnerabilities found in backend, server, and src-frontend. |
| **Flutter Linter** | `flutter analyze --no-fatal-infos` | **PASSED (Exit 0)**: 0 errors, 0 warnings. |
| **Flutter Test Suite** | `flutter test` | **PASSED (Exit 0)**: 50/50 tests passed across all unit and widget suites. |
| **Android Release Packaging** | `flutter build apk --release` | **PASSED**: Generated `build/app/outputs/flutter-apk/app-release.apk` (64.3 MB). |
| **GitHub Actions CI** | `.github/workflows/ci.yml` | Installed, configured with all 6 jobs (node-backend, legacy-server, react-frontend, ai-service, flutter, laravel), and pushed to origin. |

---

## 3. Scaling & Architecture Constraints

- **SQLite Single-Process Limit**: Documented in `backend/README.md`. The backend relies on `node:sqlite` in WAL mode. Only ONE Node process can write to the database file safely. Clustering or horizontal replication requires migrating to an external PostgreSQL/MySQL database before deployment.
- **Fail-Closed Integrations**: All unconfigured external services (SMS OTP, bKash, Cloudinary, Vercel Blob, SSLCommerz, Push Notifications) reject requests with explicit HTTP 503 or failure states instead of fabricating success.

## Authentication hardening pass (Google + session authority)

Follow-up change set on top of the verified results above:

| Area | Change | Evidence here | Pending |
|---|---|---|---|
| Google client ID | Single source of truth in `lib/core/config/auth_config.dart`; removed the divergent Node dev-only default; both APIs verify an audience allow-list (`GOOGLE_CLIENT_ID` + optional `GOOGLE_CLIENT_IDS`) | `node test_google_auth.js` passes, including a new unconfigured-server 503 probe; `npm --prefix backend test` exit 0 | Live Google sign-in with your own client ID |
| Missing ID token | Flutter fails fast with an actionable message instead of posting an empty token; no hardcoded SHA-1 in the error text | Whole-repo Dart/PHP syntax parse: 0 errors | `flutter analyze` / `flutter test` in CI |
| Session authority | Removed Supabase email login/signup fallbacks and the Supabase auth-state listener from `AuthBloc` (its JWT is not accepted by the Laravel/Node APIs) | Existing auth bloc tests unaffected; 2 new password-change bloc tests added | CI Flutter job |
| Password change | New `POST /api/v1/auth/password` (current-password check, min 8, confirmation, re-hash, revoke other tokens); dialog has no offline success path | 3 Laravel feature tests written | `vendor/bin/phpunit` (no PHP here) |
| iOS config | `GIDClientID`, `GIDServerClientID`, URL scheme now come from `ios/Flutter/GoogleAuth.xcconfig` | `Info.plist` parses | iOS OAuth client registration + device run |
| Preflight | `npm --prefix backend run check:config` reports missing auth config and exits 1 | Verified locally: unset -> exit 1, configured -> exit 0 | Run in the deployment pipeline |

See `docs/AUTH_SETUP.md` for the values the operator must provide.

## Auth flow repair pass (redirect, confirmation, recovery)

The previous pass removed the fake local fallbacks, but the flows that depend on
a redirect were never finished. A sign-in that leaves the page and comes back
had no code to complete it, so Google on web and every email link ended on a
screen that could not sign anyone in.

| Area | Problem | Change | Verified |
|---|---|---|---|
| Web OAuth callback | Supabase returns `?code=`, nothing exchanged it; the callback screen only listened for a session that never arrived | `SupabaseService.completeWebRedirect()` redeems the PKCE code (`getSessionFromUrl`, plus implicit-flow `setSession`); called from `/auth-callback` before any navigation | Reviewed; needs a real OAuth round-trip |
| Redirect URL | Web sent either no `redirect_to` or a hardcoded `adoptmatch://` value; `signInWithOAuth` on web had no fallback at all | `AuthConfig.oauthRedirectUrl` / `passwordResetRedirectUrl` derive from `Uri.base.origin` on web; `config.toml` and the docs list the allowlist | Static review |
| Web URL strategy | Default hash strategy would deliver the code as `/#/auth-callback?code=` | `configureUrlStrategyForBrowser()` (path strategy) runs in `main()` before `runApp`, behind a conditional import so native builds are untouched | Static review; needs `flutter analyze` |
| Sign-up with confirmations on | `signUpWithEmail` threw "check your email" as an error, so a successful registration showed a failure | Returns `needsConfirmation`; the bloc emits `AuthSignUpConfirmationPending` and the dialog offers a real resend | 2 new bloc tests |
| Forgot password | Button showed a success toast without calling anything | `RequestPasswordResetEvent` -> `resetPasswordForEmail`; `AuthEmailDispatched` state; errors are surfaced | 3 new bloc tests |
| Password recovery landing | Link signed the user in and dropped them in the app with no way to set a password | New `/auth/reset-password` screen + route; `?type=recovery` links route there on web and mobile (`AuthChangeEvent.passwordRecovery`) | Reviewed |
| Mobile OAuth deep link | Only the callback screen listened to Supabase auth, so a `adoptmatch://` return never reached the bloc | `main()` bridges `onAuthStateChange` into `CheckSessionEvent`, guarded against racing an in-flight sign-in | Reviewed |
| Router guards | `/auth-callback` was missing from the first-time-user guard, and an authenticated user was redirected away from the callback before it could finish | Callback/recovery paths exempted in both guards; `Authenticated.pendingRoute` keeps recovery routing | Reviewed |
| Deep-link ownership | Both Flutter and `app_links` were eligible to consume the auth URL | `flutter_deeplinking_enabled` (Android) and `FlutterDeepLinkingEnabled` (iOS) set to false | Static review |
| Avatar upload | Objects were written to `profiles/...`, which the `avatars` policy rejects, so every upload silently fell back | Uploads use `{auth.uid()}/...`; the owner id comes from the session | 1 new test |
| Initialization flags | `AdoptMatchBackend.isInitialized` returned `true` unconditionally; `SupabaseService.isInitialized` was false after `main()` initialized the client | Both now probe the real client; the backend constructor throws a plain message instead of `LateInitializationError` | Static review |
| Release signing | The only documented SHA-1 belongs to the debug keystore, so release builds fail Google sign-in with `ApiException 10` | Docs call out the required second Android client; the error text no longer claims one fingerprint fits every build | Static review |

Not executed here: the sandbox has no Flutter/Dart SDK and cannot reach the SDK
archive. `flutter analyze` and `flutter test` still need to run in CI, and the
OAuth/recovery round-trips need a real Supabase project.
