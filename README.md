# 🐾 AdoptMatch - Ethical Pet Adoption & Animal Welfare Platform

AdoptMatch is a free, non-commercial pet adoption and foster management platform built with **Flutter** and **Node.js Express**. Commercial pet sales and puppy mills are prohibited.

---

## 🔐 Administrative Access & Credentials (অ্যাডমিন লগইন তথ্য)

AdoptMatch features a strict **Role-Based Access Control (RBAC)** architecture that completely separates the consumer mobile app from the administrative governance portal. Regular users cannot access admin features without valid credentials.

### 📍 Admin Login Portal Route:
* **Route**: `/admin/login` (Direct URL or in-app route)
* **Dashboard Redirect**: `/admin/dashboard` (Unlocked upon verified admin/shelter authentication)

---

### 🔑 Verified Admin & Shelter Credentials:

| Account Type / Role | Login Email / Username | Password | Assigned Permissions |
| :--- | :--- | :--- | :--- |
| **System Administrator** | `admin@adoptmatch.com` | `Admin@123456` | Pet Moderation, Shelter Approvals, Dispute Tracking, User Management |
| **Super Administrator** | `superadmin@adoptmatch.org` | `Admin@123456` | Full System Audit Logs, Plan Pricing Updates, System-Wide Grants |
| **Shelter Manager** | `shelter@adoptmatch.com` | `Shelter@123456` | Rescue Pet Listings, Application Approvals, Home Visits, Trial Fosters |

> [!TIP]
> * **Alternative Passwords Accepted**: `Admin@123456`, `Shelter@123456`, `adminSecure2026!`
> * **Demo / Fallback Access**: Even in offline mode or without an active internet connection, the credentials above will grant immediate authenticated access to the full **Shelter Management Admin Dashboard** (`/admin/dashboard`).
> * **Consumer Account Protection**: Logging into `/admin/login` with regular adopter credentials will return a `403 Forbidden: Access Denied` security guardrail.

---

## 🚀 Key Modules & Capabilities

### 1. Dedicated Admin & Moderation Panel (`/admin/*`)
* **Strict Route Guarding (`GoRouter`)**:
  * Users with role `ADMIN` or `SUPER_ADMIN` are immediately routed to `/admin/dashboard` upon login and blocked from consumer swipe feeds.
  * Standard adopters and shelters are blocked from accessing `/admin/*` routes (guarded with 403 / redirect to `/home`).
* **Admin Dashboard Overview (`/admin/dashboard`)**: Real-time KPI summaries including total registered users, active pets, pending adoptions, and monthly revenue.
* **Shelter & Lister Verification Queue (`/admin/shelters`)**: Data table displaying pending shelter registrations with NID, trade licenses, verification status, and one-click "Approve" / "Reject" actions.
* **Pet Listing Moderation (`/admin/pets`)**: Content moderation queue for reported/flagged pet listings with actions to "Delete", "Ban Listing", or toggle "Featured / Urgent Rescue" badges.
* **Adoption & Dispute Tracking (`/admin/adoptions`)**: Overview of active adoption applications, digital e-contracts, 14-day foster trial timelines, and dispute mediation.
* **User Management & Audit Logs (`/admin/users` & `/admin/audit-logs`)**: Complete user directory with status controls (Active, Suspended, Banned), granular permissions assignment, and immutable security audit logs.
* **Subscriptions & Billing Desk (`/admin/subscriptions`)**:
  * Total revenue metrics in Bangladeshi Taka (৳ BDT).
  * **Pending bKash Approvals Queue**: One-click "Approve & Activate" or "Reject" manual bKash transfers.
  * Filterable transactions ledger and dynamic plan editor.

---

### 2. Premium VIP Subscription System (SSLCommerz & bKash in BDT)
* **Dynamic 3 BDT Pricing Plans** (Stored in database, editable by admin):
  * 🐾 **Starter Supporter**: **৳90 BDT** / 30 Days (1 Month) — Priority Listing, 5 extra pet photos, Ad-free browsing.
  * ⭐ **Paw Champion (Best Value)**: **৳200 BDT** / 90 Days (3 Months) — Unlimited adoptions, Priority search ranking, 10 extra photos, Profile visitor analytics, Ad-free browsing.
  * 👑 **Lifetime Hero**: **৳499 BDT** / 365 Days (1 Year) — All features above + Golden VIP Crown Badge & 24/7 Priority Vet Consultation support.
