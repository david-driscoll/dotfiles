#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Inspects the plugins/marketplaces already installed natively in Claude Code and/or
    GitHub Copilot CLI and generates an agents.yml manifest from that live state.

.DESCRIPTION
    This is the inverse of install-agent-plugins.ps1: instead of reading agents.yml and
    installing into the tools, it reads each tool's own on-disk state and produces an
    agents.yml you can review and fold into ai/agents.yml or agents/agents.yml.

    Workflow this enables: add a plugin natively via `/plugin install` (Claude) or the
    Copilot CLI's own plugin UI, then re-run this script to pick up the change and sync
    it into dotfiles - no need to hand-edit YAML for every native install.

    Data sources (read-only, nothing is installed or modified):
      Claude Code:
        - ~/.claude/plugins/known_marketplaces.json  -> marketplace name -> source repo
          (per-user, not per-project; see https://code.claude.com/docs/en/plugin-marketplaces)
        - ~/.claude/settings.json  (extraKnownMarketplaces, enabledPlugins)
        - .claude/settings.json / .claude/settings.local.json in the current directory,
          if present (project/local scope overrides)
      Copilot CLI:
        - ~/.copilot/config.json    -> installedPlugins[] (name, marketplace, version, enabled)
        - ~/.copilot/settings.json  -> enabledPlugins map (final enabled/disabled state)

    KNOWN GAP: Copilot CLI does not persist the marketplace's source repo anywhere on
    disk (confirmed empirically - config.json/settings.json only ever store the
    marketplace's short name). A small built-in guess table fills in well-known
    marketplaces (e.g. "awesome-copilot" -> github/awesome-copilot); anything else is
    emitted with `repo: TODO` and a warning so you can fill it in by hand.

.PARAMETER OutputPath
    Where to write the generated plugins-only manifest. Defaults to
    agents.generated.yml in the dotfiles root (next to this script) - a scratch file
    for you to diff/review/merge, NOT one of the curated ai/agents.yml or
    agents/agents.yml files.

.PARAMETER MarketplacesOutputPath
    Where to write the generated marketplace registry. Defaults to
    marketplaces.generated.yml in the dotfiles root - diff this against the real
    marketplaces.yml and fold in any new/changed entries by hand.

.PARAMETER Only
    Restrict the scan to one tool: 'claude' or 'copilot'. Defaults to both.

.PARAMETER IncludeDisabled
    Include plugins that are installed but currently disabled (skipped by default).

.PARAMETER ClaudeHome
    Override the Claude Code home directory (for testing). Defaults to ~/.claude.

.PARAMETER CopilotHome
    Override the Copilot CLI home directory (for testing). Defaults to ~/.copilot.

.EXAMPLE
    ./export-agents-yml.ps1

.EXAMPLE
    ./export-agents-yml.ps1 -Only copilot -OutputPath ./agents.copilot.generated.yml
#>
[CmdletBinding()]
param(
    [string]$OutputPath,
    [string]$MarketplacesOutputPath,
    [ValidateSet('claude', 'copilot')]
    [string]$Only,
    [switch]$IncludeDisabled,
    [string]$ClaudeHome = (Join-Path $env:USERPROFILE '.claude'),
    [string]$CopilotHome = (Join-Path $env:USERPROFILE '.copilot')
)

$ErrorActionPreference = 'Stop'
$DotfilesRoot = $PSScriptRoot
if (-not $OutputPath) {
    $OutputPath = Join-Path $DotfilesRoot 'agents.generated.yml'
}
if (-not $MarketplacesOutputPath) {
    $MarketplacesOutputPath = Join-Path $DotfilesRoot 'marketplaces.generated.yml'
}

function Write-Section($text) {
    Write-Host ""
    Write-Host "== $text ==" -ForegroundColor Cyan
}

function Get-JsonOrNull {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    try {
        return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        Write-Warning "Failed to parse JSON at $Path : $_"
        return $null
    }
}

# A PSCustomObject acting as a map (JSON object) has its keys as NoteProperty members.
function Get-ObjectMapEntries {
    param($Obj)
    if ($null -eq $Obj) { return @() }
    return @($Obj.PSObject.Properties | ForEach-Object { [pscustomobject]@{ Key = $_.Name; Value = $_.Value } })
}

# ---------------------------------------------------------------------------
# Known marketplace name -> repo guesses, used only when a tool's own state
# doesn't record the source repo (currently: Copilot CLI). Verify before
# trusting - these are best-effort defaults, not authoritative.
# ---------------------------------------------------------------------------
$KnownMarketplaceRepoGuesses = @{
    'awesome-copilot' = 'github/awesome-copilot'
}

class MarketplaceEntry {
    [string]$Name
    [string]$Repo
    [string]$Ref
    [bool]$RepoIsGuess = $false
    [System.Collections.Generic.HashSet[string]]$SeenIn = [System.Collections.Generic.HashSet[string]]::new()
}

class PluginEntry {
    [string]$Name
    [string]$Marketplace
    [bool]$Enabled = $true
    [System.Collections.Generic.HashSet[string]]$SeenIn = [System.Collections.Generic.HashSet[string]]::new()
}

$marketplaces = [ordered]@{}   # name -> MarketplaceEntry
$plugins = [ordered]@{}        # "marketplace/name" -> PluginEntry

function Get-OrAddMarketplace {
    param([string]$Name)
    if (-not $marketplaces.Contains($Name)) {
        $entry = [MarketplaceEntry]::new()
        $entry.Name = $Name
        $marketplaces[$Name] = $entry
    }
    return $marketplaces[$Name]
}

function Get-OrAddPlugin {
    param([string]$Name, [string]$Marketplace)
    $key = "$Marketplace/$Name"
    if (-not $plugins.Contains($key)) {
        $entry = [PluginEntry]::new()
        $entry.Name = $Name
        $entry.Marketplace = $Marketplace
        $plugins[$key] = $entry
    }
    return $plugins[$key]
}

# ---------------------------------------------------------------------------
# Claude Code
# ---------------------------------------------------------------------------
function Read-ClaudeState {
    Write-Section 'Reading Claude Code state'

    $knownMarketplacesPath = Join-Path $ClaudeHome 'plugins\known_marketplaces.json'
    $known = Get-JsonOrNull $knownMarketplacesPath
    if ($known) {
        foreach ($entry in (Get-ObjectMapEntries $known)) {
            $mp = Get-OrAddMarketplace $entry.Key
            $mp.SeenIn.Add('claude') | Out-Null
            $source = $entry.Value.source
            if ($source) {
                switch ($source.source) {
                    'github' {
                        $mp.Repo = $source.repo
                        if ($source.ref) { $mp.Ref = $source.ref }
                    }
                    default {
                        # git / git-subdir / npm / directory / file - store whatever
                        # identifies it (url or package) so it's still reviewable.
                        $mp.Repo = if ($source.url) { $source.url } elseif ($source.package) { $source.package } else { $null }
                        if ($source.ref) { $mp.Ref = $source.ref }
                    }
                }
            }
        }
        Write-Host "  Found $($known.PSObject.Properties.Count) marketplace(s) in $knownMarketplacesPath"
    }
    else {
        Write-Host "  No known_marketplaces.json found at $knownMarketplacesPath (Claude Code plugins not used on this machine, or ClaudeHome is wrong)."
    }

    # settings.json scopes: user (~/.claude), project (.claude), local (.claude, git-ignored).
    $settingsPaths = @(
        (Join-Path $ClaudeHome 'settings.json'),
        (Join-Path (Get-Location) '.claude\settings.json'),
        (Join-Path (Get-Location) '.claude\settings.local.json')
    )
    foreach ($settingsPath in $settingsPaths) {
        $settings = Get-JsonOrNull $settingsPath
        if (-not $settings) { continue }
        Write-Host "  Reading $settingsPath"

        # extraKnownMarketplaces is a lower-priority fallback source for repo mapping -
        # only fill in marketplaces we don't already know the repo for.
        if ($settings.extraKnownMarketplaces) {
            foreach ($entry in (Get-ObjectMapEntries $settings.extraKnownMarketplaces)) {
                $mp = Get-OrAddMarketplace $entry.Key
                $mp.SeenIn.Add('claude') | Out-Null
                if (-not $mp.Repo -and $entry.Value.source -and $entry.Value.source.repo) {
                    $mp.Repo = $entry.Value.source.repo
                    if ($entry.Value.source.ref) { $mp.Ref = $entry.Value.source.ref }
                }
            }
        }

        if ($settings.enabledPlugins) {
            foreach ($entry in (Get-ObjectMapEntries $settings.enabledPlugins)) {
                # Key format: "<plugin-name>@<marketplace-name>"
                $parts = $entry.Key -split '@', 2
                if ($parts.Count -ne 2) {
                    Write-Warning "  Unrecognized enabledPlugins key (expected name@marketplace): $($entry.Key)"
                    continue
                }
                $pluginName, $marketplaceName = $parts
                Get-OrAddMarketplace $marketplaceName | Out-Null
                $p = Get-OrAddPlugin -Name $pluginName -Marketplace $marketplaceName
                $p.SeenIn.Add('claude') | Out-Null
                $p.Enabled = [bool]$entry.Value
            }
        }
    }
}

# ---------------------------------------------------------------------------
# Copilot CLI
# ---------------------------------------------------------------------------
function Read-CopilotState {
    Write-Section 'Reading Copilot CLI state'

    $configPath = Join-Path $CopilotHome 'config.json'
    $config = Get-JsonOrNull $configPath
    $installed = @()
    if ($config -and $config.installedPlugins) {
        $installed = @($config.installedPlugins)
        Write-Host "  Found $($installed.Count) installed plugin(s) in $configPath"
    }
    else {
        Write-Host "  No installedPlugins found at $configPath (Copilot CLI plugins not used on this machine, or CopilotHome is wrong)."
    }

    foreach ($ip in $installed) {
        $mp = Get-OrAddMarketplace $ip.marketplace
        $mp.SeenIn.Add('copilot') | Out-Null
        if (-not $mp.Repo) {
            if ($KnownMarketplaceRepoGuesses.ContainsKey($ip.marketplace)) {
                $mp.Repo = $KnownMarketplaceRepoGuesses[$ip.marketplace]
                $mp.RepoIsGuess = $true
            }
        }
        $p = Get-OrAddPlugin -Name $ip.name -Marketplace $ip.marketplace
        $p.SeenIn.Add('copilot') | Out-Null
        $p.Enabled = if ($null -ne $ip.enabled) { [bool]$ip.enabled } else { $true }
    }

    # settings.json enabledPlugins is the authoritative enabled/disabled override -
    # apply it on top of config.json's snapshot.
    $settingsPath = Join-Path $CopilotHome 'settings.json'
    $settings = Get-JsonOrNull $settingsPath
    if ($settings -and $settings.enabledPlugins) {
        Write-Host "  Reading $settingsPath"
        foreach ($entry in (Get-ObjectMapEntries $settings.enabledPlugins)) {
            $parts = $entry.Key -split '@', 2
            if ($parts.Count -ne 2) {
                Write-Warning "  Unrecognized enabledPlugins key (expected name@marketplace): $($entry.Key)"
                continue
            }
            $pluginName, $marketplaceName = $parts
            $mp = Get-OrAddMarketplace $marketplaceName
            $mp.SeenIn.Add('copilot') | Out-Null
            $p = Get-OrAddPlugin -Name $pluginName -Marketplace $marketplaceName
            $p.SeenIn.Add('copilot') | Out-Null
            $p.Enabled = [bool]$entry.Value
        }
    }
}

if (-not $Only -or $Only -eq 'claude') { Read-ClaudeState }
if (-not $Only -or $Only -eq 'copilot') { Read-CopilotState }

# ---------------------------------------------------------------------------
# Filter + report
# ---------------------------------------------------------------------------
$pluginList = @($plugins.Values | Where-Object { $IncludeDisabled -or $_.Enabled })
$usedMarketplaceNames = [System.Collections.Generic.HashSet[string]]::new()
foreach ($p in $pluginList) { $usedMarketplaceNames.Add($p.Marketplace) | Out-Null }
$marketplaceList = @($marketplaces.Values | Where-Object { $usedMarketplaceNames.Contains($_.Name) } | Sort-Object Name)
$pluginList = @($pluginList | Sort-Object Marketplace, Name)

Write-Section "Resolved $($marketplaceList.Count) marketplace(s), $($pluginList.Count) enabled plugin(s)"
$missingRepo = @()
foreach ($m in $marketplaceList) {
    $tag = if ($m.RepoIsGuess) { ' (guessed repo - verify!)' } elseif (-not $m.Repo) { ' (repo UNKNOWN)' } else { '' }
    Write-Host "  marketplace: $($m.Name) -> $($m.Repo)$tag  [seen in: $($m.SeenIn -join ', ')]"
    if (-not $m.Repo -or $m.RepoIsGuess) { $missingRepo += $m }
}
foreach ($p in $pluginList) {
    $disabledTag = if (-not $p.Enabled) { ' (disabled)' } else { '' }
    Write-Host "  plugin:      $($p.Name)@$($p.Marketplace)$disabledTag  [seen in: $($p.SeenIn -join ', ')]"
}

if ($pluginList.Count -eq 0) {
    Write-Warning "No plugins found - nothing to write. (Checked ClaudeHome=$ClaudeHome, CopilotHome=$CopilotHome)"
    return
}

# ---------------------------------------------------------------------------
# Write marketplaces.generated.yml (diff against the real marketplaces.yml)
# ---------------------------------------------------------------------------
$mpLines = New-Object System.Collections.Generic.List[string]
$mpLines.Add('# Generated by export-agents-yml.ps1 from live Claude Code / Copilot CLI plugin state.')
$mpLines.Add('# Diff against marketplaces.yml and fold in any new/changed entries by hand - this')
$mpLines.Add('# is a scratch snapshot, not meant to be installed/sourced directly.')
if ($missingRepo.Count -gt 0) {
    $mpLines.Add('#')
    $mpLines.Add('# TODO: verify/fill in these marketplace repos (could not be read from local state):')
    foreach ($m in $missingRepo) {
        $mpLines.Add("#   - $($m.Name)$(if ($m.RepoIsGuess) { " (guessed: $($m.Repo))" })")
    }
}
$mpLines.Add("name: marketplaces-generated")
$mpLines.Add("description: Snapshot of natively-installed marketplaces as of $(Get-Date -Format 'yyyy-MM-dd')")
$mpLines.Add('')
$mpLines.Add('marketplaces:')
foreach ($m in $marketplaceList) {
    $mpLines.Add("  - name: $($m.Name)")
    $repoValue = if ($m.Repo) { $m.Repo } else { 'TODO' }
    $mpLines.Add("    repo: $repoValue")
    if ($m.Ref) { $mpLines.Add("    ref: $($m.Ref)") }
}
Set-Content -LiteralPath $MarketplacesOutputPath -Value $mpLines -Encoding utf8

# ---------------------------------------------------------------------------
# Write agents.generated.yml (plugins only - diff against ai/agents.yml or
# agents/agents.yml)
# ---------------------------------------------------------------------------
$lines = New-Object System.Collections.Generic.List[string]
$lines.Add('# Generated by export-agents-yml.ps1 from live Claude Code / Copilot CLI plugin state.')
$lines.Add('# Review before merging into ai/agents.yml or agents/agents.yml - this is a scratch')
$lines.Add('# snapshot, not meant to be installed/sourced directly.')
$lines.Add('# Marketplaces referenced below are defined separately - see marketplaces.generated.yml')
$lines.Add('# (diff against the real marketplaces.yml).')
$lines.Add("name: generated")
$lines.Add("description: Snapshot of natively-installed plugins as of $(Get-Date -Format 'yyyy-MM-dd')")
$lines.Add('')
$lines.Add('plugins:')
foreach ($p in $pluginList) {
    if ($p.SeenIn.Count -eq 1) {
        # Comment goes on its own line, not inline - the installer's YAML parser
        # doesn't strip trailing "# comment" text from scalar values, so an inline
        # comment here would end up as part of the plugin name.
        $lines.Add("  # $($p.SeenIn | Select-Object -First 1) only")
    }
    $lines.Add("  - name: $($p.Name)")
    $lines.Add("    marketplace: $($p.Marketplace)")
}

Set-Content -LiteralPath $OutputPath -Value $lines -Encoding utf8
Write-Section "Wrote $MarketplacesOutputPath and $OutputPath"
Write-Host "Review them, then fold any new entries into marketplaces.yml and ai/agents.yml or agents/agents.yml by hand."
if ($missingRepo.Count -gt 0) {
    Write-Warning "$($missingRepo.Count) marketplace(s) have an unverified/missing repo - see TODO comments at the top of $MarketplacesOutputPath."
}
