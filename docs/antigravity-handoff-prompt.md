# Antigravity Handoff Prompt — AdoptMatch

 নিচের block টা হুবহু copy করে Antigravity-তে paste করো। এটাই prompt; ভেতরের নির্দেশগুলো agent-এর জন্য।

---

```text
ROLE
You are a senior security-focused engineer working inside the existing AdoptMatch repository
(eliascsebaust19). Do not rewrite the project from scratch. Read the real code, verify claims by
running things, finish the pending work, and report honestly. Bangla/Banglish replies are fine.

REPO STATE (verify yourself before trusting this)
- Work branch: arena/5093f7e0-adoptmatch (already pushed to origin). Latest commit: 6210ba7.
- Baseline audit: BUG_REPORT.md contains 20 findings AM-01..AM-20 (5 critical, 11 high, 4 medium).
- Current status map: audit-resolution-report.md (verified vs pending, per finding).
- Stacks: lib/ + test/ (Flutter), backend/ (Node 22 admin/payment API, SQLite),
  backend_laravel/ (Laravel consumer API), server/ + src-frontend/ (legacy Node/MySQL + React),
  ai-service/ (FastAPI matching). These stacks are NOT interchangeable.
- One API root in Flutter: ApiClient.rootUrl via --dart-define=API_BASE_URL (legacy alias
  BACKEND_URL), default https://adoptmatch-api.onrender.com; consumer paths append /api/v1 and
  Node admin/payment use the same root. Never point device/browser builds at localhost.

WHAT WAS ALREADY VERIFIED LOCALLY (re-run and confirm; do not just trust it)
- backend: `npm test` exit 0 -> 30 security regression checks + Google/storage/admin/subscription
  suites + 6 persistence/concurrency checks.
- server: `npm test` exit 0 -> 4 legacy auth checks + production MySQL fail-closed check.
- ai-service: direct runner `python ai-service/tests/test_matching_engine.py` -> 9/9.
- src-frontend: `npm run build` exit 0 (Vite warns main chunk > 500 kB).
- npm audit in backend/, server/, src-frontend/ -> 0 reported vulnerabilities at that time.
- A Dart/PHP *syntax parser* passed on 73 changed files. This is NOT flutter analyze, NOT type
  checking, NOT PHPUnit, NOT runtime verification. Treat Flutter/Laravel as UNVERIFIED.

WHAT IS STILL PENDING (this is your job)
1. CI is NOT installed. The workflow lives at docs/ci/ci.yml (with docs/ci/README.md) because the
   previous push credential lacked GitHub `workflows` permission. Install it at
   .github/workflows/ci.yml, push, and make the run green (or report exactly what fails).
2. Flutter: `flutter pub get`, `flutter analyze`, `flutter test` were never executed (no SDK).
   Fix every compile/type/test error you find. Then verify on a device/emulator/web:
   email signup+login, admin/shelter lock screens, phone OTP, Google sign-in, pet
   search/detail/favorites/swipes, adoption application submit+track, chat send/retry/attachment,
   subscription checkout + manual bKash, admin moderation + shelter desk, logout cache clearing.
3. Laravel: `composer install` + `vendor/bin/phpunit` were never executed (no PHP). Make
   tests/Feature/SecurityContractsTest.php pass (guest 401s, favorites vs swipes, message
   sender/attachment rules, adoption signature/reference/duplicate/owner-status rules, upload fake
   422 + real PNG, phone OTP 503/mismatch/success, my-pets ownership, registration role guard,
   Google unverified-token rejection). Run migrations on a real DB.
4. Live integrations, all untested: Google OAuth, Supabase phone OTP/SMS, SSLCommerz, manual bKash,
   Cloudinary/Vercel Blob storage, FCM push. Verify in staging with real sandbox credentials.
5. Credential hygiene: an exposed Vercel Blob read/write token existed historically. Confirm it is
   gone from source/examples/build artifacts, rotate/revoke it if it was real, and review repo
   history + storage access logs. Report what you could and could not confirm.
6. Data layer scale: Node uses one SQLite file and supports ONE process per file. Either document
   and enforce that limit or migrate to a server database before any horizontal scaling.
7. Release signing: android/app/build.gradle now throws without key.properties. Prove a release
   build fails without it and succeeds with a valid config.
8. React bundle > 500 kB: code-split if cheap; otherwise record it as accepted.

NON-NEGOTIABLE SECURITY INVARIANTS (do not regress these to make a test pass)
- Fail closed everywhere: no fabricated tokens, profiles, sessions, uploads, payment records,
  subscription success, message replies, call/SOS/push/PDF success, or KPI numbers.
- No hardcoded/demo admin or shelter passwords; no caller-selected privileged roles; no local role
  elevation; no cached-profile offline admin session.
- Google: verified ID token only (signature, audience, issuer, expiry, subject, verified email);
  never link a privileged account by unverified email.
- Payments: activate only after gateway validation matching tran_id + store + amount + currency +
  status, bound to the authenticated payer; simulation forbidden in production; successful payments
  are terminal; entitlement granted once; purchased terms snapshotted; manual bKash TrxID unique
  across ALL statuses (a rejected TrxID stays consumed).
- Auth/authz: one persistent user store; check current status/role on every authenticated request;
  persist revocations; granular permissions on every sensitive admin route.
- Uploads: authenticated, real image bytes, declared-vs-actual type check, decoded size limit,
  error (not fake URL) when storage is unavailable.
- Storage on device: tokens/profiles/sensitive drafts only in secure storage; writes fail closed;
  purge legacy plaintext copies; logout clears private indexes and chat/application caches.
- Phone OTP goes through the Laravel server to Supabase; unconfigured provider => 503, never fake
  success. Roles come from server/app metadata, never user-editable metadata or email strings.
- Unsupported features must say "not configured" instead of simulating: voice relay, SOS device
  broadcast, PDF export, push without FCM creds, unmeasured revenue/dispute/adoption KPIs.
- Do not weaken validation, delete assertions, skip tests, or add `|| true` to make CI green.

KNOWN GOTCHAS (save yourself time)
- Node's built-in SQLite is experimental; `records` table column is `namespace` (NOT collection).
- backend/package.json `test` chains: test_security_regressions, test_google_auth,
  test_storage_upload, test_admin_features, test_subscription_payments, test_persistence.
- backend/node_modules was historically committed and is now UNTRACKED (npm ci to restore);
  node_modules/ and dist/ are gitignored. Do not re-commit dependencies or build output.
- Laravel responses are {status, data}; paginators are data.data. Node admin is {success, data}.
- Adoption contract: applicant_data + signature_data (non-empty signature) + emergency contacts;
  status values submitted/under_review/home_visit/foster_trial/approved/rejected.
- Flutter favorites are separate from swipes; default favorite = false. Pet mapping must stay
  conservative: unknown/empty defaults, explicit vaccination status only, no invented weight,
  address, shelter or image.
- Flutter tests use test/helpers/secure_storage_mock.dart and fake_dio_adapter.dart; pubspec has
  dev dependency flutter_secure_storage_platform_interface.
- First Node superadmin is created only via `npm run bootstrap:admin -- --google-sub ...` with a
  durable DATABASE_PATH; it is one-time and fails if a superadmin already exists.

WORKFLOW
1. Read BUG_REPORT.md, audit-resolution-report.md, README.md, docs/ci/ci.yml, then the actual code.
2. Reproduce the current state: run backend/server/AI/React commands above; install Flutter + PHP
   toolchains and run analyze/test/PHPUnit. Record exact commands, exit codes and failures.
3. Triage failures into: real bug / test bug / missing config. Fix root causes, smallest safe diff.
4. Add or extend regression tests for every bug you fix (negative paths included).
5. Install and green the CI workflow; keep Flutter and Laravel jobs mandatory.
6. Do staging verification of live integrations; list anything you cannot verify and why.
7. Update README.md and audit-resolution-report.md so every claim matches executed evidence.

DELIVERABLES
- Small focused commits on arena/5093f7e0-adoptmatch (or a PR from it). Never force-push main.
- A final report table: AM-ID | what changed | command + result that proves it | still pending.
- Explicit list of remaining risks/limits and the exact release gate before production.

REPORTING RULES
- Never say "all 20 resolved" or "production ready" unless every check actually ran and passed.
- Distinguish: verified by execution / verified by code reading only / not verified.
- If a tool or credential is unavailable, say so plainly instead of assuming success.
- Ask before destructive actions (history rewrite, force-push, dropping data, rotating live keys).

START HERE
Run: git log --oneline -3 && git status -sb
Then: cd backend && npm ci && npm test
Then: cd ../server && npm ci && npm test
Then: cd ../ai-service && pip install -r requirements.txt pytest && pytest -q
Then: cd ../src-frontend && npm ci && npm run build
Then: flutter pub get && flutter analyze && flutter test
Then: cd backend_laravel && composer install && cp .env.example .env && vendor/bin/phpunit
Report the real output of each step before changing any code.
```

