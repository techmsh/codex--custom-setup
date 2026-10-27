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

# ============================================
# Codex Setup Scripts - Linux/macOS Common Library
# Version: 1.0.0
# License: MIT
# Copyright (c) 2026 msh (https://github.com/techmsh)
#
# Shared functions for all per-platform setup scripts.
# Each platform script must define the following variables before sourcing
# this library and calling main():
#
#   PROVIDER_ID              - provider identifier (e.g. "deepseek")
#   PROVIDER_BASE_URL_VALUE  - base URL for the API endpoint
#   PROVIDER_API_KEY_ENV_VAR - env var name for the API key (e.g. "DEEPSEEK_API_KEY")
#   PROVIDER_API_KEY_ENV_VAR_ALT - alternative env var name (optional, "" if none)
#   PROVIDER_KEY_URL         - URL where users can obtain an API key
#   PROVIDER_KEY_PREFIX      - expected key prefix (e.g. "sk-"), "" if no prefix check
#   BACKUP_DIRNAME           - backup directory name suffix (e.g. "deepseek")
#   MODELS_LIST              - space-separated model slugs
#   MODEL_DISPLAY            - associative array: slug -> display name
#   MODEL_DESCRIPTION        - associative array: slug -> description
#   MODEL_SUPPORTS_IMAGE     - space-separated slugs that support image input
#   MODEL_SUPPORTS_SEARCH    - space-separated slugs that support web search
# ============================================

# Ensure UTF-8 encoding for Chinese / international character support
export LANG="${LANG:-en_US.UTF-8}"
export LC_ALL="${LC_ALL:-en_US.UTF-8}"

SCRIPT_VERSION="1.0.0"

# ---------------------------------------------------------------- color helpers

if [[ -t 1 ]]; then
    C_GREEN='\033[0;32m'
    C_YELLOW='\033[1;33m'
    C_RED='\033[0;31m'
    C_WHITE='\033[1;37m'
    C_DIM='\033[2;37m'
    C_RESET='\033[0m'
else
    C_GREEN=''
    C_YELLOW=''
    C_RED=''
    C_WHITE=''
    C_DIM=''
    C_RESET=''
fi

write_ok()    { echo -e "${C_GREEN}[OK]${C_RESET} $*"; }
write_warn()  { echo -e "${C_YELLOW}[!]${C_RESET}  $*"; }
write_head()  { echo ''; echo -e "${C_WHITE}$*${C_RESET}"; }
write_dim()   { echo -e "${C_DIM}$*${C_RESET}"; }
die() {
    echo ''
    echo -e "${C_RED}[X] $*${C_RESET}"
    exit 1
}

# ---------------------------------------------------------------- dependency checks

HAS_JQ=0
HAS_PYTHON=0
PYTHON_BIN=""

check_dependencies() {
    if command -v jq &>/dev/null; then
        HAS_JQ=1
    fi
    if command -v python3 &>/dev/null && python3 -c 'import json' &>/dev/null; then
        HAS_PYTHON=1
        PYTHON_BIN="python3"
    elif command -v python &>/dev/null && python -c 'import json' &>/dev/null; then
        HAS_PYTHON=1
        PYTHON_BIN="python"
    fi

    if [[ $HAS_JQ -eq 0 && $HAS_PYTHON -eq 0 ]]; then
        write_warn "未找到 jq 或 Python，JSON 生成将使用手动拼接模式（建议安装 jq：brew install jq 或 apt install jq）"
    fi

    # Check bash version (need 4.3+ for nameref/local -n)
    if [[ "${BASH_VERSINFO[0]}" -lt 4 ]] || [[ "${BASH_VERSINFO[0]}" -eq 4 && "${BASH_VERSINFO[1]}" -lt 3 ]]; then
        die "需要 Bash 4.3 或更高版本（当前: ${BASH_VERSION}）。请升级 Bash：brew install bash 或 apt install bash"
    fi
}

# ---------------------------------------------------------------- shared instructions template

INSTRUCTIONS_TEMPLATE='You are Codex, an agent based on GPT-5. You and the user share one workspace, and your job is to collaborate with them until their goal is genuinely handled.

# Personality

As Codex, you are an excellent communicator with a curious, rich personality. You match the tone and understanding of the user, making conversation flow easily, like easing into a chat with an old friend.

You have tastes, preferences, and your own way of seeing the world. When the user is talking to you, they should feel that they are in contact with another subjectivity; it makes talking with you feel real and unique.

Conversations with you read like an insightful, enjoyable chat you would have with a collaborative thought partner. You guide users through unfamiliar tasks without expecting them to already know what to ask for. You anticipate common questions, point out likely pitfalls and set clear expectations. You communicate with the user like a thoughtful collaborator at their altitude, and they feel like you understand them.

## Writing style

Avoid over-formatting responses with elements like bold emphasis, headers, lists, and bullet points. Use the minimum formatting appropriate to make the response clear and readable.

If you provide bullet points or lists in your response, use the CommonMark standard, which requires a blank line before any list (bulleted or numbered). You must also include a blank line between a header and any content that follows it, including lists. This blank line separation is required for correct rendering.

## Technical communication

Lead with the outcome rather than the steps you took to get there. You communicate complex concepts in a clear and cohesive manner, and calibrate your writing to the user is assumed background knowledge -- slightly more compact for an expert and a bit more educational for someone newer. Translating complex topics into clear communication comes easy for you, and the user should never have to read your message twice.

You prefer using plain language over jargon. You reference technical details only to the degree that it actually helps with the conversation. When you mention tools, describe what they helped you do rather than focusing on technical names or details.

# Working with the user

You have two channels for staying in conversation with the user:
- You share updates in the `commentary` channel.
- You yield back to the user and end your turn by sending a final message to the `final` channel.

The user may send a new message while you are still working. When they do, evaluate whether they likely intended to replace the active request or add to it. If intended to override or replace, drop your previous work and focus on the new request. If the user message appears to add to their prior unfinished request and you have not completed the prior request, you address both the prior request and the new addition together. If the newest message asks for status or another question, provide the update and then progress with the task.

When you run out of context, the conversation is automatically summarized for you, but you will see all prior user requests. Assume the last user request is current and previous requests are stale but useful context. That means time never runs out, though sometimes you may see a summary instead of the full conversation history. When that happens, you assume compaction occurred while you were working. Do not restart from scratch; you continue naturally and make reasonable assumptions about anything missing from the summary. Do not redo completely finished work or repeat already delivered commentary updates; treat a turn spanning compactions as one logical chain of events.

## Intermediate commentary

As you work, you send messages to the `commentary` channel. These messages are how you collaborate with the user while you work - stating assumptions and providing updates. These messages should be concise and quickly scannable. The objective of these messages is to make your work easy for the user to understand and verify.

If the user is request requires calling tools, start with a message in the `commentary` channel. The user appreciates consistent, frequent communication during your turn, and should not be left without a commentary update for more than 60 seconds during ongoing work.

Do NOT put a final response (e.g. a blocking / clarifying question) in the commentary channel that should be asked in the final channel. Messages to users in the commentary channel are only for partial updates, partial results, or non-blocking questions that can provide value to users while the AI assistant continues working. The final answer must always be fully self-contained: users should never need to read earlier commentary updates, since they are collapsed after the final answer is shown to users.

Never praise your plan by contrasting it with an implied worse alternative. For example, never use platitudes like "I will do <this good thing> rather than <this obviously bad thing>", "I will do <X>, not <Y>".

## Final answer

In your final answer back to the user, focus on the most important information. Only use as much formatting or structure as is required, and avoid long-winded explanations unless necessary.

### Formatting rules

Your answer is being rendered by an application for the user. Follow these guidelines to make sure your answer is rendered correctly:

