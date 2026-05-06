# ReClaim Changelog — Complete Development History

Every edit made across all development sessions, organized chronologically with rationale.

---

## Session 1 — Backend Implementation & Flutter-Native Bridge
**Date:** April 28–29, 2026  
**Goal:** Build a complete Flutter-to-Native integration layer and replace all static UI data with live system data.

### What was done

#### Android Native Layer (apps/mobile/android)

| File | Edit | Why |
|---|---|---|
| `DatabaseHelper.kt` | Fixed `import Contract.*` to explicit imports; added `android.provider.BaseColumns` | Kotlin doesn't allow star imports from `object`. Caused `Unresolved reference: BaseColumns` build failure. |
| `OverlayService.kt` | Fixed `import com.minimalism.focus.backend.R` → `com.example.hackathon_reclaim.R` | Package name mismatch — R class must match the project's actual application ID. |
| `MainActivity.kt` | Fixed placeholder package `com.your.packagename` → `com.example.hackathon_reclaim` | Build failure — the class couldn't resolve the correct generated code. |
| `build.gradle.kts` | Added `androidx.work:work-runtime-ktx` dependency | Background sync (`PeriodicWorkRequest`) was referenced but the library was missing. |
| Backend file structure | Moved files from `com/backend` → `com/minimalism/focus/backend` | Folder path didn't match Kotlin package declarations, causing the compiler to fail. |

#### Flutter UI Layer (apps/mobile/lib)

| File | Edit | Why |
|---|---|---|
| `backend_service.dart` | Created 13 `MethodChannel` bridge methods | Needed to wire Flutter screens to native Android data (usage stats, policy, rewards, enforcement). |
| Feature screens (8 files) | Connected to `BackendService` for live data | All screens were showing static placeholder values. Replaced with real `MethodChannel` calls. |

**Key Decision:** The architecture was split into two communication layers — `MethodChannel` for direct Flutter↔Kotlin calls, and `HTTP` for Flutter→Node.js API calls.

---

## Session 2 — Development Workflow & CI/CD
**Date:** April 29, 2026  
**Goal:** Establish automated CI and a documented development workflow.

### What was done

| File | Edit | Why |
|---|---|---|
| `.github/workflows/ci.yml` | **[NEW]** Created GitHub Actions pipeline | Automated build verification for backend (Node.js), Android native (Gradle), and Flutter (debug APK) on every push/PR. |
| `README.md` | Added `.github/` to the folder map | CI directory was missing from the project structure documentation. |

**Key Decision:** Three parallel CI jobs (backend, android-native, flutter-app) to keep build times fast.

---

## Session 3 — Documentation Cleanup & Sync
**Date:** April 29, 2026  
**Goal:** Synchronize all documentation with the actual codebase state.

### What was done

| File | Edit | Why |
|---|---|---|
| `docs/DB_SCHEMA.md` | Added 3 undocumented tables (`usage_logs`, `daily_summaries`, `insight_snapshots`) | Migration `002_analytics_upgrade.sql` added these tables but the docs were never updated. |
| `docs/API_DESIGN.md` | Added `GET /v1/health` endpoint | Health check existed in code but was missing from the API documentation. |
| `docs/ALGORITHMS.md` | Fixed path `apps/mobile/android/...` → `apps/android-native/...` | FocusEnforcer was relocated to the native app but the doc still pointed to the Flutter project's Android subfolder. |
| `docs/FOLDER_GUIDE.md` | Added `.github/workflows` directory | CI workflow files were not documented in the folder guide. |
| `README.md` | Added `.github/` to the top-level folder map | Same as above. |
| `docs/docx_qa/` (deleted) | Removed stale generated directory | Leftover from an earlier doc generation experiment; not part of the project. |
| `scripts/` (deleted) | Removed empty directory | Contained no files; was polluting the folder structure. |

---

## Session 4 — Performance, Glassmorphism UI, and Policy Caching
**Date:** April 30, 2026  
**Goal:** Fix build failures, implement glassmorphism UI, and optimize enforcement performance.

### What was done

#### Build Fixes

| File | Edit | Why |
|---|---|---|
| `bottom_nav.dart` | Fixed bracket mismatch | Syntax error in the navigation widget prevented the entire Flutter project from compiling. |

#### UI/Theme Changes

