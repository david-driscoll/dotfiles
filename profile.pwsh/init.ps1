Import-Module posh-sshell
Import-Module Pansies
Import-Module ZLocation
Import-Module WslInterop
Import-Module posh-git
Import-WslCommand "az", "curl"

# Chocolatey profile
$ChocolateyProfile = "$env:ChocolateyInstall/helpers/chocolateyProfile.psm1"
if (Test-Path($ChocolateyProfile)) {
    Import-Module "$ChocolateyProfile"
    Update-SessionEnvironment
}

$ENV:STARSHIP_CONFIG = Join-Path $PSScriptRoot '../starship.toml'
$ENV:USER = $ENV:USERNAME

iex (&starship init powershell)
$ExecutionContext.InvokeCommand.LocationChangedAction = {

    $env:PWD = $PWD
    $current_directory = (Convert-Path $PWD)

    $title = @(&"C:\ProgramData\chocolatey\lib\starship\tools\starship.exe" module directory "--path=$current_directory")
    $title += @(&"C:\ProgramData\chocolatey\lib\starship\tools\starship.exe" module git_branch "--path=$current_directory")

    $host.UI.RawUI.WindowTitle = $title -replace '(\[\d(?:;\d+)?m)', ''
}

$env:PYTHONIOENCODING = "utf-8"
iex "$(thefuck --alias)"
