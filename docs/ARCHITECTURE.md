# Architecture — ReClaim Enforcement Suite

Complete technical reference for the system's architecture, components, data flow, and deployment requirements.

---

## System Overview

The ReClaim Suite is a three-tier system that enforces healthy phone usage habits through real-time app blocking, usage analytics, and a gamified reward system.

```
┌─────────────────────────────────────────────────────────────────┐
│                        USER'S PHONE                             │
│                                                                 │
│  ┌─────────────────┐  MethodChannel  ┌─────────────────────┐   │
│  │  Flutter UI      │◄──────────────►│  Kotlin Native      │   │
│  │  (Material 3)    │                │  Engine             │   │
│  │                  │                │                     │   │
│  │  8 Screens:      │                │  • UsageStatsManager│   │
│  │  • Dashboard     │                │  • AccessibilityAPI │   │
│  │  • Analytics     │                │  • AlarmManager     │   │
│  │  • Focus Mode    │                │  • OverlayService   │   │
│  │  • Rewards       │                │  • SharedPreferences│   │
│  │  • Profile       │                │  • SQLite DB        │   │
│  │  • Insights      │                │                     │   │
│  │  • Settings      │                └─────────────────────┘   │
│  │  • Onboarding    │                         │                │
│  └─────────────────┘                          │                │
│           │                                   │ (event sync)   │
└───────────┼───────────────────────────────────┼────────────────┘
            │ HTTP                              │ HTTP
            ▼                                   ▼
     ┌──────────────────────────────────────────────────┐
     │              Node.js API Server                   │
     │              Port 4000 (Express + TypeScript)     │
     │                                                   │
     │  Endpoints:                                       │
     │  POST /v1/commitments       (save user rules)     │
     │  GET  /v1/commitments/:id   (read user rules)     │
     │  POST /v1/analytics/events  (ingest usage data)   │
     │  GET  /v1/analytics/daily   (daily report)        │
     │  GET  /v1/analytics/weekly  (weekly report)       │
     │  GET  /v1/policy/:id        (enforcement rules)   │
     │  GET  /v1/rewards/:id       (gamification data)   │
     │  GET  /v1/health            (system health)       │
     │                                                   │
     │  Middleware: Helmet, CORS, JWT Auth, Zod validation  │
     └──────────────────┬───────────────────────────────┘
                        │ pg (node-postgres)
                        ▼
     ┌──────────────────────────────────────────────────┐
     │              PostgreSQL 18.3                      │
     │              Database: reclaim_db            │
     │                                                   │
     │  8 Tables:                                        │
     │  schema_migrations, users, commitments,           │
     │  usage_events, usage_logs, daily_analytics,       │
     │  daily_summaries, insight_snapshots                │
     │                                                   │
     │  15 Indexes (incl. dedup + performance)           │
     │  2 Functions (cleanup + streak)                   │
     └──────────────────────────────────────────────────┘
```

---

## Component Details

### 1. Android Native Engine (`apps/android-native/`)

The authoritative enforcement layer. Runs on-device with no server dependency.

| Component | File | Purpose |
|---|---|---|
| **FocusEnforcer** | `enforcement/FocusEnforcer.kt` | 6-tier decision engine: Whitelist → Grace → Locked → Focus Window → Daily Limit → Allow |
| **EnforcementManager** | `enforcement/EnforcementManager.kt` | Lifecycle manager — initializes tracking, scheduling, policy store |
| **EnforcementService** | `services/EnforcementService.kt` | `AccessibilityService` subclass — intercepts app switches in real-time |
| **TrackingEngine** | `tracking/TrackingEngine.kt` | Reads `UsageStatsManager` data, computes per-app screen time |
| **GamificationEngine** | `rewards/GamificationEngine.kt` | Streak counter, badge awarding, reward point calculation |
| **FocusPolicyStore** | `data/FocusPolicyStore.kt` | SharedPreferences-backed policy cache with 60s TTL |
| **LocalStore** | `data/LocalStore.kt` | SharedPreferences-backed commitment storage, timestamp tracking |
| **LocalAnalyticsStore** | `data/LocalAnalyticsStore.kt` | SQLite database for on-device usage session logging |
| **OverlayService** | `services/OverlayService.kt` | Glassmorphic block overlay with dynamic override timer |
| **BootReceiver** | `receivers/BootReceiver.kt` | Restarts enforcement on device reboot via `AlarmManager` |
| **UsageReader** | `tracking/UsageReader.kt` | Maps package names to human-readable app names + categories |

#### Enforcement Decision Chain

```
App Switch Event (from AccessibilityService)
  │
  ├─ Is package whitelisted? ──────── YES → ALLOW
  │
  ├─ Is package in grace period? ──── YES → ALLOW (temporary)
  │
  ├─ Is device in LOCKED mode? ────── YES → BLOCK (full lockdown)
  │
  ├─ Is current time in focus window? ─ YES → BLOCK (unless whitelisted)
  │
  ├─ Daily limit exceeded? ─────────── YES → BLOCK
  │
  └─ Default ──────────────────────── ALLOW
```

