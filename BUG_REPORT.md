# AdoptMatch — Bug and Error Report

**Audit date:** 8 November 2026  
**Reviewed commit:** `1229a7b471643ed0370737f9e15857fde52db5e4`  
**Branch:** `arena/5093f7e0-adoptmatch`

## Summary

The repository is not ready for a production release. The most serious problems allow unauthenticated administrative access, account impersonation, and subscription activation without a valid payment. Several advertised workflows only change local demo data instead of communicating with a server.

This report contains **20 findings: 5 critical, 11 high, and 4 medium**. Severity describes the potential impact if the affected code is deployed; it does not mean a live deployment was tested.

| Area | Main result |
|---|---|
| Flutter application | Authentication fallbacks bypass verification; applications, chat, and most admin actions are local-only; several API contracts do not match. |
| `backend/` Node API | Public admin-token issuance, Google identity bypass, forgeable payments, ineffective bans, and false upload success. |
| `backend_laravel/` API | Google identity bypass and request/response contract problems. PHP execution was unavailable. |
| `server/` legacy Node API | Universal password and caller-selected administrative role. |
| `src-frontend/` React app | Production build passes, but API addressing and submission error handling are broken. |
| `ai-service/` | Matching sometimes compares the lengths of labels rather than lifestyle compatibility. |
| Dependencies | npm reports one critical, eleven high, and seven moderate vulnerable-package entries across the three Node projects. |

## Checks performed

| Check | Result |
|---|---|
| `backend`: `npm ci` | Passed |
| `node test_subscription_payments.js` | Passed; tests accept the insecure simulator path |
| `node test_admin_features.js` | Passed; does not cover the authorization gaps below |
| `node test_google_auth.js` | Reported pass; contains no assertions and forces exit code 0 |
| `node test_storage_upload.js` | Reported pass; checks only the returned URL, not stored bytes |
| Targeted local Node HTTP reproductions | Confirmed the backend findings identified below |
| `src-frontend`: `npm ci`, `npm run build` | Passed; Vite warned that the main JavaScript bundle exceeds 500 kB |
| JSX syntax check | 17 files passed |
| JavaScript syntax checks | Passed for project `.js` files outside dependencies |
| Python compilation | Passed |
| Direct matching-engine reproductions | Confirmed incorrect compatibility scores |
| `npm audit` | Findings summarized in AM-17 |
| `flutter analyze`, `flutter test`, device tests | Not run: Flutter/Dart SDK is not installed |
| Laravel/PHP tests | Not run: PHP and Composer are not installed |

Tests used ephemeral local servers and seeded data. No live deployment, payment gateway, Google account, or cloud storage credential was tested. Secret values are deliberately omitted from this report.

---

## Critical findings

### AM-01 — Anyone can obtain an administrative JWT

**Location:** `backend/server.js:40–69`; `backend/middleware/rbacMiddleware.js:8`  
**Verification:** Runtime reproduced.

`POST /api/v1/auth/token` accepts a caller-selected role and signs a JWT without authenticating the caller. The endpoint is not disabled in production. The signing secret also has a public, hardcoded fallback.

**Reproduction:** Send an empty-authentication request with `role: SUPER_ADMIN`, then call `/api/v1/admin/stats` with the returned token. Both requests returned HTTP 200.

**Impact:** Complete compromise of the Node administrative API, including user management, moderation, and payment approval.

**Fix:** Remove this endpoint from deployed builds. Require a strong secret at startup and fail closed when it is missing. Issue tokens only after verified authentication.

### AM-02 — Google login accepts attacker-supplied identity

**Location:** `backend/routes/authRoutes.js:34–64, 91–138, 166–178`; `backend_laravel/app/Http/Controllers/Api/AuthController.php:29–85`  
**Verification:** Node runtime reproduced; Laravel confirmed in source.

The Node endpoint accepts a profile object without an ID token, including in production. Its token-info fallback also fails to check the audience. Laravel decodes the JWT payload without verifying its signature when verification fails, and also accepts a supplied profile. Both implementations link accounts by email.