| File | Edit | Why |
|---|---|---|
| `app_theme.dart` | Replaced `ColorScheme.fromSeed()` with explicit `ColorScheme.dark()` | `fromSeed` was overriding the carefully chosen neon color palette with auto-generated colors, making the app look generic. |
| `dashboard_card.dart` | Changed `useGlass` default from `true` → `false` → `true` (toggled across sessions) | Initially `true` caused heavy rendering; set to `false` for testing; ultimately restored to `true` since that was the intended design. |
| `OverlayService.kt` | Replaced plain `LinearLayout` overlay with Glassmorphic card + neon button | The enforcement block overlay looked basic. New version uses a frosted-glass card with rounded corners, dim background, and a styled "Dismiss" button matching the app's visual language. |

#### Performance & Enforcement

| File | Edit | Why |
|---|---|---|
| `EnforcementService.kt` | Added policy caching with `lastPolicyCheckTime` throttle | The accessibility service was calling `UsageStatsManager` on every single app event (hundreds per minute), causing severe lag on the emulator. Now throttled to once per 10 seconds. |
| `FocusPolicyStore.kt` | Added `lastPolicyCacheTime` with 60-second TTL | Same issue — policy evaluation queries were running too frequently. |

**Key Decision:** Policy evaluation is now cached for 60 seconds. This means enforcement changes (e.g., reaching your daily limit) take up to 60 seconds to take effect, which is an acceptable trade-off for smooth performance.

---

## Session 5 — Glassmorphism Visibility Fix
**Date:** April 30, 2026  
**Goal:** Debug why glassmorphism changes weren't appearing in the app.

### What was done

| File | Edit | Why |
|---|---|---|
| `dashboard_card.dart` | Changed `useGlass` default back to `true` | The previous session set it to `false` during performance testing but forgot to revert. All cards across the app were rendering without the frosted-glass effect. |

**Root Cause:** Hot reload doesn't always pick up default parameter changes in `const` constructors. A full restart (`flutter run`) was needed.

---

## Session 6 — Dynamic Override Timer Logic
**Date:** April 30 – May 1, 2026  
**Goal:** Replace the simple 45/30-minute override timer with a context-aware dynamic system.

### What was done

| File | Edit | Why |
|---|---|---|
| `OverlayService.kt` | Rewrote override duration logic | The old system gave a flat 45 or 30 minutes. The new system is tiered: **Over limit** → max 20 min; **Approaching limit (<1hr left)** → choice of 15 or 30 min; **Well under limit (≥1hr left)** → choice of 15, 30, 45, or 60 min. |
| `OverlayService.kt` | Replaced single button with horizontal button group | Users needed to choose their override duration, so a single "Dismiss" button was replaced with multiple time-selection buttons. |
| `profile_screen.dart` | Reordered screen elements | Moved Daily Screen Limit and Emergency Unlocks to the top, pushed Streak card below them — per user request for logical flow. |

**Key Decision:** The 20-minute hard cap for over-limit users is deliberate — it provides enough time for urgent needs (e.g., looking up an address) without enabling extended distraction.

---

## Session 7 — Syncing UI with Backend & SDK Fixes
**Date:** April 30 – May 1, 2026  
**Goal:** Resolve SDK conflicts, theme crashes, and stabilize the Flutter build.

### What was done

| File | Edit | Why |
|---|---|---|
| `build.gradle` | Fixed `compileSdk` / `targetSdk` version conflicts | The Flutter module and Android native module had different SDK versions, causing `AAPT: error: resource android:attr/... not found`. |
| `styles.xml` | Removed conflicting `<style>` definitions | Theme resources were duplicated between `Theme.Hackathon` and `Theme.MinimalFocus`, causing `Duplicate resources` build errors. |
| `AndroidManifest.xml` | Consolidated manifest entries | Multiple `<activity>` declarations for `MainActivity` with conflicting `android:theme` attributes. |
| `EnforcementService.kt` | Added `try/catch` around `UsageStatsManager` queries | Crashes on emulator when usage access permission isn't granted yet. Defensive handling prevents the entire service from dying. |

---

## Session 8 — Flutter Debug Connection Fixes
**Date:** May 2, 2026  
**Goal:** Resolve persistent `DartDevelopmentServiceException` crashes on app launch.

### What was done

| File | Edit | Why |
|---|---|---|
| Multiple service files | Added lifecycle-safe startup checks | Background services were starting before the Flutter engine was fully attached, causing `DartDevelopmentServiceException` at launch. Added null checks and initialization guards. |
| Build environment | `flutter clean` → `flutter pub get` → kill stale Java processes | Gradle file locks from previous crashed builds prevented new builds. Required killing orphaned `java.exe` processes. |

