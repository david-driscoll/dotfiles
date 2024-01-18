# dotfiles installer
wget https://packages.microsoft.com/config/ubuntu/18.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
sudo dpkg -i packages-microsoft-prod.deb
rm packages-microsoft-prod.deb
sudo apt-get update

curl -sS https://starship.rs/install.sh | sh
sudo apt-get install -y python3 python3-pip powershell kubectl
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
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && sudo apt update \
    && sudo apt install gh -y

# zoxide
curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash

curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
sudo apt-get install apt-transport-https --yes
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt-get install helm

# volta
curl https://get.volta.sh | bash
volta install node

az extension add --name azure-devops
az extension add --name interactive

gh extension install dlvhdr/gh-dash
gh extension install seachicken/gh-poi
gh extension install meiji163/gh-notify

# bash and others

rm ~/.bashrc > /dev/null 2>&1
ln -s ~/dotfiles/.bashrc ~/.bashrc
chmod 644 ~/.bashrc

rm ~/.inputrc > /dev/null 2>&1
ln -s ~/dotfiles/.inputrc ~/.inputrc
chmod 644 ~/.inputrc

rm ~/.bash_aliases > /dev/null 2>&1
ln -s ~/dotfiles/.bash_aliases ~/.bash_aliases
chmod 644 ~/.bash_aliases

mkdir ~/.config/ > /dev/null 2>&1

rm ~/.config/thefuck/ > /dev/null 2>&1
ln -s ~/dotfiles/thefuck/ ~/.config/thefuck/
find ~/.config/thefuck/ -type f -print0 | xargs -0 chmod 644

rm ~/.config/powershell/ > /dev/null 2>&1
ln -s ~/dotfiles/powershell/ ~/.config/powershell/

if [ $WT_SESSION ]; then
    # ssh forwarding
    sudo apt install socat
    sudo apt install gpg
    ln -s ~/dotfiles/.wslrc ~/.wslrc
    chmod 644 ~/.wslrc
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
