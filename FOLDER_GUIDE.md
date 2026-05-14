

## Root Directory
- `apps/`: Contains the primary user-facing applications.
  - `mobile/`: **Production Plane**. Flutter + Kotlin integrated application.
  - `android-native/`: **R&D Sandbox**. Pure Kotlin native implementation for system-level testing.
- `services/`: Contains backend logic and API services.
- `docs/`: Technical documentation and design specifications.
- `Misc/`: Supplementary assets, scripts, and temporary resources.
- `reclaim-setup.ps1`: Automated environment setup script for Windows.
- `reclaim-run.ps1`: Orchestration script to launch both mobile and backend environments.

---

## Mobile App (`/apps/mobile`)
The core Flutter application that handles UI, behavioral tracking, and local-first data management.

- `lib/screens/`: Main UI screens (e.g., Dashboard, Trends, Settings).
- `lib/services/`: Local service layer and API connectors.
- `lib/widgets/`: Reusable UI components (Glassmorphic cards, custom charts).
- `lib/models/`: Data structures for focus sessions and habit logs.
- `android/`: Native Android implementation for enforcement.
  - `.../backend/engine/`: Core logic for **Cognitive Drift Engine™** and **Friction Orchestrator**.
  - `.../flutter/enforcement/`: Accessibility Service and Overlay management.

---

## Native R&D (`/apps/android-native`)
A standalone native Kotlin version of ReClaim used for benchmarking system hooks and hardware security.

- `app/src/main/kotlin/com/minimalism/focus/`:
  - `data/`: UsageReader and Local Analytics storage.
  - `enforcement/`: FocusAccessibilityService and FocusEnforcer.
  - `ui/`: Native Dashboard and BlockActivity.

---

## Backend Services (`/services/api`)
The Node.js/Express backend that provides global analytics, app categorization, and user synchronization.

- `src/controllers/`: Logic for handling API requests (Metrics, Apps, Profile).
- `src/domain/services/`: Core logic engines (**PatternEngine**, **RewardEngine**).
- `src/presentation/routes/`: API endpoint definitions (RS256 secured).
- `src/presentation/middleware/`: Security and validation layers (**Zod**, **Helmet**).

---

## API Reference

### Core Endpoints:
- `auth/`: User registration, login, and JWT session management.
- `analytics/`: Retrieves daily/weekly trends for focus and screen time.
- `drift/`: Real-time tracking for **Focus Slips** and session transitions.
- `friction/`: Logs **Focus Guard** interventions and user responses.
- `intent/`: Handles the declaration of intent before distractive app usage.
- `craving/`: Predictive analytics for identifying high-risk distraction windows.
- `policy/`: Manages app categories, blacklists, and enforcement rules.
- `social/`: Community features and accountability partner updates.

---

## Database Architecture


### Local Database (Mobile)
- **Technology**: Android Room (SQLite)
- **Purpose**: High-frequency logging of accessibility events and Focus Slips.
- **Location**: `apps/mobile/android/app/src/main/kotlin/.../db/room/`
- **Key DAOs**: `DriftDao`, `FrictionDao`, `IntentDao`, `AppUsageDao`.

### Remote Database (Backend)
- **Technology**: PostgreSQL
- **Purpose**: Global analytics, user profile synchronization, and social accountability features.
- **Location**: `services/api/src/db/migrations/`
- **Primary Tables**:
  - `users`: Core profile and RS256 security data.
  - `drift_sessions`: Aggregated focus slip events.
  - `friction_events`: History of **Focus Guard** interventions.
  - `intent_logs`: Records of declared user intentions.
  - `craving_windows`: ML-predicted distraction patterns.
  - `social_commitments`: Accountability partner data.

---

##  Documentation (`/docs` & root)
- `ReClaim_Technical_Book_v2.0.docx`: The authoritative "Technical Bible" for judges and developers.
- `CONTRIBUTING.md`: Guidelines for setting up the local dev environment.
- `FOLDER_GUIDE.md`: This file.

---

## Infrastructure & Utilities
- `.github/workflows/`: CI/CD pipelines for automated testing and deployment.
- `generate_complete_reference.js`: Script to compile the technical documentation.
- `sensitive/`: Directory for local environment secrets and keys (never committed).
