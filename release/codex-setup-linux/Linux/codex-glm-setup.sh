#!/bin/bash
set -euo pipefail

# ============================================
# Codex GLM Setup - Linux/macOS
# Version: 1.0.0
# License: MIT
# Copyright (c) 2026 msh (https://github.com/techmsh)
#
# Configures Codex to use GLM (智谱 AI) as the AI provider.
# Supports: glm-5.3, glm-5.3-flash, glm-5.3-turbo, glm-5.2, glm-5.1,
#           glm-4.6, glm-4.6v, glm-4.5, glm-4.5v, glm-4.5-air,
#           glm-4.5-flash, glm-4v-plus
#
# Usage: ./codex-glm-setup.sh
# ============================================

# Ensure UTF-8 encoding for Chinese / international character support
export LANG="${LANG:-en_US.UTF-8}"
export LC_ALL="${LC_ALL:-en_US.UTF-8}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------------------------------------------------------------- provider config

PROVIDER_ID="glm"
PROVIDER_BASE_URL_VALUE="https://open.bigmodel.cn/api/paas/v4"
PROVIDER_API_KEY_ENV_VAR="GLM_API_KEY"
PROVIDER_API_KEY_ENV_VAR_ALT="ZHIPU_API_KEY"
PROVIDER_KEY_URL="https://open.bigmodel.cn/usercenter/apikeys"
PROVIDER_KEY_PREFIX=""
BACKUP_DIRNAME="backup-glm"

# ---------------------------------------------------------------- model catalog

MODELS_LIST="glm-5.3 glm-5.3-flash glm-5.3-turbo glm-5.2 glm-5.1 glm-4.6 glm-4.6v glm-4.5 glm-4.5v glm-4.5-air glm-4.5-flash glm-4v-plus"

declare -A MODEL_DISPLAY=(
    [glm-5.3]="GLM-5.3"
    [glm-5.3-flash]="GLM-5.3-Flash"
    [glm-5.3-turbo]="GLM-5.3-Turbo"
    [glm-5.2]="GLM-5.2"
    [glm-5.1]="GLM-5.1"
    [glm-4.6]="GLM-4.6"
    [glm-4.6v]="GLM-4.6V"
    [glm-4.5]="GLM-4.5"
    [glm-4.5v]="GLM-4.5V"
    [glm-4.5-air]="GLM-4.5-Air"
    [glm-4.5-flash]="GLM-4.5-Flash"
    [glm-4v-plus]="GLM-4V-Plus"
)

declare -A MODEL_DESCRIPTION=(
    [glm-5.3]="GLM 5.3 flagship model"
    [glm-5.3-flash]="GLM 5.3 flash fast model"
    [glm-5.3-turbo]="GLM 5.3 turbo model"
    [glm-5.2]="GLM 5.2 model"
    [glm-5.1]="GLM 5.1 model"
    [glm-4.6]="GLM 4.6 model"
    [glm-4.6v]="GLM 4.6V vision model"
    [glm-4.5]="GLM 4.5 model"
    [glm-4.5v]="GLM 4.5V vision model"
    [glm-4.5-air]="GLM 4.5 Air lightweight model"
    [glm-4.5-flash]="GLM 4.5 Flash free model"
    [glm-4v-plus]="GLM 4V Plus vision model"
)

MODEL_SUPPORTS_IMAGE=""
MODEL_SUPPORTS_SEARCH=""

# ---------------------------------------------------------------- source common library and run

source "$SCRIPT_DIR/lib/common.sh"

main "$@"
