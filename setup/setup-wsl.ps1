$distros = wsl -l -q | where { $_ -ne 'docker-desktop-data' -and $_ -ne 'docker-desktop' -and $_.Trim() -ne '' } | foreach { $_.Trim() -replace '[^a-zA-Z0-9\-\.]', '' } | where { $_.Trim() -ne "" }
# $distros = @("Ubuntu20")
foreach ($d in $distros) {
    Write-Host -ForegroundColor Cyan $d
    $me = (wsl -d $d whoami).Trim()

    $script = @"
#!/bin/bash
    set -euo pipefail

    if [ -L "`$HOME/dotfiles" ]; then
        rm "`$HOME/dotfiles"
    elif [ -e "`$HOME/dotfiles" ]; then
        echo "Expected `$HOME/dotfiles to be a symlink; refusing to replace an existing path." >&2
        exit 1
    fi

    ln -s /mnt/c/Users/$ENV:USERNAME/dotfiles "`$HOME/dotfiles"
    exec bash "`$HOME/dotfiles/install.sh"

"@.Replace("`r", "")
    $file = New-TemporaryFile
    $script | Out-File $file -Encoding utf8NoBOM
    Copy-Item $file \\wsl$\$d\home\$me\temp.sh
    wsl -d $d chmod 755 ~/temp.sh
    wsl -d $d ~/temp.sh
}