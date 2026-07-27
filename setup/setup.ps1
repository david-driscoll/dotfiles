<#
.SYNOPSIS
    Thin Windows bootstrap for this dotfiles repo.

.DESCRIPTION
    winget installs mise + Git, mise owns everything else: [tools], [dotfiles],
    and (via a junctioned global config) the same config.toml every other OS
    reads. Re-running this script must be safe -- every step below checks
    state before changing it.

    WINDOWS LIMITATIONS (accepted, not worked around):

    - No [bootstrap.packages] winget/choco backend exists in mise -- see the
      #73 spike on the third-party mise-winget plugin (3 commits, one author;
      rejected). The winget package list below stays an imperative array in
      this script, not a mise-declared one.
    - [bootstrap.user] login_shell is chsh-based and Unix-only; there is no
      Windows equivalent, so `mise bootstrap` is never invoked here -- the
      three commands it would otherwise chain (trust / dotfiles apply /
      install) are called directly instead.
    - mise's [dotfiles] file symlinks (and symlink-each entries) fall back to
      *copying* on Windows, because a real file symlink needs
      SeCreateSymbolicLinkPrivilege (elevation or Developer Mode). A copy
      silently drifts from the repo the moment either side is edited. That
      fallback is fine for things Windows itself or another tool owns after
      the first write (~/.ssh, ~/.gitconfig) but wrong for a file we expect
      to keep editing in place -- the PowerShell profile -- so profiles are
      NOT declared in [dotfiles] at all. Instead this script writes a
      one-line stub at every profile path that dot-sources profile.ps1 in
      this repo, so an edit there is live in the next shell with no drift
      and no copy to go stale. Directory entries (e.g. ~/.config/mise itself)
      still get a real junction, which Windows allows without elevation.
    - Windows Terminal's settings.json is deliberately left unmanaged here.
      It doesn't fit mise's dotfiles model at all: whole-file symlink/copy
      would fight the app's own writes (it appends a dynamic profile per
      WSL distro / Azure Cloud Shell, rewrites profile GUIDs, and is the
      normal target of the Settings UI), and mise's edit-block/line modes
      are explicitly documented as unusable on JSON since it has no comment
      syntax mise can anchor markers to. See git history / the PR that
      introduced this comment for the fuller writeup; `terminal/settings.json`
      in this repo is a reference copy David restores by hand, not something
      this script applies.

.NOTES
    This script has not been executed on a real Windows machine as part of
    writing it -- it was authored and statically verified (PowerShell AST
    parse) from macOS, where it cannot run. See the PR description for
    exactly what was checked statically vs. what still needs a hands-on
    pass on a Windows box.
#>

#Requires -Version 5.1

[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidUsingWriteHost',
    '',
    Justification = 'Deliberate: this script is the user''s only feedback ' +
        'during a long, unattended-looking install (winget package installs, ' +
        'feature enablement, junction/profile setup can each take a while). ' +
        'Write-Host is the one output cmdlet guaranteed to reach the console ' +
        'regardless of $InformationPreference/redirection -- Write-Information ' +
        'would silently disappear for anyone who hasn''t set ' +
        '-InformationAction Continue, which defeats the point here.'
)]
param()

if (-not [Security.Principal.WindowsIdentity]::GetCurrent().Owner.IsWellKnown([Security.Principal.WellKnownSidType]::BuiltinAdministratorsSid)) {
    Start-Process -FilePath 'powershell.exe' -ArgumentList @('-File', ('"{0}"' -f $PSCommandPath)) -Verb RunAs
    exit
}

# Local scripts need SOME execution policy that isn't the Windows client
# default (Restricted), or even this script's relaunch above -- let alone
# the profile stubs it writes below -- can't run. Kept at Unrestricted for
# parity with the script this replaces; RemoteSigned would be the more
# conventional choice (still requires nothing for local files, but wants a
# signature on downloaded scripts) -- flagging as a deliberate call, not a
# default, since narrowing it wasn't asked for here.
if ((Get-ExecutionPolicy) -ne 'Unrestricted') {
    Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope LocalMachine -Force
}

$RepoRoot = Split-Path -Parent -Path $PSScriptRoot

# --- Windows optional features (guarded, idempotent) ------------------------