**Reproduction:** With `NODE_ENV=production`, a profile containing a seeded superadministrator email returned HTTP 200 and a JWT carrying `SUPER_ADMIN`.

**Impact:** An attacker can impersonate an existing user or administrator and receive a server-issued session.

**Fix:** Require a cryptographically verified Google ID token. Check signature, issuer, audience, expiry, subject, and verified-email status. Remove profile and unsigned-claim fallbacks. Do not link privileged accounts using an unverified email.

### AM-03 — Payments can be activated without paying

**Location:** `backend/routes/paymentRoutes.js:75–102, 157–174, 241–260, 271–298, 369–386`  
**Verification:** Runtime reproduced, including with `SSLCOMMERZ_IS_LIVE=true`.

The public IPN handler trusts the submitted `status` and never validates it with SSLCommerz. The success callback accepts any validation ID beginning with `SIMULATED-VAL-`, regardless of live mode. Payment initiation accepts an arbitrary `userId`. Even when gateway validation runs, its transaction ID, amount, and currency are not matched against the local payment.

**Reproductions:**
- A forged IPN activated a 365-day subscription for another user.
- A simulated validation ID activated a failed payment with the live-mode flag enabled.
- A mocked gateway response for **1 USD and a different transaction** activated a **499 BDT** payment.

**Impact:** Free premium access, payment-account corruption, and revenue loss.

**Fix:** Validate every activation with the gateway. Match transaction ID, store, amount, currency, and status. Bind checkout to the authenticated user. Keep simulation behind an explicit non-production test configuration that cannot share live entitlement logic.

### AM-04 — A storage read/write credential is embedded in client code

**Location:** `lib/core/services/storage_service.dart:14–17, 63–81`; `backend_laravel/app/Http/Controllers/Api/UploadController.php:25–27`; `backend_laravel/config/services.php:40–42`; both backend `.env.example` files.  
**Verification:** Confirmed in source; credential validity was not tested.

A Vercel Blob read/write token appears as a compiled Flutter default and as a server-side fallback. The Flutter client sends it directly in an authorization header. The same literal is repeated in configuration examples.

**Impact:** If active, anyone extracting the token can perform storage operations permitted by that credential. Putting it behind `String.fromEnvironment` does not protect the default value compiled into the app.

**Fix:** Revoke and rotate the exposed credential if real. Remove it from source, examples, and build artifacts; review repository history and storage access logs. Upload through an authenticated server endpoint or a narrowly scoped, short-lived upload authorization.

### AM-05 — Legacy API has a universal password and public admin registration

**Location:** `server/controllers/authController.js:8–56, 71–98`; `server/config/db.js:19–31`  
**Verification:** Runtime reproduced against the in-memory provider; MySQL path confirmed in source.

Login accepts `password123` for every account in both memory and database modes. Registration accepts the caller's `role` without an allowlist, including `ADMIN`. Database connection failure silently switches to seeded memory data.

**Reproduction:** The universal password authenticated the seeded administrator. Public registration with `role: ADMIN` returned HTTP 201 and an administrator token.

**Impact:** Full account and administrative compromise if this API is deployed.

**Fix:** Remove password bypasses, restrict registration roles, and fail startup when the production database is unavailable. Retire this API if it has been replaced.

---

## High-severity findings

### AM-06 — Flutter authentication fails open

**Location:** `lib/features/auth/bloc/auth_bloc.dart:652–679, 687–775, 787–812`; `lib/features/auth/screens/otp_screen.dart:32–35`  
**Verification:** Confirmed in source; device execution unavailable.

After server errors, ordinary login accepts any password of at least six characters. Admin login grants a local administrator profile when the email merely contains `admin` and the password is long enough. Cached-profile login does not check the supplied password. OTP request sends nothing, and OTP verification never reads `event.otp`.

**Impact:** Unauthorized access to local account/admin screens and fabricated verified sessions. These client fallbacks do not themselves create valid server credentials, but they make the app's security state unreliable and expose local administrative workflows.

**Fix:** Fail closed on authentication errors. Permit only explicitly read-only offline access. Implement real OTP delivery and server verification. Never infer a role from an email string.

