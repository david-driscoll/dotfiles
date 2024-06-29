$distros = wsl -l -q | where { $_ -ne 'docker-desktop-data' -and $_ -ne 'docker-desktop' -and $_.Trim() -ne '' } | foreach { $_.Trim() -replace '[^a-zA-Z0-9\-\.]', '' } | where { $_.Trim() -ne "" }
# $distros = @("Ubuntu20")
foreach ($d in $distros) {
    Write-Host -ForegroundColor Cyan $d
    $me = (wsl -d $d whoami).Trim()

    $script = @"
#!/bin/bash
rm ~/dotfiles
ln -s /mnt/c/Users/$ENV:USERNAME/dotfiles/ ~/dotfiles
~/dotfiles/install.sh
~/dotfiles/setup/setup.sh

"@.Replace("`r", "")
    $file = New-TemporaryFile
    $script | Out-File $file -Encoding utf8NoBOM
    Copy-Item $file \\wsl$\$d\home\$me\temp.sh
    wsl -d $d chmod 755 ~/temp.sh
    wsl -d $d ~/temp.sh
}