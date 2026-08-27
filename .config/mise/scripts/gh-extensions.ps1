#!/usr/bin/env pwsh
# Installs this repo's gh CLI extensions (#83). Idempotent (skips extensions
# already present per `gh extension list` rather than blindly re-installing),
# auth-guarded (no-ops cleanly, never prompts, when `gh auth status` fails
# and no GITHUB_TOKEN/GH_TOKEN is set -- required for unattended Codespaces/
# Coder container builds), and failure-isolated per extension so one broken/
# renamed extension can't abort the other nine or fail the postinstall hook
# chain. Full design rationale lives in the comment above the
# `[tasks.gh-extensions]` task in .config/mise/config.toml, which locates
# and invokes this file via a `{{config_root}}`-first, `$HOME`-fallback
# resolution (#96) rather than a hard-coded `$HOME` path -- see that
# comment for why, and for what happens (a warning, then a clean `exit 0`)
# if neither location has this file.

$ErrorActionPreference = "Continue"

$extensions = @(
  "davidraviv/gh-clean-branches",
  "github/gh-codeql",
  "mislav/gh-contrib",
  "github/gh-copilot",
  "dlvhdr/gh-dash",
  "meiji163/gh-notify",
  "seachicken/gh-poi",
  "vilmibm/gh-screensaver",
  "AdamVig/gh-watch",
  "shuymn/gh-mcp"
)

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
  Write-Warning "gh-extensions: gh CLI not on PATH -- skipping (should have just been installed by [tools])"
  exit 0
}

gh auth status *> $null
$authOk = ($LASTEXITCODE -eq 0)
if (-not $authOk -and -not $env:GITHUB_TOKEN -and -not $env:GH_TOKEN) {
  Write-Warning 'gh-extensions: gh is not authenticated (gh auth status failed, no GITHUB_TOKEN/GH_TOKEN set) -- skipping extension install. This never prompts; run "gh auth login" yourself, then re-run: mise run gh-extensions'
  exit 0
}

$installedSlugs = @()
foreach ($line in ((gh extension list 2>$null) -split "`n")) {
  $parts = $line -split "`t"
  if ($parts.Length -ge 2) { $installedSlugs += $parts[1].Trim().ToLowerInvariant() }
}

$installedCount = 0
$skippedCount = 0
$failedExt = @()

foreach ($ext in $extensions) {
  if ($installedSlugs -contains $ext.ToLowerInvariant()) {
    $skippedCount++
    continue
  }
  Write-Host "gh-extensions: installing $ext"
  gh extension install $ext *> $null
  if ($LASTEXITCODE -eq 0) {
    $installedCount++
  } else {
    $failedExt += $ext
  }
}

Write-Host "gh-extensions: $installedCount installed, $skippedCount already present, $($failedExt.Count) failed"
if ($failedExt.Count -gt 0) {
  Write-Warning "gh-extensions: failed to install: $($failedExt -join ', ')"
}
exit 0
