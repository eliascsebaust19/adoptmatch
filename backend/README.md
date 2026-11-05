# AdoptMatch Backend — Enterprise Role-Based Access Control (RBAC)

This Node.js / Express backend implements strict **Role-Based Access Control (RBAC)** to enforce complete separation between the **User App (Adopter/Shelter)** and the **Admin Portal**.

---

## 1. Security Architecture

### Role Hierarchy
* `USER` / `ADOPTER`: Consumer access (swipe match, quizzes, health passports). Blocked from `/api/v1/admin/*`.
* `SHELTER`: Verified shelter partner. Allowed to publish rescues and review applications.
* `ADMIN`: Platform operations moderator. Allowed to review shelter documents, moderate listings, and resolve disputes.
* `SUPER_ADMIN`: Root administrator with full privilege, user management, and audit log oversight.

### Middleware Implementation (`backend/middleware/rbacMiddleware.js`)
* `authenticateToken`: Validates Bearer JWT tokens in request headers (`Authorization: Bearer <token>`).
* `requireRole(['ADMIN', 'SUPER_ADMIN'])`: Strictly checks decoded `req.user.role`. Returns `403 Forbidden` if role is missing or unauthorized.

---

## 2. API Endpoints

### Administrative Routes (`/api/v1/admin/*`)
| Method | Endpoint | Description | Required Role |
|---|---|---|---|
| `GET` | `/api/v1/admin/stats` | KPI overview (total adoptions, pending shelters, rescues) | `ADMIN`, `SUPER_ADMIN` |
| `GET` | `/api/v1/admin/shelters` | Shelter & lister verification queue | `ADMIN`, `SUPER_ADMIN` |
| `POST` | `/api/v1/admin/shelters/:id/approve` | One-click shelter approval | `ADMIN`, `SUPER_ADMIN` |
| `POST` | `/api/v1/admin/shelters/:id/reject` | Reject shelter with reason | `ADMIN`, `SUPER_ADMIN` |
| `GET` | `/api/v1/admin/pets` | Flagged/reported pet listing queue | `ADMIN`, `SUPER_ADMIN` |
| `POST` | `/api/v1/admin/pets/:id/ban` | Ban pet listing from public feed | `ADMIN`, `SUPER_ADMIN` |
| `PUT` | `/api/v1/admin/pets/:id/badge` | Toggle "Urgent Rescue" / "Featured" badges | `ADMIN`, `SUPER_ADMIN` |
| `GET` | `/api/v1/admin/adoptions` | Adoption digital e-contracts & foster disputes | `ADMIN`, `SUPER_ADMIN` |
| `GET` | `/api/v1/admin/users` | User directory | `ADMIN`, `SUPER_ADMIN` |
| `PUT` | `/api/v1/admin/users/:id/status` | Suspend or ban user accounts | `ADMIN`, `SUPER_ADMIN` |
| `GET` | `/api/v1/admin/audit-logs` | Immutable platform audit trail | `ADMIN`, `SUPER_ADMIN` |

---

## 3. How to Run & Test

### Installation
```bash
cd backend
npm install
npm start
```

### Testing RBAC Enforcement
1. Generate an Admin token:
```bash
curl -X POST http://localhost:5000/api/v1/auth/token \
  -H "Content-Type: application/json" \
  -d '{"email": "superadmin@adoptmatch.org", "role": "SUPER_ADMIN"}'
```

2. Request protected route with Admin token (**Returns 200 OK**):
```bash
curl -H "Authorization: Bearer <ADMIN_TOKEN>" http://localhost:5000/api/v1/admin/stats
```

3. Generate a regular User token:
```bash
curl -X POST http://localhost:5000/api/v1/auth/token \
  -H "Content-Type: application/json" \
  -d '{"email": "user@gmail.com", "role": "USER"}'
```

4. Request protected route with User token (**Returns 403 Forbidden**):
```bash
curl -H "Authorization: Bearer <USER_TOKEN>" http://localhost:5000/api/v1/admin/stats
```
Response:
```json
{
  "success": false,
  "error": "Forbidden",
  "code": "INSUFFICIENT_PERMISSIONS",
  "message": "Access Denied: You do not have the required administrative privileges to perform this operation.",
  "requiredRoles": ["ADMIN", "SUPER_ADMIN"],
  "currentRole": "USER"
}
```

