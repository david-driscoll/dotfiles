if (-not [Security.Principal.WindowsIdentity]::GetCurrent().Owner.IsWellKnown("BuiltInAdministratorsSid")) {
    Start-Process powershell.exe "-File", ('"{0}"' -f $MyInvocation.MyCommand.Path) -Verb RunAs
    exit
}

$executionPolicy = Get-ExecutionPolicy;
if ($executionPolicy -ne "Unrestricted") {
    Set-ExecutionPolicy Unrestricted;
}

$PSScriptRoot = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition

$features = @(
    "Microsoft-Windows-Subsystem-Linux",
    "Microsoft-Hyper-V-All",
    "VirtualMachinePlatform",
    "Containers"
);

foreach ($feature in $features) {
    Enable-WindowsOptionalFeature -Online -FeatureName $feature -NoRestart
}

$capabilities = @(
    "OpenSSH.Client~~~~0.0.1.0",
    "OpenSSH.Server~~~~0.0.1.0"
);

foreach ($capability in $capabilities) {
    Add-WindowsCapability -Online -Name $capability
}

if (Get-Command choco) {
    choco upgrade chocolatey
}
else {
    iex ((new-object net.webclient).DownloadString('https://chocolatey.org/install.ps1'))
    choco feature enable -n allowGlobalConfirmation
}

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$releases = Invoke-RestMethod -uri "https://api.github.com/repos/microsoft/winget-cli/releases/latest"
$latestRelease = $releases.assets | Where { $_.browser_download_url.EndsWith("msixbundle") } | Select -First 1
powershell -ExecutionPolicy Bypass -NoProfile -Command "Add-AppxPackage -Path $($latestRelease.browser_download_url)"

#curl https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_x64.msi --output .\wsl_update_x64.msi
#.\wsl_update_x64.msi

$programs = @(
    # "microsoft-windows-terminal",
    "firacode",
    "firacodenf",
    "cascadiacode",
    "cascadia-code-nerd-font",
    # todo jetbrains font
    # "vivaldi",
    # "github",
    # "brave-browser",
    # "opera",
    "onenote",
    "7zip",
    "javaruntime",
    "gitversion.portable",
    "royalts-v5",
    # "office365proplus",
    "gitversion.commandline"
);
foreach ($program in $programs) {
    iex "choco upgrade $program";
}

# TODO: map these to brew mac
$wingetPrograms = @(
    "AgileBits.1Password.CLI",
    "AgileBits.1Password",
    "tailscale",
    "Microsoft.DotNet.SDK.8",
    "Microsoft.DotNet.SDK.7",
    "Microsoft.DotNet.SDK.6",
    "Microsoft.VisualStudioCode",
    "Microsoft.VisualStudioCode.Insiders",
    "Microsoft.PowerShell.Preview",
    "Microsoft.PowerShell",
    "gerardog.gsudo",
    "Microsoft.AzureDataStudio",
    "Microsoft.AzureDataStudio.Insiders",
    "Microsoft.AzureCLI",
    "Microsoft.Azure.StorageExplorer",
    "Microsoft.Azure.CosmosEmulator",
    "python3",
    "Anaconda.Miniconda3",
    "sysinternals",
    "NirSoft.ShellExView",
    "NirSoft.NirCmd",
    "NirSoft.DownTester",
    "NirSoft.BlueScreenView",
    "NirSoft.AdvancedRun",
    "Microsoft.Office",
    "Starship.Starship",
    "Google.Chrome",
    "Google.Chrome.Beta",
    "Mozilla.Firefox",
    "Microsoft.Edge",
    "Microsoft.Edge.Beta",
    "GitHub.GitHubDesktop",
    "GitHub.cli",
    "GitHub.GitLFS",
    "SlackTechnologies.Slack",
    "Microsoft.Teams",
    "Microsoft.PowerToys",
    "stedolan.jq",
    "GnuPG.Gpg4win",
    "OlegDanilov.RapidEnvironmentEditor",
    "Keybase.Keybase",
    "Notepad++.Notepad++",
    "TortoiseGit.TortoiseGit",
    "Git.Git",
    "Microsoft.GitCredentialManagerCore",
    "cURL.cURL",
    "Docker.DockerDesktop",
    "RedHat.Podman",
    "NSSM.NSSM",
    "Microsoft.WindowsTerminal.Preview",
    "Microsoft.WindowsTerminal",
    "Telerik.Fiddler.Everywhere",
    "JetBrains.Toolbox",
    "dotPDNLLC.paintdotnet",
    "LINQPad.LINQPad.7",
    "LINQPad.LINQPad.6",
    "KirillOsenkov.MSBuildStructuredLogViewer",
    "jstarks.npiperelay",
    "Hashicorp.Terraform",
    "Pulumi.Pulumi",
    "Microsoft.NuGet",
    "Volta.Volta",
    "ProjectJupyter.JupyterLab",
    "ajeetdsouza.zoxide",
    "Kubernetes.kubectl",
    "Helm.Helm"
);
foreach ($program in $wingetPrograms) {
    iex "winget install $program";
}
foreach ($program in winget search --id Microsoft.Sysinternals | foreach { $_ } | where { $_ -like '*Microsoft*' } | foreach { $_.Substring($_.IndexOf('Microsoft.'), $_.Substring($_.IndexOf('Microsoft.')).IndexOf(' ')) }) {
    iex "winget install $program";
}