### 2. Flutter UI Shell (`apps/mobile/`)

The user-facing interface. Communicates with the native engine via `MethodChannel`.

| Screen | File | Data Source |
|---|---|---|
| Dashboard | `features/dashboard/dashboard_screen.dart` | `MethodChannel` → `TrackingEngine` |
| Analytics | `features/analytics/analytics_screen.dart` | `MethodChannel` → `LocalAnalyticsStore` |
| Focus Mode | `features/focus/focus_mode_screen.dart` | `MethodChannel` → `FocusPolicyStore` |
| Rewards | `features/rewards/reward_screen.dart` | `MethodChannel` → `GamificationEngine` |
| Profile | `features/profile/profile_screen.dart` | `MethodChannel` → `LocalStore` |
| Insights | `features/insights/insights_screen.dart` | `MethodChannel` → `LocalAnalyticsStore` |
| Settings | `features/settings/settings_screen.dart` | `MethodChannel` → `LocalStore` |
| Onboarding | `features/onboarding/onboarding_screen.dart` | Local state → `MethodChannel` |

#### MethodChannel Bridge Methods (14 total)

```
com.minimalism.focus/bridge
  ├── getDashboardStats        → Map (today usage, goal, streak, blocked)
  ├── getTodayUsage            → Map<String, int> (per-app milliseconds)
  ├── getDailyLimit            → int (minutes)
  ├── setDailyLimit            → void
  ├── requestOverride          → Map (granted, duration, remaining)
  ├── getWeeklySummary         → Map (daily totals for 7 days)
  ├── getInsights              → Map (peak hour, recommendations, flags)
  ├── getCommitment            → Map (full commitment JSON)
  ├── saveCommitment           → void
  ├── getPolicyStatus          → Map (status, reason, remaining, blocked)
  ├── getRewardSummary         → Map (points, streak, badges, level)
  ├── getInstalledApps         → List<Map> (package, name, category)
  ├── getAppIcon               → Uint8List (PNG bytes)
  └── getCategoryBreakdown     → List<Map> (category, minutes)
```

### 3. Node.js API Server (`services/api/`)

Cloud-side analytics, long-term storage, and cross-device sync.

| Layer | Files | Purpose |
|---|---|---|
| **Presentation** | `routes/`, `middleware/`, `validation/` | HTTP endpoints, JWT & API Key auth, Zod validation, error handling |
| **Application** | `analyticsService.ts`, `policyService.ts` | Business logic orchestration |
| **Domain** | `patternEngine.ts`, `rewardEngine.ts`, `types/` | Pure computation — no I/O |
| **Infrastructure** | `analyticsRepository.ts` | PostgreSQL queries, batch inserts, dedup |
| **Database** | `pool.ts`, `runMigrations.ts`, `migrations/` | Connection management, schema versioning |

#### Domain Engines

**Pattern Engine** (`patternEngine.ts`):
- Distraction risk score (0–100)
- App switches per hour
- Late-night usage detection (after 23:00)
- Peak usage hour identification
- Longest continuous session tracking
- Excessive usage flags + recommendations

**Reward Engine** (`rewardEngine.ts`):
- Base 50 points for staying within daily limit
- +10 per completed focus session
- -15 per override used
- -5 per 10 late-night minutes
- Streak multiplier: +5 per consecutive day
- Badges: "Distraction Free Day", "No Escape Token", "Night Guard", "Focus Champion"
- Levels: Beginner (0–99), Disciplined (100–499), Focus Pro (500+)

---

## Database Schema

### PostgreSQL (Cloud — 8 tables, 15 indexes)

```
schema_migrations    ← Migration version tracking
  version TEXT PK
  name TEXT
  applied_at TIMESTAMPTZ

users                ← Registered user accounts
  id UUID PK
  preferences JSONB
  created_at TIMESTAMPTZ

commitments          ← User's daily rules/goals (1:1 with users)
  user_id UUID PK FK→users
  daily_limit_minutes INT [15–1440]
  focus_windows JSONB
  whitelist_packages TEXT[]
  blacklist_packages TEXT[]
  allow_whatsapp BOOL
  max_overrides_per_day INT [0–10]
  reward_system_enabled BOOL

usage_events         ← Raw event stream from device sync
  id BIGSERIAL PK
  user_id UUID FK→users
  package_name TEXT
  started_at TIMESTAMPTZ
  ended_at TIMESTAMPTZ
  duration_seconds INT [≥0]
  event_type TEXT [usage|blocked_attempt|override]
  metadata JSONB
  client_event_id TEXT (nullable, for idempotent dedup)
  created_at TIMESTAMPTZ

usage_logs           ← Normalized usage records with categories
  id BIGSERIAL PK
  user_id UUID FK→users
  app_name TEXT
  category TEXT [social|communication|productivity|entertainment|utility|other]
  start_time TIMESTAMPTZ
  end_time TIMESTAMPTZ
  duration_seconds INT [≥0]

daily_analytics      ← Computed daily metrics + rewards
  (user_id, date_key) COMPOSITE PK
  total_screen_minutes, blocked_attempts, overrides_used INT
  distraction_minutes, focus_minutes, late_night_minutes INT
  app_switches INT
  reward_points INT, streak_days INT
  badges TEXT[], insights JSONB

daily_summaries      ← App/category breakdowns per day
  (user_id, date_key) COMPOSITE PK
  total_screen_time_minutes INT
  category_breakdown JSONB
  app_breakdown JSONB

insight_snapshots    ← AI-style recommendations per day
  (user_id, date_key) COMPOSITE PK
  peak_usage_hour INT [0–23]
  excessive_usage_flags TEXT[]
  recommendation_summary JSONB
```

