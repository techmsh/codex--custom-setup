$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$providers = @(
    @{ Id = 'openrouter'; BaseUrl = 'https://openrouter.ai/api/v1'; Env = 'OPENROUTER_API_KEY'; AltEnv = ''; Models = @('anthropic/claude-sonnet-5.5', 'deepseek/deepseek-v4-pro') },
    @{ Id = 'xai'; BaseUrl = 'https://api.x.ai/v1'; Env = 'XAI_API_KEY'; AltEnv = ''; Models = @('grok-4.7', 'grok-build-0.1') },
    @{ Id = 'fireworks'; BaseUrl = 'https://api.fireworks.ai/inference/v1'; Env = 'FIREWORKS_API_KEY'; AltEnv = ''; Models = @('accounts/fireworks/routers/glm-5p3-spot', 'accounts/fireworks/routers/kimi-latest') },
    @{ Id = 'novita'; BaseUrl = 'https://api.novita.ai/openai/v1'; Env = 'NOVITA_API_KEY'; AltEnv = ''; Models = @('qwen/qwen3.8-max', 'zai-org/glm-5.3') },
    @{ Id = 'huggingface'; BaseUrl = 'https://router.huggingface.co/v1'; Env = 'HF_TOKEN'; AltEnv = ''; Models = @('openai/gpt-oss-20b', 'tencent/Hy4-preview') },
    @{ Id = 'meta'; BaseUrl = 'https://api.meta.ai/v1'; Env = 'META_MODEL_API_KEY'; AltEnv = 'MODEL_API_KEY'; Models = @('muse-spark-1.2', 'muse-spark-1.3') },
    @{ Id = 'stepfun'; BaseUrl = 'https://api.stepfun.ai/v1'; Env = 'STEPFUN_API_KEY'; AltEnv = ''; Models = @('step-3.7-flash', 'step-5-preview') },
    @{ Id = 'xiaomi'; BaseUrl = 'https://api.xiaomimimo.com/v1'; Env = 'XIAOMI_API_KEY'; AltEnv = ''; Models = @('mimo-v2.6-flash', 'mimo-v2.6-pro') }
)

$failures = [System.Collections.Generic.List[string]]::new()
$readme = Get-Content -LiteralPath (Join-Path $repoRoot 'README.md') -Raw -Encoding UTF8

foreach ($provider in $providers) {
    $scriptName = "codex-$($provider.Id)-setup.sh"
    $path = Join-Path $repoRoot "Linux/$scriptName"
    $rawUrl = "https://raw.githubusercontent.com/techmsh/codex--custom-setup/main/Linux/$scriptName"

    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        $failures.Add("Linux/$($provider.Id) missing file: $path")
        continue
    }

    $content = Get-Content -LiteralPath $path -Raw -Encoding UTF8
    foreach ($value in @(
        "PROVIDER_ID=`"$($provider.Id)`"",
        "PROVIDER_BASE_URL_VALUE=`"$($provider.BaseUrl)`"",
        "PROVIDER_API_KEY_ENV_VAR=`"$($provider.Env)`"",
        'wire_api',
        'responses',
        'experimental_bearer_token',
        "BACKUP_DIRNAME=`"backup-$($provider.Id)`""
    )) {
        if (-not $content.Contains($value)) {
            $failures.Add("Linux/$($provider.Id) missing value '$value'")
        }
    }
    if ($provider.AltEnv -and -not $content.Contains($provider.AltEnv)) {
        $failures.Add("Linux/$($provider.Id) missing alternate env '$($provider.AltEnv)'")
    }
    foreach ($model in $provider.Models) {
        if (-not $content.Contains($model)) {
            $failures.Add("Linux/$($provider.Id) missing model '$model'")
        }
    }
    if ($content -match '(?m)^\s*(source|\.)\s+.*(?:lib/common\.sh|codex-setup\.sh)') {
        $failures.Add("Linux/$($provider.Id) must be standalone and not reference shared Linux files")
    }
    if (-not $readme.Contains($scriptName) -or -not $readme.Contains($rawUrl)) {
        $failures.Add("README missing Linux command for $($provider.Id)")
    }
}

$bashCandidates = @(
    'D:\Program Files\Git\bin\bash.exe',
    'D:\Program Files\Git\usr\bin\bash.exe',
    'C:\Program Files\Git\bin\bash.exe',
    'C:\Program Files\Git\usr\bin\bash.exe'
)
$bashPath = $bashCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $bashPath) {
    $failures.Add('Bash executable not found; Linux syntax verification is unavailable')
} else {
    $allLinuxScripts = Get-ChildItem -LiteralPath (Join-Path $repoRoot 'Linux') -Filter 'codex-*-setup.sh' -File
    foreach ($script in $allLinuxScripts) {
        $content = Get-Content -LiteralPath $script.FullName -Raw -Encoding UTF8
        if ($content -match '(?m)^\s*(source|\.)\s+.*(?:lib/common\.sh|codex-setup\.sh)') {
            $failures.Add("$($script.Name) still depends on a shared Linux script")
        }
        & $bashPath -n $script.FullName
        if ($LASTEXITCODE -ne 0) {
            $failures.Add("$($script.Name) failed bash -n")
        }
    }

    foreach ($provider in $providers) {
        $path = Join-Path $repoRoot "Linux/codex-$($provider.Id)-setup.sh"
        if (-not (Test-Path -LiteralPath $path)) {
            continue
        }
        & $bashPath -n $path
        if ($LASTEXITCODE -ne 0) {
            $failures.Add("Linux/$($provider.Id) failed bash -n")
        }
    }
}

