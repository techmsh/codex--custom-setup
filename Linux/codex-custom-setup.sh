#!/bin/bash
set -euo pipefail

# ============================================
# Codex Custom Provider Setup - Linux/macOS
# Version: 1.0.0
# License: MIT
# Copyright (c) 2026 msh (https://github.com/techmsh)
#
# Configures Codex to use a custom AI provider.
# Prompts for provider ID, base URL, API key, and model slug.
#
# Usage: ./codex-custom-setup.sh
# ============================================

# Ensure UTF-8 encoding for Chinese / international character support
export LANG="${LANG:-en_US.UTF-8}"
export LC_ALL="${LC_ALL:-en_US.UTF-8}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------------------------------------------------------------- provider config (will be set interactively)

PROVIDER_ID=""
PROVIDER_BASE_URL_VALUE=""
PROVIDER_API_KEY_ENV_VAR=""
PROVIDER_API_KEY_ENV_VAR_ALT=""
PROVIDER_KEY_URL=""
PROVIDER_KEY_PREFIX=""
BACKUP_DIRNAME=""

# ---------------------------------------------------------------- minimal model catalog (will be set interactively)

MODELS_LIST=""
declare -A MODEL_DISPLAY=()
declare -A MODEL_DESCRIPTION=()
MODEL_SUPPORTS_IMAGE=""
MODEL_SUPPORTS_SEARCH=""

# ---------------------------------------------------------------- source common library

source "$SCRIPT_DIR/lib/common.sh"

# ---------------------------------------------------------------- custom provider handler

handle_custom_provider() {
    echo ''
    echo "--- 自定义 Provider 配置 ---"
    read -rp "请输入 Provider ID（如 myprovider）: " PROVIDER_ID
    if [[ -z "$PROVIDER_ID" ]]; then
        die "Provider ID 不能为空，已退出。"
    fi
    read -rp "请输入 Base URL（如 https://api.example.com/v1）: " PROVIDER_BASE_URL_VALUE
    if [[ -z "$PROVIDER_BASE_URL_VALUE" ]]; then
        die "Base URL 不能为空，已退出。"
    fi
    read -rp "请输入 API Key（或设置环境变量后留空）: " API_KEY

    # Derive backup dirname from provider id
    BACKUP_DIRNAME="backup-${PROVIDER_ID}"

    # Show model selection for custom
    echo ''
    echo "自定义 Provider - 选择模型："
    echo "  1. 使用单一模型 slug"
    echo "  2. 跳过（仅配置 provider，不生成 models.json）"
    echo ''
    local mchoice=""
    read -rp "输入 1 或 2: " mchoice
    case "$mchoice" in
        1)
            read -rp "请输入模型 slug: " MODEL_SLUG
            if [[ -z "$MODEL_SLUG" ]]; then
                die "模型 slug 不能为空，已退出。"
            fi
            # Create a single-model list
            MODELS_LIST="$MODEL_SLUG"
            MODEL_DISPLAY["$MODEL_SLUG"]="$MODEL_SLUG"
            MODEL_DESCRIPTION["$MODEL_SLUG"]="Custom model $MODEL_SLUG"
            ;;
        2)
            MODEL_SLUG="custom"
            write_warn "将仅配置 config.toml，不生成 models.json"
            ;;
        *)
            die "无效选择，已退出。" ;;
    esac
}

# ---------------------------------------------------------------- main

main() {
    check_dependencies

    write_head "Codex Custom Provider Setup  v${SCRIPT_VERSION}"
    write_dim "Codex 目录: $CODEX_HOME"

    preflight_check

    handle_custom_provider

    set_paths

    if [[ -n "$MODELS_LIST" ]]; then
        # Full install with models.json
        # Determine if install or switch
        if [[ -d "$BACKUP_DIR" ]]; then
            local problems=()
            if [[ ! -f "$MODELS_PATH" ]]; then
                problems+=("  • 缺少 $MODELS_PATH")
            fi
            if [[ ! -f "$CONFIG_PATH" ]]; then
                problems+=("  • 缺少 $CONFIG_PATH")
            fi

            if [[ ${#problems[@]} -gt 0 ]]; then
                die "检测到备份目录 $BACKUP_DIR 已存在，\n但当前配置与本脚本的预期不符：\n${problems[*]}\n\n为避免破坏现有文件或那份备份，本次已中止，未修改任何文件。"
            fi

            do_switch_model
            exit 0
        fi

        if [[ -f "$MODELS_PATH" ]]; then
            die "检测到已存在：\n  $MODELS_PATH\n\n该文件不是本脚本写入的（没有找到本脚本的备份目录 $BACKUP_DIR）。\n本脚本需要创建这个文件。请先自行删除（或另存）该文件，然后重新运行：\n  rm -f '$MODELS_PATH'\n  $0"
        fi

        do_install
    else
        # Just configure TOML without models.json
        do_backup
        local tmp_config="${CONFIG_PATH}.${PROVIDER_ID}-tmp"
        process_toml_install "$CONFIG_PATH" "$tmp_config"
        mv -f "$tmp_config" "$CONFIG_PATH"
        write_ok "config.toml 已更新（自定义 Provider，无 models.json）"
        echo ''
        write_warn "请完全退出 ChatGPT 桌面端后重新打开，配置才会生效"
    fi
}

main "$@"
