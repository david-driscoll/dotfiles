$dotfilesRoot = Split-Path -Parent $PSScriptRoot
$completionCachePath = Join-Path $dotfilesRoot '.cache\powershell-completions'
$miseLockPath = Join-Path $dotfilesRoot '.config\mise\mise.lock'
$miseLockVersion = if (Test-Path -LiteralPath $miseLockPath) {
    (Get-Item -LiteralPath $miseLockPath).LastWriteTimeUtc.Ticks
}
else {
    'missing'
}

function CheckAndRun($command) {
    if (-not (Get-Command $command.Split(' ')[0] -ErrorAction SilentlyContinue)) {
        return
    }

    $hashAlgorithm = [Security.Cryptography.SHA256]::Create()
    try {
        $commandHash = [BitConverter]::ToString(
            $hashAlgorithm.ComputeHash([Text.Encoding]::UTF8.GetBytes($command))
        ).Replace('-', '').ToLowerInvariant()
    }
    finally {
        $hashAlgorithm.Dispose()
    }

    $cachePath = Join-Path $completionCachePath "$commandHash.ps1"
    $cacheHeader = "# dotfiles-profile-completion-cache mise-lock-ticks=$miseLockVersion"
    if (Test-Path -LiteralPath $cachePath) {
        $cacheContent = Get-Content -LiteralPath $cachePath -Raw
        if (($cacheContent -split '\r?\n', 2)[0] -eq $cacheHeader) {
            $cachedCompletion = $cacheContent -replace '^[^\r\n]*\r?\n', ''
            if (-not [string]::IsNullOrWhiteSpace($cachedCompletion)) {
                & ([scriptblock]::Create($cachedCompletion))
                return
            }
        }
    }

    $previousMiseAutoInstall = $env:MISE_AUTO_INSTALL
    try {
        $env:MISE_AUTO_INSTALL = 'false'
        $completion = (& ([scriptblock]::Create($command)) 2>$null | Out-String)
    }
    finally {
        if ($null -eq $previousMiseAutoInstall) {
            Remove-Item Env:MISE_AUTO_INSTALL -ErrorAction SilentlyContinue
        }
        else {
            $env:MISE_AUTO_INSTALL = $previousMiseAutoInstall
        }
    }

    New-Item -ItemType Directory -Path $completionCachePath -Force | Out-Null
    $temporaryCachePath = Join-Path $completionCachePath "$commandHash.$([Guid]::NewGuid().ToString('N')).tmp"
    Set-Content -LiteralPath $temporaryCachePath -Value "$cacheHeader`r`n$completion" -NoNewline
    Move-Item -LiteralPath $temporaryCachePath -Destination $cachePath -Force

    if ([string]::IsNullOrWhiteSpace($completion)) {
        return
    }

    & ([scriptblock]::Create($completion))
}

$oldPreference = $ErrorActionPreference
$ErrorActionPreference = "SilentlyContinue"

Invoke-DotfilesProfileStartupStep -Name 'Activate mise' -ScriptBlock {
    CheckAndRun 'mise activate pwsh'
}
Invoke-DotfilesProfileStartupStep -Name 'Generate uv completion' -ScriptBlock {
    CheckAndRun 'uv generate-shell-completion powershell'
}
Invoke-DotfilesProfileStartupStep -Name 'Generate yq completion' -ScriptBlock {
    CheckAndRun 'yq shell-completion powershell'
}
Invoke-DotfilesProfileStartupStep -Name 'Generate dotnet completion' -ScriptBlock {
    CheckAndRun 'dotnet completions script pwsh'
}
Invoke-DotfilesProfileStartupStep -Name 'Generate gh completion' -ScriptBlock {
    CheckAndRun 'gh completion -s powershell'
}
Invoke-DotfilesProfileStartupStep -Name 'Generate 1Password completion' -ScriptBlock {
    CheckAndRun 'op completion powershell'
}
Invoke-DotfilesProfileStartupStep -Name 'Generate kubectl completion' -ScriptBlock {
    CheckAndRun 'kubectl completion powershell'
}
Invoke-DotfilesProfileStartupStep -Name 'Generate helm completion' -ScriptBlock {
    CheckAndRun 'helm completion powershell'
}
Invoke-DotfilesProfileStartupStep -Name 'Generate kustomize completion' -ScriptBlock {
    CheckAndRun 'kustomize completion powershell'
}
Invoke-DotfilesProfileStartupStep -Name 'Generate Flux completion' -ScriptBlock {
    CheckAndRun 'flux completion powershell'
}
Invoke-DotfilesProfileStartupStep -Name 'Generate Starship completion' -ScriptBlock {
    CheckAndRun 'starship completions powershell'
}
Invoke-DotfilesProfileStartupStep -Name 'Generate talosctl completion' -ScriptBlock {
    CheckAndRun 'talosctl completion powershell'
}
Invoke-DotfilesProfileStartupStep -Name 'Generate talhelper completion' -ScriptBlock {
    CheckAndRun 'talhelper completion powershell'
}

$ErrorActionPreference = $oldPreference