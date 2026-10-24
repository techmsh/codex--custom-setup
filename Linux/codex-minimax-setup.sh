#!/bin/bash
set -euo pipefail

# ============================================
# Codex MiniMax Setup - Linux/macOS
# Version: 1.0.0
# License: MIT
# Copyright (c) 2026 msh (https://github.com/techmsh)
#
# Configures Codex to use MiniMax as the AI provider.
# Supports: MiniMax-M3.1, abab7.5-chat, abab7.5s-chat, abab6.5s-chat,
#           abab6.5-chat, abab6.5t-chat, abab6.5g-chat, abab5.5-chat
#
# Usage: ./codex-minimax-setup.sh
# ============================================

# Ensure UTF-8 encoding for Chinese / international character support
export LANG="${LANG:-en_US.UTF-8}"
export LC_ALL="${LC_ALL:-en_US.UTF-8}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------------------------------------------------------------- provider config

PROVIDER_ID="minimax"
PROVIDER_BASE_URL_VALUE="https://api.minimax.chat/v1"
PROVIDER_API_KEY_ENV_VAR="MINIMAX_API_KEY"
PROVIDER_API_KEY_ENV_VAR_ALT=""
PROVIDER_KEY_URL="https://api.minimax.chat/user-center/basic-information/interface-key"
PROVIDER_KEY_PREFIX=""
BACKUP_DIRNAME="backup-minimax"

# ---------------------------------------------------------------- model catalog

MODELS_LIST="MiniMax-M3.1 abab7.5-chat abab7.5s-chat abab6.5s-chat abab6.5-chat abab6.5t-chat abab6.5g-chat abab5.5-chat"

declare -A MODEL_DISPLAY=(
    [MiniMax-M3.1]="MiniMax-M3.1"
    [abab7.5-chat]="ABAB7.5-Chat"
    [abab7.5s-chat]="ABAB7.5s-Chat"
    [abab6.5s-chat]="ABAB6.5s-Chat"
    [abab6.5-chat]="ABAB6.5-Chat"
    [abab6.5t-chat]="ABAB6.5t-Chat"
    [abab6.5g-chat]="ABAB6.5g-Chat"
    [abab5.5-chat]="ABAB5.5-Chat"
)

declare -A MODEL_DESCRIPTION=(
    [MiniMax-M3.1]="MiniMax M3.1 model"
    [abab7.5-chat]="ABAB 7.5 chat model"
    [abab7.5s-chat]="ABAB 7.5s chat model"
    [abab6.5s-chat]="ABAB 6.5s chat model"
    [abab6.5-chat]="ABAB 6.5 chat model"
    [abab6.5t-chat]="ABAB 6.5T chat model"
    [abab6.5g-chat]="ABAB 6.5G chat model"
    [abab5.5-chat]="ABAB 5.5 chat model"
)

MODEL_SUPPORTS_IMAGE=""
MODEL_SUPPORTS_SEARCH=""

# ---------------------------------------------------------------- source common library and run

source "$SCRIPT_DIR/lib/common.sh"

main "$@"
