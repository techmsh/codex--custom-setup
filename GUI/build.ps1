# ============================================================
#  Codex Setup GUI - One-Click Build and Launch (Windows)
#  PowerShell version for proper Unicode support
# ============================================================

$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  Codex Setup GUI - One-Click Build & Launch" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# --- Check if Rust is installed ---
$rustc = Get-Command rustc -ErrorAction SilentlyContinue
if (-not $rustc) {
    Write-Host "[INFO] Rust not found. Installing Rust..." -ForegroundColor Yellow
    Write-Host ""

    # Download rustup
    Write-Host "[1/3] Downloading Rust installer..." -ForegroundColor White
    $rustupUrl = "https://win.rustup.rs/x86_64"
    $rustupPath = "$env:TEMP\rustup-init.exe"
    Invoke-WebRequest -Uri $rustupUrl -OutFile $rustupPath -UseBasicParsing

    # Run installer
    Write-Host "[2/3] Running Rust installer (this may take a few minutes)..." -ForegroundColor White
    & $rustupPath -y --default-host x86_64-pc-windows-msvc --default-toolchain stable

    # Refresh PATH
    $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "User") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "Machine")

    Write-Host "[3/3] Verifying Rust installation..." -ForegroundColor White
    rustc --version
    cargo --version
    Write-Host ""
}
else {
    Write-Host "[OK] Rust is already installed:" -ForegroundColor Green
    rustc --version
    cargo --version
    Write-Host ""
}

# --- Build GUI ---
Write-Host "[BUILD] Building Codex Setup GUI (release mode)..." -ForegroundColor White
Write-Host ""
Set-Location $SCRIPT_DIR
cargo build --release 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "[ERROR] Build failed! Please check the error messages above." -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host ""
Write-Host "[OK] Build successful!" -ForegroundColor Green

# --- Launch GUI ---
Write-Host ""
Write-Host "[LAUNCH] Starting Codex Setup GUI..." -ForegroundColor White
Write-Host ""
Start-Process -FilePath "$SCRIPT_DIR\target\release\codex-setup-gui.exe"
Write-Host "[OK] GUI launched. You can close this window." -ForegroundColor Green
Start-Sleep -Seconds 3
