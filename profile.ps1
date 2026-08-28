# Both CurrentUserAllHosts and CurrentUserCurrentHost profiles dot-source this
# file on Windows. Initialize once per PowerShell process so their shared work
# (notably `mise activate pwsh`) is not performed twice.
if ($global:DotfilesProfileInitialized) {
    if ($env:DOTFILES_PROFILE_TIMING -eq '1') {
        Write-Host '[dotfiles profile] skipped duplicate dot-source.'
    }
    return
}

$global:DotfilesProfileStartupTimings = [System.Collections.Generic.List[object]]::new()

function Invoke-DotfilesProfileStartupStep {
    param(
        [Parameter(Mandatory)]
        [string] $Name,

        [Parameter(Mandatory)]
        [scriptblock] $ScriptBlock
    )

    $stopwatch = [Diagnostics.Stopwatch]::StartNew()
    $succeeded = $false
    try {
        & $ScriptBlock
        $succeeded = $true
    }
    finally {
        $stopwatch.Stop()
        $global:DotfilesProfileStartupTimings.Add([pscustomobject]@{
                Step        = $Name
                Milliseconds = [Math]::Round($stopwatch.Elapsed.TotalMilliseconds, 1)
                Completed    = $succeeded
            })
    }
}

function Show-DotfilesProfileStartupTiming {
    $global:DotfilesProfileStartupTimings | Format-Table -AutoSize
}

$profileStopwatch = [Diagnostics.Stopwatch]::StartNew()
$profileInitialized = $false

try {
    $env:COPILOT_CUSTOM_INSTRUCTIONS_DIRS = Join-Path $PSScriptRoot 'ai'

    $dotfilesModulePath = Join-Path $PSScriptRoot 'psmodules'
    if (-not $env:PSModulePath.Contains($dotfilesModulePath)) {
        $env:PSModulePath = $env:PSModulePath.Insert(0, "$dotfilesModulePath$([IO.Path]::PathSeparator)")
    }

    if ($IsMacOS) {
        Invoke-DotfilesProfileStartupStep -Name 'Source profile.darwin.ps1' -ScriptBlock {
            . (Join-Path $PSScriptRoot 'profile.darwin.ps1')
        }
    }
    if ($IsWindows) {
        Invoke-DotfilesProfileStartupStep -Name 'Source profile.windows.ps1' -ScriptBlock {
            . (Join-Path $PSScriptRoot 'profile.windows.ps1')
        }
    }
    if ($IsLinux) {
        Invoke-DotfilesProfileStartupStep -Name 'Source profile.linux.ps1' -ScriptBlock {
            . (Join-Path $PSScriptRoot 'profile.linux.ps1')
        }
    }

    foreach ($profileScript in Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'profile.pwsh') -Filter '*.ps1' | Sort-Object Name) {
        $profileScriptPath = $profileScript.FullName
        Invoke-DotfilesProfileStartupStep -Name "Source profile.pwsh\$($profileScript.Name)" -ScriptBlock {
            . $profileScriptPath
        }
    }

    $profileExtensions = foreach ($profilePath in $PROFILE | Get-Member | Where-Object { $_.Name.StartsWith('Current') } | ForEach-Object { $PROFILE.($_.Name) } | ForEach-Object { Split-Path -Parent $_ } | Select-Object -Unique) {
        Get-ChildItem -ErrorAction SilentlyContinue (Join-Path $profilePath 'Profile') -Filter '*.ps1'
    }
    foreach ($profileExtension in $profileExtensions) {
        $profileExtensionPath = $profileExtension.FullName
        Invoke-DotfilesProfileStartupStep -Name "Source profile extension $($profileExtension.Name)" -ScriptBlock {
            . $profileExtensionPath
        }
    }

    Invoke-DotfilesProfileStartupStep -Name 'Initialize Starship prompt' -ScriptBlock {
        $env:STARSHIP_CONFIG = Join-Path $PSScriptRoot 'starship.toml'
        $starship = Get-Command starship
        $promptModule = & $starship init powershell --print-full-init | Out-String

        $customPrompt = ''
        if ($IsWindows) {
            $customPrompt = @'
$loc = $executionContext.SessionState.Path.CurrentLocation;
$ext = "$([char]27)]9;12$([char]7)"
if ($loc.Provider.Name -eq "FileSystem") {
    $ext += "$([char]27)]9;9;`"$($loc.ProviderPath)`"$([char]27)\"
}

'@
        }
        $customPrompt = $customPrompt + @'
# Return the prompt

$title = $promptText
$promptText = $ext + $promptText
$space = $title.IndexOf(' ');
$gitStop = $title.LastIndexOf(' ');
$title = $title.Substring($space + 1, ($gitStop - $space)-1)
$host.UI.RawUI.WindowTitle = ($title -replace '\x1b\[[0-9;]*m', '') -replace '', '📂'
'@

        $promptModule = $promptModule.Replace('# Return the prompt', $customPrompt)
        Invoke-Expression $promptModule
    }

    $profileInitialized = $true
}
finally {
    $profileStopwatch.Stop()
    $global:DotfilesProfileStartupTimings.Add([pscustomobject]@{
            Step        = 'Total profile initialization'
            Milliseconds = [Math]::Round($profileStopwatch.Elapsed.TotalMilliseconds, 1)
            Completed    = $profileInitialized
        })

    if ($profileInitialized) {
        $global:DotfilesProfileInitialized = $true
    }

    if ($env:DOTFILES_PROFILE_TIMING -eq '1') {
        Show-DotfilesProfileStartupTiming
    }
}
