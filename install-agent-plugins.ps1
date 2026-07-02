#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Installs plugins natively into Claude Code and/or GitHub Copilot CLI, reading
    plugins from a given agents.yml manifest (or all sources listed in .apm/agents.yml
    if none is given).

.DESCRIPTION
    APM flattens plugin-shaped packages (.claude-plugin/plugin.json) into shared skill
    directories (~/.claude/skills, ~/.copilot/skills), losing plugin boundaries and
    causing name collisions (see microsoft/apm#739, #1120 - both open/unresolved).

    This script instead drives each tool's OWN plugin install CLI, so plugins stay
    namespaced and managed the way the tool expects:
      - Claude Code:  claude plugin install
      - Copilot CLI:  copilot plugin install

    This script only installs PLUGINS. Marketplaces are a separate concern - run
    install-marketplaces.ps1 first (once, or whenever marketplaces.yml changes) so
    every marketplace a plugin might reference is already registered in each tool.

    Plugins come from one of two places:
      - AgentsYamlPath given (positionally, e.g. `.\install-agent-plugins.ps1 .\ai\agents.yml`):
        reads `plugins` from just that one agents.yml file - i.e. "install only what
        this file lists".
      - AgentsYamlPath omitted: reads .apm/agents.yml (the root aggregator) for a list
        of `sources`, then reads each source agents.yml's `plugins`, combining all of
        them - i.e. "install everything".

    Safe to re-run; failures for one entry are reported and don't stop the rest of
    the run.

.PARAMETER AgentsYamlPath
    Path to a single agents.yml to install plugins from (relative to DotfilesRoot, or
    absolute), given positionally. When given, only that file's plugins are installed -
    the .apm/agents.yml source-aggregation is skipped entirely.

.PARAMETER DotfilesRoot
    Root of the dotfiles repo. Defaults to this script's directory.

.PARAMETER Only
    Restrict installation to one tool: 'claude' or 'copilot'. Defaults to both
    (whichever are found on PATH).

.PARAMETER DryRun
    Print the commands that would run without executing them.

.EXAMPLE
    ./install-agent-plugins.ps1

.EXAMPLE
    ./install-agent-plugins.ps1 -Only claude -DryRun

.EXAMPLE
    ./install-agent-plugins.ps1 .\ai\agents.yml
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$AgentsYamlPath,
    [string]$DotfilesRoot = ($PSScriptRoot),
    [ValidateSet('claude', 'copilot')]
    [string]$Only,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Minimal YAML reader for the restricted agents.yml schema:
#   name: <scalar>
#   description: <scalar>
#   sources:
#     - <scalar>
#   marketplaces:
#     - name: <scalar>
#       repo: <scalar>
#       ref: <scalar>          # optional
#   plugins:
#     - name: <scalar>
#       marketplace: <scalar>
#       targets: [claude, copilot]   # optional, defaults to both
# No external module dependency (powershell-yaml may not be installed everywhere).
# ---------------------------------------------------------------------------
function ConvertFrom-AgentsYaml {
    param([Parameter(Mandatory)][string]$Path)

    $result = [ordered]@{
        name          = $null
        description   = $null
        sources       = @()
        marketplaces  = @()
        plugins       = @()
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

        # Top-level scalar or list key, e.g. "name: ai" or "marketplaces:"
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

function Get-DotfilesPath {
    param([string]$RelativePath)
    return Join-Path $DotfilesRoot $RelativePath
}

function Write-Section($text) {
    Write-Host ""
    Write-Host "== $text ==" -ForegroundColor Cyan
}

# ---------------------------------------------------------------------------
# Resolve plugins: either from one explicit agents.yml, or aggregated from
# every source listed in .apm/agents.yml (default, "install everything").
# ---------------------------------------------------------------------------
$allPlugins = @()

if ($AgentsYamlPath) {
    $singlePath = if ([System.IO.Path]::IsPathRooted($AgentsYamlPath)) { $AgentsYamlPath } else { Get-DotfilesPath $AgentsYamlPath }
    if (-not (Test-Path $singlePath)) {
        throw "Agents manifest not found: $singlePath"
    }
    Write-Verbose "Loading $singlePath"
    $config = ConvertFrom-AgentsYaml -Path $singlePath
    foreach ($p in $config.plugins) { $allPlugins += $p }
}
else {
    $rootConfigPath = Get-DotfilesPath '.apm\agents.yml'
    if (-not (Test-Path $rootConfigPath)) {
        throw "Root agents manifest not found: $rootConfigPath"
    }
    $rootConfig = ConvertFrom-AgentsYaml -Path $rootConfigPath

    foreach ($source in $rootConfig.sources) {
        $sourcePath = Get-DotfilesPath $source
        if (-not (Test-Path $sourcePath)) {
            Write-Warning "Source not found, skipping: $sourcePath"
            continue
        }
        Write-Verbose "Loading $sourcePath"
        $config = ConvertFrom-AgentsYaml -Path $sourcePath
        foreach ($p in $config.plugins) { $allPlugins += $p }
    }
}

# Dedupe plugins by "marketplace/name".
$pluginsByKey = [ordered]@{}
foreach ($p in $allPlugins) { $pluginsByKey["$($p.marketplace)/$($p.name)"] = $p }

Write-Section "Resolved $($pluginsByKey.Count) plugin(s)"
foreach ($p in $pluginsByKey.Values) {
    Write-Host "  plugin:      $($p.name)@$($p.marketplace)"
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
# Install plugins
#
# NOTE: this assumes each plugin's marketplace is already registered in the
# target tool(s). Run install-marketplaces.ps1 first if it isn't.
# ---------------------------------------------------------------------------
Write-Section 'Installing plugins'
foreach ($p in $pluginsByKey.Values) {
    $targets = if ($p.targets) { @($p.targets) } else { $tools }
    $pluginSpec = "$($p.name)@$($p.marketplace)"
    foreach ($tool in $tools) {
        if ($targets -notcontains $tool) { continue }
        switch ($tool) {
            'claude' { Invoke-Native -Tool 'claude' -ArgumentList @('plugin', 'install', $pluginSpec) }
            'copilot' { Invoke-Native -Tool 'copilot' -ArgumentList @('plugin', 'install', $pluginSpec) }
        }
    }
}

Write-Section 'Done'
