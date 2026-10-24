@echo off
REM ============================================================
REM  Codex Setup GUI - One-Click Build and Launch (Windows)
REM  一键构建并启动 GUI 程序
REM ============================================================

setlocal EnableDelayedExpansion

echo ============================================================
echo   Codex Setup GUI - One-Click Build ^& Launch
echo ============================================================
echo.

REM --- Check if Rust is installed ---
where rustc >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [INFO] Rust not found. Installing Rust...
    echo.

    REM Download and install rustup
    echo [1/3] Downloading Rust installer...
    powershell -Command "Invoke-WebRequest -Uri 'https://win.rustup.rs/x86_64' -OutFile '%TEMP%\rustup-init.exe' -UseBasicParsing"

    echo [2/3] Running Rust installer (this may take a few minutes)...
    %TEMP%\rustup-init.exe -y --default-host x86_64-pc-windows-msvc --default-toolchain stable

    REM Refresh environment
    call refreshenv.cmd 2>nul
    set "PATH=%PATH%;%USERPROFILE%\.cargo\bin"

    echo [3/3] Verifying Rust installation...
    rustc --version
    cargo --version
    echo.
) else (
    echo [OK] Rust is already installed:
    rustc --version
    cargo --version
    echo.
)

REM --- Build GUI ---
echo [BUILD] Building Codex Setup GUI (release mode)...
echo.
cd /d "%~dp0GUI"
cargo build --release 2>&1

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ERROR] Build failed! Please check the error messages above.
    pause
    exit /b 1
)

echo.
echo [OK] Build successful!

REM --- Launch GUI ---
echo.
echo [LAUNCH] Starting Codex Setup GUI...
echo.
start "" "%~dp0GUI\target\release\codex-setup-gui.exe"

echo [OK] GUI launched. You can close this window.
timeout /t 3 /nobreak >nul
