#!/bin/bash
set -euo pipefail

# ============================================
# Codex Kimi Setup - Linux/macOS
# Version: 1.0.0
# License: MIT
# Copyright (c) 2026 msh (https://github.com/techmsh)
#
# Configures Codex to use Kimi (月之暗面) as the AI provider.
# Supports: kimi-k3.1-pro, kimi-k3.1-pro-highspeed, kimi-k2.5-pro,
#           kimi-k2.5-pro-highspeed, kimi-k2.5, kimi-k2.5-flash,
#           kimi-latest, kimi-2.6
#
# Usage: ./codex-kimi-setup.sh
# ============================================

# Ensure UTF-8 encoding for Chinese / international character support
export LANG="${LANG:-en_US.UTF-8}"
export LC_ALL="${LC_ALL:-en_US.UTF-8}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------------------------------------------------------------- provider config

PROVIDER_ID="kimi"
PROVIDER_BASE_URL_VALUE="https://api.moonshot.cn/v1"
PROVIDER_API_KEY_ENV_VAR="MOONSHOT_API_KEY"
PROVIDER_API_KEY_ENV_VAR_ALT=""
PROVIDER_KEY_URL="https://platform.moonshot.cn/console/api-keys"
PROVIDER_KEY_PREFIX=""
BACKUP_DIRNAME="backup-kimi"

# ---------------------------------------------------------------- model catalog

MODELS_LIST="kimi-k3.1-pro kimi-k3.1-pro-highspeed kimi-k2.5-pro kimi-k2.5-pro-highspeed kimi-k2.5 kimi-k2.5-flash kimi-latest kimi-2.6"

declare -A MODEL_DISPLAY=(
    [kimi-k3.1-pro]="Kimi-K3.1-Pro"
    [kimi-k3.1-pro-highspeed]="Kimi-K3.1-Pro-Highspeed"
    [kimi-k2.5-pro]="Kimi-K2.5-Pro"
    [kimi-k2.5-pro-highspeed]="Kimi-K2.5-Pro-Highspeed"
    [kimi-k2.5]="Kimi-K2.5"
    [kimi-k2.5-flash]="Kimi-K2.5-Flash"
    [kimi-latest]="Kimi-Latest"
    [kimi-2.6]="Kimi-2.6"
)

declare -A MODEL_DESCRIPTION=(
    [kimi-k3.1-pro]="Kimi K3.1 Pro model"
    [kimi-k3.1-pro-highspeed]="Kimi K3.1 Pro high-speed model"
    [kimi-k2.5-pro]="Kimi K2.5 Pro model"
    [kimi-k2.5-pro-highspeed]="Kimi K2.5 Pro high-speed model"
    [kimi-k2.5]="Kimi K2.5 base model"
    [kimi-k2.5-flash]="Kimi K2.5 Flash model"
    [kimi-latest]="Kimi latest model"
    [kimi-2.6]="Kimi 2.6 model"
)

MODEL_SUPPORTS_IMAGE=""
MODEL_SUPPORTS_SEARCH=""

# ---------------------------------------------------------------- source common library and run

source "$SCRIPT_DIR/lib/common.sh"

main "$@"
