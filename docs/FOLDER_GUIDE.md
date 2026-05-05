# Folder Guide

This document explains where code lives, what each folder is for, and which path is authoritative.

Last verified: **May 3, 2026**

---

## 1. Repository Root

```
Hackathon/
├── .github/           CI/CD workflows
├── .gradle-home/      Workspace-local Gradle cache
├── apps/              Application clients
│   ├── android-native/   Standalone Android app (Kotlin-only)
│   └── mobile/           Flutter + Kotlin hybrid app
├── docs/              All project documentation
├── services/          Backend services
│   └── api/              Node.js/TypeScript API
└── README.md          Project overview
```

### `.github/`

GitHub Actions CI/CD workflows.

- `workflows/ci.yml` — Runs 3 parallel jobs on push/PR: backend build+test, Android native Gradle build, Flutter debug APK build.

### `.gradle-home/`

Workspace-local Gradle cache. Avoids permission problems under the Windows user profile. Always set `$env:GRADLE_USER_HOME` to this path before Gradle builds.

### `docs/`

All project documentation:

| File | Purpose |
|---|---|
| `CHANGELOG.md` | Every edit across all development sessions with reasons |
| `ARCHITECTURE.md` | Full system architecture, data flow diagrams, tech stack |
| `API_DESIGN.md` | Comprehensive API documentation for all phases |
| `DB_SCHEMA.md` | PostgreSQL schema — 12 tables, 22 indexes |
| `FOLDER_GUIDE.md` | This file |
| `STEP_BY_STEP_RUN.md` | How to run every component (Manual & Docker) |
| `Digital_Minimalism_Hackathon_Pitch.docx` | Hackathon pitch deck |

---

## 2. Flutter + Android Hybrid App

**Path:** `apps/mobile/`  
**Package:** `com.minimalism.focus.flutter`

This is the **primary demo app**. It has a Flutter UI shell with native Kotlin enforcement services running underneath.

### `android/app/src/main/AndroidManifest.xml`

Declares all permissions, activities, services, and receivers:
- `USAGE_ACCESS` — read app usage stats
- `SYSTEM_ALERT_WINDOW` — draw blocking overlay
- `SCHEDULE_EXACT_ALARM` — schedule enforcement alarms
- `RECEIVE_BOOT_COMPLETED` — restart enforcement on reboot
- Accessibility service declaration for `AppAccessibilityService`

### `android/app/src/main/kotlin/com/minimalism/focus/flutter/`

Flutter host activities and enforcement:

| File | Purpose |
|---|---|
| `MainActivity.kt` | Flutter host. Wires `MethodChannelHandler` and initializes `EnforcementManager`. |
| `MinimalLauncherActivity.kt` | Native-only home screen replacement (no Flutter engine). Standalone Kotlin UI. |

#### `flutter/enforcement/` — On-device enforcement subsystem

| File | Purpose |
|---|---|
| `AppAccessibilityService.kt` | `AccessibilityService` — intercepts app switches in real-time |
| `BlockingOverlayService.kt` | Glassmorphic block overlay with dynamic override timer |
| `BootReceiver.kt` | `BroadcastReceiver` — restarts enforcement alarms on device reboot |
| `EnforcementManager.kt` | Lifecycle manager — initializes tracking, scheduling, policy store |
| `FocusPolicyStore.kt` | SharedPreferences-backed policy cache with 60s TTL |

### `android/app/src/main/kotlin/com/minimalism/focus/backend/`

Native backend engine — data, tracking, gamification:

#### `backend/bridge/`

| File | Purpose |
|---|---|
| `MethodChannelHandler.kt` | Handles all 16 Flutter↔Kotlin `MethodChannel` calls |

#### `backend/engine/`

| File | Purpose |
|---|---|
| `TrackingEngine.kt` | Reads `UsageStatsManager`, computes per-app screen time |
| `GamificationEngine.kt` | Streak counter, badge awarding, reward points |
| `AnalyticsEngine.kt` | Aggregates usage data into daily/weekly summaries |
| `RecommendationEngine.kt` | Generates behavioral recommendations |
| `FocusSessionManager.kt` | Manages timed focus sessions |

#### `backend/services/`

| File | Purpose |
|---|---|
| `EnforcementService.kt` | `AccessibilityService` subclass — the legacy enforcement path |
| `OverlayService.kt` | System overlay with glassmorphic card + dynamic timer buttons |
| `FocusService.kt` | Foreground service for active focus sessions |
| `BackgroundSyncWorker.kt` | `PeriodicWorkRequest` — syncs usage data to the API server |
| `DeviceEventReceiver.kt` | Listens for screen on/off and user-present broadcasts |

#### `backend/db/`

| File | Purpose |
|---|---|
| `DatabaseHelper.kt` | SQLite helper — creates/upgrades local `usage_logs` table |
| `Contract.kt` | SQLite table/column name constants |
| `AppCategoryMapping.kt` | Maps package names to categories (social, productivity, etc.) |