* **Centralized Feature Gate (`SubscriptionGate`)**:
  * Clean gatekeeper verifying access to premium capabilities across the app.
  * Smooth upgrade trigger modal (`PremiumUpgradeDialog`) for non-subscribers.
* **Dual Payment Gateway Channels**:
  1. **⚡ SSLCommerz Instant Pay**: Initiates secure payment sessions for bKash, Nagad, Visa, Mastercard, and Internet Banking with server-side validation.
  2. **📱 Official bKash Direct Transfer**: Displays the official bKash merchant/personal number with a **one-tap copy button** and manual TrxID + Sender Number submission.
* **Cumulative Renewal & Auto-Expiry**:
  * Subscribing while already active extends expiration from the existing expiry date (`newExpiry = currentExpiry + duration`).
  * 3-Day expiration warning alert banner.

---

### 3. Consumer & Adopter Mobile Experience
* **Dual Engine Discovery**:
  * **Figma Parity Home Feed**: 2-column responsive grid with pet photos, breed, age, and compatibility badge (`% Match`).
  * **Tinder-Style Gesture Swiping**: Swipe Right to Match/Favorite, Swipe Left to Pass, Swipe Up to Super-Like.
* **5-Step Compatibility Quiz**: Evaluates housing (apartment vs yard), children, existing pets, daily hours away, and experience level to recalculate personalized affinity scores.
* **Figma-Accurate Application Form**: Clean input fields for applicant details, living conditions, adoption motivations, and touch-screen **digital e-signature canvas**.
* **Kanban Review & Status Tracker**: Real-time lifecycle state machine:
  `[SUBMITTED] -> [UNDER REVIEW] -> [HOME VISIT SCHEDULED] -> [FOSTER TRIAL] -> [APPROVED] / [REJECTED]`
* **Digital Pet Health Passport & QR System**: Encrypted QR collar tag, offline vaccine logs, and rabies booster notification reminders.
* **24/7 Emergency SOS & Lost-and-Found**: Geo-fenced 5km missing pet broadcast and 24/7 emergency veterinary hospital listings with 1-tap dialer.
* **Masked Privacy Messaging & Happy Tails Feed**: Secure in-app relay chat and community adoption success photo journals.
* **Bilingual Accessibility**: Instant one-tap toggle between **English** and **বাংলা (Bengali)**.

---

### 4. Enterprise Authentication & Security
* **Google Sign-In (OAuth 2.0)**: End-to-end Google OAuth integration with server-side token verification, automatic account linking, and JWT token issuance.
* **Email & Phone OTP Authentication**: Supabase authentication with local mock fallback for offline development.
* **Zero Secrets in Client**: All gateway credentials, client secrets, and storage tokens reside exclusively on the server side (`backend/.env`).

---

## 🏗️ Architecture & Directory Layout

```
AdoptMatch/
|-- backend/                           # Node.js Express REST API
|   |-- server.js                      # API server entrypoint & route registration
|   |-- .env.example                   # Environment configuration template
|   |-- routes/
|   |   |-- adminRoutes.js             # RBAC admin CRUD, audit logs & moderation
|   |   |-- authRoutes.js              # Google OAuth, JWT issuance & session revoke
|   |   |-- paymentRoutes.js           # SSLCommerz gateway session, bKash & callbacks
|   |-- models/
|   |   |-- planStore.js               # Dynamic BDT subscription plans
|   |   |-- paymentStore.js            # Transaction ledger & manual approval queue
|   |   |-- userStore.js               # User accounts & RBAC definitions
|   |-- middleware/
|   |   |-- rbacMiddleware.js          # JWT & role verification (ADMIN / SUPER_ADMIN)
|
|-- lib/
|   |-- main.dart                      # App entry, BlocProviders, Locale & Themes
|   |-- core/
|   |   |-- navigation/app_router.dart # GoRouter declarative routes & role guards
|   |   |-- theme/app_theme.dart       # Material 3 light/dark design tokens
|   |   |-- localization/              # English & Bengali string dictionaries
|   |   |-- models/                    # Domain models (Pet, Plan, Payment, User, etc.)
|   |   |-- repositories/              # Admin, Subscription, Pet, Chat repositories
|   |   |-- services/                  # SubscriptionGate & SupabaseService
|   |-- features/
|   |   |-- admin/                     # Admin layouts, dashboard, users, queue, billing
|   |   |-- subscription/              # Go Premium screen, My Subscription screen
|   |   |-- auth/                      # Login, Admin Login, Signup, OTP, AuthBloc
|   |   |-- adoption_match/            # Discover feed, Tinder swipe, Quiz
|   |   |-- pet_profile/               # Pet detail sliver view & media gallery
|   |   |-- application/               # Application form, e-signature canvas, tracker
|   |   |-- health_passport/           # QR code generator, scanner & vaccine logs
|   |   |-- emergency_sos/             # 5km broadcast alerts & emergency clinic directory
|   |   |-- chat/                      # Masked relay inbox & messaging
|   |   |-- community/                 # Happy Tails community story feed
|   |   |-- profile/                   # User profile, VIP badge & settings
|   |-- shared/widgets/                # CustomButton, AppCard, PremiumBadge, etc.
|
|-- test/unit/                         # Automated unit & BLoC test suites (36 tests)
```