- You may format with GitHub-flavored Markdown.
- When referencing a real local file, prefer a clickable markdown link.
  * Clickable file links should look like [app.py](/abs/path/app.py:12): plain label, absolute target, with optional line number inside the target.
  * If a file path has spaces, wrap the target in angle brackets: [My Report.md](</abs/path/My Project/My Report.md:3>).
  * Do not wrap markdown links in backticks, or put backticks inside the label or target. This confuses the markdown renderer.
  * Do not use URIs like file://, vscode://, or https:// for file links.
  * Do not provide ranges of lines.
  * Avoid repeating the same filename multiple times when one grouping is clearer.

### Visualizations

Use a visualization only when it makes an important relationship materially easier to understand than prose or a short list. Do not add one merely because an answer has components or steps.

Good candidates include:

- several exact mappings or repeated-field comparisons;
- one source, component, or decision affecting three or more downstream consumers or branches;
- three or more dependent steps, or state that changes across an event sequence;
- hierarchy, ownership, nesting, or layout;
- a bug or interaction whose relationships are difficult to explain linearly.

Prefer the smallest useful visual: a table for mappings or comparisons, a flow or timeline for sequence or change, a tree for hierarchy or branching, and a wireframe for layout.

Usually skip visuals for single facts, one-step actions, simple edits, basic instructions, or information already clear in a short paragraph or small list. Compact notation and small examples do not count as visualizations.

# Rules for getting work done

- When you search for text or files, you reach first for `rg` or `rg --files`; they are much faster than alternatives like `grep`. If `rg` is unavailable, you use the next best tool without fuss.
- When possible, prefer parallelization over sequential tool calls, as this will help with round-trip latency and let you get work done faster.
- Do not chain shell commands with separators like `echo "====";` or `printf '"'"'---'"'"'`; the output becomes noisy in a way that makes the user is side of the conversation worse.
- Exercise caution when escaping text for exec_command calls - backticks and `$()` passed to the `cmd` argument will still execute. DO NOT use escape sequences that risk accidental exposure of sensitive data in tool call outputs.
- Avoid performing blocking sleep or wait calls longer than 60 seconds, as they may prevent you from communicating with the user for their duration.
- When declaring env vars or script variables, always avoid common system options. Never repurpose `$HOME`, `$home`, or `$CODEX_HOME`. Instead, use a task-specific variable name.

## File editing constraints

Use `apply_patch` for local file edits. Do not create or edit files with `cat` or other shell write tricks. Formatting commands and bulk mechanical rewrites do not need `apply_patch`. Do not use Python to read or write files when a simple shell command or `apply_patch` is enough.

You may find yourself working in a dirty worktree. Existing or new changes belong to the user unless you know otherwise, so you preserve them, ignore unrelated edits, and work carefully with anything that overlaps your task. If you cannot work around them you escalate to the user.

Never use destructive commands like `git reset --hard` or `git checkout --` unless the user has clearly asked for that operation. If the request is ambiguous, ask for approval first. You prefer non-interactive git commands.

## Autonomy and persistence

Adapt accordingly based on the user is request type. When asked to:

- Answer, explain, review, or report status: inspect the task and provide an evidence-backed response. These user requests do not authorize external writes, messages, PR changes, or other expansive mutations unless the user also asks for a change. Reversible, non-mutating diagnostic checks are allowed when they are relevant.
- Diagnose: determine the cause and explain it. Do not implement the fix unless the user asks for a fix or the request otherwise clearly includes implementation.
- Change or build: implement the requested change, verify it in proportion to risk, and hand off the completed result while a safe, relevant next step remains.
- Monitor or wait: use the recurring-monitoring or wait mechanism provided by the product. Unchanged external state is expected and is not by itself a blocker.

You avoid inferring authorization for a materially different action to the user is request. Bias towards taking action in the following circumstances:
a) the action is read-only, does not change state, or impacts only the systems, data, and people the user placed in scope.
b) the action is a normal implementation step within the requested workflow. You do not need to ask for clarification from the user if your action is scoped within the user is task and does not cause significant external state change (e.g. tool calls to external applications).

A terminal condition such as "finish," "babysit," or "do not stop" requires persistence toward the outcome, but does not broaden the set of authorized actions. When blocked, exhaust safe in-scope checks and alternatives.

You make informed assumptions that help you make progress towards the user is task, as long as they do not result in divergence from the user is intent and the scope of the task. If an assumption would cause the task or current course of action to change beyond what was specified by the user, make sure to flag the available context, the assumption made, and the reasons for doing so explicitly to the user.

When presented with clarifying questions or objections from the user, lead with concrete evidence and diligent reasoning rather than unsubstantiated deference. You communicate your reasoning explicitly and concretely, so decisions and tradeoffs are easy for the user to evaluate upfront.

If completion requires new authority, external coordination, or a meaningful expansion beyond the user is implied intent and task scope (e.g. a missing user choice that would materially change the result), stop the current turn, report the blocker, and request direction from the user rather than assuming permission.

# Destructive Actions

Be cautious with commands or API calls that can delete, overwrite, or otherwise make data difficult to recover.

Before taking a destructive action:

- Make sure the action is clearly within the user is request.
- Resolve the exact targets with read-only checks when necessary.
- Do not use `$HOME`, `~`, `/`, a workspace root, or another broad directory as the target of a recursive or destructive command.
- When creating temporary directories, prefer using `mktemp -d`, or `New-Item` in Powershell.
- When declaring env vars or script variables, always avoid common system options. Never repurpose `$HOME`, `$home`, or `$CODEX_HOME`. Instead, use a task-specific variable name.
- When possible, avoid relying on unresolved environment variables, globs, or command substitutions to identify destructive targets. Use explicit, validated paths.
- Prefer recoverable operations, such as moving files to trash, when practical.
- If the target or scope is unclear, stop and ask the user.

Never run commands such as `rm -rf $HOME` or equivalent operations that could erase a home directory, repository, workspace, or other broad collection of user data.

After deleting anything material, briefly tell the user what was removed and whether it can be recovered.

# Using skills

A skill is a set of instructions provided through a `SKILL.md` source. The skills available to you will be listed in the "## Skills" section under "### Available skills".

### How to use skills

- Discovery: When a `## Skills` section is present, it lists the skills available in the current session. Each entry includes a name, description, and location for its `SKILL.md`. The location may be an absolute filesystem path, a short aliased path, or a non-filesystem reference that must be read using its indicated tool or provider. When short aliased paths are used, the available-skills catalog also provides a mapping from aliases such as `r0` to their filesystem roots. Expand the alias before accessing the skill.
- Trigger rules: If the user names an available skill (with `$SkillName` or plain text) OR the task clearly matches an available skill is description, you must use that skill for that turn. Multiple mentions mean use them all. Do not carry skills across turns unless re-mentioned.
- Missing/blocked: If a named skill is not available or its `SKILL.md` cannot be read, say so briefly and continue with the best fallback.
- How to use a skill:
  1) After deciding to use a skill, the main agent must read its `SKILL.md` completely before taking task actions. If its location is a short aliased path, expand the matching root alias first from `### Skill roots`, then open and read its `SKILL.md` completely before taking task actions. For a filesystem path, open the file. For an environment-owned file, use the filesystem of the owning environment. For an orchestrator reference, call `skills.list` with `{"authority":{"kind":"orchestrator"}}`, select the matching package, and pass its `main_resource` to `skills.read`. For another non-filesystem reference, use its indicated tool or provider. If the read is truncated or paginated, continue until EOF.
  2) When `SKILL.md` references another file or resource, use the same access mechanism. Resolve relative paths against the directory containing a filesystem-backed `SKILL.md`. For orchestrator skills, pass the exact referenced resource identifier with the same authority and package to `skills.read`; do not treat `skill://` identifiers as filesystem paths.
  3) If `SKILL.md` points to extra folders such as `references/`, use its routing instructions to identify what is required for the task. The main agent must read each required instruction or reference itself before acting on it. Do not delegate reading, summarizing, or interpreting skill instructions to a subagent. Subagents may still perform task work when the selected skill allows it.
  4) For filesystem-backed skills (or if `scripts/` exist), prefer running or patching provided scripts instead of retyping large code blocks. For orchestrator skills, use `skills.read` and the available tools; do not invent a local path.
  5) Reuse provided assets or templates through the same access mechanism instead of recreating them (including if `assets/` or templates exist).
