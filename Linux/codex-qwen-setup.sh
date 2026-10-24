#!/bin/bash
set -euo pipefail

# ============================================
# Codex Qwen Setup - Linux/macOS
# Version: 1.0.0
# License: MIT
# Copyright (c) 2026 msh (https://github.com/techmsh)
#
# Configures Codex to use Qwen (通义千问) as the AI provider.
# Supports: qwen-max, qwen-max-longcontext, qwen-plus, qwen-turbo,
#           qwen-vl-max, qwen-vl-plus, qwen2.5-72b-instruct,
#           qwen2.5-32b-instruct, qwen2.5-14b-instruct, qwen2.5-7b-instruct,
#           qwen2.5-3b-instruct, qwen2.5-1.5b-instruct, qwen2.5-0.5b-instruct,
#           qwen2.5-coder-32b-instruct, qwen2.5-coder-14b-instruct,
#           qwen2.5-coder-7b-instruct
#
# Usage: ./codex-qwen-setup.sh
# ============================================

# Ensure UTF-8 encoding for Chinese / international character support
export LANG="${LANG:-en_US.UTF-8}"
export LC_ALL="${LC_ALL:-en_US.UTF-8}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------------------------------------------------------------- provider config

PROVIDER_ID="qwen"
PROVIDER_BASE_URL_VALUE="https://dashscope.aliyuncs.com/compatible-mode/v1"
PROVIDER_API_KEY_ENV_VAR="DASHSCOPE_API_KEY"
PROVIDER_API_KEY_ENV_VAR_ALT=""
PROVIDER_KEY_URL="https://dashscope.console.aliyun.com/apiKey"
PROVIDER_KEY_PREFIX=""
BACKUP_DIRNAME="backup-qwen"

# ---------------------------------------------------------------- model catalog

MODELS_LIST="qwen-max qwen-max-longcontext qwen-plus qwen-turbo qwen-vl-max qwen-vl-plus qwen2.5-72b-instruct qwen2.5-32b-instruct qwen2.5-14b-instruct qwen2.5-7b-instruct qwen2.5-3b-instruct qwen2.5-1.5b-instruct qwen2.5-0.5b-instruct qwen2.5-coder-32b-instruct qwen2.5-coder-14b-instruct qwen2.5-coder-7b-instruct"

declare -A MODEL_DISPLAY=(
    [qwen-max]="Qwen-Max"
    [qwen-max-longcontext]="Qwen-Max-LongContext"
    [qwen-plus]="Qwen-Plus"
    [qwen-turbo]="Qwen-Turbo"
    [qwen-vl-max]="Qwen-VL-Max"
    [qwen-vl-plus]="Qwen-VL-Plus"
    [qwen2.5-72b-instruct]="Qwen2.5-72B-Instruct"
    [qwen2.5-32b-instruct]="Qwen2.5-32B-Instruct"
    [qwen2.5-14b-instruct]="Qwen2.5-14B-Instruct"
    [qwen2.5-7b-instruct]="Qwen2.5-7B-Instruct"
    [qwen2.5-3b-instruct]="Qwen2.5-3B-Instruct"
    [qwen2.5-1.5b-instruct]="Qwen2.5-1.5B-Instruct"
    [qwen2.5-0.5b-instruct]="Qwen2.5-0.5B-Instruct"
    [qwen2.5-coder-32b-instruct]="Qwen2.5-Coder-32B-Instruct"
    [qwen2.5-coder-14b-instruct]="Qwen2.5-Coder-14B-Instruct"
    [qwen2.5-coder-7b-instruct]="Qwen2.5-Coder-7B-Instruct"
)

declare -A MODEL_DESCRIPTION=(
    [qwen-max]="Qwen Max flagship model"
    [qwen-max-longcontext]="Qwen Max long context model"
    [qwen-plus]="Qwen Plus model"
    [qwen-turbo]="Qwen Turbo fast model"
    [qwen-vl-max]="Qwen VL Max vision model"
    [qwen-vl-plus]="Qwen VL Plus vision model"
    [qwen2.5-72b-instruct]="Qwen 2.5 72B instruct model"
    [qwen2.5-32b-instruct]="Qwen 2.5 32B instruct model"
    [qwen2.5-14b-instruct]="Qwen 2.5 14B instruct model"
    [qwen2.5-7b-instruct]="Qwen 2.5 7B instruct model"
    [qwen2.5-3b-instruct]="Qwen 2.5 3B instruct model"
    [qwen2.5-1.5b-instruct]="Qwen 2.5 1.5B instruct model"
    [qwen2.5-0.5b-instruct]="Qwen 2.5 0.5B instruct model"
    [qwen2.5-coder-32b-instruct]="Qwen 2.5 Coder 32B instruct model"
    [qwen2.5-coder-14b-instruct]="Qwen 2.5 Coder 14B instruct model"
    [qwen2.5-coder-7b-instruct]="Qwen 2.5 Coder 7B instruct model"
)

MODEL_SUPPORTS_IMAGE=""
MODEL_SUPPORTS_SEARCH=""

# ---------------------------------------------------------------- source common library and run

source "$SCRIPT_DIR/lib/common.sh"

main "$@"