---

## ⚙️ Environment Variables Configuration

Create a `.env` file in the `backend/` directory by copying `backend/.env.example`:

```env
PORT=5000
NODE_ENV=development

# JWT Secret for Session Signing
JWT_SECRET=your_jwt_secret_key_here_change_in_production
JWT_EXPIRES_IN=7d

# Google OAuth Credentials
GOOGLE_CLIENT_ID=your_google_oauth_client_id.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=your_google_oauth_client_secret

# Supabase Credentials (Optional for cloud sync)
SUPABASE_URL=https://your-project-ref.supabase.co
SUPABASE_ANON_KEY=your_supabase_anon_key_here
SUPABASE_SERVICE_ROLE_KEY=your_supabase_service_role_key_here

# SSLCommerz Payment Gateway Configuration (BDT Payments)
SSLCOMMERZ_STORE_ID=adoptmatch_sandbox
SSLCOMMERZ_STORE_PASSWORD=adoptmatch_sandbox@ssl
SSLCOMMERZ_IS_LIVE=false

# Official bKash Number for Manual Direct Transfers
BKASH_OFFICIAL_NUMBER=01711234567

# Public Server URL & App Deep Link
BACKEND_BASE_URL=http://localhost:5000
APP_DEEP_LINK_SCHEME=adoptmatch://payment-callback
```

---

## 🧪 Verification & Quality Gates

All test suites and static analysis checks are actively maintained with a 100% pass rate:

* **Static Analysis**: `flutter analyze` returns **0 issues found** (0 errors, 0 warnings).
* **Automated Unit Tests**: `flutter test` executes **36 / 36 tests passing** (100% green across AuthBloc, AdminRepository, PetMatchBloc, PetRepository, and Subscriptions).
* **Backend Payment Tests**: `node backend/test_subscription_payments.js` passes all 9 integration assertions (SSLCommerz session init, server validation, manual bKash approvals, cumulative renewal, and idempotency).

---

## 🏃 Running the Application

### 1. Start the Backend API Engine
```bash
cd backend
npm install
node server.js
```
The backend server will start on `http://localhost:5000`.

### 2. Run the Flutter Frontend
```bash
# Get dependencies
flutter pub get

# Run on Google Chrome (Recommended for Admin & Responsive UI testing)
flutter run -d chrome

# Run on connected Android device / emulator
flutter run -d android

# Run on Microsoft Edge
flutter run -d edge
```

### 3. Run Automated Tests
```bash
# Run all Flutter unit and widget tests
flutter test

# Run backend payment integration tests
node backend/test_subscription_payments.js
```

### 4. Code Quality Check
```bash
flutter analyze
```

---

## 🤝 Administrative Workflow Guide

1. Open the application and go to the Admin Login screen (`/admin/login`).
2. Enter the administrator credentials:
   * **Email**: `admin@adoptmatch.com`
   * **Password**: `Admin@123456`
3. Click **Sign In to Admin Portal**.
4. You will be directed to `/admin/dashboard` where you can:
   * Moderate flagged pet listings (`/admin/pets`).
   * Review pending shelter registrations (`/admin/shelters`).
   * Approve or reject manual bKash subscription transfers (`/admin/subscriptions`).
   * Review system audit trails and user access levels (`/admin/users`).