$RequiredFeatures = @(
    'Microsoft-Windows-Subsystem-Linux',
    'Microsoft-Hyper-V-All',
    'VirtualMachinePlatform',
    'Containers'
)
foreach ($Feature in $RequiredFeatures) {
    if ((Get-WindowsOptionalFeature -Online -FeatureName $Feature).State -eq 'Enabled') {
        Write-Verbose "Windows feature already enabled: $Feature"
        continue
    }
    Write-Host "Enabling Windows feature: $Feature"
    Enable-WindowsOptionalFeature -Online -FeatureName $Feature -All -NoRestart | Out-Null
}

$RequiredCapabilities = @('OpenSSH.Client~~~~0.0.1.0', 'OpenSSH.Server~~~~0.0.1.0')
foreach ($Capability in $RequiredCapabilities) {
    if ((Get-WindowsCapability -Online -Name $Capability).State -eq 'Installed') {
        Write-Verbose "Windows capability already installed: $Capability"
        continue
    }
    Write-Host "Installing Windows capability: $Capability"
    Add-WindowsCapability -Online -Name $Capability | Out-Null
}

# --- winget bootstrap: mise + Git --------------------------------------------

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    throw "winget was not found. Install 'App Installer' from the Microsoft Store, then re-run this script."
}

function Install-WingetPackage {
    param([Parameter(Mandatory)] [string] $PackageId)

    winget install --id $PackageId --exact --silent `
        --accept-package-agreements --accept-source-agreements --disable-interactivity
    if ($LASTEXITCODE -ne 0) {
        # Non-zero here is routinely "already installed" / "no applicable
        # update" on a re-run, not necessarily a failure -- winget has no
        # dedicated exit code we can rely on across versions to tell the two
        # apart, so this is a warning, not a throw. Fail loudly means make it
        # visible, not treat every idempotent no-op as fatal.
        Write-Warning "winget install $PackageId exited $LASTEXITCODE (may already be installed/up to date)"
    }
}

Install-WingetPackage -PackageId 'jdx.mise'
Install-WingetPackage -PackageId 'Git.Git'

# winget updates the User/Machine PATH in the registry but does not push that
# change into this already-running process -- without this, `mise`/`git`
# below would fail with "not recognized" every time this script installs
# them fresh, defeating the point of doing it top-to-bottom in one run.
$env:PATH = @(
    [Environment]::GetEnvironmentVariable('Path', 'Machine')
    [Environment]::GetEnvironmentVariable('Path', 'User')
) -join ';'

if (-not (Get-Command mise -ErrorAction SilentlyContinue)) {
    throw "mise was not found on PATH after 'winget install jdx.mise'. Open a new shell and re-run this script."
}
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw "git was not found on PATH after 'winget install Git.Git'. Open a new shell and re-run this script."
}

# --- ~/.config/mise -> <repo>/.config/mise -----------------------------------

# Join-Path only takes -Path/-ChildPath on Windows PowerShell 5.1 (the host
# this script relaunches into for elevation) -- -AdditionalChildPath is a PS
# 6+ addition -- so every multi-segment join below is nested two-arg calls.
$MiseConfigHome = Join-Path (Join-Path $env:USERPROFILE '.config') 'mise'
$MiseConfigRepo = Join-Path (Join-Path $RepoRoot '.config') 'mise'
$MiseConfigFile = Join-Path $MiseConfigRepo 'config.toml'

$ExistingLink = Get-Item -LiteralPath $MiseConfigHome -ErrorAction SilentlyContinue
$LinkIsCorrect = $ExistingLink -and $ExistingLink.LinkType -eq 'Junction' -and
    ($ExistingLink.Target -contains $MiseConfigRepo)

if (-not $LinkIsCorrect) {
    if ($ExistingLink) {
        if ($ExistingLink.LinkType) {
            # $MiseConfigHome is already a reparse point (junction or
            # symlink), just pointed at the wrong place. `Remove-Item
            # -Recurse` on a reparse point follows the link and deletes the
            # TARGET's real contents instead of just unlinking it -- a
            # long-documented PowerShell foot-gun
            # (https://github.com/PowerShell/PowerShell/issues/621).
            # Omitting -Recurse removes the link itself and leaves whatever
            # it pointed at untouched.
            Remove-Item -LiteralPath $MiseConfigHome -Force
        } else {
            # A real, non-linked directory (or a stray file) -- safe to clear.
            Remove-Item -LiteralPath $MiseConfigHome -Recurse -Force
        }
    }
    New-Item -ItemType Directory -Path (Split-Path -Parent $MiseConfigHome) -Force | Out-Null
    try {
        New-Item -ItemType Junction -Path $MiseConfigHome -Value $MiseConfigRepo -ErrorAction Stop | Out-Null
        Write-Host "Linked $MiseConfigHome -> $MiseConfigRepo (junction)"
    } catch {
        # Directory junctions don't require elevation on NTFS in the normal
        # case (unlike file symlinks), so this should be rare -- but if it
        # does fail (locked-down policy, non-NTFS volume, etc.), point mise
        # at the repo's config file directly instead of leaving it unlinked.
        Write-Warning "Could not create the ~/.config/mise junction ($($_.Exception.Message)); falling back to MISE_GLOBAL_CONFIG_FILE."
        [Environment]::SetEnvironmentVariable('MISE_GLOBAL_CONFIG_FILE', $MiseConfigFile, 'User')
        $env:MISE_GLOBAL_CONFIG_FILE = $MiseConfigFile
    }
} else {
    Write-Verbose "~/.config/mise is already junctioned to the repo."
}