### AM-07 — Applications, chat, and most admin actions never reach a backend

**Location:** `lib/core/repositories/application_repository.dart:70–148`; `lib/features/application/screens/adoption_application_screen.dart:341–389`; `lib/core/repositories/chat_repository.dart:135–209`; `lib/core/repositories/admin_repository.dart:368–588`  
**Verification:** Confirmed in source.

Adoption submissions are written only to local preferences and then shown as submitted. Chat messages receive timed, keyword-based replies attributed to the shelter. Shelter approval, user blocking, role changes, and listing moderation mutate local arrays rather than calling the available APIs.

**Impact:** Shelters do not receive applications or messages; administrators believe actions succeeded when no server state changed. Reinstalling or switching devices loses local workflows.

**Fix:** Persist through authenticated APIs, show success only after server acknowledgement, and synchronize state. Remove simulated shelter replies or label them unmistakably as demo behavior.

### AM-08 — Subscription integration uses the wrong host and reports false success

**Location:** `lib/core/repositories/subscription_repository.dart:16–24, 107–180, 238–267, 300–340`; `lib/features/admin/screens/subscription_management_screen.dart:52–70, 134`; `lib/features/subscription/screens/go_premium_screen.dart:177–196`; `lib/features/auth/bloc/auth_bloc.dart:939–960`  
**Verification:** Confirmed in source.

Subscription requests target localhost or the Android-emulator host instead of the configured deployed API. Admin calls omit the bearer token even though the server requires one. Network exceptions return `true` for approval/rejection, failed stats loads return fabricated revenue, and failed manual submissions return a fabricated pending record. The “I Have Completed Payment” button activates premium locally without checking the transaction.

**Impact:** Payments and admin decisions fail on real devices while the UI reports success; premium can be enabled without verification.

**Fix:** Use one configured API client with authentication. Propagate failures, remove fabricated records, and refresh entitlements from a verified server transaction before enabling premium.

### AM-09 — Flutter and backend API contracts disagree

**Location:** `lib/core/services/google_auth_service.dart:112–135`; `backend/routes/authRoutes.js:93, 226–230`; `lib/core/services/laravel_pet_service.dart:73–145`; `backend_laravel/app/Http/Controllers/Api/PetController.php:75–112`; `backend_laravel/app/Http/Controllers/Api/AdoptionRequestController.php:18–25, 86–106`  
**Verification:** Node response shape runtime reproduced; remaining mismatches confirmed in source.

- Flutter sends `id_token`; the Node endpoint reads `idToken`.
- Node returns `tokens.accessToken`; Flutter reads top-level `access_token` or `token`, then manufactures a fallback token.
- Nearby search sends `lat/lng/radius`; Laravel requires `latitude/longitude/radius_km`.
- Nearby search and application listing cast Laravel paginator objects to lists.
- The adoption adapter sends `answers_json`; Laravel requires `applicant_data` and specific nested fields.

The nearby and remote adoption adapter methods currently have no callers, so those defects are dormant rather than the cause of the active local-only submission flow.

**Fix:** Define one versioned response/request contract per backend, remove invented session tokens, unwrap paginated responses correctly, and add client/server contract tests.

### AM-10 — Remote pet cards cannot reliably open or be favorited

**Location:** `lib/core/repositories/pet_repository.dart:859–955`; `lib/features/adoption_match/screens/discover_screen.dart:704–710`; `lib/features/pet_profile/screens/pet_detail_screen.dart:35–59`  
**Verification:** Confirmed in source.

`fetchAvailablePets()` returns remote pets without updating the repository's seeded `_pets` list. Detail lookup and favorite toggling search only that local list. A numeric Laravel ID therefore commonly resolves to “Pet not found,” or to an unrelated seeded pet if IDs collide. Favorites also fail to update when the ID is absent. The remote-result branch ignores the requested maximum distance.

**Fix:** Fetch details by server ID, cache remote results consistently, implement server-backed favorites, and apply every filter to remote results.

### AM-11 — Moderators can perform actions outside their permissions