### Android SQLite (On-Device — 1 table)

```
usage_logs           ← Local session log for offline analytics
  id INTEGER PK AUTOINCREMENT
  package_name TEXT
  app_name TEXT
  category TEXT
  start_time INTEGER (epoch ms)
  end_time INTEGER (epoch ms)
  duration_ms INTEGER
```

### SharedPreferences Stores (On-Device — 3 stores)

| Store | Key Data |
|---|---|
| `focus_policy_store` | Policy JSON, override count/date, grace windows, event queue (max 200) |
| `focus_native_store` | Commitment JSON, last capture/upload/nudge timestamps |
| Flutter `SharedPreferences` | Analytics cache (sessions, events, categories, reports) |

---

## Category Classification (Unified)

Both Android and the API server use the same classification rules:

| Category | Package Patterns |
|---|---|
| `social` | instagram, facebook, twitter, reddit, snapchat, tiktok |
| `entertainment` | youtube, netflix, spotify, primevideo, hotstar, twitch |
| `communication` | whatsapp, telegram, message, dialer, sms, signal |
| `productivity` | chrome, docs, gmail, calendar, sheets, drive, notion, slack |
| `utility` | calculator, clock, settings, camera, gallery, files |
| `other` | Everything else |

---

## Technology Stack

| Component | Technology | Version |
|---|---|---|
| Android Native | Kotlin, Gradle | Kotlin 1.9+, Gradle 8.x |
| Flutter UI | Dart, Flutter SDK | Dart 3.4+, Flutter 3.4+ |
| API Server | TypeScript, Node.js, Express | Node.js 25.x, Express 4.x |
| Database | PostgreSQL | 18.3 |
| Validation | Zod | 4.4.2 |
| CI/CD | GitHub Actions | N/A |

### Flutter Dependencies

| Package | Purpose |
|---|---|
| `shared_preferences` | Local key-value cache |
| `http` | HTTP client for API calls |
| `fl_chart` | Charts and graphs |
| `intl` | Date/time formatting |
| `permission_handler` | Runtime permissions |

### API Dependencies

| Package | Purpose |
|---|---|
| `express` | HTTP framework |
| `pg` | PostgreSQL client |
| `helmet` | Security headers |
| `cors` | Cross-origin requests |
| `zod` | Input validation |
| `dotenv` | Environment config |
| `tsx` | TypeScript execution |

---

## Running Locally

### Prerequisites
- Node.js 20+
- PostgreSQL 15+ (running on port 5432)
- Flutter SDK 3.4+
- Android Studio with emulator
- Java 17+

### Backend
```powershell
cd services/api
npm install
npm run migrate    # creates 8 tables + 15 indexes
npm run dev        # starts on http://localhost:4000
```

### Android Native App
```powershell
cd apps/android-native
./gradlew assembleDebug
# Install APK on device/emulator
```

### Flutter Mobile App
```powershell
cd apps/mobile
flutter pub get
flutter run        # launches on connected device/emulator
```

### Verify Everything
```powershell
# Health check (should return {"status":"ok","database":"connected"})
curl http://localhost:4000/v1/health

# Run backend tests
cd services/api && npm run test
```

---

## Key Architecture Decisions

1. **Dual-client architecture**: Native Android for enforcement (reliability), Flutter for UI (speed of development). Enforcement cannot depend on Flutter because the Dart VM may not be running.

2. **Offline-first**: All enforcement decisions happen locally using SharedPreferences + SQLite. The API server is optional — the app works fully without internet.

3. **Event sourcing for analytics**: Raw `usage_events` are never modified. Daily analytics are computed from events and stored separately, allowing recomputation if the algorithm changes.

4. **Policy caching (60s TTL)**: Enforcement policy is cached for 60 seconds to avoid hammering `UsageStatsManager` on every app switch. Trade-off: enforcement changes take up to 60 seconds to apply.

5. **Idempotent event ingestion**: Events include a `client_event_id` with a `UNIQUE` constraint. Re-syncing the same events is safe — duplicates are silently skipped.

6. **Unified category classification**: Both Android and the API use the same `CATEGORY_RULES` mapping, eliminating mismatches between local and cloud analytics.