# --- PowerShell profile stubs ------------------------------------------------

# Resolved ONCE. The script this replaces linked the WindowsPowerShell
# (5.1) profile from two separate, identical blocks, then a third time from
# a $PROFILE loop that only ever reflected whichever host (5.1 or 7) had
# relaunched the elevated process -- never both. Hardcoding all four
# well-known profile paths for both hosts sidesteps that: it always covers
# both, regardless of which host is running this script right now.
# [Environment]::GetFolderPath('MyDocuments') (not $env:USERPROFILE\Documents)
# because Documents is commonly OneDrive-redirected on managed/work machines.
$DocumentsPath = [Environment]::GetFolderPath('MyDocuments')
$ProfileTargets = @(
    (Join-Path (Join-Path $DocumentsPath 'WindowsPowerShell') 'profile.ps1'),
    (Join-Path (Join-Path $DocumentsPath 'WindowsPowerShell') 'Microsoft.PowerShell_profile.ps1'),
    (Join-Path (Join-Path $DocumentsPath 'PowerShell') 'profile.ps1'),
    (Join-Path (Join-Path $DocumentsPath 'PowerShell') 'Microsoft.PowerShell_profile.ps1')
) | Select-Object -Unique

$StubContent = @"
# Managed by $RepoRoot\setup\setup.ps1 -- edit $RepoRoot\profile.ps1 instead.
# This file is regenerated every time setup.ps1 runs.
`$env:PATH = "`$env:USERPROFILE\.local\share\mise\shims;`$env:PATH"
. "$RepoRoot\profile.ps1"
"@

foreach ($ProfilePath in $ProfileTargets) {
    New-Item -ItemType Directory -Path (Split-Path -Parent $ProfilePath) -Force | Out-Null
    Set-Content -LiteralPath $ProfilePath -Value $StubContent -Encoding utf8
    Write-Host "Wrote stub profile: $ProfilePath"
}

# --- git: layer the Windows-only overrides -----------------------------------

# The shared, cross-platform ~/.gitconfig (git/gitconfig) is deployed by
# `mise dotfiles apply` below like on every other OS (copy fallback, same as
# the profile stubs' reasoning above -- but ~/.gitconfig isn't something
# David hand-edits in place the way a profile is, so the copy fallback is
# fine here). What that shared file can't carry is the two settings that are
# genuinely different on native Windows (git's own ssh.exe transport, and
# 1Password's Windows SSH-signing binary path) -- those live in
# git/gitconfig.windows and are layered on top with a single, idempotent
# `include.path` (git replaces a single-valued key in place on repeat runs).
$GitConfigWindows = Join-Path (Join-Path $RepoRoot 'git') 'gitconfig.windows'
if (Test-Path -LiteralPath $GitConfigWindows) {
    git config --global include.path $GitConfigWindows
}

# --- mise: trust, apply dotfiles, install tools ------------------------------

# Not `mise bootstrap` -- on Windows there is nothing in [bootstrap.packages]
# or [bootstrap.user] to run (see the header comment), so the three steps it
# would otherwise chain are called directly.
mise trust $MiseConfigFile
mise dotfiles apply --yes
mise install

# --- winget: apps and platform pieces mise cannot install --------------------

# Every CLI tool #66 moved into mise [tools] (jq, kubectl, helm, terraform,
# pulumi, starship, zoxide, sops, flux, age, gh, python, powershell, ...) is
# gone from this list -- `mise install` above is what installs those now,
# on Windows same as everywhere else. What's left is GUI apps and a couple
# of platform pieces with no mise/aqua backend.
$WingetPackages = @(
    # --- Security & credentials ---
    'AgileBits.1Password'
    'AgileBits.1Password.CLI'
    'GnuPG.Gpg4win'

    # --- Networking / remoting ---
    'tailscale'
    'gerardog.gsudo'
    'jstarks.npiperelay'
    'NSSM.NSSM'

    # --- Editors & IDEs ---
    'Microsoft.VisualStudioCode'
    'Microsoft.VisualStudioCode.Insiders'
    'JetBrains.Toolbox'
    'Notepad++.Notepad++'
    'TortoiseGit.TortoiseGit'    # epic flagged "trim?" -- kept, unresolved
    'GitHub.GitHubDesktop'       # epic flagged "trim?" -- kept, unresolved

    # --- Azure ---
    'Microsoft.AzureCLI'
    'Microsoft.Azure.StorageExplorer'
    'Microsoft.Azure.CosmosEmulator'

    # --- Terminal & shell ---
    'Microsoft.WindowsTerminal'
    'Microsoft.WindowsTerminal.Preview'
    'Microsoft.PowerShell.Preview' # mise owns stable `powershell`; Preview is
                                    # a distinct pre-release channel mise
                                    # doesn't track, kept for that reason

    # --- Git & dev infra (Git.Git itself is installed in the bootstrap step above) ---
    'GitHub.GitLFS'
    'cURL.cURL'
    'Docker.DockerDesktop'
    'RedHat.Podman'
    'Microsoft.NuGet'
    'KirillOsenkov.MSBuildStructuredLogViewer'
    'LINQPad.LINQPad.8'          # 6 and 7 dropped per epic ("keep 8 only");
                                  # a LINQPad.LINQPad.9 now exists upstream too
    'Telerik.Fiddler.Everywhere'

    # --- Browsers ---
    'Google.Chrome'
    'Google.Chrome.Beta'         # epic flagged "trim betas?" -- kept, unresolved
    'Mozilla.Firefox'
    'Microsoft.Edge'
    'Microsoft.Edge.Beta'        # epic flagged "trim betas?" -- kept, unresolved

    # --- Communication ---
    'SlackTechnologies.Slack'
    'Microsoft.Teams'

    # --- Utilities ---
    'Microsoft.PowerToys'
    'dotPDNLLC.paintdotnet'
    'OlegDanilov.RapidEnvironmentEditor'
    'sysinternals'
    'NirSoft.ShellExView'        # epic flagged "NirSoft set ... trim?" -- kept, unresolved
    'NirSoft.NirCmd'
    'NirSoft.DownTester'
    'NirSoft.BlueScreenView'
    'NirSoft.AdvancedRun'

    # --- Office ---
    'Microsoft.Office'

    # --- Fonts (replaces choco) ---
    # winget's official repo does not have broad Nerd Font coverage --
    # verified by walking microsoft/winget-pkgs: DEVCOM.JetBrainsMonoNerdFont
    # is the only genuine icon-patched Nerd Font package found there.
    # FiraCode, CaskaydiaCove (Cascadia Code's Nerd Font build), Meslo, a
    # nerd-patched Hack, OpenDyslexic, FantasqueSansMono, and BigBlueTerminal
    # -- the other 7 the old choco list carried -- have no winget equivalent
    # as of this writing (confirmed against microsoft/winget-cli discussion
    # #4515: font support is still an open winget feature request).
    # IMPORTANT: terminal/settings.json's one active profile face is
    # "CaskaydiaCove NF", not JetBrainsMono -- removing choco is a real
    # regression for the font your terminal actually uses. See the PR
    # description for options; this script does not install it.
    'DEVCOM.JetBrainsMonoNerdFont'
)

foreach ($PackageId in $WingetPackages) {
    Install-WingetPackage -PackageId $PackageId
}

Write-Host "setup.ps1 complete."