**Location:** `backend/routes/adminRoutes.js:23–24, 401–500, 1039–1089`  
**Verification:** Runtime reproduced.

The router admits `MODERATOR`, but payment approval/rejection and permission changes lack the intended fine-grained permission checks. A seeded moderator without payment or user-management permissions rejected a payment and changed another user's permissions, both with HTTP 200. The separate guard preventing moderator promotion to `ADMIN` correctly returned 403.

**Impact:** Unauthorized financial decisions and permission delegation.

**Fix:** Apply explicit permissions to every sensitive route. Restrict role and permission administration to appropriately privileged administrators, and test allowed and denied cases for each role.

### AM-12 — Bans and role changes update a different user store

**Location:** `backend/routes/adminRoutes.js:39–105, 313–451`; `backend/models/userStore.js:6–110`; `backend/routes/authRoutes.js:154–207`; `backend/middleware/rbacMiddleware.js:10–13`  
**Verification:** Runtime reproduced.

Administrative user operations mutate `adminRoutes.js`'s local array, while authentication reads `userStore.js`. After a successful ban, the authentication record remained `Active`. The old token was revoked, but a fresh login and authenticated `/auth/me` request succeeded. Role changes have the same split-state problem. Users, payments, revocations, and audit logs are also process-local and disappear on restart.

**Fix:** Use one persistent user store. Check current account status and authorization state when authenticating requests. Persist revocations and financial/audit records outside process memory.

### AM-13 — Paid transactions can be replayed and purchased terms can change

**Location:** `backend/models/paymentStore.js:67–94, 127–157`; `backend/routes/paymentRoutes.js:294–297, 354–386`; `backend/routes/adminRoutes.js:1051–1056`  
**Verification:** Runtime reproduced.

A successful payment can be changed to `CANCELLED` through the public cancel endpoint. A later IPN treats it as unpaid again and adds another subscription period. Payment records do not snapshot purchased duration; activation reads the current plan. Changing a plan from 30 to 999 days after checkout caused activation to grant 999 days.

**Fix:** Make successful payments immutable terminal records, grant entitlements once per transaction under a unique constraint, and snapshot price, currency, plan, and duration at checkout.

### AM-14 — The upload endpoint returns success without uploading

**Location:** `backend/server.js:77–132`; `backend/test_storage_upload.js:34–39`  
**Verification:** Runtime reproduced.

When Vercel Blob is unavailable, the endpoint constructs a Supabase public URL and returns `success: true` without writing the bytes to Supabase. The endpoint is also unauthenticated and does not validate image content or decoded size.

**Impact:** Broken profile/pet images, misleading success messages, and unrestricted upload attempts.

**Fix:** Perform and verify a real storage write before returning a URL. Authenticate callers, validate media type and size, and return an explicit error when storage is unavailable.

### AM-15 — React app points browsers at localhost and fabricates submission success

**Location:** `src-frontend/src/services/api.js:3–6`; `src-frontend/vite.config.js:5–13`; `src-frontend/src/pages/ApplicationPage.jsx:41–55`  
**Verification:** Build passed; behavior confirmed in source.

The absolute localhost API URL bypasses the Vite proxy and targets the visitor's machine in a deployed build. Any application-submission exception creates a fake submitted record and advances to the success screen.

**Fix:** Use a relative API path with environment-aware deployment routing. Preserve submission data on failure and show an error instead of a success timeline.

### AM-17 — Locked Node dependencies have known security advisories

**Location:** `backend/package-lock.json`, `server/package-lock.json`, `src-frontend/package-lock.json`  
**Verification:** `npm audit` against the installed lockfiles on the audit date.

| Project | Critical | High | Moderate | Total vulnerable-package entries |
|---|---:|---:|---:|---:|
| `backend/` | 0 | 4 | 2 | 6 |
| `server/` | 1 | 3 | 1 | 5 |
| `src-frontend/` | 0 | 4 | 4 | 8 |

Notable entries include `proxy-addr` in the legacy server, `axios`, `follow-redirects`, `body-parser`, Vite, `source-map-js`, and Zod through the Vercel dependency chain. These counts include development and transitive dependencies; they are not a count of distinct advisories or proof that every advisory is exploitable in this application.

