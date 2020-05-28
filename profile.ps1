# Add Cmder modules directory to the autoload path.
$CmderModulePath = Join-path $PSScriptRoot "psmodules/"

if (-not $env:PSModulePath.Contains($CmderModulePath) ) {
    $env:PSModulePath = $env:PSModulePath.Insert(0, "$CmderModulePath$([System.IO.Path]::PathSeparator)")
}

# Enhance Path
$env:Path = "$PSScriptRoot$([System.IO.Path]::DirectorySeparatorChar)bin$([System.IO.Path]::PathSeparator)$env:Path"

foreach ($x in Get-ChildItem $PSScriptRoot/profile.pwsh -Filter *.ps1) {
    # write-host write-host Sourcing $x
    . $x.FullName
    # Write-Host "Loading" $x.Name "took" $r.TotalMilliseconds"ms"
}

$ENV:STARSHIP_CONFIG = Join-Path $PSScriptRoot 'starship.toml'
$ENV:USER = $ENV:USERNAME

iex (&starship init powershell)
$ExecutionContext.InvokeCommand.LocationChangedAction = {

    $env:PWD = $PWD
    $current_directory = (Convert-Path $PWD)

    $title = starship module directory "--path=$current_directory"
    $title += starship module git_branch "--path=$current_directory"

    $host.UI.RawUI.WindowTitle = $title -replace '(\[\d(?:;\d+)?m)', ''
}

$env:PYTHONIOENCODING = "utf-8"
iex "$(thefuck --alias)"


Start-SshAgent -Quiet

# Doesn't look great in conenum
[PoshCode.Pansies.RgbColor]::ColorMode = [PoshCode.Pansies.ColorMode]::XTerm256;