### `lib/` — Flutter Dart source

#### `lib/main.dart`

Flutter entrypoint.

#### `lib/core/`

App constants — backend base URL, package defaults, shared configuration.

#### `lib/navigation/`

Bottom navigation bar and route management.

#### `lib/features/` — Feature screens

| Directory | Screen | Data Source |
|---|---|---|
| `dashboard/` | Dashboard overview | `MethodChannel` → `TrackingEngine` |
| `app_usage/` | Per-app usage bars and category view | `MethodChannel` → `LocalAnalyticsStore` |
| `insights/` | Behavioral insights and recommendations | `MethodChannel` → `AnalyticsEngine` |
| `focus/` | Focus mode timer | `MethodChannel` → `FocusSessionManager` |
| `rewards/` | Streaks, points, badges | `MethodChannel` → `GamificationEngine` |
| `profile/` | Daily limit, emergency unlocks, streak | `MethodChannel` → `FocusPolicyStore` |

#### `lib/shared/`

Shared widgets, models, and utilities used across features.

#### `lib/services/`

Platform bridge services — `MethodChannel` wrappers that call the native Kotlin layer.

---

## 3. Native Android App (Standalone)

**Path:** `apps/android-native/`  
**Package:** `com.minimalism.focus`

A standalone Kotlin-only Android app. Uses the same enforcement architecture as the Flutter hybrid but without the Flutter UI layer. Contains its own `MainActivity`, data layer, and enforcement services.

**Note:** This app was the original prototype. The Flutter hybrid app (`apps/mobile/`) is now the primary demo path since it has the full UI.

---

## 4. Backend API

**Path:** `services/api/`  
**Stack:** Node.js, TypeScript, Express, PostgreSQL, Zod v4

### Source Structure

```
src/
├── app.ts                    Express app setup
├── server.ts                 HTTP server entrypoint
├── db/
│   ├── pool.ts               PostgreSQL connection pool
│   ├── runMigrations.ts      Migration runner
│   └── migrations/
│       ├── 001...003         Initial and production hardening
│       └── 004_social.sql    Buddies and group challenges
├── application/
│   ├── analyticsService.ts   Analytics orchestration
│   ├── notificationService.ts  **NEW:** FCM Push delivery
│   └── purgingService.ts     Automated data retention
├── domain/
│   └── services/
│       ├── patternEngine.ts  **ENHANCED:** Predictive risk logic
│       └── rewardEngine.ts   Gamification logic
├── infrastructure/
│   ├── analyticsRepository.ts  Postgres persistence
│   └── socialRepository.ts   **NEW:** Buddy/Challenge persistence
├── presentation/
│   ├── routes/
│   │   ├── analyticsRoutes.ts    Usage events, devices, export
│   │   ├── socialRoutes.ts       **NEW:** Social API
│   │   ├── adminRoutes.ts        **NEW:** Admin stats API
│   │   ├── policyRoutes.ts       Policy & Rewards
│   │   └── healthRoutes.ts       System health
│   ├── middleware/
│   │   ├── auth.ts               x-api-key check
│   │   ├── rateLimiter.ts        Memory-based limiter
│   │   └── errorHandler.ts       Unified error mapping
│   └── validation/
│       └── schemas.ts            Zod validation rules
```

### Deployment Configuration

| File | Purpose |
|---|---|
| `Dockerfile` | Multi-stage production build |
| `docker-compose.yml` | Full stack orchestration (API + Postgres) |
| `.env.example` | Template with FCM and Retention settings |

### Key Files

| File | Purpose |
|---|---|
| `pool.ts` | Connection pooling with error listener, 5s connect timeout, 30s query timeout, graceful SIGINT/SIGTERM shutdown |
| `runMigrations.ts` | Version-tracked migration runner — wraps each migration in a transaction, skips already-applied |
| `schemas.ts` | Zod v4 validation — UUID regex, ISO datetime, event payloads, query params |
| `errorHandler.ts` | `ZodError` → 400 with field details; generic errors → 500 with stack hidden in production |
| `analyticsRepository.ts` | Batch multi-row INSERT, `ON CONFLICT DO NOTHING` dedup, unified `CATEGORY_RULES` |
| `env.ts` | `PORT`, `DATABASE_URL`, `DEFAULT_TIMEZONE`, `EVENT_RETENTION_DAYS`, `MAX_EVENTS_PER_BATCH`, `CORS_ORIGINS` |

### Configuration Files

| File | Purpose |
|---|---|
| `.env` | Active environment variables (not committed) |
| `.env.example` | Template with all config options and safe defaults |
| `package.json` | Dependencies, scripts (`dev`, `build`, `test`, `migrate`) |
| `tsconfig.json` | TypeScript compiler config |
