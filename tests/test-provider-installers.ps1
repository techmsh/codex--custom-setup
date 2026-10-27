$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$providers = @(
    [pscustomobject]@{
        Id = 'openrouter'
        BaseUrl = 'https://openrouter.ai/api/v1'
        Env = 'OPENROUTER_API_KEY'
        AltEnv = ''
        Models = @(
            'anthropic/claude-sonnet-5.5',
            'anthropic/claude-opus-5',
            'openai/gpt-6.1-sol',
            'google/gemini-3.1-pro-preview',
            'x-ai/grok-4.7',
            'deepseek/deepseek-v4-pro',
            'qwen/qwen3.8-max-0902',
            'moonshotai/kimi-k3',
            'minimax/minimax-m3',
            'z-ai/glm-5.3',
            'nvidia/nemotron-3-super-120b-a12b',
            'meta/muse-spark-1.2'
        )
    },
    [pscustomobject]@{
        Id = 'xai'
        BaseUrl = 'https://api.x.ai/v1'
        Env = 'XAI_API_KEY'
        AltEnv = ''
        Models = @(
            'grok-4.7',
            'grok-4.6',
            'grok-4.5',
            'grok-4.3',
            'grok-build-0.1',
            'grok-4.20-0309-reasoning',
            'grok-4.20-0309-non-reasoning',
            'grok-4.20-multi-agent-0309'
        )
    },
    [pscustomobject]@{
        Id = 'fireworks'
        BaseUrl = 'https://api.fireworks.ai/inference/v1'
        Env = 'FIREWORKS_API_KEY'
        AltEnv = ''
        Models = @(
            'accounts/fireworks/routers/glm-5p3-spot',
            'accounts/fireworks/routers/kimi-latest',
            'accounts/fireworks/routers/glm-fast-latest',
            'accounts/fireworks/routers/glm-latest',
            'accounts/fireworks/routers/kimi-fast-latest',
            'accounts/fireworks/routers/minimax-latest',
            'accounts/fireworks/routers/deepseek-flash-latest',
            'accounts/fireworks/routers/deepseek-v4p1-flash-spot'
        )
    },
    [pscustomobject]@{
        Id = 'novita'
        BaseUrl = 'https://api.novita.ai/openai/v1'
        Env = 'NOVITA_API_KEY'
        AltEnv = ''
        Models = @(
            'qwen/qwen3.8-max',
            'qwen/qwen3.8-27b',
            'qwen/qwen3.8-flash',
            'qwen/qwen3.8-2.4t-a95b',
            'tencent/hy4-preview',
            'zai-org/glm-5.3',
            'zai-org/glm-5.3-flash',
            'apodex/apodex-1.1-mini'
        )
    },
    [pscustomobject]@{
        Id = 'huggingface'
        BaseUrl = 'https://router.huggingface.co/v1'
        Env = 'HF_TOKEN'
        AltEnv = ''
        Models = @(
            'openai/gpt-oss-20b',
            'openai/gpt-oss-120b',
            'tencent/Hy4-preview',
            'tencent/Hy3',
            'meta-llama/Llama-3.3-70B-Instruct',
            'meta-llama/Llama-3.1-8B-Instruct',
            'google/gemma-3-27b-it'
        )
    },
    [pscustomobject]@{
        Id = 'meta'
        BaseUrl = 'https://api.meta.ai/v1'
        Env = 'META_MODEL_API_KEY'
        AltEnv = 'MODEL_API_KEY'
        Models = @(
            'muse-spark-1.2',
            'muse-spark-1.3',
            'muse-spark-1.2-contributor',
            'muse-spark-1.3-contributor',
            'muse-wonder-1.0',
            'muse-spark-1.1'
        )
    },
    [pscustomobject]@{
        Id = 'stepfun'
        BaseUrl = 'https://api.stepfun.ai/v1'
        Env = 'STEPFUN_API_KEY'
        AltEnv = ''
        Models = @(
            'step-3.7-flash',
            'step-5-preview'
        )
    },
    [pscustomobject]@{
        Id = 'xiaomi'
        BaseUrl = 'https://api.xiaomimimo.com/v1'
        Env = 'XIAOMI_API_KEY'
        AltEnv = ''
        Models = @(
            'mimo-v2.6-flash',
            'mimo-v2.6-pro',
            'mimo-v2.6-pro-ultraspeed'
        )
    }
)

$failures = [System.Collections.Generic.List[string]]::new()

function Assert-Contains {
    param(
        [string]$Path,
        [string]$Value,
        [string]$Label
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        $failures.Add("$Label missing file: $Path")
        return
    }

    $content = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    if (-not $content.Contains($Value)) {
        $failures.Add("$Label missing value '$Value' in $Path")
    }
}

foreach ($provider in $providers) {
    $windowsPath = Join-Path $repoRoot "Windows/codex-$($provider.Id)-setup.ps1"

    Assert-Contains $windowsPath $provider.Id "Windows/$($provider.Id)"
    Assert-Contains $windowsPath $provider.BaseUrl "Windows/$($provider.Id)"
    Assert-Contains $windowsPath $provider.Env "Windows/$($provider.Id)"
    if ($provider.AltEnv) {
        Assert-Contains $windowsPath $provider.AltEnv "Windows/$($provider.Id)"
    }
    foreach ($model in $provider.Models) {
        Assert-Contains $windowsPath $model "Windows/$($provider.Id)"
    }
}

foreach ($provider in $providers) {
    $windowsPath = Join-Path $repoRoot "Windows/codex-$($provider.Id)-setup.ps1"
    foreach ($required in @(
        '$ModelCatalog',
        'wire_api = "responses"',
        'experimental_bearer_token',
        'model_catalog_json',
        'backup-'
    )) {
        Assert-Contains $windowsPath $required "Windows/$($provider.Id) standalone"
    }
    $windowsContent = if (Test-Path -LiteralPath $windowsPath) {
        Get-Content -LiteralPath $windowsPath -Raw -Encoding UTF8
    } else {
        ''
    }
    if ($windowsContent.Contains('provider-core.ps1')) {
        $failures.Add("Windows/$($provider.Id) must be standalone, not a shared-core wrapper")
    }
}

$readmePath = Join-Path $repoRoot 'README.md'
foreach ($provider in $providers) {
    $scriptName = "codex-$($provider.Id)-setup.ps1"
    $rawUrl = "https://raw.githubusercontent.com/techmsh/codex--custom-setup/main/Windows/$scriptName"
    Assert-Contains $readmePath $scriptName "README/$($provider.Id)"
    Assert-Contains $readmePath $rawUrl "README/$($provider.Id) command"
}

if ($failures.Count -gt 0) {
    foreach ($failure in $failures) {
        Write-Host "[FAIL] $failure" -ForegroundColor Red
    }
    Write-Host "`n$($failures.Count) test failure(s)." -ForegroundColor Red
    exit 1
}

Write-Host '[PASS] Provider installer structure and metadata are valid.' -ForegroundColor Green
