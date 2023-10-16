# Add Cmder modules directory to the autoload path.
$CmderModulePath = Join-path $PSScriptRoot "psmodules/"

if (-not $env:PSModulePath.Contains($CmderModulePath) ) {
    $env:PSModulePath = $env:PSModulePath.Insert(0, "$CmderModulePath$([System.IO.Path]::PathSeparator)")
}

foreach ($x in Get-ChildItem $PSScriptRoot/profile.pwsh -Filter *.ps1) {
    # write-host write-host Sourcing $x
    . $x.FullName
    # Write-Host "Loading" $x.Name "took" $r.TotalMilliseconds"ms"
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
$title = $promptText
$space = $title.IndexOf('');
$gitStop = $title.LastIndexOf('');
$title = $title.Substring($space + 1, ($gitStop - $space)-1)
$host.UI.RawUI.WindowTitle = ($title -replace '\x1b\[[0-9;]*m', '') -replace '', '📂'
'@);
Invoke-Expression $promptModule
(volta completions powershell) -join "`n" | Invoke-Expression
(gh completion -s powershell) -join "`n" | Invoke-Expression
(op completion powershell) -join "`n" | Invoke-Expression

$env:PYTHONIOENCODING = "utf-8"
iex "$(thefuck --alias)"

Import-Module ZLocation
