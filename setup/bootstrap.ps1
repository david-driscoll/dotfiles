# Pre-clone bootstrap: get 1Password (for the SSH-signing key used to clone
# over SSH, and generally needed day one) plus Git itself onto a genuinely
# fresh machine, then hand off to setup.ps1 for everything else. No choco --
# #72 removed it from setup.ps1 entirely and this script never actually used
# it either (it installed chocolatey but never ran `choco install`).
if (-not [Security.Principal.WindowsIdentity]::GetCurrent().Owner.IsWellKnown([Security.Principal.WellKnownSidType]::BuiltinAdministratorsSid)) {
    Start-Process -FilePath 'powershell.exe' -ArgumentList @('-File', ('"{0}"' -f $PSCommandPath)) -Verb RunAs
    exit
}

$WingetPrograms = @('AgileBits.1Password.CLI', 'AgileBits.1Password', 'Git.Git')
foreach ($Program in $WingetPrograms) {
    winget install --id $Program --exact --silent `
        --accept-package-agreements --accept-source-agreements --disable-interactivity
}

# winget updates the registry's User/Machine PATH but not this already-running
# process -- without this, `git clone` below fails with "not recognized" on a
# genuinely fresh machine where Git.Git was just installed above.
$env:PATH = @(
    [Environment]::GetEnvironmentVariable('Path', 'Machine')
    [Environment]::GetEnvironmentVariable('Path', 'User')
) -join ';'

git clone https://github.com/david-driscoll/dotfiles.git "$env:USERPROFILE\dotfiles"
& "$env:USERPROFILE\dotfiles\setup\setup.ps1"