---

### ছোট 버전 (দ্রুত কাজের জন্য)

```text
AdoptMatch repo, branch arena/5093f7e0-adoptmatch (commit 6210ba7). BUG_REPORT.md-এ AM-01..AM-20
findings, audit-resolution-report.md-এ verified-vs-pending map. আগের agent Node backend (30 security
+ 6 persistence checks), legacy server test, AI 9/9, React build, npm audit 0 — এগুলো local-এ pass
করেছে; কিন্তু Flutter analyze/test, Laravel PHPUnit, hosted CI, live OAuth/SMS/gateway/storage
কখনো চালানো হয়নি। শুধু Dart/PHP syntax parse হয়েছিল, সেটা type/runtime check নয়।

কাজ: (1) docs/ci/ci.yml কে .github/workflows/ci.yml-এ বসিয়ে CI green করো, (2) Flutter SDK দিয়ে
analyze/test চালিয়ে সব error ঠিক করো + device-এ মূল ফ্লো যাচাই করো, (3) PHP/Composer দিয়ে Laravel
PHPUnit + migration চালাও, (4) staging-এ Google/Supabase OTP/SSLCommerz/bKash/storage/FCM যাচাই করো,
(5) পুরনো exposed blob token rotate + history review, (6) SQLite single-process সীমা ডকুমেন্ট/মাইগ্রেশন,
(7) README + audit report শুধু প্রমাণিত ফল দিয়ে আপডেট করো।

নিয়ম: fail-closed ভাঙবে না (fake token/payment/upload/success/KPI নিষেধ), hardcoded password বা
local role elevation ফেরত আনবে না, test মুছে বা validation দুর্বল করে CI green করবে না,
node_modules/dist commit করবে না। প্রমাণ ছাড়া "20/20 resolved" বা "production ready" বলবে না।
প্রথমে উপরের কমান্ডগুলো চালিয়ে আসল output দেখাও, তারপর কোড বদলাও।
```