if ($bashPath -and $failures.Count -eq 0) {
    $tempRoot = Join-Path $PSScriptRoot '.tmp-linux-install'
    $cygpath = Join-Path (Split-Path -Parent $bashPath) 'cygpath.exe'
    $previousCodexHome = $env:CODEX_HOME
    try {
        foreach ($provider in $providers) {
            if (Test-Path -LiteralPath $tempRoot) {
                Remove-Item -LiteralPath $tempRoot -Recurse -Force
            }
            New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
            $env:CODEX_HOME = if (Test-Path -LiteralPath $cygpath) {
                (& $cygpath -u $tempRoot).Trim()
            } else {
                $tempRoot.Replace('\', '/')
            }
            Set-Item -Path "Env:$($provider.Env)" -Value 'test-key-not-real'

            $scriptPath = Join-Path $repoRoot "Linux/codex-$($provider.Id)-setup.sh"
            $output = "1`n" | & $bashPath $scriptPath 2>&1
            if ($LASTEXITCODE -ne 0) {
                $failures.Add("Linux/$($provider.Id) install failed: $($output | Out-String)")
                continue
            }

            $configPath = Join-Path $tempRoot 'config.toml'
            $modelsPath = Join-Path $tempRoot 'models.json'
            $config = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8
            if ($config -notmatch [regex]::Escape("[model_providers.$($provider.Id)]")) {
                $failures.Add("Linux/$($provider.Id) did not write its provider section")
            }
            if ($config -notmatch 'wire_api = "responses"') {
                $failures.Add("Linux/$($provider.Id) did not use Responses API")
            }
            $models = Get-Content -LiteralPath $modelsPath -Raw -Encoding UTF8 | ConvertFrom-Json
            if (@($models.models).Count -eq 0) {
                $failures.Add("Linux/$($provider.Id) produced an empty models.json")
            }
            if (-not (Test-Path -LiteralPath (Join-Path $tempRoot "backup-$($provider.Id)"))) {
                $failures.Add("Linux/$($provider.Id) did not create a backup directory")
            }
        }

        if ($failures.Count -eq 0) {
            if (Test-Path -LiteralPath $tempRoot) {
                Remove-Item -LiteralPath $tempRoot -Recurse -Force
            }
            New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
            $env:CODEX_HOME = if (Test-Path -LiteralPath $cygpath) {
                (& $cygpath -u $tempRoot).Trim()
            } else {
                $tempRoot.Replace('\', '/')
            }
            $env:OPENROUTER_API_KEY = 'test-key-not-real'
            $openRouter = Join-Path $repoRoot 'Linux/codex-openrouter-setup.sh'
            $installOutput = "1`n" | & $bashPath $openRouter 2>&1
            if ($LASTEXITCODE -ne 0) {
                $failures.Add("Linux/openrouter restore setup failed: $($installOutput | Out-String)")
            }
            $restoreOutput = "9`ny`n" | & $bashPath $openRouter 2>&1
            if ($LASTEXITCODE -ne 0) {
                $failures.Add("Linux/openrouter restore failed: $($restoreOutput | Out-String)")
            } elseif (Test-Path -LiteralPath (Join-Path $tempRoot 'models.json')) {
                $failures.Add('Linux/openrouter restore did not remove models.json')
            }

            if ($failures.Count -eq 0) {
                if (Test-Path -LiteralPath $tempRoot) {
                    Remove-Item -LiteralPath $tempRoot -Recurse -Force
                }
                New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
                $env:CODEX_HOME = if (Test-Path -LiteralPath $cygpath) {
                    (& $cygpath -u $tempRoot).Trim()
                } else {
                    $tempRoot.Replace('\', '/')
                }
                $env:DEEPSEEK_API_KEY = 'sk-test-not-real'
                $deepSeek = Join-Path $repoRoot 'Linux/codex-deepseek-setup.sh'
                $legacyOutput = "1`n" | & $bashPath $deepSeek 2>&1
                if ($LASTEXITCODE -ne 0) {
                    $failures.Add("Linux/deepseek regression install failed: $($legacyOutput | Out-String)")
                } else {
                    $legacyConfig = Get-Content -LiteralPath (Join-Path $tempRoot 'config.toml') -Raw -Encoding UTF8
                    if ($legacyConfig -notmatch '\[model_providers\.deepseek\]') {
                        $failures.Add('Linux/deepseek regression install did not write its provider section')
                    }
                }
            }
        }
    } finally {
        $env:CODEX_HOME = $previousCodexHome
        Remove-Item -Path 'Env:DEEPSEEK_API_KEY' -ErrorAction SilentlyContinue
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
}

if ($failures.Count -gt 0) {
    foreach ($failure in $failures) {
        Write-Host "[FAIL] $failure" -ForegroundColor Red
    }
    Write-Host "`n$($failures.Count) test failure(s)." -ForegroundColor Red
    exit 1
}

Write-Host '[PASS] Linux standalone provider installers are present and valid.' -ForegroundColor Green
