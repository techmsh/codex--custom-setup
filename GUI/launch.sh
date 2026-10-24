#!/bin/bash
# One-click launch script for Linux/macOS
# 一键启动 Codex Setup GUI

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GUI_BIN="${SCRIPT_DIR}/codex-setup-gui"

# Check if binary exists
if [[ ! -f "$GUI_BIN" ]]; then
    echo "正在构建 Codex Setup GUI..."
    cd "$SCRIPT_DIR"
    cargo build --release 2>&1
    echo ""
fi

# Launch GUI
exec "$GUI_BIN"
