#!/bin/bash
# ============================================================
#  Codex Setup GUI - One-Click Build and Launch (Linux/macOS)
#  一键构建并启动 GUI 程序
# ============================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "============================================================"
echo "  Codex Setup GUI - One-Click Build & Launch"
echo "============================================================"
echo ""

# --- Check if Rust is installed ---
if ! command -v rustc &>/dev/null; then
    echo -e "${YELLOW}[INFO] Rust not found. Installing Rust...${NC}"
    echo ""

    # Install rustup
    echo "[1/3] Downloading Rust installer..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs -o /tmp/rustup-init.sh

    echo "[2/3] Running Rust installer (this may take a few minutes)..."
    sh /tmp/rustup-init.sh -y --default-toolchain stable --profile minimal

    # Source cargo environment
    source "$HOME/.cargo/env"

    echo "[3/3] Verifying Rust installation..."
    rustc --version
    cargo --version
    echo ""
else
    echo -e "${GREEN}[OK] Rust is already installed:${NC}"
    rustc --version
    cargo --version
    echo ""
fi

# --- Install system dependencies (Linux only) ---
if [[ "$(uname)" == "Linux" ]]; then
    echo "[DEPS] Checking system dependencies..."
    MISSING_DEPS=""

    # Check for required libraries
    if ! ldconfig -p 2>/dev/null | grep -q libegl; then
        MISSING_DEPS="$MISSING_DEPS libegl1-mesa-dev"
    fi
    if ! ldconfig -p 2>/dev/null | grep -q libgl; then
        MISSING_DEPS="$MISSING_DEPS libgl1-mesa-dev"
    fi
    if ! ldconfig -p 2>/dev/null | grep -q libX11; then
        MISSING_DEPS="$MISSING_DEPS libx11-dev"
    fi
    if ! ldconfig -p 2>/dev/null | grep -q libXi; then
        MISSING_DEPS="$MISSING_DEPS libxi-dev"
    fi

    if [[ -n "$MISSING_DEPS" ]]; then
        echo -e "${YELLOW}[INFO] Missing system libraries:$MISSING_DEPS${NC}"
        echo "[INFO] Installing system dependencies..."

        if command -v apt-get &>/dev/null; then
            sudo apt-get update -qq
            sudo apt-get install -y -qq $MISSING_DEPS pkg-config
        elif command -v yum &>/dev/null; then
            sudo yum install -y $MISSING_DEPS pkg-config
        elif command -v dnf &>/dev/null; then
            sudo dnf install -y $MISSING_DEPS pkg-config
        elif command -v pacman &>/dev/null; then
            sudo pacman -S --noconfirm mesa libx11 libxi pkg-config
        elif command -v apk &>/dev/null; then
            sudo apk add mesa-dev libx11-dev libxi-dev pkgconfig
        else
            echo -e "${RED}[WARN] Could not detect package manager. Please install manually:${NC}"
            echo "  $MISSING_DEPS pkg-config"
        fi
    else
        echo -e "${GREEN}[OK] All system dependencies satisfied.${NC}"
    fi
    echo ""
fi

# --- Build GUI ---
echo "[BUILD] Building Codex Setup GUI (release mode)..."
echo ""
cd "$SCRIPT_DIR"
cargo build --release 2>&1

if [[ $? -ne 0 ]]; then
    echo ""
    echo -e "${RED}[ERROR] Build failed! Please check the error messages above.${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}[OK] Build successful!${NC}"

# --- Launch GUI ---
echo ""
echo "[LAUNCH] Starting Codex Setup GUI..."
echo ""
"$SCRIPT_DIR/target/release/codex-setup-gui" &
echo -e "${GREEN}[OK] GUI launched. You can close this terminal.${NC}"
