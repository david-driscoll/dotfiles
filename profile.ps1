# Add Dotfiles modules directory to the autoload path.
$DotfilesModulePath = Join-path $PSScriptRoot "psmodules/"

if (-not $env:PSModulePath.Contains($DotfilesModulePath) ) {
    $env:PSModulePath = $env:PSModulePath.Insert(0, "$DotfilesModulePath$([System.IO.Path]::PathSeparator)")
}

if ($IsMacOS) {
    . "$PSScriptRoot/profile.darwin.ps1"
}
if ($IsWindows) {
    . "$PSScriptRoot/profile.windows.ps1"
}
if ($IsLinux) {
    . "$PSScriptRoot/profile.linux.ps1"
}

foreach ($x in Get-ChildItem $PSScriptRoot/profile.pwsh -Filter *.ps1) {
    . $x.FullName
}

foreach ($x in $PROFILE | Get-Member | where { $_.Name.StartsWith("Current") } | foreach { $PROFILE.($_.Name) } | foreach { Split-Path -Parent $_ } | select -Unique | foreach { Get-ChildItem "$_/Profile/" -Filter *.ps1 }) {
    . $x.FullName
}

$ENV:STARSHIP_CONFIG = Join-Path $PSScriptRoot 'starship.toml';
$ENV:COPILOT_CUSTOM_INSTRUCTIONS_DIRS = Join-Path $PSScriptRoot 'ai';
$starship = get-command starship;

#Invoke-Expression (&starship init powershell)
$promptModule = & $starship init powershell --print-full-init | Out-String;

$customPrompt = "";
if ($IsWindows) {
    $customPrompt = @'
$loc = $executionContext.SessionState.Path.CurrentLocation;
$ext = "$([char]27)]9;12$([char]7)"
if ($loc.Provider.Name -eq "FileSystem") {
    $ext += "$([char]27)]9;9;`"$($loc.ProviderPath)`"$([char]27)\"
}

'@;
}
$customPrompt = $customPrompt + @'
# Return the prompt

$title = $promptText
$promptText = $ext + $promptText
$space = $title.IndexOf(' ');
$gitStop = $title.LastIndexOf(' ');
$title = $title.Substring($space + 1, ($gitStop - $space)-1)
$host.UI.RawUI.WindowTitle = ($title -replace '\x1b\[[0-9;]*m', '') -replace '', '📂'
'@;

function CheckAndRun($command) {
    if (-not (Get-Command $command.Split(' ')[0] -ErrorAction SilentlyContinue)) {
        return
    }
    (iex $command) | Out-String | Invoke-Expression
}

$promptModule = $promptModule.Replace("# Return the prompt", $customPrompt);
Invoke-Expression $promptModule

$oldPreference = $ErrorActionPreference
$ErrorActionPreference = "SilentlyContinue"

CheckAndRun "volta completions powershell"
CheckAndRun "gh completion -s powershell"
CheckAndRun "op completion powershell"
CheckAndRun "mise activate pwsh"
CheckAndRun "kubectl completion powershell"
CheckAndRun "helm completion powershell"

$ErrorActionPreference = $oldPreference
