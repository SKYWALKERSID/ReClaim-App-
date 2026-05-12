# ReClaim Platform Setup Script
# Version 1.1.1 (Automated Step-by-Step)

$ErrorActionPreference = "Stop"

function Write-Header($text) {
    Write-Host ""
    Write-Host "=== $text ===" -ForegroundColor Cyan
}

function Write-Success($text) {
    Write-Host "  [OK] $text" -ForegroundColor Green
}

function Write-Info($text) {
    Write-Host "  [INFO] $text" -ForegroundColor Gray
}

function Write-Warning-Custom($text) {
    Write-Host "  [WARN] $text" -ForegroundColor Yellow
}

Write-Header "ReClaim Platform Automation Setup"
Write-Host "This script will automate the steps from STEP_BY_STEP_RUN.md" -ForegroundColor Gray

# 1. Prerequisite Check
Write-Header "Step 1: Checking Prerequisites"

$tools = @{
    "Node.js" = "node --version"
    "Flutter" = "flutter --version"
    "PostgreSQL" = "psql --version"
}

foreach ($tool in $tools.Keys) {
    try {
        $version = Invoke-Expression $tools[$tool] | Out-String
        Write-Success "$tool is installed ($($version.Trim().Split("`n")[0]))"
    } catch {
        Write-Error "$tool is NOT installed or not in PATH. Please install it before continuing."
    }
}

# 2. PostgreSQL Service
Write-Header "Step 2: Database Service Management"

$pgService = Get-Service *postgres* -ErrorAction SilentlyContinue
if ($null -eq $pgService) {
    Write-Warning-Custom "PostgreSQL service not found. Make sure it is installed and the service name contains 'postgres'."
} else {
    if ($pgService.Status -ne "Running") {
        Write-Info "Starting PostgreSQL service ($($pgService.Name))..."
        try {
            Start-Service $pgService.Name
            Write-Success "PostgreSQL service started."
        } catch {
            Write-Warning-Custom "Could not start PostgreSQL service. Please run this script as Administrator."
        }
    } else {
        Write-Success "PostgreSQL service is already running."
    }
}

# 3. Database Creation
Write-Header "Step 3: Database Initialization"

$dbName = "reclaim_db"
Write-Info "Checking if database '$dbName' exists..."
$dbExists = psql -U postgres -h localhost -lqt | Select-String -Pattern "^\s*$dbName\s*|"

if (!$dbExists) {
    Write-Info "Creating database '$dbName'..."
    psql -U postgres -h localhost -c "CREATE DATABASE $dbName;"
    Write-Success "Database created."
} else {
    Write-Success "Database already exists."
}

# 4. Backend Configuration
Write-Header "Step 4: Backend API Configuration"

Set-Location "services/api"

Write-Info "Installing backend dependencies..."
npm install | Out-Null
Write-Success "Dependencies installed."

if (!(Test-Path .env)) {
    Write-Info "Creating .env from example..."
    Copy-Item .env.example .env
    Write-Warning-Custom ".env created. Please update it with your actual DB password if needed."
} else {
    Write-Success ".env already exists."
}

# Firebase Service Account Injection
Write-Info "Syncing Firebase Service Account..."
$sensitiveDir = "../../sensitive"
$jsonFile = Get-ChildItem -Path $sensitiveDir -Filter "*.json" | Where-Object { $_.Name -like "*firebase-adminsdk*" } | Select-Object -First 1

if ($null -ne $jsonFile) {
    $jsonContent = Get-Content -Raw $jsonFile.FullName | ConvertFrom-Json | ConvertTo-Json -Compress
    $envContent = Get-Content .env
    $newEnvContent = @()
    $found = $false

    foreach ($line in $envContent) {
        if ($line.StartsWith("FIREBASE_SERVICE_ACCOUNT=")) {
            $newEnvContent += "FIREBASE_SERVICE_ACCOUNT='$jsonContent'"
            $found = $true
        } else {
            $newEnvContent += $line
        }
    }

    if (!$found) {
        $newEnvContent += "FIREBASE_SERVICE_ACCOUNT='$jsonContent'"
    }

    $newEnvContent | Set-Content .env
    Write-Success "Firebase credentials injected into .env"
} else {
    Write-Warning-Custom "Firebase service account JSON not found in /sensitive directory."
}

# RS256 Key Generation
Write-Info "Checking for RS256 keys..."
if (!(Test-Path "private.pem") -or !(Test-Path "public.pem")) {
    node generateKeys.js
    Write-Success "RS256 keys generated."
} else {
    Write-Success "RS256 keys already exist."
}

# Run Migrations
Write-Info "Running database migrations..."
npm run migrate
Write-Success "Migrations complete."

Set-Location "../.."

# 5. Mobile App Configuration
Write-Header "Step 5: Mobile App Configuration"

Set-Location "apps/mobile"

Write-Info "Running flutter pub get..."
flutter pub get | Out-Null
Write-Success "Flutter dependencies ready."

Set-Location "../.."

Write-Header "Setup Complete!"
Write-Host "You are ready to run the ReClaim platform." -ForegroundColor Green
Write-Host "Next Steps:" -ForegroundColor Gray
Write-Host "1. Run the backend: cd services/api; npm run dev"
Write-Host "2. Run the mobile app: cd apps/mobile; flutter run"
Write-Host ""
Write-Host "Tip: Use 'npm start' from the root to launch everything automatically."