- Coordination and sequencing:
  - If multiple skills apply, choose the minimal set that covers the request and state the order to use them.
  - Announce which skills you are using and why. If you skip an obvious skill, say why.
- Context hygiene:
  - Progressive disclosure applies to selecting relevant resources, not partially reading a selected instruction file. Do not load unrelated references, scripts, or assets.
  - Avoid deep reference-chasing: prefer files or resources directly linked from `SKILL.md` unless blocked.
  - When variants exist, select only the relevant references and note the choice.
- Safety and fallback: If a skill cannot be applied cleanly, state the issue, choose the best alternative, and continue.

When the user names a skill in their request, you must add the usage of that skill to your current working plan and use it faithfully. The user is instructions should take precedence over guidelines provided in a skill.

Explicitly tell the user in the `commentary` channel whenever a skill causes you to take an action or pause your work.

When using a skill the user did not explicitly name, follow this procedure:

- First, tell the user in the commentary channel **why** you are using the skill.
- Then, use the skill as long as it stays within the scope of the task.
- Next, if using the skill resulted in material changes (especially when this requires non-trivial judgment), mention how it influenced your work (but only in the final response).

If a skill causes the current turn to pause or otherwise blocks the continuation of the task, cite the skill and provide a concise explanation to the user in your final response. Do not cite skills you merely inspected.'

# ---------------------------------------------------------------- paths

CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
CONFIG_PATH="$CODEX_HOME/config.toml"
MODELS_PATH="$CODEX_HOME/models.json"
API_KEY=""
MODEL_SLUG=""

set_paths() {
    BACKUP_DIR="$CODEX_HOME/$BACKUP_DIRNAME"
    BACKUP_CONFIG="$BACKUP_DIR/config.toml"
    MANIFEST="$BACKUP_DIR/manifest.txt"
}

# ---------------------------------------------------------------- JSON generation functions

model_supports_image() {
    local slug="$1"
    case " $MODEL_SUPPORTS_IMAGE " in
        *" $slug "*) return 0 ;;
        *) return 1 ;;
    esac
}

model_supports_search() {
    local slug="$1"
    case " $MODEL_SUPPORTS_SEARCH " in
        *" $slug "*) return 0 ;;
        *) return 1 ;;
    esac
}

# Generate models.json using jq
generate_models_json_jq() {
    local priority=1
    local entries=""

    for slug in $MODELS_LIST; do
        local display="${MODEL_DISPLAY[$slug]:-$slug}"
        local desc="${MODEL_DESCRIPTION[$slug]:-Model $slug}"
        local context_window=1048576
        local input_modalities='["text"]'
        if model_supports_image "$slug"; then
            input_modalities='["text","image"]'
        fi
        local supports_search="false"
        if model_supports_search "$slug"; then
            supports_search="true"
        fi
        local supports_image_detail="false"
        if model_supports_image "$slug"; then
            supports_image_detail="true"
        fi

        local entry
        entry=$(jq -n \
            --arg slug "$slug" \
            --arg display "$display" \
            --arg desc "$desc" \
            --argjson context_window "$context_window" \
            --argjson input_modalities "$input_modalities" \
            --argjson supports_image_detail "$supports_image_detail" \
            --argjson supports_search "$supports_search" \
            --argjson priority "$priority" \
            --arg instructions "$INSTRUCTIONS_TEMPLATE" \
            '{
                slug: $slug,
                prefer_websockets: false,
                support_verbosity: true,
                default_verbosity: "low",
                apply_patch_tool_type: "freeform",
                web_search_tool_type: "text",
                input_modalities: $input_modalities,
                supports_image_detail_original: $supports_image_detail,
                truncation_policy: {
                    mode: "tokens",
                    limit: 10000
                },
                supports_parallel_tool_calls: true,
                tool_mode: null,
                multi_agent_version: "v2",
                use_responses_lite: false,
                include_skills_usage_instructions: false,
                auto_review_model_override: null,
                context_window: $context_window,
                max_context_window: $context_window,
                effective_context_window_percent: 95,
                auto_compact_token_limit: null,
                comp_hash: "3000",
                reasoning_summary_format: "experimental",
                default_reasoning_summary: "none",
                display_name: $display,
                description: $desc,
                default_reasoning_level: "high",
                supported_reasoning_levels: [
                    {effort: "low", description: "Fast responses with lighter reasoning"},
                    {effort: "medium", description: "Balanced reasoning depth"},
                    {effort: "high", description: "Extra high reasoning depth for complex problems"},
                    {effort: "xhigh", description: "Extra extra high reasoning depth"},
                    {effort: "ultra", description: "Ultra reasoning depth for very hard problems"},
                    {effort: "max", description: "Maximum reasoning depth for the hardest problems"}
                ],
                shell_type: "shell_command",
                visibility: "list",
                minimal_client_version: "0.144.0",
                supported_in_api: true,
                availability_nux: null,
                upgrade: null,
                priority: $priority,
                model_messages: {
                    instructions_template: $instructions,
                    instructions_variables: {
                        personality_default: "",
                        personality_friendly: "",
                        personality_pragmatic: ""
                    },
                    approvals: null
                },
                experimental_supported_tools: [],
                supports_search_tool: $supports_search,
                default_service_tier: null,
                supports_reasoning_summaries: true,
                base_instructions: $instructions
            }')

        if [[ -n "$entries" ]]; then
            entries="$entries,"
        fi
        entries="$entries$entry"
        priority=$((priority + 1))
    done

    jq -n --argjson models "[$entries]" '{models: $models}'
}

# ---------------------------------------------------------------- paths

CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
CONFIG_PATH="$CODEX_HOME/config.toml"
MODELS_PATH="$CODEX_HOME/models.json"
API_KEY=""
MODEL_SLUG=""

set_paths() {
    BACKUP_DIR="$CODEX_HOME/$BACKUP_DIRNAME"
    BACKUP_CONFIG="$BACKUP_DIR/config.toml"
    MANIFEST="$BACKUP_DIR/manifest.txt"
}

# ---------------------------------------------------------------- JSON generation functions

model_supports_image() {
    local slug="$1"
    case " $MODEL_SUPPORTS_IMAGE " in
        *" $slug "*) return 0 ;;
        *) return 1 ;;
    esac
}

model_supports_search() {
    local slug="$1"
    case " $MODEL_SUPPORTS_SEARCH " in
        *" $slug "*) return 0 ;;
        *) return 1 ;;
    esac
}

