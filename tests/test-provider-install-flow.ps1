$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$tempRoot = Join-Path $PSScriptRoot '.tmp-provider-install'
$providers = @(
    @{ Id = 'openrouter'; Env = 'OPENROUTER_API_KEY'; Model = 'anthropic/claude-sonnet-5.5' },
    @{ Id = 'xai'; Env = 'XAI_API_KEY'; Model = 'grok-4.7' },
    @{ Id = 'fireworks'; Env = 'FIREWORKS_API_KEY'; Model = 'accounts/fireworks/routers/glm-5p3-spot' },
    @{ Id = 'novita'; Env = 'NOVITA_API_KEY'; Model = 'qwen/qwen3.8-max' },
    @{ Id = 'huggingface'; Env = 'HF_TOKEN'; Model = 'openai/gpt-oss-20b' },
    @{ Id = 'meta'; Env = 'META_MODEL_API_KEY'; Model = 'muse-spark-1.2' },
    @{ Id = 'stepfun'; Env = 'STEPFUN_API_KEY'; Model = 'step-3.7-flash' },
    @{ Id = 'xiaomi'; Env = 'XIAOMI_API_KEY'; Model = 'mimo-v2.6-flash' }
)

function Reset-TestHome {
    if (Test-Path -LiteralPath $tempRoot) {
        $resolved = (Resolve-Path -LiteralPath $tempRoot).Path
        $allowed = (Resolve-Path -LiteralPath $PSScriptRoot).Path + [IO.Path]::DirectorySeparatorChar
        if (-not $resolved.StartsWith($allowed, [StringComparison]::OrdinalIgnoreCase)) {
            throw "Refusing to remove unexpected test path: $resolved"
        }
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
}

function Invoke-Installer {
    param(
        [string]$Path,
        [string]$InputText
    )

    $output = $InputText | & pwsh -NoProfile -File $Path 2>&1
    return @{
        ExitCode = $LASTEXITCODE
        Output = ($output | Out-String)
    }
}

$previousCodexHome = $env:CODEX_HOME
try {
    foreach ($provider in $providers) {
        Reset-TestHome
        $env:CODEX_HOME = $tempRoot
        Set-Item -Path "Env:$($provider.Env)" -Value 'test-key-not-real'

        $scriptPath = Join-Path $repoRoot "Windows/codex-$($provider.Id)-setup.ps1"
        $result = Invoke-Installer -Path $scriptPath -InputText "1`n"
        if ($result.ExitCode -ne 0) {
            throw "$($provider.Id) install failed:`n$($result.Output)"
        }

        $configPath = Join-Path $tempRoot 'config.toml'
        $modelsPath = Join-Path $tempRoot 'models.json'
        $config = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8
        if ($config -notmatch [regex]::Escape("[model_providers.$($provider.Id)]")) {
            throw "$($provider.Id) did not write its model_providers section"
        }
        if ($config -notmatch [regex]::Escape("model = `"$($provider.Model)`"")) {
            throw "$($provider.Id) did not write the selected model"
        }
        if ($config -notmatch 'wire_api = "responses"') {
            throw "$($provider.Id) did not use the Responses API"
        }

        $models = Get-Content -LiteralPath $modelsPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if (@($models.models).Count -eq 0) {
            throw "$($provider.Id) produced an empty models.json"
        }
        if (-not (Test-Path -LiteralPath (Join-Path $tempRoot "backup-$($provider.Id)"))) {
            throw "$($provider.Id) did not create its backup directory"
        }
    }

    Reset-TestHome
    $env:CODEX_HOME = $tempRoot
    $env:OPENROUTER_API_KEY = 'test-key-not-real'
    $openRouter = Join-Path $repoRoot 'Windows/codex-openrouter-setup.ps1'
    $install = Invoke-Installer -Path $openRouter -InputText "1`n"
    if ($install.ExitCode -ne 0) {
        throw "OpenRouter restore setup failed:`n$($install.Output)"
    }
    $restore = Invoke-Installer -Path $openRouter -InputText "9`ny`n"
    if ($restore.ExitCode -ne 0) {
        throw "OpenRouter restore failed:`n$($restore.Output)"
    }
    if (Test-Path -LiteralPath (Join-Path $tempRoot 'models.json')) {
        throw 'Restore did not remove models.json'
    }

    Write-Host '[PASS] Windows standalone install and restore flows are valid.' -ForegroundColor Green
}
finally {
    $env:CODEX_HOME = $previousCodexHome
    foreach ($provider in $providers) {
        Remove-Item -Path "Env:$($provider.Env)" -ErrorAction SilentlyContinue
    }
    if (Test-Path -LiteralPath $tempRoot) {
        $resolved = (Resolve-Path -LiteralPath $tempRoot).Path
        $allowed = (Resolve-Path -LiteralPath $PSScriptRoot).Path + [IO.Path]::DirectorySeparatorChar
        if ($resolved.StartsWith($allowed, [StringComparison]::OrdinalIgnoreCase)) {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force
        }
    }
}