wsl --set-default-version 2
wsl install Ubuntu
# wsl install kali-linux

$wc = (New-Object System.Net.WebClient);
Invoke-WebRequest https://raw.githubusercontent.com/microsoft/artifacts-credprovider/master/helpers/installcredprovider.ps1 -OutFile "$ENV:USERPROFILE/installcredprovider.ps1"
. $ENV:USERPROFILE/installcredprovider.ps1 -AddNetfx -Force
Remove-Item "$ENV:USERPROFILE/installcredprovider.ps1"

RefreshEnv

volta.exe setup
volta.exe install node

pip install thefuck
# dotnet tool update -g Microsoft.dotnet-try
# dotnet try jupyter install

az extension add --name azure-devops
az extension add --name interactive

gh extension install dlvhdr/gh-dash
gh extension install seachicken/gh-poi
gh extension install meiji163/gh-notify

# keybase login

rm -Recurse -Force $ENV:USERPROFILE/.ssh/
New-Item -ItemType SymbolicLink -Value $ENV:USERPROFILE/dotfiles/ssh/ -Path $ENV:USERPROFILE/.ssh/

mkdir "$ENV:USERPROFILE/Documents/WindowsPowerShell/" -ErrorAction SilentlyContinue
rm $ENV:USERPROFILE/Documents/WindowsPowerShell/Microsoft.PowerShell_profile.ps1 -ErrorAction SilentlyContinue
New-Item -ItemType SymbolicLink -Value $ENV:USERPROFILE/dotfiles/powershell/Microsoft.PowerShell_profile.ps1 -Path $ENV:USERPROFILE/Documents/WindowsPowerShell/Microsoft.PowerShell_profile.ps1

mkdir "$ENV:USERPROFILE/Documents/PowerShell/" -ErrorAction SilentlyContinue
rm $ENV:USERPROFILE/Documents/PowerShell/Microsoft.PowerShell_profile.ps1 -ErrorAction SilentlyContinue
New-Item -ItemType SymbolicLink -Value $ENV:USERPROFILE/dotfiles/powershell/Microsoft.PowerShell_profile.ps1 -Path $ENV:USERPROFILE/Documents/PowerShell/Microsoft.PowerShell_profile.ps1

mkdir $ENV:USERPROFILE/Documents/WindowsPowerShell/ -ErrorAction SilentlyContinue
rm $ENV:USERPROFILE/Documents/WindowsPowerShell/Microsoft.PowerShell_profile.ps1 -ErrorAction SilentlyContinue
New-Item -ItemType SymbolicLink -Value $ENV:USERPROFILE/dotfiles/powershell/Microsoft.PowerShell_profile.ps1 -Path $ENV:USERPROFILE/Documents/WindowsPowerShell/Microsoft.PowerShell_profile.ps1

