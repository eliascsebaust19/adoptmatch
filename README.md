# AdoptMatch — AI-Powered Pet Adoption & Matching Platform

> **"Don't just find a pet. Find the right pet for your life."**

AdoptMatch is a full-stack, AI-powered pet adoption platform that connects shelter animals with suitable adopters based on lifestyle, home environment, experience, preferences, and pet compatibility.

---

## 🌟 Key Features

1. **AI Pet Matching Engine ("Find My Perfect Pet")**: Transparent weighted scoring algorithm calculating 0–100% compatibility, match classification, and natural language match reasons & considerations.
2. **Role-Based Portals**:
   - **Adopter**: Lifestyle assessment, personalized match recommendations, pet favoriting, online adoption applications, application timeline tracking, post-adoption support.
   - **Shelter Staff / Admin**: Pet CRUD, application review & status management, foster assignments, medical/behavior history logging, real-time analytics.
   - **Foster Volunteer**: Available capacity management, species/size preference, assignment tracking.
   - **Veterinarian**: Authorized medical records & vaccination entries.
3. **End-to-End Adoption Lifecycle**: Multi-step application submission, visual live status timeline (Submitted → Under Review → Interview → Approved/Rejected → Completed).
4. **Post-Adoption & Return-Risk Support**: 3-3-3 rule transition guidance, care guides, and periodic checkup surveys calculating risk levels (*Low Concern*, *Needs Attention*, *High Concern*).
5. **Real-time Analytics**: Monthly adoption trends, pet status distribution, match accuracy rates.

---

## 🏗 System Architecture

```
React + Vite Frontend (Port 5173)
        ↓ (HTTP REST / Axios)
Node.js / Express API Server (Port 5000)
        ↓
MySQL Database (adoptmatch_db / fallback store)
        ↓
Python FastAPI Matching Service (Port 8000)
```

---

## 🚀 Quick Setup & Installation

### 1. Install Dependencies
```bash
# Install root dependencies
npm install

# Install server dependencies
cd server && npm install && cd ..

# Install frontend dependencies
cd src-frontend && npm install && cd ..

# Install Python AI service dependencies
cd ai-service && pip install -r requirements.txt && cd ..
```

### 2. Environment Configuration
Copy `.env.example` to `.env`:
```env
DB_HOST=localhost
DB_USER=root
DB_PASSWORD=
DB_NAME=adoptmatch_db
DB_PORT=3306
PORT=5000
JWT_SECRET=adoptmatch_secret_jwt_key_2026_secure
AI_SERVICE_URL=http://localhost:8000
FRONTEND_URL=http://localhost:5173
```

### 3. Database Setup (Optional MySQL)
Import `server/schema.sql` and `server/seed.sql` into MySQL, or run:
```bash
npm run seed
```
*(Note: If MySQL is not running locally, the server automatically uses the built-in in-memory demo data provider for seamless testing).*

### 4. Running the Services

**Terminal 1: Node.js Backend API (Port 5000)**
```bash
npm run start:server
```

**Terminal 2: Python FastAPI AI Service (Port 8000)**
```bash
npm run start:ai
```

**Terminal 3: React + Vite Frontend (Port 5173)**
```bash
npm run start:frontend
```

Open [http://localhost:5173](http://localhost:5173) in your browser.

---

## 🔑 Demo Login Accounts

| Role | Email | Password |
|---|---|---|
| **Adopter** | `sarah.adopter@gmail.com` | `password123` |
| **Shelter Staff** | `staff@pawshelter.org` | `password123` |
| **System Admin** | `admin@adoptmatch.com` | `password123` |
| **Foster** | `elena.foster@gmail.com` | `password123` |
| **Veterinarian** | `dr.vance@vetcare.org` | `password123` |
