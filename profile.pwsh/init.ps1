Import-Module posh-sshell
Import-Module Pansies
Import-Module ZLocation
Import-Module WslInterop
Import-WslCommand "az"

# Chocolatey profile
$ChocolateyProfile = "$env:ChocolateyInstall/helpers/chocolateyProfile.psm1"
if (Test-Path($ChocolateyProfile)) {
    Import-Module "$ChocolateyProfile"
    Update-SessionEnvironment
}

$ENV:STARSHIP_CONFIG = Join-Path $env:CMDER_ROOT 'starship.toml'
$ENV:USER = $ENV:USERNAME
iex (&starship init powershell)
$env:PYTHONIOENCODING = "utf-8"
iex "$(thefuck --alias)"