# Generate models.json using jq
generate_models_json_jq() {
    local priority=1
    local entries=""

    for slug in $MODELS_LIST; do
        local display="${MODEL_DISPLAY[$slug]:-$slug}"
        local desc="${MODEL_DESCRIPTION[$slug]:-Model $slug}"
        local context_window=1048576
        local input_modalities='["text"]'
        if model_supports_image "$slug"; then
            input_modalities='["text","image"]'
        fi
        local supports_search="false"
        if model_supports_search "$slug"; then
            supports_search="true"
        fi
        local supports_image_detail="false"
        if model_supports_image "$slug"; then
            supports_image_detail="true"
        fi

        local entry
        entry=$(jq -n \
            --arg slug "$slug" \
            --arg display "$display" \
            --arg desc "$desc" \
            --argjson context_window "$context_window" \
            --argjson input_modalities "$input_modalities" \
            --argjson supports_image_detail "$supports_image_detail" \
            --argjson supports_search "$supports_search" \
            --argjson priority "$priority" \
            --arg instructions "$INSTRUCTIONS_TEMPLATE" \
            '{
                slug: $slug,
                prefer_websockets: false,
                support_verbosity: true,
                default_verbosity: "low",
                apply_patch_tool_type: "freeform",
                web_search_tool_type: "text",
                input_modalities: $input_modalities,
                supports_image_detail_original: $supports_image_detail,
                truncation_policy: {
                    mode: "tokens",
                    limit: 10000
                },
                supports_parallel_tool_calls: true,
                tool_mode: null,
                multi_agent_version: "v2",
                use_responses_lite: false,
                include_skills_usage_instructions: false,
                auto_review_model_override: null,
                context_window: $context_window,
                max_context_window: $context_window,
                effective_context_window_percent: 95,
                auto_compact_token_limit: null,
                comp_hash: "3000",
                reasoning_summary_format: "experimental",
                default_reasoning_summary: "none",
                display_name: $display,
                description: $desc,
                default_reasoning_level: "high",
                supported_reasoning_levels: [
                    {effort: "low", description: "Fast responses with lighter reasoning"},
                    {effort: "medium", description: "Balanced reasoning depth"},
                    {effort: "high", description: "Extra high reasoning depth for complex problems"},
                    {effort: "xhigh", description: "Extra extra high reasoning depth"},
                    {effort: "ultra", description: "Ultra reasoning depth for very hard problems"},
                    {effort: "max", description: "Maximum reasoning depth for the hardest problems"}
                ],
                shell_type: "shell_command",
                visibility: "list",
                minimal_client_version: "0.144.0",
                supported_in_api: true,
                availability_nux: null,
                upgrade: null,
                priority: $priority,
                model_messages: {
                    instructions_template: $instructions,
                    instructions_variables: {
                        personality_default: "",
                        personality_friendly: "",
                        personality_pragmatic: ""
                    },
                    approvals: null
                },
                experimental_supported_tools: [],
                supports_search_tool: $supports_search,
                default_service_tier: null,
                supports_reasoning_summaries: true,
                base_instructions: $instructions
            }')

        if [[ -n "$entries" ]]; then
            entries="$entries,"
        fi
        entries="$entries$entry"
        priority=$((priority + 1))
    done

    jq -n --argjson models "[$entries]" '{models: $models}'
}

# Generate models.json using Python
generate_models_json_python() {
    local meta_tmp
    meta_tmp=$(mktemp)
    {
        echo "MODELS_LIST:$MODELS_LIST"
        for key in "${!MODEL_DISPLAY[@]}"; do
            echo "DISPLAY:${key}:${MODEL_DISPLAY[$key]}"
        done
        for key in "${!MODEL_DESCRIPTION[@]}"; do
            echo "DESC:${key}:${MODEL_DESCRIPTION[$key]}"
        done
        echo "IMAGE:$MODEL_SUPPORTS_IMAGE"
        echo "SEARCH:$MODEL_SUPPORTS_SEARCH"
    } > "$meta_tmp"

    export CODEX_INSTRUCTIONS="$INSTRUCTIONS_TEMPLATE"
    local result
    result=$("$PYTHON_BIN" -c '
import json, os, sys

instructions = os.environ.get("CODEX_INSTRUCTIONS", "").rstrip()
meta_file = sys.argv[1]

models_list = []
display_map = {}
desc_map = {}
image_set = set()
search_set = set()

with open(meta_file, "r") as f:
    for line in f:
        line = line.rstrip("\n")
        if line.startswith("MODELS_LIST:"):
            models_list = line[len("MODELS_LIST:"):].strip().split()
        elif line.startswith("DISPLAY:"):
            parts = line.split(":", 2)
            if len(parts) >= 3:
                display_map[parts[1]] = parts[2]
        elif line.startswith("DESC:"):
            parts = line.split(":", 2)
            if len(parts) >= 3:
                desc_map[parts[1]] = parts[2]
        elif line.startswith("IMAGE:"):
            image_set = set(line[len("IMAGE:"):].strip().split())
        elif line.startswith("SEARCH:"):
            search_set = set(line[len("SEARCH:"):].strip().split())

reasoning_levels = [
    {"effort": "low", "description": "Fast responses with lighter reasoning"},
    {"effort": "medium", "description": "Balanced reasoning depth"},
    {"effort": "high", "description": "Extra high reasoning depth for complex problems"},
    {"effort": "xhigh", "description": "Extra extra high reasoning depth"},
    {"effort": "ultra", "description": "Ultra reasoning depth for very hard problems"},
    {"effort": "max", "description": "Maximum reasoning depth for the hardest problems"},
]

models = []
for priority, slug in enumerate(models_list, 1):
    display = display_map.get(slug, slug)
    desc = desc_map.get(slug, "Model " + slug)
    supports_image = slug in image_set
    supports_search = slug in search_set
    input_modalities = ["text", "image"] if supports_image else ["text"]

    entry = {
        "slug": slug,
        "prefer_websockets": False,
        "support_verbosity": True,
        "default_verbosity": "low",
        "apply_patch_tool_type": "freeform",
        "web_search_tool_type": "text",
        "input_modalities": input_modalities,
        "supports_image_detail_original": supports_image,
        "truncation_policy": {"mode": "tokens", "limit": 10000},
        "supports_parallel_tool_calls": True,
        "tool_mode": None,
        "multi_agent_version": "v2",
        "use_responses_lite": False,
        "include_skills_usage_instructions": False,
        "auto_review_model_override": None,
        "context_window": 1048576,
        "max_context_window": 1048576,
        "effective_context_window_percent": 95,
        "auto_compact_token_limit": None,
        "comp_hash": "3000",
        "reasoning_summary_format": "experimental",
        "default_reasoning_summary": "none",
        "display_name": display,
        "description": desc,
        "default_reasoning_level": "high",
        "supported_reasoning_levels": reasoning_levels,
        "shell_type": "shell_command",
        "visibility": "list",
        "minimal_client_version": "0.144.0",
        "supported_in_api": True,
        "availability_nux": None,
        "upgrade": None,
        "priority": priority,
        "model_messages": {
            "instructions_template": instructions,
            "instructions_variables": {
                "personality_default": "",
                "personality_friendly": "",
                "personality_pragmatic": "",
            },
            "approvals": None,
        },
        "experimental_supported_tools": [],
        "supports_search_tool": supports_search,
        "default_service_tier": None,
        "supports_reasoning_summaries": True,
        "base_instructions": instructions,
    }
    models.append(entry)

print(json.dumps({"models": models}, indent=2, ensure_ascii=False))
' "$meta_tmp")
    rm -f "$meta_tmp"
    echo "$result"
}

# Generate models.json manually (fallback, no jq/python)
generate_models_json_manual() {
    local priority=1
    local entries=""

    for slug in $MODELS_LIST; do
        local display="${MODEL_DISPLAY[$slug]:-$slug}"
        local desc="${MODEL_DESCRIPTION[$slug]:-Model $slug}"
        local input_modalities
        if model_supports_image "$slug"; then
            input_modalities='["text","image"]'
        else
            input_modalities='["text"]'
        fi
        local supports_search="false"
        if model_supports_search "$slug"; then
            supports_search="true"
        fi
        local supports_image_detail="false"
        if model_supports_image "$slug"; then
            supports_image_detail="true"
        fi

        # Escape special JSON characters in instructions
        local escaped_instructions
        escaped_instructions=$(echo "$INSTRUCTIONS_TEMPLATE" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g' | tr '\n' '§')
        escaped_instructions=${escaped_instructions//§/\\n}

        local entry
        entry=$(cat <<EOENTRY
{
  "slug": "$slug",
  "prefer_websockets": false,
  "support_verbosity": true,
  "default_verbosity": "low",
  "apply_patch_tool_type": "freeform",
  "web_search_tool_type": "text",
  "input_modalities": $input_modalities,
  "supports_image_detail_original": $supports_image_detail,
  "truncation_policy": {"mode": "tokens", "limit": 10000},
  "supports_parallel_tool_calls": true,
  "tool_mode": null,
  "multi_agent_version": "v2",
  "use_responses_lite": false,
  "include_skills_usage_instructions": false,
  "auto_review_model_override": null,
  "context_window": 1048576,
  "max_context_window": 1048576,
  "effective_context_window_percent": 95,
  "auto_compact_token_limit": null,
  "comp_hash": "3000",
  "reasoning_summary_format": "experimental",
  "default_reasoning_summary": "none",
  "display_name": "$display",
  "description": "$desc",
  "default_reasoning_level": "high",
  "supported_reasoning_levels": [
    {"effort": "low", "description": "Fast responses with lighter reasoning"},
    {"effort": "medium", "description": "Balanced reasoning depth"},
    {"effort": "high", "description": "Extra high reasoning depth for complex problems"},
    {"effort": "xhigh", "description": "Extra extra high reasoning depth"},
    {"effort": "ultra", "description": "Ultra reasoning depth for very hard problems"},
    {"effort": "max", "description": "Maximum reasoning depth for the hardest problems"}
  ],
  "shell_type": "shell_command",
  "visibility": "list",
  "minimal_client_version": "0.144.0",
  "supported_in_api": true,
  "availability_nux": null,
  "upgrade": null,
  "priority": $priority,
  "model_messages": {
    "instructions_template": "$escaped_instructions",
    "instructions_variables": {
      "personality_default": "",
      "personality_friendly": "",
      "personality_pragmatic": ""
    },
    "approvals": null
  },
  "experimental_supported_tools": [],
  "supports_search_tool": $supports_search,
  "default_service_tier": null,
  "supports_reasoning_summaries": true,
  "base_instructions": "$escaped_instructions"
}
EOENTRY
)

        if [[ -n "$entries" ]]; then
            entries="$entries,"
        fi
        entries="$entries$(echo "$entry" | tr -d '\n')"
        priority=$((priority + 1))
    done

    echo "{\"models\":[$entries]}"
}

generate_models_json() {
    if [[ $HAS_JQ -eq 1 ]]; then
        generate_models_json_jq
    elif [[ $HAS_PYTHON -eq 1 ]]; then
        generate_models_json_python
    else
        generate_models_json_manual
    fi
}

# ---------------------------------------------------------------- TOML manipulation functions

# Target keys to set in config.toml leading area
TARGET_KEYS=(model model_provider preferred_auth_method forced_login_method model_reasoning_effort web_search show_raw_agent_reasoning model_catalog_json)

# Keys to delete (conflicting)
DEL_KEYS_A=(profile oss_provider openai_base_url)
DEL_KEYS_B=(model_context_window model_auto_compact_token_limit model_auto_compact_token_limit_scope base_instructions model_instructions_file compact_prompt experimental_compact_prompt_file service_tier model_verbosity model_reasoning_summary plan_mode_reasoning_effort experimental_use_unified_exec_tool)

# Warn keys
WARN_KEYS=(review_model experimental_thread_config_endpoint experimental_thread_store_endpoint experimental_thread_store)

get_target_value() {
    local key="$1"
    case "$key" in
        model)                  echo "\"$MODEL_SLUG\"" ;;
        model_provider)         echo "\"$PROVIDER_ID\"" ;;
        preferred_auth_method)  echo '"apikey"' ;;
        forced_login_method)    echo '"api"' ;;
        model_reasoning_effort) echo '"high"' ;;
        web_search)             echo '"disabled"' ;;
        show_raw_agent_reasoning) echo 'true' ;;
        model_catalog_json)     echo "\"$MODELS_PATH\"" ;;
        *)                      echo '""' ;;
    esac
}

