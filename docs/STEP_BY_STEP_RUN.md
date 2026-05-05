# Step-by-Step Run Guide (Windows)

Last verified: **May 3, 2026** — all commands tested and confirmed working.

## Quick Start

### A. Manual Start
```
1. Start PostgreSQL             → service must be running
2. Start Backend API            → npm run migrate, then npm run dev
3. Launch Emulator              → flutter emulators --launch <name>
4. Run Flutter App              → flutter run (primary demo path)
```

### B. Docker Start (Backend Only)
```
1. cd services/api
2. docker-compose up --build
```

---

## 1. Prerequisites

Install these before proceeding:

| Tool | Version | Download |
|---|---|---|
| PostgreSQL | 18+ | https://www.postgresql.org/download/windows/ |
| Node.js | 20+ | https://nodejs.org/ |
| Android Studio | Latest | https://developer.android.com/studio |
| Flutter SDK | 3.4+ | https://docs.flutter.dev/get-started/install |
| Java JDK | 17+ | Included with Android Studio |

Verify installations:

```powershell
node --version          # should show v20+ or v25+
flutter --version       # should show Flutter 3.4+
java -version           # should show 17+
```

---

## 2. Start PostgreSQL

### 2.1 Find the Postgres service

```powershell
Get-Service *postgres*
```

### 2.2 Start the service

```powershell
Start-Service postgresql-x64-18
```

> If PowerShell says "access denied", open PowerShell **as Administrator** and retry.

### 2.3 Verify login

```powershell
$env:PGPASSWORD='YOUR_PASSWORD'
psql -U postgres -h localhost -p 5432 -c "SELECT version();"
```

### 2.4 Create the database (first time only)

```powershell
psql -U postgres -h localhost -p 5432 -c "CREATE DATABASE reclaim_db;"
```

If it already exists, this will show an error — that's fine, continue.

---

## 3. Start the Backend API

### 3.1 Navigate to the API directory

```powershell
cd C:\Users\siddh\Desktop\Hackathon\services\api
```

### 3.2 Create `.env` if missing

```powershell
if (!(Test-Path .env)) { Copy-Item .env.example .env }
```

### 3.3 Edit `.env` with your database password

```powershell
notepad .env
```

Required variables:

```env
PORT=4000
NODE_ENV=development
DATABASE_URL=postgres://postgres:YOUR_PASSWORD@localhost:5432/reclaim_db
DEFAULT_TIMEZONE=Asia/Kolkata
EVENT_RETENTION_DAYS=90
MAX_EVENTS_PER_BATCH=500
CORS_ORIGINS=*
X_API_KEY=your_secure_api_key_here
```

### 3.4 Fix PowerShell npm policy (if needed)

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

### 3.5 Install dependencies

```powershell
npm install
```

### 3.6 Run database migrations

```powershell
npm run migrate
```

Expected output:

```
Starting database migration...
  ✅ 001_init.sql applied successfully
  ✅ 002_analytics_upgrade.sql applied successfully
  ✅ 003_production_hardening.sql applied successfully
  ✅ 003_device_registry.sql applied successfully
  ✅ 004_social_accountability.sql applied successfully

Migration complete: 5 applied, 0 skipped.
```

On subsequent runs, it will skip already-applied migrations:

```
  ⏭  001_init.sql (already applied)
  ⏭  002_analytics_upgrade.sql (already applied)
  ⏭  003_production_hardening.sql (already applied)
  ⏭  004_social_accountability.sql (already applied)

Migration complete: 0 applied, 4 skipped.
```

### 3.7 Start the API server

```powershell
npm run dev
```

Expected:

```
reclaim-api listening on port 4000
```

---

## 4. Verify Backend Health

Open a **second terminal**:

```powershell
Invoke-RestMethod http://localhost:4000/v1/health
```

Expected:

```
status service              database  timestamp
------ -------              --------  ---------
ok     reclaim-api connected 2026-05-03T16:31:59.142Z
```

### Quick API smoke test

