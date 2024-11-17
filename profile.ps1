# Add Dotfiles modules directory to the autoload path.
$DotfilesModulePath = Join-path $PSScriptRoot "psmodules/"

if (-not $env:PSModulePath.Contains($DotfilesModulePath) ) {
    $env:PSModulePath = $env:PSModulePath.Insert(0, "$DotfilesModulePath$([System.IO.Path]::PathSeparator)")
}

write-host $PSScriptRoot
foreach ($x in Get-ChildItem $PSScriptRoot/profile.pwsh -Filter *.ps1) {
    . $x.FullName
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

$ENV:STARSHIP_CONFIG = Join-Path $PSScriptRoot 'starship.toml';

#Invoke-Expression (&starship init powershell)
$promptModule = & 'C:\Program Files\starship\bin\starship.exe' init powershell --print-full-init | Out-String;
$promptModule = $promptModule.Replace("# Return the prompt", @'
# Return the prompt
$loc = $executionContext.SessionState.Path.CurrentLocation;
$ext = "$([char]27)]9;12$([char]7)"
if ($loc.Provider.Name -eq "FileSystem") {
    $ext += "$([char]27)]9;9;`"$($loc.ProviderPath)`"$([char]27)\"
}
$ext

$title = $promptText
$space = $title.IndexOf(' ');
$gitStop = $title.LastIndexOf(' ');
$title = $title.Substring($space + 1, ($gitStop - $space)-1)
$host.UI.RawUI.WindowTitle = ($title -replace '\x1b\[[0-9;]*m', '') -replace '', '📂'
'@);
Invoke-Expression $promptModule
(volta completions powershell) -join "`n" | Invoke-Expression
(gh completion -s powershell) -join "`n" | Invoke-Expression
(op completion powershell) -join "`n" | Invoke-Expression
(kubectl completion powershell) -join "`n" | Invoke-Expression
(helm completion powershell) -join "`n" | Invoke-Expression
Invoke-Expression (& { (zoxide init powershell | Out-String) })

$env:PYTHONIOENCODING = "utf-8"
iex "$(thefuck --alias)"