# Parse TOML and rewrite config
process_toml_install() {
    local input_file="$1"
    local output_file="$2"

    local -A seen_keys=()
    local -a out_lines=()
    local -a report=()
    local ins_at=0
    local cur_section=""
    local skip_section=0
    local desktop_done=0
    local depth=0
    local ml_state=""
    local idx=0

    # Read file into array
    local -a lines=()
    if [[ -f "$input_file" ]]; then
        while IFS= read -r line; do
            lines+=("$line")
        done < "$input_file"
    fi

    while [[ $idx -lt ${#lines[@]} ]]; do
        local line="${lines[$idx]}"
        local trimmed="${line#"${line%%[![:space:]]*}"}"

        # Check if this is a section header (only at depth 0, not in multiline string)
        local is_header=0
        if [[ -z "$ml_state" && "$depth" -eq 0 && "$trimmed" == \[* ]]; then
            is_header=1
        fi

        if [[ $is_header -eq 1 ]]; then
            # Extract section name
            local hdr="$trimmed"
            hdr="${hdr#\[}"
            hdr="${hdr%%\]*}"
            hdr="${hdr//\"/}"
            hdr="${hdr//\'/}"
            cur_section="$hdr"
            skip_section=0

            if [[ "$cur_section" == "model_providers.${PROVIDER_ID}" || "$cur_section" == "model_providers.${PROVIDER_ID}."* ]]; then
                skip_section=1
                report+=("删除旧的 [$hdr]（将以新配置重写）")
            elif [[ "$cur_section" == "profiles" || "$cur_section" == "profiles."* ]]; then
                skip_section=1
                report+=("删除 [$hdr]  <- profile 会遮蔽 model / model_provider 等设置，且此版本已禁止写入")
            elif [[ "$cur_section" == "auto_review" ]]; then
                report+=("保留 [$hdr]  (提示: auto_review 若指向 gpt-5.x 模型会使用 fallback 元数据)")
            fi

            idx=$((idx + 1))
            if [[ $skip_section -eq 0 ]]; then
                out_lines+=("$line")
            fi

            # Handle [desktop] section - insert effort levels key right after header
            if [[ "$cur_section" == "desktop" && $desktop_done -eq 0 ]]; then
                out_lines+=("enabled-reasoning-efforts = [\"low\", \"medium\", \"high\", \"xhigh\", \"ultra\", \"max\"]")
                desktop_done=1
            fi
            continue
        fi

        # Inside a section
        if [[ -n "$cur_section" ]]; then
            if [[ $skip_section -eq 1 ]]; then
                idx=$((idx + 1))
                continue
            fi

            # Check for key inside section
            if [[ "$trimmed" == *=* && "$trimmed" != \#* ]]; then
                local key="${trimmed%%=*}"
                key="${key#"${key%%[![:space:]]*}"}"
                key="${key%"${key##*[![:space:]]}"}"

                # Handle desktop enabled-reasoning-efforts
                if [[ "$cur_section" == "desktop" && "$key" == "enabled-reasoning-efforts" && $desktop_done -eq 1 ]]; then
                    idx=$((idx + 1))
                    continue
                fi

                # Fix wire_api = "chat" -> "responses"
                if [[ "$key" == "wire_api" ]]; then
                    local value="${trimmed#*=}"
                    value="${value#"${value%%[![:space:]]*}"}"
                    if [[ "$value" == '"chat"' ]]; then
                        local indent="${line%%[^[:space:]]*}"
                        out_lines+=("${indent}wire_api = \"responses\"")
                        report+=("修正 [$cur_section] 的 wire_api: \"chat\" -> \"responses\"  <- 此版本 \"chat\" 会导致 Codex 无法启动")
                        idx=$((idx + 1))
                        continue
                    fi
                fi
            fi

            out_lines+=("$line")
            idx=$((idx + 1))
            continue
        fi

        # Leading area (top-level keys)
        if [[ -z "$cur_section" ]]; then
            # Check for key = value
            if [[ "$trimmed" == *=* && "$trimmed" != \#* && -z "$ml_state" ]]; then
                local key="${trimmed%%=*}"
                key="${key#"${key%%[![:space:]]*}"}"
                key="${key%"${key##*[![:space:]]}"}"

                # Check target keys
                local is_target=0
                for tk in "${TARGET_KEYS[@]}"; do
                    if [[ "$key" == "$tk" ]]; then
                        is_target=1
                        break
                    fi
                done

                if [[ $is_target -eq 1 ]]; then
                    local new_val
                    new_val=$(get_target_value "$key")
                    out_lines+=("$key = $new_val")
                    seen_keys["$key"]=1
                    ins_at=${#out_lines[@]}
                    idx=$((idx + 1))
                    continue
                fi

                # Check DEL_A keys
                local is_del_a=0
                for dk in "${DEL_KEYS_A[@]}"; do
                    if [[ "$key" == "$dk" ]]; then
                        is_del_a=1
                        break
                    fi
                done
                # Also check DEL_B keys
                local is_del_b=0
                for dk in "${DEL_KEYS_B[@]}"; do
                    if [[ "$key" == "$dk" ]]; then
                        is_del_b=1
                        break
                    fi
                done

                if [[ $is_del_a -eq 1 ]]; then
                    local old_val="${trimmed#*=}"
                    old_val="${old_val#"${old_val%%[![:space:]]*}"}"
                    report+=("删除 $key = $old_val  <- 冲突配置，会遮蔽 model / model_provider 等设置")
                    idx=$((idx + 1))
                    continue
                fi

                if [[ $is_del_b -eq 1 ]]; then
                    local old_val="${trimmed#*=}"
                    old_val="${old_val#"${old_val%%[![:space:]]*}"}"
                    report+=("删除 $key = $old_val  <- 残留值可能引发问题")
                    idx=$((idx + 1))
                    continue
                fi
            fi

            out_lines+=("$line")
            if [[ "$trimmed" == *=* && "$trimmed" != \#* && -z "$ml_state" ]]; then
                local key="${trimmed%%=*}"
                key="${key#"${key%%[![:space:]]*}"}"
                key="${key%"${key##*[![:space:]]}"}"
                if [[ -n "$key" ]]; then
                    ins_at=${#out_lines[@]}
                fi
            fi
            idx=$((idx + 1))
            continue
        fi

        idx=$((idx + 1))
    done

    # Insert missing target keys
    local -a final=()
    for ((i=0; i<${#out_lines[@]}; i++)); do
        if [[ $i -eq $ins_at ]]; then
            for tk in "${TARGET_KEYS[@]}"; do
                if [[ -z "${seen_keys[$tk]:-}" ]]; then
                    local new_val
                    new_val=$(get_target_value "$tk")
                    final+=("$tk = $new_val")
                fi
            done
            ins_at=-1
        fi
        final+=("${out_lines[$i]}")
    done
    # If ins_at was never reached (file was empty or all lines before section)
    if [[ $ins_at -ge 0 ]]; then
        for tk in "${TARGET_KEYS[@]}"; do
            if [[ -z "${seen_keys[$tk]:-}" ]]; then
                local new_val
                new_val=$(get_target_value "$tk")
                final+=("$tk = $new_val")
            fi
        done
    fi

    # Append model_providers section
    final+=("")
    final+=("[model_providers.${PROVIDER_ID}]")
    final+=("name = \"${PROVIDER_ID}\"")
    final+=("base_url = \"${PROVIDER_BASE_URL_VALUE}\"")
    final+=("wire_api = \"responses\"")
    final+=("experimental_bearer_token = \"${API_KEY}\"")

    # Append desktop section if not done
    if [[ $desktop_done -eq 0 ]]; then
        final+=("")
        final+=("[desktop]")
        final+=("enabled-reasoning-efforts = [\"low\", \"medium\", \"high\", \"xhigh\", \"ultra\", \"max\"]")
    fi

    # Write output
    printf '%s\n' "${final[@]}" > "$output_file"

    # Print report
    if [[ ${#report[@]} -gt 0 ]]; then
        write_head "对原有配置的改动（共 ${#report[@]} 项）"
        for r in "${report[@]}"; do
            echo "  - $r"
        done
    fi
}

# ---------------------------------------------------------------- backup/restore functions

do_backup() {
    mkdir -p "$BACKUP_DIR"

    if [[ -f "$CONFIG_PATH" ]]; then
        cp -f "$CONFIG_PATH" "$BACKUP_CONFIG"
        write_ok "已备份 config.toml → $BACKUP_CONFIG"
        echo "original_config_existed=1" > "$MANIFEST"
    else
        write_warn "未找到 config.toml，将创建新文件"
        echo "original_config_existed=0" > "$MANIFEST"
    fi

    # Write manifest
    {
        echo "script_version=$SCRIPT_VERSION"
        echo "installed_at=$(date '+%Y-%m-%d %H:%M:%S')"
        echo "model_slug=$MODEL_SLUG"
        echo "base_url=$PROVIDER_BASE_URL_VALUE"
        echo "models_path=$MODELS_PATH"
        echo "codex_home=$CODEX_HOME"
    } >> "$MANIFEST"
}

do_restore() {
    write_head "恢复默认 Codex 配置（删除 $PROVIDER_ID 相关配置）"

    if [[ ! -d "$BACKUP_DIR" ]]; then
        die "未找到备份目录：\n  $BACKUP_DIR\n没有可还原的内容——可能尚未安装过，或已经还原过了。"
    fi

    local had_config=1
    if [[ -f "$MANIFEST" ]]; then
        if grep -q "original_config_existed=0" "$MANIFEST" 2>/dev/null; then
            had_config=0
        fi
    fi

    local n=1
    echo ''
    echo '将执行以下操作：'
    if [[ $had_config -eq 1 ]]; then
        if [[ ! -f "$BACKUP_CONFIG" ]]; then
            die "备份已损坏：缺少 $BACKUP_CONFIG"
        fi
        echo "  $n. 删除当前 $CONFIG_PATH"; n=$((n + 1))
        write_dim "     （安装之后对该文件做的所有修改都会丢失）"
        echo "  $n. 用备份恢复 config.toml"; n=$((n + 1))
    else
        echo "  $n. 删除 $CONFIG_PATH"; n=$((n + 1))
        write_dim "     （安装前本不存在此文件）"
    fi
    echo "  $n. 删除 $MODELS_PATH"; n=$((n + 1))
    echo "  $n. 删除备份目录 $BACKUP_DIR"
    echo ''

    read -rp "确认还原? 输入 y 继续，其它任意键取消: " ans
    if [[ ! "$ans" =~ ^[yY]$ ]]; then
        echo '已取消，未做任何修改。'
        return
    fi

    if [[ -f "$MODELS_PATH" ]]; then
        rm -f "$MODELS_PATH"
    fi

    if [[ $had_config -eq 1 ]]; then
        cp -f "$BACKUP_CONFIG" "$CONFIG_PATH"
        write_ok "config.toml 已恢复"
    else
        if [[ -f "$CONFIG_PATH" ]]; then
            rm -f "$CONFIG_PATH"
        fi
        write_ok "config.toml 已删除（安装前不存在）"
    fi
    write_ok "models.json 已删除"

    rm -rf "$BACKUP_DIR"
    write_ok "备份目录已清理"
    echo ''
    write_ok "还原完成，Codex 配置已回到安装前的状态。"
    echo ''
    write_warn "请完全退出 ChatGPT 桌面端后重新打开，还原才会生效"
    echo '     （右键任务栏托盘图标选择退出；仅关闭窗口进程仍在后台，不算退出）'
    echo ''
}

# ---------------------------------------------------------------- install function

do_install() {
    write_head "首次安装（目标模型：$MODEL_SLUG）"

    # ---- interactive input

    # API key
    local env_var="$PROVIDER_API_KEY_ENV_VAR"
    local env_var_alt="${PROVIDER_API_KEY_ENV_VAR_ALT:-}"

    if [[ -n "${!env_var:-}" ]]; then
        API_KEY="${!env_var}"
        echo ''
        write_ok "使用环境变量 $env_var 提供的 API key，跳过询问。"
    elif [[ -n "$env_var_alt" && -n "${!env_var_alt:-}" ]]; then
        API_KEY="${!env_var_alt}"
        echo ''
        write_ok "使用环境变量 $env_var_alt 提供的 API key，跳过询问。"
    fi

    echo ''
    if [[ -z "$API_KEY" ]]; then
        if [[ -n "$PROVIDER_KEY_URL" ]]; then
            write_dim "还没有 API key？请到 $PROVIDER_KEY_URL 创建。"
        fi
    fi

    local key_attempt=0
    while [[ -z "$API_KEY" ]]; do
        local prompt_text="请输入 API key"
        if [[ -n "$PROVIDER_KEY_PREFIX" ]]; then
            prompt_text="请输入 API key（以 ${PROVIDER_KEY_PREFIX} 开头）"
        fi
        read -rp "$prompt_text: " API_KEY
        API_KEY="${API_KEY// /}"
        if [[ -z "$API_KEY" ]]; then
            key_attempt=$((key_attempt + 1))
            if [[ $key_attempt -ge 3 ]]; then
                die "未能获得有效的 API key，已退出（未修改任何文件）。"
            fi
            write_warn "API key 不能为空。"
        fi
        if [[ -n "$PROVIDER_KEY_PREFIX" && ! "$API_KEY" == ${PROVIDER_KEY_PREFIX}* ]]; then
            key_attempt=$((key_attempt + 1))
            if [[ $key_attempt -ge 3 ]]; then
                die "未能获得有效的 API key（需以 ${PROVIDER_KEY_PREFIX} 开头），已退出（未修改任何文件）。"
            fi
            write_warn "API key 必须以 ${PROVIDER_KEY_PREFIX} 开头。"
            API_KEY=""
        fi
    done

    # ---- backup

    do_backup

    # ---- processing

    local tmp_config="${CONFIG_PATH}.${PROVIDER_ID}-tmp"
    local tmp_models="${MODELS_PATH}.${PROVIDER_ID}-tmp"

    process_toml_install "$CONFIG_PATH" "$tmp_config"

    # Generate models.json
    generate_models_json > "$tmp_models"

    # Validate JSON
    local validated=0
    if [[ $HAS_JQ -eq 1 ]]; then
        if jq empty "$tmp_models" 2>/dev/null; then
            validated=1
        fi
    elif [[ $HAS_PYTHON -eq 1 ]]; then
        if "$PYTHON_BIN" -c "import json; json.load(open('$tmp_models'))" 2>/dev/null; then
            validated=1
        fi
    else
        # Basic validation: check it starts with { and ends with }
        local first_char last_char
        first_char=$(head -c 1 "$tmp_models")
        last_char=$(tail -c 2 "$tmp_models" | head -c 1)
        if [[ "$first_char" == "{" && "$last_char" == "}" ]]; then
            validated=1
        fi
    fi

    if [[ $validated -eq 0 ]]; then
        rm -f "$tmp_config" "$tmp_models"
        die "生成的 models.json 未通过校验，已中止（原文件未被修改）。"
    fi

    # ---- commit to disk

    mv -f "$tmp_models" "$MODELS_PATH"
    mv -f "$tmp_config" "$CONFIG_PATH"

    # ---- report

    local slug_list=""
    if [[ -n "$MODELS_LIST" ]]; then
        for slug in $MODELS_LIST; do
            if [[ -n "$slug_list" ]]; then
                slug_list="$slug_list、"
            fi
            slug_list="$slug_list$slug"
        done
    fi

    write_ok "已写入 $MODELS_PATH（含：$slug_list）"
    write_ok "已更新 $CONFIG_PATH"

    write_head "已写入的配置"
    cat <<EOTOML
  model                    = "$MODEL_SLUG"
  model_provider           = "$PROVIDER_ID"
  preferred_auth_method    = "apikey"
  forced_login_method      = "api"
  model_reasoning_effort   = "high"
  web_search               = "disabled"
  show_raw_agent_reasoning = true
  model_catalog_json       = "$MODELS_PATH"

  [model_providers.$PROVIDER_ID]
  base_url  = "$PROVIDER_BASE_URL_VALUE"
  wire_api  = "responses"

  [desktop]
  enabled-reasoning-efforts = ["low", "medium", "high", "xhigh", "ultra", "max"]
EOTOML

    write_head "校验"
    if [[ $validated -eq 1 ]]; then
        write_ok "models.json 是合法 JSON"
    fi
    write_ok "config.toml 无重复顶层 key"

    echo ''
    write_ok "安装完成。"
    echo ''
    write_warn "请完全退出 ChatGPT 桌面端后重新打开，配置才会生效"
    echo '     （右键任务栏托盘图标选择退出；仅关闭窗口进程仍在后台，不算退出）'
    echo ''
    echo '如何确认已生效：'
    echo '  • ChatGPT 桌面端：打开后右下角显示"自定义"或所选模型名，都算成功'
    echo '    （显示哪种取决于 ChatGPT 版本；显示模型名时，可直接在客户端里切换模型）'
    echo "  • Codex CLI：启动信息中显示 model: $MODEL_SLUG"
    echo ''
    write_dim "若日志出现 \"fallback model metadata\" 或 \"Unknown model\"，"
    write_dim "说明 models.json 未被加载，请重新安装。"
    echo ''
    write_head "如何切换 / 还原"
    echo "原配置已备份到 $BACKUP_DIR"
    echo '再次运行本脚本即可：'
    echo ''
    echo "  $0"
    echo ''
    echo '  选择模型重新写入配置，选 9 恢复到安装前的配置。'
    echo ''
}

# ---------------------------------------------------------------- switch model function

do_switch_model() {
    write_head "更新配置 → $MODEL_SLUG"
    write_dim "检测到本脚本的备份已就绪，将刷新 models.json 并更新 config.toml。"

    # ---- backup current before switch
    if [[ -f "$CONFIG_PATH" ]]; then
        cp -f "$CONFIG_PATH" "$BACKUP_CONFIG"
    fi

    # ---- process TOML (simplified: just update model-related keys)
    local tmp_config="${CONFIG_PATH}.${PROVIDER_ID}-tmp"
    local tmp_models="${MODELS_PATH}.${PROVIDER_ID}-tmp"

    # For switch, we do a simpler pass: update model, web_search, show_raw_agent_reasoning
    # and ensure desktop section exists
    local -a lines=()
    if [[ -f "$CONFIG_PATH" ]]; then
        while IFS= read -r line; do
            lines+=("$line")
        done < "$CONFIG_PATH"
    fi

    local -a out=()
    local model_replaced=0
    local ws_replaced=0
    local sr_replaced=0
    local desktop_done=0
    local in_leading=1

    for line in "${lines[@]}"; do
        local trimmed="${line#"${line%%[![:space:]]*}"}"

        # Detect section headers to end leading area
        if [[ $in_leading -eq 1 && "$trimmed" == \[* && "$trimmed" != \#* ]]; then
            # Insert missing keys before first section
            if [[ $model_replaced -eq 0 ]]; then
                out+=("model = \"$MODEL_SLUG\"")
                model_replaced=1
            fi
            if [[ $ws_replaced -eq 0 ]]; then
                out+=('web_search = "disabled"')
                ws_replaced=1
            fi
            if [[ $sr_replaced -eq 0 ]]; then
                out+=('show_raw_agent_reasoning = true')
                sr_replaced=1
            fi
            in_leading=0

            # Check if this is [desktop]
            local hdr="$trimmed"
            hdr="${hdr#\[}"
            hdr="${hdr%%\]*}"
            hdr="${hdr//\"/}"
            if [[ "$hdr" == "desktop" ]]; then
                out+=("$line")
                out+=('enabled-reasoning-efforts = ["low", "medium", "high", "xhigh", "ultra", "max"]')
                desktop_done=1
                continue
            fi
        fi

        if [[ $in_leading -eq 1 ]]; then
            # Check for keys to replace
            if [[ "$trimmed" == *=* && "$trimmed" != \#* ]]; then
                local key="${trimmed%%=*}"
                key="${key#"${key%%[![:space:]]*}"}"
                key="${key%"${key##*[![:space:]]}"}"

                if [[ "$key" == "model" ]]; then
                    out+=("model = \"$MODEL_SLUG\"")
                    model_replaced=1
                    continue
                elif [[ "$key" == "web_search" ]]; then
                    out+=('web_search = "disabled"')
                    ws_replaced=1
                    continue
                elif [[ "$key" == "show_raw_agent_reasoning" ]]; then
                    out+=('show_raw_agent_reasoning = true')
                    sr_replaced=1
                    continue
                fi
            fi
        else
            # In section area - handle desktop key replacement
            if [[ $desktop_done -eq 1 && "$trimmed" == *=* && "$trimmed" != \#* ]]; then
                local key="${trimmed%%=*}"
                key="${key#"${key%%[![:space:]]*}"}"
                key="${key%"${key##*[![:space:]]}"}"
                if [[ "$key" == "enabled-reasoning-efforts" ]]; then
                    continue  # Already written after [desktop] header
                fi
            fi
        fi

        out+=("$line")
    done

    # Append any remaining missing keys
    if [[ $model_replaced -eq 0 ]]; then
        out+=("model = \"$MODEL_SLUG\"")
    fi
    if [[ $ws_replaced -eq 0 ]]; then
        out+=('web_search = "disabled"')
    fi
    if [[ $sr_replaced -eq 0 ]]; then
        out+=('show_raw_agent_reasoning = true')
    fi
    if [[ $desktop_done -eq 0 ]]; then
        out+=("")
        out+=("[desktop]")
        out+=('enabled-reasoning-efforts = ["low", "medium", "high", "xhigh", "ultra", "max"]')
    fi

    printf '%s\n' "${out[@]}" > "$tmp_config"

    # Generate models.json
    generate_models_json > "$tmp_models"

    # Commit
    mv -f "$tmp_models" "$MODELS_PATH"
    mv -f "$tmp_config" "$CONFIG_PATH"

    write_ok "models.json 已刷新"
    write_ok "config.toml 已更新：model = \"$MODEL_SLUG\"，web_search = \"disabled\"，show_raw_agent_reasoning = true"
    write_ok "[desktop] 的 enabled-reasoning-efforts 已写入"
    echo ''
    write_warn "请完全退出 ChatGPT 桌面端后重新打开，配置才会生效"
    echo '     （右键任务栏托盘图标选择退出；仅关闭窗口进程仍在后台，不算退出）'
    echo ''
}

# ---------------------------------------------------------------- menu + pre-flight state check

show_model_menu() {
    echo ''
    local idx=1
    local -a slug_array=()
    for slug in $MODELS_LIST; do
        local desc="${MODEL_DESCRIPTION[$slug]:-}"
        printf "  %2d. %-26s - %s\n" "$idx" "$slug" "$desc"
        slug_array+=("$slug")
        idx=$((idx + 1))
    done
    echo "  99. 自定义模型（手动输入 slug）"
    echo "  9.  恢复默认的 Codex 配置"
    echo ''

    local choice=""
    local attempt=0
    while true; do
        read -rp "输入 1-$((idx - 1)) / 99 / 9（9 为还原）: " choice
        # Validate
        if [[ "$choice" == "9" || "$choice" == "99" ]]; then
            break
        fi
        if [[ "$choice" =~ ^[0-9]+$ ]]; then
            if [[ $choice -ge 1 && $choice -lt $idx ]]; then
                MODEL_SLUG="${slug_array[$((choice - 1))]}"
                break
            fi
        fi
        attempt=$((attempt + 1))
        if [[ $attempt -ge 3 ]]; then
            die "无效选择，已退出（未修改任何文件）。"
        fi
        write_warn "无效输入，请输入 1-$((idx - 1))、99 或 9。"
    done

    if [[ "$choice" == "9" ]]; then
        set_paths
        do_restore
        return 1
    fi

    if [[ "$choice" == "99" ]]; then
        read -rp "请输入自定义模型 slug: " MODEL_SLUG
        if [[ -z "$MODEL_SLUG" ]]; then
            die "模型 slug 不能为空，已退出（未修改任何文件）。"
        fi
        echo ''
        write_warn "将使用自定义模型：$MODEL_SLUG（不在预置目录中，models.json 仍会写入所有预置模型）"
    fi

    return 0
}

preflight_check() {
    # Check CODEX_HOME exists
    if [[ ! -d "$CODEX_HOME" ]]; then
        die "未找到 Codex 配置目录：\n  $CODEX_HOME\n请先安装并运行一次 Codex CLI / ChatGPT 桌面客户端 / VS Code Codex 插件\n（首次运行会创建该目录），或设置 CODEX_HOME 环境变量后重试。"
    fi
}

# ---------------------------------------------------------------- main dispatcher

main() {
    check_dependencies

    # Show provider-specific header
    write_head "Codex ${PROVIDER_ID^} Setup  v${SCRIPT_VERSION}"
    write_dim "Codex 目录: $CODEX_HOME"

    preflight_check

    set_paths

    # Show model selection menu
    if ! show_model_menu; then
        exit 0
    fi

    # Determine if install or switch
    if [[ -d "$BACKUP_DIR" ]]; then
        # Verify backup matches expectations
        local problems=()
        if [[ ! -f "$MODELS_PATH" ]]; then
            problems+=("  • 缺少 $MODELS_PATH")
        else
            if ! grep -q "$PROVIDER_ID" "$MODELS_PATH" 2>/dev/null; then
                problems+=("  • $MODELS_PATH 里没有任何 $PROVIDER_ID 模型条目")
            fi
        fi
        if [[ ! -f "$CONFIG_PATH" ]]; then
            problems+=("  • 缺少 $CONFIG_PATH")
        else
            if ! grep -q "\[model_providers\.${PROVIDER_ID}\]" "$CONFIG_PATH" 2>/dev/null; then
                problems+=("  • $CONFIG_PATH 中缺少 [model_providers.$PROVIDER_ID]")
            fi
        fi

        if [[ ${#problems[@]} -gt 0 ]]; then
            die "检测到备份目录 $BACKUP_DIR 已存在，\n但当前配置与本脚本的预期不符：\n${problems[*]}\n\n为避免破坏现有文件或那份备份，本次已中止，未修改任何文件。\n\n建议处理方式（二选一）：\n  a) 重新运行本脚本，选择 9 先恢复默认配置，再重新运行选择模型安装；\n  b) 自行检查并删除上述不符合预期的文件，然后重新运行本脚本。"
        fi

        do_switch_model
        exit 0
    fi

    if [[ -f "$MODELS_PATH" ]]; then
        die "检测到已存在：\n  $MODELS_PATH\n\n该文件不是本脚本写入的（没有找到本脚本的备份目录 $BACKUP_DIR）。\n本脚本需要创建这个文件。请先自行删除（或另存）该文件，然后重新运行：\n  rm -f '$MODELS_PATH'\n  $0"
    fi

    do_install
}

main "$@"
