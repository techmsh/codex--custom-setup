#!/bin/bash
set -euo pipefail

# ============================================
# Codex LongCat Setup - Linux/macOS
# Version: 1.0.0
# License: MIT
# Copyright (c) 2026 msh (https://github.com/techmsh)
#
# Configures Codex to use LongCat (美团龙猫) as the AI provider.
# Supports: LongCat-2.0, LongCat-2.5-Preview, LongCat-Flash, LongCat-OmniFlash
#
# Usage: ./codex-longcat-setup.sh
# ============================================

# Ensure UTF-8 encoding for Chinese / international character support
export LANG="${LANG:-en_US.UTF-8}"
export LC_ALL="${LC_ALL:-en_US.UTF-8}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------------------------------------------------------------- provider config

PROVIDER_ID="longcat"
PROVIDER_BASE_URL_VALUE="https://api.longcat.chat/openai/v1/"
PROVIDER_API_KEY_ENV_VAR="LONGCAT_API_KEY"
PROVIDER_API_KEY_ENV_VAR_ALT=""
PROVIDER_KEY_URL="https://longcat.chat/platform/api_keys"
PROVIDER_KEY_PREFIX=""
BACKUP_DIRNAME="backup-longcat"

# ---------------------------------------------------------------- model catalog

MODELS_LIST="LongCat-2.0 LongCat-2.5-Preview LongCat-Flash LongCat-OmniFlash"

declare -A MODEL_DISPLAY=(
    [LongCat-2.0]="LongCat-2.0"
    [LongCat-2.5-Preview]="LongCat-2.5-Preview"
    [LongCat-Flash]="LongCat-Flash"
    [LongCat-OmniFlash]="LongCat-OmniFlash"
)

declare -A MODEL_DESCRIPTION=(
    [LongCat-2.0]="LongCat 2.0 base model"
    [LongCat-2.5-Preview]="LongCat 2.5 preview model"
    [LongCat-Flash]="LongCat Flash fast model"
    [LongCat-OmniFlash]="LongCat OmniFlash multimodal model"
)

MODEL_SUPPORTS_IMAGE=""
MODEL_SUPPORTS_SEARCH=""

# ---------------------------------------------------------------- source common library and run

source "$SCRIPT_DIR/lib/common.sh"

main "$@"
