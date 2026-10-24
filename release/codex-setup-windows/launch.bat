@echo off
REM One-click launch script for Windows
REM 一键启动 Codex Setup GUI

setlocal

set "SCRIPT_DIR=%~dp0"
set "GUI_BIN=%SCRIPT_DIR%codex-setup-gui.exe"

REM Check if binary exists
if not exist "%GUI_BIN%" (
    echo Building Codex Setup GUI...
    cd /d "%SCRIPT_DIR%"
    cargo build --release
    echo.
)

REM Launch GUI (no console window)
start "" "%GUI_BIN%"

endlocal
