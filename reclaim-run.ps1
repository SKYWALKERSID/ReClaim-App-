# ReClaim Platform Run Script
# Version 1.0.1

$ErrorActionPreference = "Continue"

Write-Host ""
Write-Host "Launching ReClaim Platform..." -ForegroundColor Cyan

# 1. Start Backend API in a new window
Write-Host "  Cleaning up port 4000..." -ForegroundColor Gray
$portProcess = Get-NetTCPConnection -LocalPort 4000 -ErrorAction SilentlyContinue | Select-Object -ExpandProperty OwningProcess -First 1
if ($portProcess) {
    Stop-Process -Id $portProcess -Force -ErrorAction SilentlyContinue
    Write-Host "  Killed existing process on port 4000." -ForegroundColor Gray
}

Write-Host "  Starting Backend API..." -ForegroundColor Gray
Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd services/api; npm run dev"

# 2. Check for Android Device/Emulator
Write-Host "  Checking for Android devices..." -ForegroundColor Gray
$devices = flutter devices | Select-String "android"

if ($null -eq $devices) {
    Write-Host "  No Android device found. Attempting to launch emulator..." -ForegroundColor Yellow
    $emulator = flutter emulators | Select-String "android" | Select-Object -First 1
    if ($null -ne $emulator) {
        $emuId = $emulator.ToString().Split(" ")[0].Trim()
        Write-Host "  Launching emulator: $emuId" -ForegroundColor Gray
        Start-Process flutter -ArgumentList "emulators", "--launch", $emuId
        Write-Host "  Waiting for emulator to boot..." -ForegroundColor Gray
        Start-Sleep -Seconds 15
    } else {
        Write-Host "  [WARN] No emulators found. Please start an emulator or connect a device manually." -ForegroundColor Red
        exit
    }
}

# 3. Run Flutter App
Write-Host "  Setting up port forwarding (adb reverse)..." -ForegroundColor Gray
$adbCmd = "adb"
if (!(Get-Command adb -ErrorAction SilentlyContinue)) {
    $possibleAdb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
    if (Test-Path $possibleAdb) {
        $adbCmd = $possibleAdb
    }
}

try {
    & $adbCmd reverse tcp:4000 tcp:4000
} catch {
    Write-Host "  [WARN] Could not run adb reverse. Please ensure Android SDK Platform-Tools are installed." -ForegroundColor Yellow
}

Write-Host "  Launching Flutter App..." -ForegroundColor Green
Set-Location "apps/mobile"
flutter run