mkdir $ENV:USERPROFILE/.gnupg/ -ErrorAction SilentlyContinue
rm $ENV:USERPROFILE/.gnupg/gpg-agent.conf -ErrorAction SilentlyContinue
New-Item -ItemType SymbolicLink -Value $ENV:USERPROFILE/dotfiles/gpg-agent.conf -Path $ENV:USERPROFILE/.gnupg/gpg-agent.conf

mkdir $ENV:APPDATA/gnupg/ -ErrorAction SilentlyContinue
rm $ENV:APPDATA/gnupg/gpg-agent.conf -ErrorAction SilentlyContinue
New-Item -ItemType SymbolicLink -Value $ENV:USERPROFILE/dotfiles/gpg-agent.conf -Path $ENV:APPDATA/gnupg/gpg-agent.conf

mkdir $ENV:USERPROFILE/.config/ -ErrorAction SilentlyContinue
rm -Recurse -Force "$ENV:USERPROFILE/.config/thefuck" -ErrorAction SilentlyContinue
New-Item -ItemType SymbolicLink -Value $ENV:USERPROFILE/dotfiles/thefuck/ -Path "$ENV:USERPROFILE/.config/thefuck/"

# mkdir $ENV:LOCALAPPDATA/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/ -ErrorAction SilentlyContinue
# rm $ENV:LOCALAPPDATA/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/settings.json -ErrorAction SilentlyContinue
# New-Item -ItemType SymbolicLink -Value $ENV:USERPROFILE/dotfiles/terminal/ -Path $ENV:LOCALAPPDATA/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/
# cp $ENV:LOCALAPPDATA/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/terminal/*.* $ENV:LOCALAPPDATA/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/
# rm -Recurse -Force $ENV:LOCALAPPDATA/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/terminal/ -ErrorAction SilentlyContinue

# mkdir $ENV:LOCALAPPDATA/Packages/Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe/LocalState/ -ErrorAction SilentlyContinue
# rm $ENV:LOCALAPPDATA/Packages/Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe/LocalState/settings.json -ErrorAction SilentlyContinue
# New-Item -ItemType SymbolicLink -Value $ENV:USERPROFILE/dotfiles/terminal/ -Path $ENV:LOCALAPPDATA/Packages/Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe/LocalState/

# cp $ENV:LOCALAPPDATA/Packages/Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe/LocalState/terminal/*.* $ENV:LOCALAPPDATA/Packages/Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe/LocalState/
# rm -Recurse -Force $ENV:LOCALAPPDATA/Packages/Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe/LocalState/terminal/ -ErrorAction SilentlyContinue

$PROFILE | Get-Member | where { $_.Name.StartsWith("Current") } | foreach { $($PROFILE.($_.Name)) } | where { test-path $_ } | foreach { Unblock-File $_.FullName }
gci $ENV:USERPROFILE\.ssh\ | foreach { Unblock-File $_.FullName }
gci $ENV:USERPROFILE\.gnupg\ | foreach { Unblock-File $_.FullName }

git config --global core.eol lf
git config --global core.autocrlf true
git config --global github.user david-driscoll
git config --global gpg.format ssh
git config --global user.signingkey "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFEZpmeANLSx9Worwn0REmiWKLEkDvGaaz5ZlCVuRc67"
git config --global user.name "David Driscoll"
git config --global user.email "david.driscoll@gmail.com"
git config --global commit.gpgsign true
git config --global core.sshCommand "C:/Windows/System32/OpenSSH/ssh.exe"
git config --global alias.amend "commit --amend --reuse-message=HEAD"
git config --global url."git@github.com:".insteadOf "https://github.com/"
git config --global gpg."ssh".program "C:/Program Files/1Password/app/8/op-ssh-sign.exe"