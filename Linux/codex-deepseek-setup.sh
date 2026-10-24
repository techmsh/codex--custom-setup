#!/bin/bash
set -euo pipefail

# ============================================
# Codex DeepSeek Setup - Linux/macOS
# Version: 1.0.0
# License: MIT
# Copyright (c) 2026 msh (https://github.com/techmsh)
#
# Configures Codex to use DeepSeek as the AI provider.
# Supports: deepseek-chat, deepseek-reasoner, deepseek-coder, deepseek-v3,
#           deepseek-r1, deepseek-flash, deepseek-v4-pro
#
# Usage: ./codex-deepseek-setup.sh
# ============================================

# Ensure UTF-8 encoding for Chinese / international character support
export LANG="${LANG:-en_US.UTF-8}"
export LC_ALL="${LC_ALL:-en_US.UTF-8}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------------------------------------------------------------- provider config

PROVIDER_ID="deepseek"
PROVIDER_BASE_URL_VALUE="https://api.deepseek.com/"
PROVIDER_API_KEY_ENV_VAR="DEEPSEEK_API_KEY"
PROVIDER_API_KEY_ENV_VAR_ALT=""
PROVIDER_KEY_URL="https://platform.deepseek.com/api_keys"
PROVIDER_KEY_PREFIX="sk-"
BACKUP_DIRNAME="backup-deepseek"

# ---------------------------------------------------------------- model catalog

MODELS_LIST="deepseek-chat deepseek-reasoner deepseek-coder deepseek-v3 deepseek-r1 deepseek-flash deepseek-v4-pro"

declare -A MODEL_DISPLAY=(
    [deepseek-chat]="DeepSeek-Chat"
    [deepseek-reasoner]="DeepSeek-Reasoner"
    [deepseek-coder]="DeepSeek-Coder"
    [deepseek-v3]="DeepSeek-V3"
    [deepseek-r1]="DeepSeek-R1"
    [deepseek-flash]="DeepSeek-Flash"
    [deepseek-v4-pro]="DeepSeek-V4-Pro"
)

declare -A MODEL_DESCRIPTION=(
    [deepseek-chat]="General-purpose chat model"
    [deepseek-reasoner]="Advanced reasoning model"
    [deepseek-coder]="Code-specialized model"
    [deepseek-v3]="Latest V3 model"
    [deepseek-r1]="Reasoning-optimized R1 model"
    [deepseek-flash]="Fast frontier agentic coding model"
    [deepseek-v4-pro]="Most capable frontier agentic coding model"
)

MODEL_SUPPORTS_IMAGE="deepseek-flash"
MODEL_SUPPORTS_SEARCH="deepseek-chat deepseek-reasoner deepseek-coder deepseek-v3 deepseek-r1 deepseek-flash deepseek-v4-pro"

# ---------------------------------------------------------------- source common library and run

source "$SCRIPT_DIR/lib/common.sh"

main "$@"
