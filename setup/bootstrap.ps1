if (-not [Security.Principal.WindowsIdentity]::GetCurrent().Owner.IsWellKnown("BuiltInAdministratorsSid")) {
    Start-Process powershell.exe "-File", ('"{0}"' -f $MyInvocation.MyCommand.Path) -Verb RunAs
    exit
}

if (-not (Get-Command choco)) {
    iex ((new-object net.webclient).DownloadString('https://chocolatey.org/install.ps1'))
    choco feature enable -n allowGlobalConfirmation
}

$wingetPrograms = @("AgileBits.1Password.CLI", "AgileBits.1Password", "Keybase.Keybase")

foreach ($program in $wingetPrograms) {
    iex "winget install -e --id $program";
}

git clone https://github.com/david-driscoll/dotfiles.git $ENV:USERPROFILE/dotfiles
& "$ENV:USERPROFILE/dotfiles/setup/setup.ps1"