**Root Cause:** The emulator's limited resources caused race conditions between the Flutter engine boot, native service startup, and Dart DevTools port allocation.

---

## Session 9 — Exact Alarm Permission Fix
**Date:** May 3, 2026  
**Goal:** Fix `SecurityException` crash on app startup.

### What was done

| File | Edit | Why |
|---|---|---|
| `AndroidManifest.xml` | Added `<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>` | Android 12+ requires this permission for `AlarmManager.setExactAndAllowWhileIdle()`. The `BootReceiver` was calling it without the permission, causing a `SecurityException` crash. |
| `EnforcementManager.kt` | Added `canScheduleExactAlarms()` runtime check | Even with the manifest permission, Android 12+ can revoke it at any time. The code now checks before scheduling and falls back to `setAndAllowWhileIdle()` (inexact alarm) if denied. |
| `MethodChannelHandler.kt` | Removed duplicate `"getDashboardStats"` `when` branch (line 62) | Kotlin `when` only matches the first matching branch — the duplicate was dead code causing confusion during debugging. |
| `MainActivity.kt` | Added `EnforcementManager.initialize(this)` in `configureFlutterEngine` | Without this, enforcement state (policy, focus windows, usage tracking) was never initialized from the Flutter host. `MethodChannelHandler` queries returned stale/empty data. |

---

## Session 10 — Feature Audit & Architecture Analysis
**Date:** May 3, 2026 (current)  
**Goal:** Comprehensive project audit — feature inventory, architecture mapping, and improvement roadmap.

### What was done

No code changes. Generated `analysis_results.md` artifact documenting:
- 14 native Android features, 14 Flutter UI features, 8 API endpoints
- 7 database tables, 2 domain engines (pattern + reward)
- 32 actionable improvement items across 4 priority tiers

---

## Session 11 — Production-Ready Database Overhaul
**Date:** May 3, 2026 (current)  
**Goal:** Transform empty PostgreSQL into a fully operational, production-hardened database.

### What was done

#### Database Layer

| File | Edit | Why |
|---|---|---|
| `001_init.sql` | Added `schema_migrations` table, `client_event_id` column + idempotency index, tightened `CHECK` constraints | Original migration had no version tracking (re-runs were uncontrolled), no dedup support, and `daily_limit_minutes` allowed 0 (should be ≥15). |
| `002_analytics_upgrade.sql` | Added `category` CHECK constraint, `peak_usage_hour` range check (0–23) | Raw text `category` column had no validation — could store garbage. `peak_usage_hour` had no bounds. |
| `003_production_hardening.sql` | **[NEW]** 4 performance indexes, dedup index, `cleanup_old_events()` function, `get_current_streak()` function | Query performance was unbounded. No data retention mechanism existed. Streak computation required app-level query each time. |
| `runMigrations.ts` | Full rewrite with version tracking, per-migration transactions with rollback | Old runner blindly re-ran all SQL files. No rollback on failure. No skip-if-applied logic. |
| `pool.ts` | Added error listener, 5s connect timeout, 30s query timeout, min/max tuning, SIGINT/SIGTERM graceful shutdown | Old pool had no error handling (crashed silently), no timeouts (queries could hang forever), no shutdown handling (leaked connections). |

#### Application Layer

| File | Edit | Why |
|---|---|---|
| `analyticsRepository.ts` | Batch INSERT replacing N+1 pattern, `ON CONFLICT DO NOTHING` dedup, unified `CATEGORY_RULES` | Old code fired 1 INSERT per event (100 queries for 50 events). No dedup — re-sync created duplicates. Android and backend classified apps differently (Chrome = "utility" on backend, "productivity" on Android). |
| `analyticsService.ts` | `ingestEvents()` returns inserted count; typed 404 errors with status codes | Old version returned `void` — caller couldn't tell how many events were actually inserted. Errors were generic `throw new Error()` with no HTTP status code. |
| `errorHandler.ts` | `ZodError` → 400 with field-level details, structured JSON logging for 500s, stack hiding in production | Old handler returned raw stack traces in all environments. No special handling for validation errors. |

#### Presentation Layer

