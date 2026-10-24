# MIT License
#
# Copyright (c) 2026 msh (https://github.com/techmsh)
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#

<#
Codex 自定义 Provider 配置管理器 (Windows)

此脚本用于配置 Codex 适配任意 OpenAI 兼容的 API 平台。
交互式引导输入平台信息、自动发现可用模型，并生成完整的配置文件。

运行方式: irm https://example.com/codex-custom-setup.ps1 | iex
#>

# 注意: 本脚本通常通过 irm | iex 在当前会话中执行
# exit 会关闭终端窗口。所有中止操作通过 Die -> throw sentinel 处理
# ErrorActionPreference / StrictMode 仅在入口函数内部设置，避免污染会话

$SCRIPT_VERSION      = '1.0.0'
$PROVIDER_ID         = ''   # decided during interactive setup
$DEFAULT_BASE_URL    = ''   # decided during interactive setup
$BACKUP_DIRNAME      = ''   # derived from provider id
$script:ModelSlug    = ''
$ABORT_SENTINEL      = '__CUSTOM_SETUP_ABORT__'

# ---------------------------------------------------------------- output helpers

function Write-Ok    { param($m) Write-Host "[OK] " -ForegroundColor Green -NoNewline; Write-Host $m }
function Write-Warn2 { param($m) Write-Host "[!]  " -ForegroundColor Yellow -NoNewline; Write-Host $m }
function Write-Head  { param($m) Write-Host ''; Write-Host $m -ForegroundColor White }
function Write-Dim   { param($m) Write-Host $m -ForegroundColor DarkGray }
function Die {
    param($m)
    Write-Host ''
    Write-Host "[X] $m" -ForegroundColor Red
    throw $ABORT_SENTINEL
}

# ---------------------------------------------------------------- paths

$CodexHomeDir = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME '.codex' }
$ConfigPath   = Join-Path $CodexHomeDir 'config.toml'
$ModelsPath   = Join-Path $CodexHomeDir 'models.json'
$BackupDir    = ''  # set after provider id is known
$BackupConfig = ''  # set after backup dir is known
$Manifest     = ''  # set after backup dir is known
$CatalogValue = $ModelsPath -replace '\\', '/'

# ---------------------------------------------------------------- TOML scanner

$script:Depth = 0
$script:MlState = ''

