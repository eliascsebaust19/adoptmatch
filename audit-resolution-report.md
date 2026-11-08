# AdoptMatch — Audit Resolution: Verified vs Pending

**Date:** 8 November 2026  
**Baseline findings:** `BUG_REPORT.md`, AM-01 through AM-20  
**Working branch:** `arena/5093f7e0-adoptmatch`

This replaces the earlier “20 of 20 resolved” claim. The code changes below are present in this checkout, but **production readiness is not established**. Flutter/Dart and PHP/Composer were unavailable in this workspace, so Flutter analyze/test, Laravel PHPUnit, device builds, live OAuth/SMS/gateway/storage checks, and hosted CI results remain pending.

## Finding-by-finding status

| ID | Code change in this checkout | Evidence available here | Still pending |
|---|---|---|---|
| AM-01 | Public test-token endpoint disabled in production; all test tokens require `TEST_AUTH_SECRET`; production JWT secret required. | Node suite: production token endpoint 403, missing/weak secret fail-closed, authenticated admin paths. | Hosted CI run. |
| AM-02 | Node and Laravel require verified Google ID tokens; audience/issuer/expiry/subject checks; no profile-only or unsigned fallback; privileged email auto-linking blocked. | Node Google tests pass. Laravel feature tests added. | Laravel PHPUnit; real Google account/device flow. |
| AM-03 | Gateway validation required; transaction/store/amount/currency/status matched; checkout bound to authenticated user; production simulation disabled. | Node HTTP tests include forged IPN, simulated live validation, cross-transaction/store/amount/currency mocks. | Live SSLCommerz sandbox/production verification. |
| AM-04 | Embedded Flutter/server/example storage token removed; uploads go through authenticated server endpoints. | Source search and upload tests. | Revoke/rotate any real exposed credential; review history and storage access logs. |
| AM-05 | Legacy universal password removed; public registration limited to non-privileged roles; production MySQL failure fails startup. | `server npm test`: 4 auth checks + production DB fail-closed check pass. | Real MySQL deployment check. |
| AM-06 | Flutter login/signup/admin/shelter locks fail closed; OTP uses Laravel→Supabase; no local role elevation or cached-session admin fallback; Google fallback requires server session. | Dart syntax parse only; unit tests rewritten. | `flutter analyze`, `flutter test`, OTP/device verification. |
| AM-07 | Applications, chat, admin moderation and shelter desk use authenticated APIs; fake shelter replies, fake calls/SOS/PDF success removed; failures surface. | Dart syntax parse; Node admin API tests. | Flutter widget/integration tests; Laravel message/application PHPUnit. |
| AM-08 | Subscription client uses configured API root and bearer token; no fabricated stats/records; premium refreshes from verified server subscription; manual TrxID unique. | Node subscription/persistence tests pass. | Flutter tests; live bKash/manual approval flow. |
| AM-09 | Google token/response shapes, Laravel nearby parameters/pagination, adoption `applicant_data`/signature contract aligned. | Node response tests; Laravel contract tests added. | Laravel PHPUnit; Flutter service tests. |
| AM-10 | Remote pets cached by server ID; detail/favorites/swipes use Laravel endpoints; distance filter applied to remote results. | Dart syntax parse; Laravel favorite/swipe tests added. | Flutter tests/device search. |
| AM-11 | Granular permission guards on payment approval/rejection, role/permission changes and moderation routes. | Node admin privilege tests pass. | Hosted CI. |
| AM-12 | Users, payments, plans, revocations, audit and admin records use SQLite stores; auth checks current status/role. | Node persistence tests: restart durability, ban/revocation behavior. | Multi-process/server-DB migration before scaling. |
| AM-13 | Successful payments terminal; entitlements granted once; purchased terms snapshotted; manual bKash TrxID DB-unique across statuses. | Node tests: replay/cancel rejection, snapshot duration, duplicate/reused TrxID 409. | Live gateway/manual reconciliation. |
| AM-14 | Authenticated uploads; decoded size and image-signature validation; no fabricated Supabase URL; storage failure returns error. | Node upload tests verify stored bytes/rejection paths. Laravel upload test added. | Laravel PHPUnit; live storage provider check. |
| AM-15 | React API base relative/env-aware; submission failure preserves form and shows error; success requires server reference; demo credentials removed. | `npm run build` exit 0 (bundle-size warning). | Browser E2E against a running API. |
| AM-16 | Ordered energy/activity scoring, bounded inputs, hard housing/care constraints. | AI direct runner 9/9; pytest-compatible tests. | Hosted CI pytest run. |
| AM-17 | npm overrides/lockfiles updated. | `npm audit`: backend/server/src-frontend 0 reported vulnerabilities at audit time. | Flutter/PHP dependency audit; re-audit on CI. |
| AM-18 | Behavioral assertions and non-zero failure exits added; README claims corrected; CI definition written to `docs/ci/ci.yml`. | Local Node/AI/React commands above. | Install the workflow at `.github/workflows/ci.yml` (push token lacks `workflows` permission), then a hosted run for the exact commit including Flutter/Laravel jobs. |
| AM-19 | Tokens/profiles/sensitive drafts secure-only; plaintext legacy copies purged; logout resets private indexes/chat/application caches. | Dart syntax parse; storage/persistence unit tests rewritten. | Device secure-storage behavior and migration testing. |
| AM-20 | Android release build throws when `key.properties` is missing; debug signing not used for release. | Source inspection. | Android release build on a provisioned SDK/signing config. |

## Commands actually run here

| Command | Result |
|---|---|
| `cd backend && npm test` | Exit 0. 30 security regression checks; Google, storage, admin and subscription suites; 6 persistence/concurrency checks. |
| `cd server && npm test` | Exit 0. 4 legacy auth checks and production database fail-closed check. |
| AI direct runner (`ai-service/tests/test_matching_engine.py`) | 9/9 passed. |
| `cd src-frontend && npm run build` | Exit 0; main chunk >500 kB warning. |
| `npm audit` in backend/server/src-frontend | 0 reported vulnerabilities. |
| Dart/PHP syntax parser | 73 changed files, 0 syntax errors. This is **not** type checking or runtime testing. |
| `flutter analyze`, `flutter test`, Android/iOS build | Not run: SDK unavailable. |
| `vendor/bin/phpunit` | Not run: PHP/Composer unavailable. |
| Live Google/Supabase SMS/SSLCommerz/bKash/cloud storage | Not run: credentials/devices unavailable. |

## Release gate

Do not release until: exposed credentials are rotated/history-reviewed; the CI workflow is installed from `docs/ci/ci.yml` and passes on the release commit; Flutter analyze/tests and Laravel PHPUnit pass; OTP/OAuth/payment/storage flows are verified in staging; SQLite single-process limits are replaced or accepted for the deployment size; and unsupported features remain visibly disabled rather than simulated.