| File | Edit | Why |
|---|---|---|
| `schemas.ts` | **[NEW]** Zod v4 schemas for all inputs — UUID regex, datetime, event payloads, query params | **Zero input validation existed.** Any malformed request would crash the server or corrupt the database. |
| `commitmentRoutes.ts` | Added Zod validation on POST body and GET params | Raw `request.body as Commitment` — blindly trusted any input. |
| `analyticsRoutes.ts` | Added Zod validation on event payloads and query strings | Same — no validation, no error messages for bad input. |
| `policyRoutes.ts` | Added Zod validation on params/query, consistent error codes | Same. |
| `healthRoutes.ts` | Health endpoint now checks actual DB connectivity, returns 503 if unreachable | Old health route returned 200 OK even when the database was down. |

#### Configuration

| File | Edit | Why |
|---|---|---|
| `env.ts` | Added `DEFAULT_TIMEZONE`, `EVENT_RETENTION_DAYS`, `MAX_EVENTS_PER_BATCH`, `CORS_ORIGINS` | All were hardcoded. Timezone was `"Asia/Kolkata"` scattered across multiple files. Retention was documented but not configurable. |
| `.env` | Added all new config variables | Match the extended `env.ts`. |
| `.env.example` | **[NEW]** Template with all config options and safe defaults | No `.env.example` existed — new developers had to guess what environment variables were needed. |
| `app.ts` | Configurable CORS origins from env, 1MB body size limit, dev request logging | CORS was `*` always. No body size limit — a single large request could crash the server. No request logging for debugging. |

#### Dependencies

| Package | Version | Why Added |
|---|---|---|
| `zod` | 4.4.2 | Input validation for all API routes |
---

## Session 12 — Security Hardening & JWT Integration
**Date:** May 4, 2026 (current)  
**Goal:** Finalize production security by transitioning from a shared API key to a per-user JWT authentication flow and stabilizing native-mobile communication.

### What was done

#### Authentication & Backend (services/api)

| File | Edit | Why |
|---|---|---|
| `authMiddleware.ts` | Implemented JWT verification; added `/health` and `/auth/anonymous` to `publicPaths` | Critical #3, #4. Shared API key was insecure; health check was accidentally gated behind auth. |
| `authRoutes.ts` | **[NEW]** Created `/v1/auth/anonymous` endpoint | Needed for seamless user onboarding without requiring credentials while still maintaining per-user data isolation. |
| `socialRoutes.ts` | Replaced `x-user-id` header dependency with `req.user.userId` from JWT | Critical #10. Identity is now cryptographically verified rather than self-reported by the client. |
| `commitmentRoutes.ts`| Rewrote routes to use `req.user.userId`; added `/commitments/me` | Standardized secure access to user-specific rules. |

#### Flutter Mobile Layer (apps/mobile)

| File | Edit | Why |
|---|---|---|
| `backend_service.dart` | Added `_jwtToken` and `_userId` state; implemented `_authenticateAnonymous()` | Critical #1. Removed hardcoded API secret. App now negotiates a unique token on first launch. |
| `backend_service.dart` | Updated all HTTP methods to use `Authorization: Bearer` header | Critical #4. Authenticates all cloud requests with the verified user identity. |
| `backend_service.dart` | Updated `registerDevice` to pass `jwt_token` and `base_url` to platform | Critical #2. Native layer needs the token to call the backend securely. |
| `main.dart` | Added `BackendService.initialize()` in `main()` | Ensures auth state is loaded or created before the UI renders. |
| `devices_screen.dart` | Connected to real `getDevices` and `unregisterDevice` API methods | Medium #10. Removed mock device data; users can now manage real device links. |

#### Android Native Layer (apps/mobile/android)

| File | Edit | Why |
|---|---|---|
| `MethodChannelHandler.kt`| Rewrote `handleRegisterDevice` with Coroutines and explicit result handling | High #10. Old implementation used raw Threads and could hang the Flutter UI on failure. |
| `MethodChannelHandler.kt`| Added null-check guards for `getAppIcon` arguments | Critical #7. Passing null package names caused unhandled exceptions and hung the Flutter side. |
| `MethodChannelHandler.kt`| Optimized `drawableToPngBytes` with bitmap recycling and scaling | Medium #12. Loading many high-res app icons was causing memory pressure and potential OOMs. |
| `ApiClient.kt` | Updated to use `Authorization: Bearer` and dynamic `baseUrl` | Critical #2. Native registration was pointing to a hardcoded placeholder URL and using no auth. |

**Key Decision:** Anonymous JWTs provide a balance between ease of use (no login required) and production security (data is isolated and keys can be rotated). The JWTs are set to expire in 10 years for the demo, but can be shortened for production.
