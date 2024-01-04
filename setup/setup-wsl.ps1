$distros = wsl -l -q | where { $_ -ne 'docker-desktop-data' -and $_ -ne 'docker-desktop' -and $_.Trim() -ne '' } | foreach { $_.Trim() -replace '[^a-zA-Z0-9\-\.]', '' } | where { $_.Trim() -ne "" }
# $distros = @("Ubuntu20")
foreach ($d in $distros) {
    Write-Host -ForegroundColor Cyan $d
    $me = (wsl -d $d whoami).Trim()

    $script = @"
#!/bin/bash
mkdir -p ~/.local/state/
mkdir -p ~/.config/
ln -s /mnt/c/Users/$ENV:USERNAME/dotfiles/ ~/dotfiles
ln -s `"/mnt/c/Users/$ENV:USERNAME/AppData/Roaming/GitHub CLI/`" ~/.config/gh
ln -s `"/mnt/c/Users/$ENV:USERNAME/AppData/Local/GitHub CLI/`" ~/.local/state/gh


"@.Replace("`r", "")
    $file = New-TemporaryFile
    $script | Out-File $file -Encoding utf8NoBOM

    Copy-Item $file \\wsl$\$d\home\$me\temp.sh
    wsl -d $d chmod 755 ~/temp.sh
    wsl -d $d ~/temp.sh
    # Copy-Item ~/.ssh/ \\wsl$\$d\home\$me\ -Recurse
    # wsl -d $d 'chmod 777 ~/.ssh'
    # foreach ($file in gci ~/.ssh) {
    #     if ($file.Name.EndsWith(".pub")) {
    #         wsl -d $d chmod 644 "~/.ssh/$($_.Name)"
    #     }
    #     else {
    #         wsl -d $d chmod 600 "~/.ssh/$($_.Name)"
    #     }

    # }
    # wsl -d $d git clone git@github.com:david-driscoll/dotfiles.git ~/dotfiles
}