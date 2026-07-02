#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Adds every marketplace listed in marketplaces.yml to Claude Code and/or GitHub
    Copilot CLI.

.DESCRIPTION
    Marketplaces are the source repos that plugins are installed from. This script
    always adds ALL marketplaces defined in marketplaces.yml (next to this script) -
    it does not filter by what any particular agents.yml plugin manifest references,
    since a marketplace add is cheap/idempotent and you generally want every
    marketplace you use available for plugin discovery/install in each tool.

    Run this once (or whenever marketplaces.yml changes) before install-agent-plugins.ps1,
    which installs individual plugins from an agents.yml and expects their marketplaces
    to already be registered.

    Safe to re-run; failures for one entry are reported and don't stop the rest of
    the run.

.PARAMETER DotfilesRoot
    Root of the dotfiles repo. Defaults to this script's directory.

.PARAMETER Only
    Restrict installation to one tool: 'claude' or 'copilot'. Defaults to both
    (whichever are found on PATH).

.PARAMETER DryRun
    Print the commands that would run without executing them.

.EXAMPLE
    ./install-marketplaces.ps1

.EXAMPLE
    ./install-marketplaces.ps1 -Only claude -DryRun
#>
[CmdletBinding()]
param(
    [string]$DotfilesRoot = ($PSScriptRoot),
    [ValidateSet('claude', 'copilot')]
    [string]$Only,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Minimal YAML reader for the restricted marketplaces.yml schema:
#   name: <scalar>
#   description: <scalar>
#   marketplaces:
#     - name: <scalar>
#       repo: <scalar>
#       ref: <scalar>                  # optional
#       targets: [claude, copilot]     # optional, defaults to both
# No external module dependency (powershell-yaml may not be installed everywhere).
# ---------------------------------------------------------------------------
function ConvertFrom-AgentsYaml {
    param([Parameter(Mandatory)][string]$Path)

    $result = [ordered]@{
        name          = $null
        description   = $null
        marketplaces  = @()
    }

    $currentKey = $null
    $currentItem = $null

    function Strip-Quotes([string]$s) {
        $s = $s.Trim()
        if ($s.Length -ge 2 -and (($s.StartsWith('"') -and $s.EndsWith('"')) -or ($s.StartsWith("'") -and $s.EndsWith("'")))) {
            return $s.Substring(1, $s.Length - 2)
        }
        return $s
    }

    # Parses a scalar value that may be an inline flow array, e.g. "[claude, copilot]",
    # into a string[]; otherwise returns the (quote-stripped) scalar string as-is.
    function Convert-ScalarOrList([string]$s) {
        $s = $s.Trim()
        if ($s.Length -ge 2 -and $s.StartsWith('[') -and $s.EndsWith(']')) {
            $inner = $s.Substring(1, $s.Length - 2)
            if ($inner.Trim() -eq '') { return @() }
            return @($inner -split ',' | ForEach-Object { Strip-Quotes $_ })
        }
        return Strip-Quotes $s
    }

    foreach ($rawLine in Get-Content -LiteralPath $Path) {
        $line = $rawLine -replace "`t", '    '
        if ($line -match '^\s*#' -or $line.Trim() -eq '') { continue }

        # Top-level scalar or list key, e.g. "name: marketplaces" or "marketplaces:"
        if ($line -match '^(\w+):\s*(.*)$') {
            $key = $Matches[1]
            $val = $Matches[2].Trim()
            if ($val -eq '') {
                $currentKey = $key
                $currentItem = $null
            }
            else {
                $result[$key] = Strip-Quotes $val
                $currentKey = $null
            }
            continue
        }

        # List item start: "  - name: value" (map item) or "  - value" (scalar item)
        if ($line -match '^\s{2}-\s*(.*)$') {
            $rest = $Matches[1]
            if ($rest -match '^(\w+):\s*(.*)$') {
                $currentItem = [ordered]@{}
                $currentItem[$Matches[1]] = Convert-ScalarOrList $Matches[2]
                if ($currentKey -and $result.Contains($currentKey)) {
                    $result[$currentKey] = @($result[$currentKey]) + , $currentItem
                }
            }
            else {
                $scalar = Strip-Quotes $rest
                if ($currentKey -and $result.Contains($currentKey)) {
                    $result[$currentKey] = @($result[$currentKey]) + $scalar
                }
            }
            continue
        }

        # Continuation of a map item's fields: "    repo: value"
        if ($line -match '^\s{4,}(\w+):\s*(.*)$' -and $currentItem -ne $null) {
            $currentItem[$Matches[1]] = Convert-ScalarOrList $Matches[2]
            continue
        }
    }

    return $result
}

function Write-Section($text) {
    Write-Host ""
    Write-Host "== $text ==" -ForegroundColor Cyan
}

# ---------------------------------------------------------------------------
# Load marketplaces.yml (always ALL entries - no filtering)
# ---------------------------------------------------------------------------
$marketplacesYamlPath = Join-Path $DotfilesRoot 'marketplaces.yml'
if (-not (Test-Path $marketplacesYamlPath)) {
    throw "Shared marketplace registry not found: $marketplacesYamlPath"
}
$marketplacesConfig = ConvertFrom-AgentsYaml -Path $marketplacesYamlPath
$marketplaceList = @($marketplacesConfig.marketplaces)

Write-Section "Resolved $($marketplaceList.Count) marketplace(s) from $marketplacesYamlPath"
foreach ($m in $marketplaceList) {
    $refSuffix = if ($m.ref) { "@$($m.ref)" } else { '' }
    $targetsSuffix = if ($m.targets) { " (targets: $($m.targets -join ', '))" } else { '' }
    Write-Host "  marketplace: $($m.name) -> $($m.repo)$refSuffix$targetsSuffix"
}

# ---------------------------------------------------------------------------
# Detect available CLIs
# ---------------------------------------------------------------------------
$tools = @()
if ((-not $Only -or $Only -eq 'claude') -and (Get-Command claude -ErrorAction SilentlyContinue)) {
    $tools += 'claude'
}
if ((-not $Only -or $Only -eq 'copilot') -and (Get-Command copilot -ErrorAction SilentlyContinue)) {
    $tools += 'copilot'
}
if ($tools.Count -eq 0) {
    Write-Warning "Neither 'claude' nor 'copilot' CLI found on PATH (or -Only excluded the one available). Nothing to install."
    return
}
Write-Section "Installing into: $($tools -join ', ')"

function Invoke-Native {
    param([string]$Tool, [string[]]$ArgumentList)
    $display = "$Tool $($ArgumentList -join ' ')"
    if ($DryRun) {
        Write-Host "  [dry-run] $display" -ForegroundColor DarkGray
        return
    }
    Write-Host "  $display"
    try {
        & $Tool @ArgumentList 2>&1 | ForEach-Object { Write-Host "    $_" }
    }
    catch {
        Write-Warning "    Failed: $_"
    }
}

# ---------------------------------------------------------------------------
# Add marketplaces
# ---------------------------------------------------------------------------
Write-Section 'Adding marketplaces'
foreach ($m in $marketplaceList) {
    # Pinned refs use git shorthand (owner/repo@ref), matching the convention
    # already used for pinned deps in apm.yml (#marketplace@ref).
    $spec = if ($m.ref) { "$($m.repo)@$($m.ref)" } else { $m.repo }
    $targets = if ($m.targets) { @($m.targets) } else { $tools }
    foreach ($tool in $tools) {
        if ($targets -notcontains $tool) { continue }
        switch ($tool) {
            'claude' { Invoke-Native -Tool 'claude' -ArgumentList @('plugin', 'marketplace', 'add', $spec) }
            'copilot' { Invoke-Native -Tool 'copilot' -ArgumentList @('plugin', 'marketplace', 'add', $spec) }
        }
    }
}

Write-Section 'Done'
