# dotfiles installer
wget https://packages.microsoft.com/config/ubuntu/18.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
sudo dpkg -i packages-microsoft-prod.deb
rm packages-microsoft-prod.deb
sudo apt-get update

curl -fsSL https://starship.rs/install.sh | sudo bash -s -- --yes
sudo apt-get install -y python3 python3-pip powershell
sudo update-alternatives --install /usr/bin/python python /usr/bin/python3 10
sudo update-alternatives --install /usr/bin/pip pip /usr/bin/pip3 10
sudo pip install thefuck

# jq
sudo apt install jq

# 1password cli
sudo -s curl -sS https://downloads.1password.com/linux/keys/1password.asc | gpg --dearmor --output /usr/share/keyrings/1password-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/$(dpkg --print-architecture) stable main" | tee /etc/apt/sources.list.d/1password.list
mkdir -p /etc/debsig/policies/AC2D62742012EA22/
curl -sS https://downloads.1password.com/linux/debian/debsig/1password.pol | tee /etc/debsig/policies/AC2D62742012EA22/1password.pol
mkdir -p /usr/share/debsig/keyrings/AC2D62742012EA22
curl -sS https://downloads.1password.com/linux/keys/1password.asc | gpg --dearmor --output /usr/share/debsig/keyrings/AC2D62742012EA22/debsig.gpg
sudo apt update && sudo apt install 1password-cli

# gh
GHVERSION=`curl  "https://api.github.com/repos/cli/cli/releases/latest" | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/' | cut -c2-`

curl -sSL https://github.com/cli/cli/releases/download/v${GHVERSION}/gh_${GHVERSION}_linux_amd64.deb -o gh.deb
sudo apt install ./gh.deb
rm gh.deb

# volta
curl https://get.volta.sh | bash
volta install node

# bash and others

touch ~/.bashrc > /dev/null 2>&1
cp -f ~/dotfiles/.bashrc ~/.bashrc
chmod 644 ~/.bashrc

touch ~/.inputrc > /dev/null 2>&1
cp -f ~/dotfiles/.inputrc ~/.inputrc
chmod 644 ~/.inputrc

touch ~/.bash_aliases > /dev/null 2>&1
cp -f ~/dotfiles/.bash_aliases ~/.bash_aliases
chmod 644 ~/.bash_aliases

mkdir ~/.config/ > /dev/null 2>&1

mkdir ~/.config/thefuck/ > /dev/null 2>&1
cp -rf ~/dotfiles/thefuck/ ~/.config/
find ~/.config/thefuck/ -type f -print0 | xargs -0 chmod 644

mkdir ~/.config/powershell/ > /dev/null 2>&1
cp -rf ~/dotfiles/powershell/ ~/.config/

if [ $WT_SESSION ]; then
    # ssh forwarding
    sudo apt install socat
    sudo apt install gpg

    WINDOWS_USER=$(/mnt/c/Windows/System32/cmd.exe /c 'echo %USERNAME%' | sed -e 's/\r//g') > /dev/null 2>&1

    rm ~/.ssh > /dev/null 2>&1
    rm ~/.local/state/gh > /dev/null 2>&1
    rm ~/.config/gh > /dev/null 2>&1
    rm ~/dotfiles > /dev/null 2>&1
    rm ~/.bashrc > /dev/null 2>&1
    rm ~/.inputrc > /dev/null 2>&1
    rm ~/.bash_aliases > /dev/null 2>&1
    rm ~/.wslrc > /dev/null 2>&1
    rm ~/.config/powershell > /dev/null 2>&1
    mkdir -p ~/.local/state/ > /dev/null 2>&1
    mkdir -p ~/.config/ > /dev/null 2>&1
    ln -s /mnt/c/Users/$WINDOWS_USER/.ssh/ ~/.ssh
    ln -s /mnt/c/Users/$WINDOWS_USER/.cmder/config/ ~/dotfiles
    ln -s "/mnt/c/Users/$WINDOWS_USER/AppData/Roaming/GitHub CLI/" ~/.config/gh
    ln -s "/mnt/c/Users/$WINDOWS_USER/AppData/Local/GitHub CLI/" ~/.local/state/gh
    ln -s "/mnt/c/Users/$WINDOWS_USER/.cmder/config/powershell/" ~/.config/powershell
    ln -s "/mnt/c/Users/$WINDOWS_USER/.cmder/config/.bashrc" ~/.bashrc
    ln -s "/mnt/c/Users/$WINDOWS_USER/.cmder/config/.inputrc" ~/.inputrc
    ln -s "/mnt/c/Users/$WINDOWS_USER/.cmder/config/.bash_aliases" ~/.bash_aliases
    ln -s "/mnt/c/Users/$WINDOWS_USER/.cmder/config/.wslrc" ~/.wslrc
fi

git config --global core.eol lf
git config --global core.autocrlf false
git config --global github.user david-driscoll
git config --global gpg.format ssh
git config --global user.signingkey "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFEZpmeANLSx9Worwn0REmiWKLEkDvGaaz5ZlCVuRc67"
git config --global user.name "David Driscoll"
git config --global user.email "david.driscoll@gmail.com"
git config --global core.editor "vi"
# TODO: 1Password
# TODO: Setup npiperelay
git config --global commit.gpgsign true
git config --global alias.amend "commit --amend --reuse-message=HEAD"
git config --global url."git@github.com:".insteadOf "https://github.com/"