```powershell
# Test validation (should return 400 with field errors)
try {
  Invoke-RestMethod -Uri "http://localhost:4000/v1/commitments" -Method Post -ContentType "application/json" -Body '{"bad":"data"}'
} catch { $_.ErrorDetails.Message }

# Test valid commitment (requires x-api-key)
$headers = @{ "x-api-key" = "your_secure_api_key_here" }
$body = '{"userId":"d290f1ee-6c54-4b01-90e6-d701748f0851","dailyLimitMinutes":120}'
Invoke-RestMethod -Uri "http://localhost:4000/v1/commitments" -Method Post -ContentType "application/json" -Body $body -Headers $headers

# Test device registration
$deviceBody = '{"userId":"d290f1ee-6c54-4b01-90e6-d701748f0851","deviceId":"demo-123","model":"Emulator","osVersion":"13"}'
Invoke-RestMethod -Uri "http://localhost:4000/v1/devices" -Method Post -ContentType "application/json" -Body $deviceBody -Headers $headers
```

### 4.5 Real-time Push (FCM) Setup (Phase 3)

To enable real push notifications:

1. **Backend:**
   - Go to Firebase Console → Project Settings → Service Accounts
   - Generate a new private key JSON
   - Minify the JSON and add it to your `.env` as `FIREBASE_SERVICE_ACCOUNT='{"type": "service_account", ...}'`
2. **Mobile:**
   - Download `google-services.json` from Firebase Console
   - Place it in `apps/mobile/android/app/`
   - Rebuild the app: `flutter run`

### 4.6 Admin Dashboard API (Phase 3)

Verify the system-wide stats for the dashboard:

```powershell
Invoke-RestMethod -Uri "http://localhost:4000/v1/admin/stats" -Headers $headers
```

---

## 5. Launch Android Emulator

Open a **third terminal**:

### 5.1 List available emulators

```powershell
flutter emulators
```

### 5.2 Launch an emulator

```powershell
flutter emulators --launch Pixel_10
```

Replace `Pixel_10` with your emulator name from step 5.1.

### 5.3 Verify device is visible

```powershell
flutter devices
```

If `adb` is not on PATH:

```powershell
& "$env:LOCALAPPDATA\Android\sdk\platform-tools\adb.exe" devices
```

---

## 6. Run the Flutter App (Primary Demo Path)

```powershell
cd C:\Users\siddh\Desktop\Hackathon\apps\mobile
flutter pub get
flutter run
```

This builds the app with both the Flutter UI and the native Kotlin enforcement engine.

**Flutter package name:** `com.minimalism.focus.flutter`

### What to expect

1. The app launches with the Dashboard screen
2. Native enforcement services start in the background
3. MethodChannel bridge connects Flutter UI to Kotlin engine
4. Usage data flows from `UsageStatsManager` → Flutter charts

---

## 7. First-Time App Setup

After the app launches, you need to grant permissions:

1. **Set daily screen time limit** (15–1440 minutes)
2. **Grant Usage Access** — Settings → Apps → Special Access → Usage Access
3. **Grant Accessibility Service** — Settings → Accessibility → Focus Enforcement
4. **Grant Display Over Other Apps** — for the blocking overlay
5. **Ignore Battery Optimization** — for reliable background enforcement

---

## 8. Demo Checklist

Use this sequence for the hackathon demo:

| Step | What to show | Where |
|---|---|---|
| 1 | Onboarding flow — set a low daily limit (e.g., 30 min) | Flutter UI |
| 2 | Dashboard — live screen time, goal progress, streak | Flutter UI |
| 3 | Social Tab — view buddies and active group challenges | Flutter UI |
| 4 | Open Instagram/YouTube — show the glassmorphic block overlay | Native overlay |
| 5 | Override friction — dynamic timer (20min if over limit) | Native overlay |
| 6 | Home Screen Widget — real-time focus stats at a glance | Android Home |
| 7 | Analytics — daily/weekly charts, app breakdown | Flutter UI |
| 8 | Rewards — points, badges, streak counter | Flutter UI |
| 9 | API health & Admin Stats — `GET /v1/admin/stats` | Terminal |
| 10 | Data Export — `GET /v1/export/:userId?format=csv` | Browser/Curl |
| 11 | Offline-first — enforcement works without internet | Verbal |

---

## 9. Run the Native Android App (Alternative)

If you need to test the standalone Kotlin-only version:

