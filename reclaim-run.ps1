# ReClaim Platform Run Script
# Version 1.1.0 - Production Readiness Pass

$ErrorActionPreference = "Continue"

Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "   ReClaim: AI-Powered Productivity Engine     " -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host ""

# 1. Environment Validation
Write-Host "[1/4] Validating environment..." -ForegroundColor Yellow

if (!(Test-Path "services/api/.env")) {
    Write-Host "  [ERR] services/api/.env file missing!" -ForegroundColor Red
    Write-Host "  Please create one with DATABASE_URL and ANTHROPIC_API_KEY." -ForegroundColor White
    exit
}

if (!(Test-Path "services/api/node_modules")) {
    Write-Host "  [INFO] node_modules missing in API. Running npm install..." -ForegroundColor Gray
    Set-Location "services/api"
    npm install
    Set-Location "../.."
}

# 2. Start Backend API
Write-Host "[2/4] Launching Backend API..." -ForegroundColor Yellow
Write-Host "  Cleaning up port 4000..." -ForegroundColor Gray
$portProcess = Get-NetTCPConnection -LocalPort 4000 -ErrorAction SilentlyContinue | Select-Object -ExpandProperty OwningProcess -First 1
if ($portProcess) {
    Stop-Process -Id $portProcess -Force -ErrorAction SilentlyContinue
    Write-Host "  Killed existing process on port 4000." -ForegroundColor Gray
}

Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd services/api; npm run dev"
Write-Host "  API Service started in background window." -ForegroundColor Gray

# 3. Android Device Setup
Write-Host "[3/4] Checking for Android devices..." -ForegroundColor Yellow
$devices = flutter devices | Select-String "android"

if ($null -eq $devices) {
    Write-Host "  No Android device found. Attempting to launch emulator..." -ForegroundColor Gray
    $emulator = flutter emulators | Select-String "android" | Select-Object -First 1
    if ($null -ne $emulator) {
        $emuId = $emulator.ToString().Split(" ")[0].Trim()
        Write-Host "  Launching emulator: $emuId" -ForegroundColor Gray
        Start-Process flutter -ArgumentList "emulators", "--launch", $emuId
        Write-Host "  Waiting for emulator to boot (15s)..." -ForegroundColor Gray
        Start-Sleep -Seconds 15
    } else {
        Write-Host "  [WARN] No emulators found. Connect a device manually." -ForegroundColor Red
    }
}

# Setup port forwarding
Write-Host "  Setting up adb reverse (port 4000)..." -ForegroundColor Gray
$adbCmd = "adb"
if (!(Get-Command adb -ErrorAction SilentlyContinue)) {
    $possibleAdb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
    if (Test-Path $possibleAdb) { $adbCmd = $possibleAdb }
}
try { & $adbCmd reverse tcp:4000 tcp:4000 } catch { }

# 4. Launch Flutter App
Write-Host "[4/4] Launching Flutter App..." -ForegroundColor Green
Set-Location "apps/mobile"
flutter run --debug

Write-Host ""
Write-Host "System active. Logs are visible in the API window and this terminal." -ForegroundColor Cyan
