#!/usr/bin/env pwsh
# Installs this repo's az CLI extensions (#90). Mirrors gh-extensions.ps1's
# shape (idempotent pre-check, failure isolation, exit 0, cross-platform
# pwsh), with one deliberate divergence: auth is checked and logged but does
# NOT gate the install, since `az extension add` downloads a wheel from the
# public extension index and doesn't need an authenticated session. Full
# design rationale lives in the comment above the `[tasks.az-extensions]`
# task in .config/mise/config.toml, which locates and invokes this file via
# a `{{config_root}}`-first, `$HOME`-fallback resolution (#96) rather than
# a hard-coded `$HOME` path -- see that comment (and gh-extensions.ps1's
# own header) for why, and for what happens (a warning, then a clean
# `exit 0`) if neither location has this file.

$ErrorActionPreference = "Continue"

$extensions = @(
  @{ Name = "azure-devops"; AllowPreview = $false },
  @{ Name = "interactive"; AllowPreview = $true }
)

if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
  Write-Warning "az-extensions: az CLI not on PATH -- skipping (expected on Linux, where az isn't provisioned by this repo yet)"
  exit 0
}

# Informational only -- NOT a gate. See the block comment above this task
# for why: az extension add doesn't call any Azure API, so it doesn't
# need an authenticated session, and gating on one here would defeat the
# purpose of this task on unattended/unauthenticated containers.
az account show *> $null
if ($LASTEXITCODE -ne 0) {
  Write-Host "az-extensions: az is not logged in (az account show failed) -- proceeding anyway; extension install doesn't require auth"
}

$installedNames = @()
try {
  $installedJson = az extension list --output json 2>$null | ConvertFrom-Json
  foreach ($e in $installedJson) { $installedNames += ([string]$e.name).ToLowerInvariant() }
} catch {
  Write-Warning "az-extensions: could not parse 'az extension list' output -- treating as no extensions installed"
}

$installedCount = 0
$skippedCount = 0
$failedExt = @()

foreach ($ext in $extensions) {
  if ($installedNames -contains $ext.Name.ToLowerInvariant()) {
    $skippedCount++
    continue
  }
  Write-Host "az-extensions: installing $($ext.Name)"
  if ($ext.AllowPreview) {
    az extension add --name $ext.Name --allow-preview true --yes *> $null
  } else {
    az extension add --name $ext.Name --yes *> $null
  }
  if ($LASTEXITCODE -eq 0) {
    $installedCount++
  } else {
    $failedExt += $ext.Name
  }
}

Write-Host "az-extensions: $installedCount installed, $skippedCount already present, $($failedExt.Count) failed"
if ($failedExt.Count -gt 0) {
  Write-Warning "az-extensions: failed to install: $($failedExt -join ', ')"
}
exit 0
