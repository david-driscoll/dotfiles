$dotfilesRoot = Split-Path -Parent $PSScriptRoot
$completionCachePath = Join-Path $dotfilesRoot '.cache\powershell-completions'
$miseLockPath = Join-Path $dotfilesRoot '.config\mise\mise.lock'
$miseLockVersion = if (Test-Path -LiteralPath $miseLockPath) {
    (Get-Item -LiteralPath $miseLockPath).LastWriteTimeUtc.Ticks
}
else {
    'missing'
}

# Returns the (cached) output of $command as a script block for the caller to
# dot-source, e.g. `. (Get-DotfilesCommandScript 'mise activate pwsh')`. Running
# it here with `&` would put anything it defines (such as mise's `mise` wrapper
# function) in this function's child scope, where it is discarded on return.
function Get-DotfilesCommandScript($command) {
    if (-not (Get-Command $command.Split(' ')[0] -ErrorAction SilentlyContinue)) {
        return {}
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
                return [scriptblock]::Create($cachedCompletion)
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
        return {}
    }

    return [scriptblock]::Create($completion)
}

$oldPreference = $ErrorActionPreference
$ErrorActionPreference = "SilentlyContinue"

. Invoke-DotfilesProfileStartupStep -Name 'Activate mise' -ScriptBlock {
    . (Get-DotfilesCommandScript 'mise activate pwsh')
}
. Invoke-DotfilesProfileStartupStep -Name 'Activate fnox' -ScriptBlock {
    . (Get-DotfilesCommandScript 'fnox activate pwsh')
}
. Invoke-DotfilesProfileStartupStep -Name 'Generate fnox completion' -ScriptBlock {
    . (Get-DotfilesCommandScript 'fnox completion pwsh')
}
. Invoke-DotfilesProfileStartupStep -Name 'Generate uv completion' -ScriptBlock {
    . (Get-DotfilesCommandScript 'uv generate-shell-completion powershell')
}
. Invoke-DotfilesProfileStartupStep -Name 'Generate yq completion' -ScriptBlock {
    . (Get-DotfilesCommandScript 'yq shell-completion powershell')
}
. Invoke-DotfilesProfileStartupStep -Name 'Generate dotnet completion' -ScriptBlock {
    . (Get-DotfilesCommandScript 'dotnet completions script pwsh')
}
. Invoke-DotfilesProfileStartupStep -Name 'Generate gh completion' -ScriptBlock {
    . (Get-DotfilesCommandScript 'gh completion -s powershell')
}
. Invoke-DotfilesProfileStartupStep -Name 'Generate 1Password completion' -ScriptBlock {
    . (Get-DotfilesCommandScript 'op completion powershell')
}
. Invoke-DotfilesProfileStartupStep -Name 'Generate kubectl completion' -ScriptBlock {
    . (Get-DotfilesCommandScript 'kubectl completion powershell')
}
. Invoke-DotfilesProfileStartupStep -Name 'Generate helm completion' -ScriptBlock {
    . (Get-DotfilesCommandScript 'helm completion powershell')
}
. Invoke-DotfilesProfileStartupStep -Name 'Generate kustomize completion' -ScriptBlock {
    . (Get-DotfilesCommandScript 'kustomize completion powershell')
}
. Invoke-DotfilesProfileStartupStep -Name 'Generate Flux completion' -ScriptBlock {
    . (Get-DotfilesCommandScript 'flux completion powershell')
}
. Invoke-DotfilesProfileStartupStep -Name 'Generate Starship completion' -ScriptBlock {
    . (Get-DotfilesCommandScript 'starship completions powershell')
}
. Invoke-DotfilesProfileStartupStep -Name 'Generate talosctl completion' -ScriptBlock {
    . (Get-DotfilesCommandScript 'talosctl completion powershell')
}
. Invoke-DotfilesProfileStartupStep -Name 'Generate talhelper completion' -ScriptBlock {
    . (Get-DotfilesCommandScript 'talhelper completion powershell')
}

$ErrorActionPreference = $oldPreference