**Fix:** Review reachability, update compatible patched versions and lockfiles, then rerun tests and audits. Do not blindly apply npm's suggested major-version changes without checking compatibility. Flutter and PHP dependencies were not audited because their package runtimes are unavailable.

---

## Medium-severity findings

### AM-16 — Matching scores depend partly on string length

**Location:** `ai-service/app/services/matching_engine.py:69–86`; `ai-service/app/models/schemas.py:6`  
**Verification:** Runtime reproduced.

The fallback energy score uses `abs(len(activity) - len(p_energy))`. Label length has no relationship to compatibility. With the engine defaults, sedentary/moderate and active/low combinations scored 91 and were classified as excellent matches. The schema also accepts 999 daily free-time hours.

**Fix:** Map energy and activity to ordered levels and score their distance. Bound numeric inputs and enforce hard constraints such as housing permission and required care capacity. Add mismatch regression tests.

### AM-18 — Tests and README overstate verification

**Location:** `backend/test_google_auth.js:76–136`; `backend/test_storage_upload.js:34–39`; `README.md:173–177`  
**Verification:** Test execution and source inspection.

The Google test prints responses without assertions, catches failures, and always exits with code 0. The storage test accepts a fabricated URL as proof of upload. Payment tests explicitly exercise the simulator bypass. The README claims zero Flutter analysis issues and 36 passing tests, but those results could not be verified here; the source contains 42 `test`, `blocTest`, and `testWidgets` declarations, which is not an executed-test count.

**Fix:** Add behavioral assertions, propagate failures through exit codes, test rejection paths, and publish only results produced by CI on the current commit.

### AM-19 — Sensitive application data and tokens are duplicated into ordinary local storage

**Location:** `lib/core/services/local_storage_service.dart:8–16, 63–67`; `lib/core/models/application_model.dart:217–244`; `lib/core/storage/secure_storage_service.dart:28–40, 63–79`; `lib/core/services/google_auth_service.dart:130–134`  
**Verification:** Confirmed in source.

Applications containing NID numbers, addresses, phone numbers, and signature data are serialized into SharedPreferences. Auth tokens and profile data are written to secure storage and also duplicated into SharedPreferences.

**Impact:** Sensitive data has a wider local exposure surface than the secure-storage abstraction suggests.

**Fix:** Minimize retained identity data, use protected storage for sensitive offline records, avoid token duplication, and define deletion/retention behavior.

### AM-20 — Release configuration can silently use debug signing

**Location:** `android/app/build.gradle:35–49`  
**Verification:** Confirmed in source; Android build not run.

When `key.properties` is absent, the release build selects the debug signing configuration. This can produce an incorrectly signed release artifact without a clear failure.

**Fix:** Require release signing configuration for release builds and fail the build when it is missing. Keep debug signing limited to debug builds.

---

## Recommended repair order

1. **Contain credentials and access:** rotate any real exposed storage credential; remove public token issuance, identity fallbacks, universal passwords, and caller-selected admin registration.
2. **Stop unverified entitlement changes:** validate gateway notifications, bind payments to authenticated users, and make activation idempotent and persistent.
3. **Choose the production backend:** the repository contains three incompatible API stacks. Retire or clearly isolate unused implementations and standardize configuration.
4. **Replace local-only workflows:** connect applications, chat, moderation, and subscriptions to persistent authenticated APIs.
5. **Fix client contracts and error handling:** remove fabricated success and test real-device/web API routing.
6. **Update dependencies and CI:** patch advisories, add negative security tests, and run Flutter analysis/tests plus Laravel tests on a properly provisioned runner.

## Audit limits

This was a repository audit with targeted local reproductions, not a penetration test or a guarantee that every defect has been found. Flutter UI behavior, Android/iOS builds, Laravel database behavior, real OAuth, cloud storage, and live payment processing still need verification in their respective runtimes.

No application source was changed for this report. Temporary dependency/build artifacts created during checks were removed, and tracked dependency files restored to their original state.
