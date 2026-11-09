# AdoptMatch Backend — Enterprise Role-Based Access Control (RBAC)

This Node.js / Express backend implements strict **Role-Based Access Control (RBAC)** to enforce complete separation between the **User App (Adopter/Shelter)** and the **Admin Portal**.

---

## 1. Security Architecture

### Role Hierarchy
* `USER` / `ADOPTER`: Consumer access (swipe match, quizzes, health passports). Blocked from `/api/v1/admin/*`.
* `MODERATOR`: Content and listings review. Denied access to user permissions, role elevation, and payment settlement.
* `SHELTER`: Verified shelter partner. Allowed to publish rescues and review adoption dossiers.
* `ADMIN`: Platform operations administrator. Allowed to review shelter documents, moderate listings, and resolve disputes.
* `SUPER_ADMIN`: Root administrator with full privilege, user management, and audit log oversight.

### Authentication & Authorization Invariants
* **Fail-Closed RBAC**: Endpoints require cryptographically signed Bearer JWT tokens (`Authorization: Bearer <token>`). Privileged roles cannot be self-assigned.
* **Google Identity**: `POST /api/v1/auth/google` strictly verifies the Google ID token against Google's tokeninfo/OAuth endpoints (checking signature, audience, issuer, and email verification). Attacker-supplied profiles without verified tokens are rejected.
* **Payment Integrity**: SSLCommerz IPN/success callbacks strictly validate transaction ID, store ID, currency, and amount before settling payments. Manual bKash submissions enforce unique TrxIDs across all accounts.
* **Upload Security**: Upload endpoints require authentication, validate MIME headers and magic bytes, enforce size limits, and fail closed if cloud storage is unconfigured.

---

## 2. API Endpoints

### Administrative Routes (`/api/v1/admin/*`)
| Method | Endpoint | Description | Required Role |
|---|---|---|---|
| `GET` | `/api/v1/admin/stats` | KPI overview (total adoptions, pending shelters, rescues) | `ADMIN`, `SUPER_ADMIN` |
| `GET` | `/api/v1/admin/shelters` | Shelter & lister verification queue | `ADMIN`, `SUPER_ADMIN` |
| `POST` | `/api/v1/admin/shelters/:id/approve` | One-click shelter approval | `ADMIN`, `SUPER_ADMIN` |
| `POST` | `/api/v1/admin/shelters/:id/reject` | Reject shelter with reason | `ADMIN`, `SUPER_ADMIN` |
| `GET` | `/api/v1/admin/pets` | Flagged/reported pet listing queue | `ADMIN`, `SUPER_ADMIN`, `MODERATOR` |
| `POST` | `/api/v1/admin/pets/:id/ban` | Ban pet listing from public feed | `ADMIN`, `SUPER_ADMIN`, `MODERATOR` |
| `PUT` | `/api/v1/admin/pets/:id/badge` | Toggle "Urgent Rescue" / "Featured" badges | `ADMIN`, `SUPER_ADMIN` |
| `GET` | `/api/v1/admin/adoptions` | Adoption digital e-contracts & foster disputes | `ADMIN`, `SUPER_ADMIN` |
| `GET` | `/api/v1/admin/users` | User directory | `ADMIN`, `SUPER_ADMIN` |
| `PUT` | `/api/v1/admin/users/:id/role` | Delegate user roles | `ADMIN`, `SUPER_ADMIN` |
| `PATCH` | `/api/v1/admin/users/:id/block` | Suspend or ban user accounts (revokes active JWTs) | `ADMIN`, `SUPER_ADMIN` |
| `GET` | `/api/v1/admin/audit-logs` | Immutable platform audit trail | `ADMIN`, `SUPER_ADMIN` |

---

## 3. Data Layer Architecture & Scaling Constraints

### Single-Process SQLite Constraint
* The Node API uses Node 22's embedded `node:sqlite` database stored in `backend/database.sqlite`.
* SQLite relies on filesystem locks (`WAL` mode). **Only ONE Node process may access the SQLite database file at a time**.
* **Do NOT scale horizontally** (e.g. multiple replicas or container instances) while using local SQLite. Concurrent multi-process writes across separate processes or network-attached filesystems (NFS, EFS) can result in database locking errors (`SQLITE_BUSY`) or database corruption.
* **Path to Horizontal Scaling**: Before deploying multiple backend containers behind a load balancer, migrate the data store to an external client-server RDBMS (PostgreSQL or MySQL).

---

## 4. How to Run & Test

### Installation
```bash
cd backend
npm install
```

### Running Tests
Execute the complete security regression and persistence suite:
```bash
npm test
```
All suites run with zero simulated bypasses and verify:
1. `test_security_regressions.js` — AM-01 to AM-14 security contracts.
2. `test_google_auth.js` — Google OAuth ID token verification.
3. `test_storage_upload.js` — Content type and size validation.
4. `test_admin_features.js` — Administrative role delegation and token revocation.
5. `test_subscription_payments.js` — SSLCommerz gateway verification & manual bKash workflows.
6. `test_persistence.js` — Ledger, atomic transitions, and single-process durable storage.