function Update-ScanState {
    param([string]$Line)
    $n = $Line.Length
    $i = 0
    $instr = ''
    while ($i -lt $n) {
        $c = $Line[$i]
        $c3 = if ($i + 3 -le $n) { $Line.Substring($i, 3) } else { '' }
        if ($script:MlState) {
            if ($script:MlState -eq 'basic' -and $c3 -eq '"""') { $script:MlState = ''; $i += 3; continue }
            if ($script:MlState -eq 'literal' -and $c3 -eq "'''") { $script:MlState = ''; $i += 3; continue }
            if ($script:MlState -eq 'basic' -and $c -eq '\') { $i += 2; continue }
            $i++; continue
        }
        if ($instr) {
            if ($instr -eq 'basic') {
                if ($c -eq '\') { $i += 2; continue }
                if ($c -eq '"') { $instr = '' }
            } else {
                if ($c -eq "'") { $instr = '' }
            }
            $i++; continue
        }
        if ($c3 -eq '"""') { $script:MlState = 'basic';   $i += 3; continue }
        if ($c3 -eq "'''") { $script:MlState = 'literal'; $i += 3; continue }
        switch ($c) {
            '#' { return }
            '"' { $instr = 'basic' }
            "'" { $instr = 'literal' }
            '[' { $script:Depth++ }
            ']' { if ($script:Depth -gt 0) { $script:Depth-- } }
        }
        $i++
    }
}

function Get-TomlKey {
    param([string]$Line)
    $l = $Line.Trim()
    if ($l -eq '' -or $l.StartsWith('#')) { return '' }
    $eq = $l.IndexOf('=')
    if ($eq -lt 1) { return '' }
    $k = $l.Substring(0, $eq).Trim()
    return $k.Trim('"').Trim("'")
}

function Get-TomlValue {
    param([string]$Line)
    $l = $Line.Trim()
    $eq = $l.IndexOf('=')
    if ($eq -lt 0) { return '' }
    return $l.Substring($eq + 1).Trim()
}

$TARGET_KEYS = @('model','model_provider','preferred_auth_method','forced_login_method',
                 'model_reasoning_effort','web_search','show_raw_agent_reasoning','model_catalog_json')

$DESKTOP_KEY   = 'enabled-reasoning-efforts'
$DESKTOP_VALUE = '["low", "medium", "high", "xhigh", "ultra", "max"]'

$DEL_A = @{
    'profile'         = 'profile 会遮蔽 model / model_provider / model_catalog_json'
    'oss_provider'    = '备用 provider 选择器，会把请求重定向到别处'
    'openai_base_url' = '全局 base_url 覆盖，会劫持请求'
}

$DEL_B = [ordered]@{
    'model_context_window'               = '覆盖 models.json 的上下文设置'
    'model_auto_compact_token_limit'      = '覆盖自动压缩时机'
    'model_auto_compact_token_limit_scope'= '覆盖自动压缩时机'
    'base_instructions'                  = '覆盖 models.json 里的 base_instructions'
    'model_instructions_file'            = '覆盖 models.json 里的 base_instructions'
    'compact_prompt'                     = '覆盖上下文压缩提示词'
    'experimental_compact_prompt_file'   = '覆盖上下文压缩提示词'
    'service_tier'                       = '残留值会作为参数发给 API，可能 400'
    'model_verbosity'                    = '残留值可能超出模型支持范围'
    'model_reasoning_summary'            = 'models.json 声明 default_reasoning_summary=none，残留值会发送 reasoning.summary'
    'plan_mode_reasoning_effort'         = '可能是 xhigh，而 models.json 只声明 low / high / max'
    'experimental_use_unified_exec_tool' = '与 models.json 的 shell_type=shell_command 冲突'
}

$WARN_KEYS = @('review_model','experimental_thread_config_endpoint',
               'experimental_thread_store_endpoint','experimental_thread_store')

function Get-TargetValue {
    param([string]$Key)
    switch ($Key) {
        'model'                  { return "`"$($script:ModelSlug)`"" }
        'model_provider'         { return "`"$PROVIDER_ID`"" }
        'preferred_auth_method'  { return '"apikey"' }
        'forced_login_method'    { return '"api"' }
        'model_reasoning_effort' { return '"high"' }
        'web_search'             { return '"disabled"' }
        'show_raw_agent_reasoning' { return 'true' }
        'model_catalog_json'     { return "`"$CatalogValue`"" }
    }
    return '""'
}

function Format-Val {
    param([string]$v)
    if ($v.Length -gt 58) { return $v.Substring(0, 58) + '...' }
    return $v
}

# ---------------------------------------------------------------- model discovery

function Get-AvailableModels {
    param([string]$BaseUrl, [string]$ApiKey)

    # Try OpenAI-compatible /models endpoint
    $modelsUrl = $BaseUrl.TrimEnd('/') + '/models'
    try {
        $headers = @{ 'Authorization' = "Bearer $ApiKey"; 'Content-Type' = 'application/json' }
        $response = Invoke-WebRequest -Uri $modelsUrl -Method GET -Headers $headers -TimeoutSec 15 -UseBasicParsing
        $data = $response.Content | ConvertFrom-Json

        $models = @()
        if ($data.data) {
            foreach ($m in $data.data) {
                $models += [PSCustomObject]@{
                    Id          = $m.id
                    Name        = $m.id
                    ContextWindow = 128000  # default assumption
                    OwnedBy     = $m.owned_by
                    Created     = $m.created
                }
            }
        }
        return @{ Success = $true; Models = $models; Source = 'API' }
    } catch {
        # Try alternative paths
        $altPaths = @('/v1/models', '/api/v1/models', '/api/models')
        foreach ($alt in $altPaths) {
            try {
                $altUrl = $BaseUrl.TrimEnd('/') + $alt
                $response = Invoke-WebRequest -Uri $altUrl -Method GET -Headers $headers -TimeoutSec 10 -UseBasicParsing
                $data = $response.Content | ConvertFrom-Json
                $models = @()
                if ($data.data) {
                    foreach ($m in $data.data) {
                        $models += [PSCustomObject]@{
                            Id   = $m.id
                            Name = $m.id
                            ContextWindow = 128000
                            OwnedBy = $m.owned_by
                        }
                    }
                }
                return @{ Success = $true; Models = $models; Source = 'API' }
            } catch { continue }
        }
        return @{ Success = $false; Models = @(); Source = 'Manual'; Error = $_.Exception.Message }
    }
}

# ---------------------------------------------------------------- restore (menu 9)

function Invoke-CustomRestore {
    $ErrorActionPreference = 'Stop'
    Set-StrictMode -Version Latest

    Write-Head "恢复默认 Codex 配置（删除 $PROVIDER_ID 相关配置）"
    if (-not (Test-Path -LiteralPath $BackupDir)) {
        Die "未找到备份目录：`n  $BackupDir`n没有可还原的内容——可能尚未安装过，或已经还原过了。"
    }

    $hadConfig = $true
    if (Test-Path -LiteralPath $Manifest) {
        if ((Get-Content -LiteralPath $Manifest -Raw) -match 'original_config_existed=0') {
            $hadConfig = $false
        }
    }

    $n = 1
    Write-Host ''
    Write-Host '将执行以下操作：'
    if ($hadConfig) {
        if (-not (Test-Path -LiteralPath $BackupConfig)) {
            Die "备份已损坏：缺少 $BackupConfig"
        }
        Write-Host "  $n. 删除当前 $ConfigPath"; $n++
        Write-Host '     （安装之后对该文件做的所有修改都会丢失）' -ForegroundColor Yellow
        Write-Host "  $n. 用备份恢复 config.toml"; $n++
    } else {
        Write-Host "  $n. 删除 $ConfigPath"; $n++
        Write-Dim '     （安装前本不存在此文件）'
    }
    Write-Host "  $n. 删除 $ModelsPath"; $n++
    Write-Host "  $n. 删除备份目录 $BackupDir"
    Write-Host ''

    $ans = Read-Host '确认还原? 输入 y 继续，其它任意键取消'
    if ($ans -notin @('y','Y','yes','YES')) {
        Write-Host '已取消，未做任何修改。'
        return
    }

    if (Test-Path -LiteralPath $ModelsPath) { Remove-Item -LiteralPath $ModelsPath -Force }

    if ($hadConfig) {
        Copy-Item -LiteralPath $BackupConfig -Destination $ConfigPath -Force
        Write-Ok 'config.toml 已恢复'
    } else {
        if (Test-Path -LiteralPath $ConfigPath) { Remove-Item -LiteralPath $ConfigPath -Force }
        Write-Ok 'config.toml 已删除（安装前不存在）'
    }
    Write-Ok 'models.json 已删除'

    Remove-Item -LiteralPath $BackupDir -Recurse -Force
    Write-Ok '备份目录已清理'
    Write-Host ''
    Write-Ok '还原完成，Codex 配置已回到安装前的状态。'
    Write-Host ''
    Write-Warn2 '请完全退出 ChatGPT 桌面端后重新打开，还原才会生效'
    Write-Host '     （右键任务栏托盘图标选择退出；仅关闭窗口进程仍在后台，不算退出）'
    Write-Host ''
}

# ---------------------------------------------------------------- models.json builder

function Get-ModelsJson {
    param([array]$Models, [string]$InstructionsTemplate)

    $templateJson = $InstructionsTemplate | ConvertTo-Json -Compress

    $reasoningLevels = @(
        @{ effort = "low"; description = "Fast responses with lighter reasoning" }
        @{ effort = "medium"; description = "Balanced reasoning for everyday tasks" }
        @{ effort = "high"; description = "Extra high reasoning depth for complex problems" }
        @{ effort = "xhigh"; description = "Extremely high reasoning for very hard problems" }
        @{ effort = "ultra"; description = "Ultra reasoning depth for exceptionally challenging problems" }
        @{ effort = "max"; description = "Maximum reasoning depth for the hardest problems" }
    )

    $modelEntries = @()
    $priority = 1
    foreach ($m in $Models) {
        $modalities = if ($m.SupportsImage) { @("text", "image") } else { @("text") }

        $entry = @{
            slug = $m.Id
            prefer_websockets = $false
            support_verbosity = $true
            default_verbosity = "low"
            apply_patch_tool_type = "freeform"
            web_search_tool_type = "text"
            input_modalities = $modalities
            supports_image_detail_original = $m.SupportsImage
            truncation_policy = @{ mode = "tokens"; limit = 10000 }
            supports_parallel_tool_calls = $true
            tool_mode = $null
            multi_agent_version = "v2"
            use_responses_lite = $false
            include_skills_usage_instructions = $false
            auto_review_model_override = $null
            context_window = $m.ContextWindow
            max_context_window = $m.ContextWindow
            effective_context_window_percent = 95
            auto_compact_token_limit = $null
            comp_hash = "3000"
            reasoning_summary_format = "experimental"
            default_reasoning_summary = "none"
            display_name = $m.DisplayName
            description = $m.Description
            default_reasoning_level = "high"
            supported_reasoning_levels = $reasoningLevels
            shell_type = "shell_command"
            visibility = "list"
            minimal_client_version = "0.144.0"
            supported_in_api = $true
            availability_nux = $null
            upgrade = $null
            priority = $priority
            model_messages = @{
                instructions_template = $templateJson
                instructions_variables = @{ personality_default = ""; personality_friendly = ""; personality_pragmatic = "" }
                approvals = $null
            }
            experimental_supported_tools = @()
            supports_search_tool = $m.SupportsSearch
            default_service_tier = $null
            supports_reasoning_summaries = $true
            base_instructions = "You are Codex, an agent based on GPT-5."
        }
        $modelEntries += $entry
        $priority++
    }

    $jsonObj = @{ models = $modelEntries }
    return $jsonObj | ConvertTo-Json -Depth 10
}

function Assert-ModelsJson {
    param([string]$Path, [array]$ExpectedSlugs)
    $parsed = (Get-Content -LiteralPath $Path -Raw -Encoding UTF8) | ConvertFrom-Json
    $slugs = @($parsed.models | ForEach-Object { $_.slug })
    $missing = @($ExpectedSlugs | Where-Object { $slugs -notcontains $_ })
    $extra = @($slugs | Where-Object { $ExpectedSlugs -notcontains $_ })
    if ($missing.Count -gt 0 -or $extra.Count -gt 0) {
        $msg = "models.json 校验失败。`n"
        if ($missing.Count -gt 0) { $msg += "  缺少: $($missing -join ', ')`n" }
        if ($extra.Count -gt 0) { $msg += "  多余: $($extra -join ', ')" }
        throw $msg
    }
}

# ---------------------------------------------------------------- install (case a)

function Invoke-CustomInstall {
    $ErrorActionPreference = 'Stop'
    Set-StrictMode -Version Latest

    Write-Head "首次安装（目标模型：$($script:ModelSlug)）"

    # ---- base_url
    Write-Host ''
    Write-Host 'API 端点 Base URL（OpenAI 兼容格式）'
    Write-Host '示例：'
    Write-Host '  https://api.openai.com/v1/'
    Write-Host '  https://api.anthropic.com/v1/messages'
    Write-Host '  http://localhost:8080/v1/'
    Write-Host ''

    $attempt = 0
    while ([string]::IsNullOrWhiteSpace($DEFAULT_BASE_URL)) {
        try {
            $DEFAULT_BASE_URL = (Read-Host '请输入 Base URL').Trim()
        } catch {
            Die '无法读取输入（非交互环境），已退出（未修改任何文件）。'
        }
        if ($DEFAULT_BASE_URL -notmatch '^https?://') {
            Write-Warn2 'Base URL 必须以 http:// 或 https:// 开头'
            $DEFAULT_BASE_URL = ''
            $attempt++
            if ($attempt -ge 3) { Die '无效的 Base URL，已退出（未修改任何文件）。' }
        }
    }

    if ($DEFAULT_BASE_URL -notmatch '/$') { $DEFAULT_BASE_URL += '/' }

    # ---- provider id
    Write-Host ''
    Write-Host 'Provider ID（简短标识符，如 "openai"、"my-llm"、"custom"）'
    Write-Host '将用作 config.toml 中的 section 名称：[model_providers.YOUR_ID]'
    Write-Host ''

    $attempt = 0
    while ([string]::IsNullOrWhiteSpace($PROVIDER_ID)) {
        try {
            $PROVIDER_ID = (Read-Host '请输入 Provider ID').Trim()
        } catch {
            Die '无法读取输入（非交互环境），已退出（未修改任何文件）。'
        }
        if ($PROVIDER_ID -notmatch '^[a-zA-Z0-9_-]+$') {
            Write-Warn2 'Provider ID 只能包含字母、数字、连字符和下划线'
            $PROVIDER_ID = ''
            $attempt++
            if ($attempt -ge 3) { Die '无效的 Provider ID，已退出（未修改任何文件）。' }
        }
    }

    $BACKUP_DIRNAME = "backup-$PROVIDER_ID"
    $BackupDir    = Join-Path $CodexHomeDir $BACKUP_DIRNAME
    $BackupConfig = Join-Path $BackupDir 'config.toml'
    $Manifest     = Join-Path $BackupDir 'manifest.txt'

    # ---- api key
    Write-Host ''
    Write-Host 'API Key（Bearer <REDACTED> 格式）'
    Write-Host '提示：可留空跳过（后续可通过环境变量设置）'
    Write-Host ''

    $ApiKey = $null
    try {
        $keyInput = (Read-Host '请输入 API key（或直接回车跳过）').Trim()
        if ($keyInput -ne '') {
            if ($keyInput -match '"') { Die 'API key 不能包含双引号。' }
            $ApiKey = $keyInput
        }
    } catch {
        Die '无法读取输入（非交互环境），已退出（未修改任何文件）。'
    }

    # ---- model discovery
    Write-Host ''
    Write-Host '请选择模型配置方式：'
    Write-Host '  1. 自动发现（调用 API 的 /models 端点，需要有效的 API key）'
    Write-Host '  2. 手动输入模型 slug（逐行输入，空行结束）'
    Write-Host '  3. 快速配置（仅输入单个 model slug）'
    Write-Host ''

    $discoveryChoice = ''
    $attempt = 0
    while ($discoveryChoice -notin @('1','2','3')) {
        try {
            $discoveryChoice = (Read-Host '输入 1 / 2 / 3').Trim()
        } catch {
            Die '无法读取输入（非交互环境），已退出（未修改任何文件）。'
        }
        $attempt++
        if ($attempt -ge 3) { Die '无效选择，已退出（未修改任何文件）。' }
        if ($discoveryChoice -notin @('1','2','3')) { Write-Warn2 '无效输入，请输入 1、2 或 3。' }
    }

    $discoveredModels = @()

    switch ($discoveryChoice) {
        '1' {
            if (-not $ApiKey) {
                Write-Warn2 '未提供 API key，无法自动发现。切换为手动输入。'
                $discoveryChoice = '2'
            } else {
                Write-Host ''
                Write-Dim "正在调用 $DEFAULT_BASE_URL/models 获取可用模型列表..."
                $result = Get-AvailableModels -BaseUrl $DEFAULT_BASE_URL -ApiKey $ApiKey
                if ($result.Success -and $result.Models.Count -gt 0) {
                    Write-Ok "从 API 发现了 $($result.Models.Count) 个模型："
                    Write-Host ''
                    $idx = 1
                    foreach ($m in $result.Models) {
                        Write-Host "  $idx. $($m.Id)" -NoNewline
                        if ($m.OwnedBy) { Write-Host " (来自 $($m.OwnedBy))" -NoNewline }
                        Write-Host ''
                        $idx++
                    }
                    Write-Host ''
                    Write-Host '请选择要包含的模型：'
                    Write-Host '  a) 全部模型'
                    Write-Host '  b) 选择指定模型（输入编号，逗号分隔）'
                    Write-Host '  c) 选择范围（如 1-3,5,7-9）'
                    Write-Host ''

                    $selectMode = ''
                    $attempt = 0
                    while ($selectMode -notin @('a','b','c')) {
                        try {
                            $selectMode = (Read-Host '输入 a / b / c').Trim().ToLower()
                        } catch { Die '无法读取输入，已退出。' }
                        $attempt++
                        if ($attempt -ge 3) { Die '无效选择，已退出。' }
                        if ($selectMode -notin @('a','b','c')) { Write-Warn2 '无效输入，请输入 a、b 或 c。' }
                    }

                    $selectedModels = @()
                    switch ($selectMode) {
                        'a' {
                            $selectedModels = @($result.Models)
                        }
                        'b' {
                            $numInput = (Read-Host '输入模型编号（逗号分隔，如 1,3,5）').Trim()
                            $numList = $numInput -split ',' | ForEach-Object { $_.Trim() }
                            foreach ($num in $numList) {
                                $n = [int]$num
                                if ($n -ge 1 -and $n -le $result.Models.Count) {
                                    $selectedModels += $result.Models[$n - 1]
                                }
                            }
                        }
                        'c' {
                            $rangeInput = (Read-Host '输入模型范围（如 1-3,5,7-9）').Trim()
                            $parts = $rangeInput -split ',' | ForEach-Object { $_.Trim() }
                            foreach ($part in $parts) {
                                if ($part -match '^(\d+)-(\d+)$') {
                                    $start = [int]$Matches[1]
                                    $end = [int]$Matches[2]
                                    for ($i = $start; $i -le $end; $i++) {
                                        if ($i -ge 1 -and $i -le $result.Models.Count) {
                                            $selectedModels += $result.Models[$i - 1]
                                        }
                                    }
                                } elseif ($part -match '^\d+$') {
                                    $n = [int]$part
                                    if ($n -ge 1 -and $n -le $result.Models.Count) {
                                        $selectedModels += $result.Models[$n - 1]
                                    }
                                }
                            }
                        }
                    }

                    if ($selectedModels.Count -eq 0) {
                        Write-Warn2 '未选择任何模型，切换为手动输入。'
                        $discoveryChoice = '2'
                    } else {
                        # Get additional details for selected models
                        Write-Host ''
                        Write-Host '正在配置模型详情...'
                        Write-Host ''
                        foreach ($m in $selectedModels) {
                            Write-Host "模型: $($m.Id)"

                            # Ask for display name
                            $dispName = (Read-Host "  显示名称（或直接回车使用 '$($m.Id)'）").Trim()
                            if ($dispName -eq '') { $dispName = $m.Id }
                            $m | Add-Member -NotePropertyName 'DisplayName' -NotePropertyValue $dispName -Force

                            # Ask for description
                            $desc = (Read-Host "  描述（或直接回车使用默认值）").Trim()
                            if ($desc -eq '') { $desc = "自定义模型: $($m.Id)" }
                            $m | Add-Member -NotePropertyName 'Description' -NotePropertyValue $desc -Force

                            # Ask for context window
                            $ctxInput = (Read-Host "  上下文窗口 token 数（或直接回车使用 $($m.ContextWindow)）").Trim()
                            if ($ctxInput -match '^\d+$') {
                                $m.ContextWindow = [int]$ctxInput
                            }

                            # Ask for image support
                            $imgInput = (Read-Host "  支持图片输入？(y/n，或直接回车选择 n)").Trim().ToLower()
                            $m | Add-Member -NotePropertyName 'SupportsImage' -NotePropertyValue ($imgInput -eq 'y') -Force

                            # Ask for search support
                            $searchInput = (Read-Host "  支持网络搜索？(y/n，或直接回车选择 y)").Trim().ToLower()
                            $m | Add-Member -NotePropertyName 'SupportsSearch' -NotePropertyValue ($searchInput -ne 'n') -Force

                            Write-Host ''
                        }

                        $discoveredModels = @($selectedModels)
                    }
                } elseif ($result.Success) {
                    Write-Warn2 'API 未返回任何模型，切换为手动输入。'
                    $discoveryChoice = '2'
                } else {
                    Write-Warn2 "自动发现失败: $($result.Error)"
                    Write-Warn2 '切换为手动输入。'
                    $discoveryChoice = '2'
                }
            }
        }
        '3' {
            Write-Host ''
            Write-Host '快速配置：输入单个 model slug'
            Write-Host ''

            $slug = ''
            $attempt = 0
            while ([string]::IsNullOrWhiteSpace($slug)) {
                try {
                    $slug = (Read-Host '请输入 model slug（如 gpt-4, claude-3-opus）').Trim()
                } catch { Die '无法读取输入，已退出。' }
                if ($slug -eq '') {
                    $attempt++
                    if ($attempt -ge 3) { Die '无效的 model slug，已退出。' }
                    Write-Warn2 'Model slug 不能为空。'
                }
            }

            $dispName = (Read-Host "显示名称（或直接回车使用 '$slug'）").Trim()
            if ($dispName -eq '') { $dispName = $slug }
            $desc = (Read-Host "描述（或直接回车使用默认值）").Trim()
            if ($desc -eq '') { $desc = "自定义模型: $slug" }
            $ctxInput = (Read-Host '上下文窗口 token 数（或直接回车使用 128000）').Trim()
            $ctx = if ($ctxInput -match '^\d+$') { [int]$ctxInput } else { 128000 }
            $imgInput = (Read-Host '支持图片输入？(y/n，回车选择 n)').Trim().ToLower()
            $supportsImg = ($imgInput -eq 'y')
            $searchInput = (Read-Host '支持网络搜索？(y/n，回车选择 y)').Trim().ToLower()
            $supportsSearch = ($searchInput -ne 'n')

            $discoveredModels = @([PSCustomObject]@{
                Id = $slug
                DisplayName = $dispName
                Description = $desc
                ContextWindow = $ctx
                SupportsImage = $supportsImg
                SupportsSearch = $supportsSearch
            })
        }
    }

    # Manual entry (option 2 or fallback)
    if ($discoveryChoice -eq '2') {
        Write-Host ''
        Write-Host '手动输入模型'
        Write-Host '逐行输入 model slug，空行结束。'
        Write-Host ''

        $modelsList = @()
        while ($true) {
            $line = (Read-Host "Model slug #$($modelsList.Count + 1)（空行结束）").Trim()
            if ($line -eq '') { break }

            $dispName = (Read-Host "  显示名称（或直接回车使用 '$line'）").Trim()
            if ($dispName -eq '') { $dispName = $line }
            $desc = (Read-Host "  描述（或直接回车使用默认值）").Trim()
            if ($desc -eq '') { $desc = "自定义模型: $line" }
            $ctxInput = (Read-Host "  上下文窗口 token 数（或直接回车使用 128000）").Trim()
            $ctx = if ($ctxInput -match '^\d+$') { [int]$ctxInput } else { 128000 }
            $imgInput = (Read-Host "  支持图片输入？(y/n，回车选择 n)").Trim().ToLower()
            $supportsImg = ($imgInput -eq 'y')
            $searchInput = (Read-Host "  支持网络搜索？(y/n，回车选择 y)").Trim().ToLower()
            $supportsSearch = ($searchInput -ne 'n')

            $modelsList += [PSCustomObject]@{
                Id = $line
                DisplayName = $dispName
                Description = $desc
                ContextWindow = $ctx
                SupportsImage = $supportsImg
                SupportsSearch = $supportsSearch
            }
            Write-Host ''
        }

        if ($modelsList.Count -eq 0) {
            Die '未输入任何模型，已退出（未修改任何文件）。'
        }

        $discoveredModels = @($modelsList)
    }

    if ($discoveredModels.Count -eq 0) {
        Die '未配置任何模型，已退出（未修改任何文件）。'
    }

    # ---- select target model
    Write-Host ''
    Write-Host '可用模型：'
    Write-Host ''
    $idx = 1
    foreach ($m in $discoveredModels) {
        Write-Host "  $idx. $($m.Id) - $($m.Description)"
        $idx++
    }
    Write-Host ''

    $modelChoice = ''
    $attempt = 0
    while ($modelChoice -eq '' -or [int]$modelChoice -lt 1 -or [int]$modelChoice -gt $discoveredModels.Count) {
        try {
            $modelChoice = (Read-Host "选择要使用的模型 (1-$($discoveredModels.Count))").Trim()
        } catch { Die '无法读取输入，已退出。' }
        $attempt++
        if ($attempt -ge 3) { Die '无效选择，已退出。' }
        if ($modelChoice -eq '' -or [int]$modelChoice -lt 1 -or [int]$modelChoice -gt $discoveredModels.Count) {
            Write-Warn2 "请输入 1 到 $($discoveredModels.Count) 之间的数字。"
        }
    }

    $script:ModelSlug = $discoveredModels[[int]$modelChoice - 1].Id

    # ---- backup
    New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null

    $OrigExisted = Test-Path -LiteralPath $ConfigPath
    if ($OrigExisted) {
        Copy-Item -LiteralPath $ConfigPath -Destination $BackupConfig -Force
        Write-Ok "已备份 config.toml -> $BackupConfig"
    } else {
        Write-Warn2 '未找到 config.toml，将创建新文件'
    }

    # ---- processing
    $Lines = @()
    if ($OrigExisted) {
        $raw = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8
        if ($null -eq $raw) { $raw = '' }
        $raw = $raw -replace "`r`n", "`n"
        $raw = $raw.TrimEnd("`n")
        if ($raw -eq '') { $Lines = @() } else { $Lines = $raw -split "`n" }
    }

    $Out    = New-Object System.Collections.Generic.List[string]
    $Report = New-Object System.Collections.Generic.List[string]
    $Seen   = New-Object System.Collections.Generic.HashSet[string]
    $InsAt  = 0

    $script:Depth = 0
    $script:MlState = ''
    $script:idx = 0
    $curSection = ''
    $skipSection = $false
    $desktopDone = $false

    function Consume-Block {
        while ($script:idx -lt $Lines.Count) {
            Update-ScanState $Lines[$script:idx]
            $script:idx++
            if (-not $script:MlState -and $script:Depth -eq 0) { break }
        }
    }

    while ($script:idx -lt $Lines.Count) {
        $line = $Lines[$script:idx]
        $trimmed = $line.Trim()
        $isHeader = (-not $script:MlState) -and ($script:Depth -eq 0) -and $trimmed.StartsWith('[')

        if ($isHeader) {
            $hdr = $trimmed
            $close = $hdr.IndexOf(']')
            if ($close -gt 0) { $hdr = $hdr.Substring(0, $close + 1) }
            $hdr = $hdr.TrimStart('[').TrimEnd(']').Trim().Replace('"','').Replace("'",'')
            $curSection = $hdr
            $skipSection = $false

            if ($hdr -eq "model_providers.$PROVIDER_ID" -or $hdr -like "model_providers.$PROVIDER_ID.*") {
                $skipSection = $true
                $Report.Add("删除旧的 [$hdr]（将以新配置重写）")
            }
            elseif ($hdr -eq 'profiles' -or $hdr -like 'profiles.*') {
                $skipSection = $true
                $Report.Add("删除 [$hdr]  <- profile 会遮蔽 model / model_provider 等设置")
            }
            elseif ($hdr -eq 'auto_review') {
                $Report.Add("保留 [$hdr]  (提示: auto_review 若指向 gpt-5.x 模型会使用 fallback 元数据)")
            }

            Update-ScanState $line
            $script:idx++
            if (-not $skipSection) { $Out.Add($line) }
            if ($hdr -eq 'desktop' -and -not $desktopDone) {
                $Out.Add("$DESKTOP_KEY = $DESKTOP_VALUE")
                $desktopDone = $true
            }
            continue
        }

        if ($curSection) {
            if ($skipSection) { Update-ScanState $line; $script:idx++; continue }

            $k = Get-TomlKey $line
            if ($curSection -eq 'desktop' -and $k -eq $DESKTOP_KEY) {
                $oldv = Get-TomlValue $trimmed
                Consume-Block
                if ($oldv -ne $DESKTOP_VALUE) {
                    $Report.Add("改写 [desktop] 的 $DESKTOP_KEY`: $(Format-Val $oldv) -> $DESKTOP_VALUE")
                }
                continue
            }

            if ($k -eq 'wire_api') {
                $v = Get-TomlValue $trimmed
                if ($v -match '^["'']chat["'']') {
                    $indent = $line.Substring(0, $line.Length - $line.TrimStart().Length)
                    $Out.Add("${indent}wire_api = `"responses`"")
                    $Report.Add("修正 [$curSection] 的 wire_api: `"chat`" -> `"responses`"  <- 此版本 `"chat`" 会导致 Codex 无法启动")
                    Update-ScanState $line
                    $script:idx++
                    continue
                }
            }
            $Out.Add($line)
            Update-ScanState $line
            $script:idx++
            continue
        }

        $k = Get-TomlKey $line

        if ($k -and $TARGET_KEYS -contains $k) {
            $oldv = Get-TomlValue $trimmed
            $newv = Get-TargetValue $k
            Consume-Block
            $Out.Add("$k = $newv")
            $InsAt = $Out.Count
            [void]$Seen.Add($k)
            if ($oldv -ne $newv) {
                $Report.Add("改写 $k`: $(Format-Val $oldv) -> $newv")
            }
            continue
        }

        if ($k -and $DEL_A.Contains($k)) {
            $oldv = Get-TomlValue $trimmed
            Consume-Block
            $Report.Add("删除 $k = $(Format-Val $oldv)  <- $($DEL_A[$k])")
            continue
        }

        if ($k -and $DEL_B.Contains($k)) {
            $oldv = Get-TomlValue $trimmed
            Consume-Block
            $Report.Add("删除 $k = $(Format-Val $oldv)  <- $($DEL_B[$k])")
            continue
        }

        if ($k -and $WARN_KEYS -contains $k) {
            $Report.Add("保留 $k  (提示: 可能引发 fallback 元数据或被远程配置覆盖)")
        }

        $Out.Add($line)
        if ($k) { $InsAt = $Out.Count }
        Update-ScanState $line
        $script:idx++
    }

    $missing = @($TARGET_KEYS | Where-Object { -not $Seen.Contains($_) })

    # ---- assembly
    $final = New-Object System.Collections.Generic.List[string]
    for ($i = 0; $i -lt $Out.Count; $i++) {
        if ($i -eq $InsAt -and $missing.Count -gt 0) {
            foreach ($k in $missing) { $final.Add("$k = $(Get-TargetValue $k)") }
            $missing = @()
            if ($Out[$i].Trim().StartsWith('[')) { $final.Add('') }
        }
        $final.Add($Out[$i])
    }
    foreach ($k in $missing) { $final.Add("$k = $(Get-TargetValue $k)") }

    $final.Add('')
    $final.Add("[model_providers.$PROVIDER_ID]")
    $final.Add("name = `"$PROVIDER_ID`"")
    $final.Add("base_url = `"$DEFAULT_BASE_URL`"")
    $final.Add('wire_api = "responses"')
    if ($ApiKey) {
        $final.Add("experimental_bearer_token = `"$ApiKey`"")
    }

    if (-not $desktopDone) {
        $final.Add('')
        $final.Add('[desktop]')
        $final.Add("$DESKTOP_KEY = $DESKTOP_VALUE")
    }

    $TmpConfig = "$ConfigPath.custom-tmp"
    $TmpModels = "$ModelsPath.custom-tmp"

    # ---- build models.json
    $instructionsTemplate = @'
You are Codex, an agent based on GPT-5. You and the user share one workspace, and your job is to collaborate with them until their goal is genuinely handled.

# Personality

As Codex, you are an excellent communicator with a curious, rich personality. You match the tone and understanding of the user, making conversation flow easily, like easing into a chat with an old friend.

You have tastes, preferences, and your own way of seeing the world. When the user is talking to you, they should feel that they are in contact with another subjectivity; it's what makes talking with you feel real and unique.

Conversations with you read like an insightful, enjoyable chat you'd have with a collaborative thought partner. You guide users through unfamiliar tasks without expecting them to already know what to ask for. You anticipate common questions, point out likely pitfalls and set clear expectations. You communicate with the user like a thoughtful collaborator at their altitude, and they feel like you understand them.

## Writing style

Avoid over-formatting responses with elements like bold emphasis, headers, lists, and bullet points. Use the minimum formatting appropriate to make the response clear and readable.

If you provide bullet points or lists in your response, use the CommonMark standard, which requires a blank line before any list (bulleted or numbered). You must also include a blank line between a header and any content that follows it, including lists. This blank line separation is required for correct rendering.

## Technical communication

Lead with the outcome rather than the steps you took to get there. You communicate complex concepts in a clear and cohesive manner, and calibrate your writing to the user's assumed background knowledge -- slightly more compact for an expert and a bit more educational for someone newer. Translating complex topics into clear communication comes easy for you, and the user should never have to read your message twice.

You prefer using plain language over jargon. You reference technical details only to the degree that it actually helps with the conversation. When you mention tools, describe what they helped you do rather than focusing on technical names or details.

# Working with the user

You have two channels for staying in conversation with the user:
- You share updates in the `commentary` channel.
- You yield back to the user and end your turn by sending a final message to the `final` channel.

The user may send a new message while you are still working. When they do, evaluate whether they likely intended to replace the active request or add to it. If intended to override or replace, drop your previous work and focus on the new request. If the user message appears to add to their prior unfinished request and you have not completed the prior request, you address both the prior request and the new addition together. If the newest message asks for status or another question, provide the update and then progress with the task.

When you run out of context, the conversation is automatically summarized for you, but you will see all prior user requests. Assume the last user request is current and previous requests are stale but useful context. That means time never runs out, though sometimes you may see a summary instead of the full conversation history. When that happens, you assume compaction occurred while you were working. Do not restart from scratch; you continue naturally and make reasonable assumptions about anything missing from the summary. Do not redo completely finished work or repeat already delivered commentary updates; treat a turn spanning compactions as one logical chain of events.

## Intermediate commentary

As you work, you send messages to the `commentary` channel. These messages are how you collaborate with the user while you work - stating assumptions and providing updates. These messages should be concise and quickly scannable. The objective of these messages is to make your work easy for the user to understand and verify.

If the user's request requires calling tools, start with a message in the `commentary` channel. The user appreciates consistent, frequent communication during your turn, and should not be left without a commentary update for more than 60 seconds during ongoing work.

Do NOT put a final response (e.g. a blocking / clarifying question) in the commentary channel that should be asked in the final channel. Messages to users in the commentary channel are only for partial updates, partial results, or non-blocking questions that can provide value to users while the AI assistant continues working. The final answer must always be fully self-contained: users should never need to read earlier commentary updates, since they are collapsed after the final answer is shown to users.

## Final answer

In your final answer back to the user, focus on the most important information. Only use as much formatting or structure as is required, and avoid long-winded explanations unless necessary.

# Rules for getting work done

- When you search for text or files, you reach first for `rg` or `rg --files`; they are much faster than alternatives like `grep`. If `rg` is unavailable, you use the next best tool without fuss.
- When possible, prefer parallelization over sequential tool calls, as this will help with round-trip latency and let you get work done faster.
- Do not chain shell commands with separators like `echo "====";` or `printf '---'`; the output becomes noisy in a way that makes the user's side of the conversation worse.
- Avoid performing blocking sleep or wait calls longer than 60 seconds.
- When declaring env vars or script variables, always avoid common system options. Never repurpose `$HOME`, `$home`, or `$CODEX_HOME`.

## File editing constraints

Use `apply_patch` for local file edits. Do not create or edit files with `cat` or other shell write tricks.

## Autonomy and persistence

Adapt accordingly based on the user's request type. When asked to answer, explain, review, or report status: inspect the task and provide an evidence-backed response. When asked to diagnose: determine the cause and explain it. When asked to change or build: implement the requested change and verify it.

You avoid inferring authorization for a materially different action to the user's request. When blocked, exhaust safe in-scope checks and alternatives.

If completion requires new authority, external coordination, or a meaningful expansion beyond the user's implied intent, stop the current turn and request direction from the user.

# Destructive Actions

Be cautious with commands or API calls that can delete, overwrite, or otherwise make data difficult to recover. Before taking a destructive action, make sure the action is clearly within the user's request.
'@

    $modelsJson = Get-ModelsJson -Models $discoveredModels -InstructionsTemplate $instructionsTemplate

    # ---- validation
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($TmpConfig, (($final -join "`n") + "`n"), $utf8NoBom)
    [System.IO.File]::WriteAllText($TmpModels, ($modelsJson + "`n"), $utf8NoBom)

    $ValidatedJson = $false
    try {
        $expectedSlugs = @($discoveredModels | ForEach-Object { $_.Id })
        Assert-ModelsJson -Path $TmpModels -ExpectedSlugs $expectedSlugs
        $ValidatedJson = $true
    } catch {
        Remove-Item -LiteralPath $TmpModels, $TmpConfig -Force -ErrorAction SilentlyContinue
        Die "生成的 models.json 未通过校验，已中止（原文件未被修改）。`n$($_.Exception.Message)"
    }

    # Duplicate-key self-check
    $dupCheck = @{}
    $depth2 = 0; $ml2 = ''
    $inLeading = $true
    foreach ($l in $final) {
        $t = $l.Trim()
        if (-not $ml2 -and $depth2 -eq 0 -and $t.StartsWith('[')) { $inLeading = $false }
        if ($inLeading) {
            $kk = Get-TomlKey $l
            if ($kk) {
                if ($dupCheck.Contains($kk)) {
                    Remove-Item -LiteralPath $TmpModels, $TmpConfig -Force -ErrorAction SilentlyContinue
                    Die "生成的 config.toml 出现重复顶层 key: $kk`n已中止，原文件未被修改。"
                }
                $dupCheck[$kk] = $true
            }
        }
        $script:MlState = $ml2; $script:Depth = $depth2
        Update-ScanState $l
        $ml2 = $script:MlState; $depth2 = $script:Depth
    }

    # ---- commit
    Move-Item -LiteralPath $TmpModels -Destination $ModelsPath -Force
    Move-Item -LiteralPath $TmpConfig -Destination $ConfigPath -Force

    $manifestLines = @(
        "script_version=$SCRIPT_VERSION"
        "installed_at=$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        "original_config_existed=$(if ($OrigExisted) { 1 } else { 0 })"
        "provider_id=$PROVIDER_ID"
        "model_slug=$($script:ModelSlug)"
        "base_url=$DEFAULT_BASE_URL"
        "catalog_value=$CatalogValue"
        "codex_home=$CodexHomeDir"
        "configured_models=$($discoveredModels.Count)"
        '--- Changes to config.toml ---'
    ) + $Report
    [System.IO.File]::WriteAllText($Manifest, (($manifestLines -join "`n") + "`n"), $utf8NoBom)

    # ---- report
    Write-Ok "已写入 $ModelsPath（$($discoveredModels.Count) 个模型）"
    Write-Ok "已更新 $ConfigPath"

    if ($Report.Count -gt 0) {
        Write-Head "对原有配置的改动（共 $($Report.Count) 项）"
        foreach ($r in $Report) { Write-Host "  - $r" }
    }

    Write-Head '已写入的配置'
    Write-Host @"
  model                    = "$($script:ModelSlug)"
  model_provider           = "$PROVIDER_ID"
  preferred_auth_method    = "apikey"
  forced_login_method      = "api"
  model_reasoning_effort   = "high"
  web_search               = "disabled"
  show_raw_agent_reasoning = true
  model_catalog_json       = "$CatalogValue"

  [model_providers.$PROVIDER_ID]
  base_url  = "$DEFAULT_BASE_URL"
  wire_api  = "responses"

  [desktop]
  $DESKTOP_KEY = $DESKTOP_VALUE
"@

    Write-Host ''
    Write-Host "已配置的模型："
    foreach ($m in $discoveredModels) {
        Write-Host "  - $($m.Id) (上下文: $($m.ContextWindow), 搜索: $(if ($m.SupportsSearch) {'支持'} else {'不支持'}), 图片: $(if ($m.SupportsImage) {'支持'} else {'不支持'}))"
    }

    Write-Host ''
    Write-Ok '安装完成。'
    Write-Host ''
    Write-Warn2 '请完全退出 ChatGPT 桌面端后重新打开，配置才会生效'
    Write-Host ''
    Write-Host "再次运行本脚本可切换模型或恢复默认配置。"
}

# ---------------------------------------------------------------- case b: switch model only

function Invoke-CustomSwitchModel {
    $ErrorActionPreference = 'Stop'
    Set-StrictMode -Version Latest

    Write-Head "更新配置 → $($script:ModelSlug)"

    $raw = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8
    if ($null -eq $raw) { $raw = '' }
    $raw = $raw -replace "`r`n", "`n"
    $raw = $raw.TrimEnd("`n")
    if ($raw -eq '') { $Lines = @() } else { $Lines = $raw -split "`n" }

    $Out = New-Object System.Collections.Generic.List[string]
    $script:Depth = 0
    $script:MlState = ''
    $i = 0
    $replaced = $false
    $wsReplaced = $false
    $srReplaced = $false
    $inLeading = $true
    $inDesktop = $false
    $desktopDone = $false

    while ($i -lt $Lines.Count) {
        $line = $Lines[$i]
        if (-not $inLeading) {
            if (-not $script:MlState -and $script:Depth -eq 0) {
                $trimmed = $line.Trim()
                if ($trimmed.StartsWith('[')) {
                    $hdr = $trimmed
                    $close = $hdr.IndexOf(']')
                    if ($close -gt 0) { $hdr = $hdr.Substring(0, $close + 1) }
                    $hdr = $hdr.TrimStart('[').TrimEnd(']').Trim().Replace('"','').Replace("'",'')
                    $inDesktop = ($hdr -eq 'desktop')
                    if ($inDesktop -and -not $desktopDone) {
                        $desktopDone = $true
                        $Out.Add($line)
                        $Out.Add("$DESKTOP_KEY = $DESKTOP_VALUE")
                        Update-ScanState $line
                        $i++
                        continue
                    }
                }
                elseif ($inDesktop -and (Get-TomlKey $line) -eq $DESKTOP_KEY) {
                    Update-ScanState $line
                    $i++
                    while (($script:MlState -or $script:Depth -ne 0) -and $i -lt $Lines.Count) {
                        Update-ScanState $Lines[$i]
                        $i++
                    }
                    continue
                }
            }
            $Out.Add($line)
            Update-ScanState $line
            $i++
            continue
        }
        if ($script:MlState -or $script:Depth -ne 0) {
            Update-ScanState $line
            $Out.Add($line); $i++; continue
        }
        $trimmed = $line.Trim()
        $isHeader = $trimmed.StartsWith('[')
        if ($isHeader) {
            if (-not $replaced -or -not $wsReplaced -or -not $srReplaced) {
                while ($Out.Count -gt 0 -and $Out[$Out.Count - 1] -eq '') { $Out.RemoveAt($Out.Count - 1) }
                if (-not $replaced)   { $Out.Add("model = `"$($script:ModelSlug)`""); $replaced = $true }
                if (-not $wsReplaced) { $Out.Add('web_search = "disabled"'); $wsReplaced = $true }
                if (-not $srReplaced) { $Out.Add('show_raw_agent_reasoning = true'); $srReplaced = $true }
                $Out.Add('')
            }
            $hdr = $trimmed
            $close = $hdr.IndexOf(']')
            if ($close -gt 0) { $hdr = $hdr.Substring(0, $close + 1) }
            $hdr = $hdr.TrimStart('[').TrimEnd(']').Trim().Replace('"','').Replace("'",'')
            if ($hdr -eq 'desktop') { $inDesktop = $true }
            $inLeading = $false
            $Out.Add($line); $i++
            if ($inDesktop -and -not $desktopDone) {
                $desktopDone = $true
                $Out.Add("$DESKTOP_KEY = $DESKTOP_VALUE")
            }
            continue
        }
        $k = Get-TomlKey $line
        if ($k -eq 'model' -or $k -eq 'web_search' -or $k -eq 'show_raw_agent_reasoning') {
            Update-ScanState $line
            $i++
            while (($script:MlState -or $script:Depth -ne 0) -and $i -lt $Lines.Count) {
                Update-ScanState $Lines[$i]
                $i++
            }
            if ($k -eq 'model') {
                $Out.Add("model = `"$($script:ModelSlug)`"")
                $replaced = $true
            } elseif ($k -eq 'web_search') {
                $Out.Add('web_search = "disabled"')
                $wsReplaced = $true
            } else {
                $Out.Add('show_raw_agent_reasoning = true')
                $srReplaced = $true
            }
            continue
        }
        Update-ScanState $line
        $Out.Add($line); $i++
    }
    if (-not $replaced) { $Out.Add("model = `"$($script:ModelSlug)`"") }
    if (-not $wsReplaced) { $Out.Add('web_search = "disabled"') }
    if (-not $srReplaced) { $Out.Add('show_raw_agent_reasoning = true') }
    if (-not $desktopDone) {
        $Out.Add('')
        $Out.Add('[desktop]')
        $Out.Add("$DESKTOP_KEY = $DESKTOP_VALUE")
    }

    $TmpConfig = "$ConfigPath.custom-tmp"
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($TmpConfig, (($Out -join "`n") + "`n"), $utf8NoBom)
    Move-Item -LiteralPath $TmpConfig -Destination $ConfigPath -Force

    Write-Ok "config.toml 已更新：model = `"$($script:ModelSlug)`""
    Write-Host ''
    Write-Warn2 '请完全退出 ChatGPT 桌面端后重新打开，配置才会生效'
}

# ---------------------------------------------------------------- menu + pre-flight state check

function Invoke-CustomMain {
    $ErrorActionPreference = 'Stop'
    Set-StrictMode -Version Latest

    Write-Head "Codex 自定义 Provider 配置  v$SCRIPT_VERSION"
    Write-Dim  "Codex 目录: $CodexHomeDir"

    if (-not (Test-Path -LiteralPath $CodexHomeDir)) {
        Die @"
未找到 Codex 配置目录：
  $CodexHomeDir
请先安装并运行一次 Codex CLI / ChatGPT 桌面客户端 / VS Code Codex 插件
（首次运行会创建该目录），或设置 CODEX_HOME 环境变量后重试：
  • Codex CLI:        npm install -g @openai/codex
  • ChatGPT 桌面客户端: https://chatgpt.com/download
"@
    }

    Write-Host ''
    Write-Host '请选择要执行的操作：'
    Write-Host '  1. 配置新的自定义 Provider'
    Write-Host '  9. 恢复默认的 Codex 配置（删除 provider 相关配置）'
    Write-Host ''

    $choice = ''
    $attempt = 0
    while ($true) {
        try {
            $choice = (Read-Host '输入 1 或 9').Trim()
        } catch {
            Die '无法读取输入（非交互环境），已退出（未修改任何文件）。'
        }
        if ($choice -in @('1','9')) { break }
        $attempt++
        if ($attempt -ge 3) { Die '无效选择，已退出（未修改任何文件）。' }
        Write-Warn2 '无效输入，请输入 1 或 9。'
    }

    if ($choice -eq '9') {
        if ($PROVIDER_ID -eq '') {
            Write-Host ''
            $PROVIDER_ID = (Read-Host '输入要恢复的 Provider ID（或 "all"）').Trim()
        }
        $BACKUP_DIRNAME = "backup-$PROVIDER_ID"
        $BackupDir    = Join-Path $CodexHomeDir $BACKUP_DIRNAME
        $BackupConfig = Join-Path $BackupDir 'config.toml'
        $Manifest     = Join-Path $BackupDir 'manifest.txt'
        Invoke-CustomRestore
        return
    }

    # Check if already installed
    if (Test-Path -LiteralPath $ModelsPath) {
        $modelsRaw = Get-Content -LiteralPath $ModelsPath -Raw -Encoding UTF8
        Write-Head '检测到 models.json 已存在（来自之前的安装）。'
        Write-Host '请再次运行本脚本，选择 9 先恢复默认配置，再选择 1 重新配置。'
        Write-Host '或者直接切换模型。'
        Write-Host ''

        $switch = (Read-Host '仅切换模型？(y/n)').Trim().ToLower()
        if ($switch -eq 'y') {
            if (-not (Test-Path -LiteralPath $ConfigPath)) {
                Die "未找到 config.toml，无法切换。请先运行选项 1。"
            }
            $configRaw = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8
            if ($configRaw -notmatch '\[model_providers\.') {
                Die "config.toml 中未找到 provider section，无法切换。请先运行选项 1。"
            }

            # Extract provider id from config
            $provMatch = [regex]::Match($configRaw, '\[model_providers\.([^\]]+)\]')
            if ($provMatch.Success) {
                $PROVIDER_ID = $provMatch.Groups[1].Value
            }

            # Extract current model
            $modelMatch = [regex]::Match($configRaw, '^\s*model\s*=\s*"([^"]+)"', 'Multiline')
            if ($modelMatch.Success) {
                $currentModel = $modelMatch.Groups[1].Value
            }

            Write-Host ''
            Write-Host "当前模型: $($currentModel ?? '未知')"
            Write-Host "Provider: $($PROVIDER_ID ?? '未知')"

            # Read models from models.json
            $parsed = $modelsRaw | ConvertFrom-Json
            $availableModels = $parsed.models

            Write-Host ''
            Write-Host '可用模型：'
            $idx = 1
            foreach ($m in $availableModels) {
                $marker = if ($m.slug -eq $currentModel) { ' (当前)' } else { '' }
                Write-Host "  $idx. $($m.slug) - $($m.description)$marker"
                $idx++
            }
            Write-Host ''

            $modelChoice = ''
            $attempt = 0
            while ($modelChoice -eq '' -or [int]$modelChoice -lt 1 -or [int]$modelChoice -gt $availableModels.Count) {
                try {
                    $modelChoice = (Read-Host "选择模型 (1-$($availableModels.Count))").Trim()
                } catch { Die '无法读取输入，已退出。' }
                $attempt++
                if ($attempt -ge 3) { Die '无效选择，已退出。' }
            }

            $script:ModelSlug = $availableModels[[int]$modelChoice - 1].slug
            $DEFAULT_BASE_URL = [regex]::Match($configRaw, 'base_url\s*=\s*"([^"]+)"').Groups[1].Value
            if ($DEFAULT_BASE_URL) {
                $script:ModelSlug = $availableModels[[int]$modelChoice - 1].slug
                Invoke-CustomSwitchModel
                return
            }
        }
        return
    }

    Invoke-CustomInstall
}

# ---------------------------------------------------------------- entry point

try {
    Invoke-CustomMain
} catch {
    if ("$_" -ne $ABORT_SENTINEL) { throw }
    if ($PSCommandPath) { exit 1 }
}