```powershell
cd C:\Users\siddh\Desktop\Hackathon\apps\android-native
$env:GRADLE_USER_HOME = "C:\Users\siddh\Desktop\Hackathon\.gradle-home"
.\gradlew.bat :app:assembleDebug --no-daemon --console=plain
& "$env:LOCALAPPDATA\Android\sdk\platform-tools\adb.exe" install -r app\build\outputs\apk\debug\app-debug.apk
& "$env:LOCALAPPDATA\Android\sdk\platform-tools\adb.exe" shell am start -n com.minimalism.focus/.MainActivity
```

APK output: `apps/android-native/app/build/outputs/apk/debug/app-debug.apk`

---

## 10. Build Verification Commands

These commands were verified on May 3, 2026:

### Backend

```powershell
cd C:\Users\siddh\Desktop\Hackathon\services\api
npm run build       # TypeScript compilation — should output zero errors
npm run test        # Unit tests — Pattern Engine, Policy Service, Validation Schemas
npm run migrate     # Database migrations — should apply or skip all 4
```

### Flutter App

```powershell
cd C:\Users\siddh\Desktop\Hackathon\apps\mobile
flutter pub get
flutter build apk --debug
```

### Native Android

```powershell
cd C:\Users\siddh\Desktop\Hackathon\apps\android-native
$env:GRADLE_USER_HOME = "C:\Users\siddh\Desktop\Hackathon\.gradle-home"
.\gradlew.bat :app:assembleDebug --no-daemon --console=plain
```

---

## 11. Troubleshooting

### A. `npm.ps1 cannot be loaded`

PowerShell execution policy blocks npm. Fix:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
npm run dev
```

### B. Database connection refused

PostgreSQL service isn't running:

```powershell
Start-Service postgresql-x64-18
```

### C. Migration fails with "relation already exists"

This is safe — the migration runner tracks versions. If it fails mid-migration, it rolls back automatically. Re-run `npm run migrate`.

### D. Emulator shows `offline`

```powershell
& "$env:LOCALAPPDATA\Android\sdk\platform-tools\adb.exe" kill-server
& "$env:LOCALAPPDATA\Android\sdk\platform-tools\adb.exe" start-server
flutter emulators --launch Pixel_10
```

### E. `adb` not recognized

Use the full path:

```powershell
& "$env:LOCALAPPDATA\Android\sdk\platform-tools\adb.exe" devices
```

### F. Gradle permission or cache issues

Always set the Gradle home to the workspace-local cache:

```powershell
$env:GRADLE_USER_HOME = "C:\Users\siddh\Desktop\Hackathon\.gradle-home"
```

### G. Flutter `DartDevelopmentServiceException`

Stale processes from a previous build. Fix:

```powershell
Stop-Process -Name "java" -Force -ErrorAction SilentlyContinue
Stop-Process -Name "dart" -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2
cd C:\Users\siddh\Desktop\Hackathon\apps\mobile
flutter clean
flutter pub get
flutter run
```

### H. `SecurityException` on app startup (exact alarm)

The `AndroidManifest.xml` requires `SCHEDULE_EXACT_ALARM` permission. If the app crashes on startup with this error, verify the permission is declared. The `EnforcementManager` now checks `canScheduleExactAlarms()` at runtime and falls back to inexact alarms if denied.

---

## 12. Deployment

### Backend API

1. Provision a production PostgreSQL database (Supabase, AWS RDS, Railway, etc.)
2. Host the Node.js API (Render, Railway, Heroku, or AWS)
3. Set environment variables:
   ```env
   PORT=4000
   NODE_ENV=production
   DATABASE_URL=postgres://user:pass@host:5432/reclaim_db
   CORS_ORIGINS=https://your-app-domain.com
   ```
4. Run migrations: `npm run migrate`
5. Start: `npm start` (or use the platform's process manager)

### Android App

1. Update `versionCode` and `versionName` in `build.gradle`
2. Generate a signed release bundle:
   ```powershell
   cd apps/mobile
   flutter build appbundle --release
   ```
3. Upload to Google Play Console

### CI/CD

GitHub Actions (`.github/workflows/ci.yml`) automatically runs on push/PR:
- **Backend job:** npm install → build → test
- **Android job:** Gradle assembleDebug
- **Flutter job:** flutter pub get → flutter build apk --debug

