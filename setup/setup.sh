sudo apt-get update

curl -fsSL https://starship.rs/install.sh | bash -s -- --yes
sudo apt-get install -y git
sudo apt-get install -y postgresql-client
sudo apt-get install -y jq
sudo apt-get install -y python3 python3-pip
sudo apt-get install -y fonts-firacode
# todo nerd font, jetbrain fonts, cascadia code
sudo apt-get install -y pinentry-tty pinentry-gtk2
sudo apt-get install -y openssh-client openssh-server
sudo update-alternatives --install /usr/bin/python python /usr/bin/python3 10
sudo update-alternatives --install /usr/bin/pip pip /usr/bin/pip3 10
sudo pip install thefuck

# pwsh
wget -q https://packages.microsoft.com/config/ubuntu/18.04/packages-microsoft-prod.deb
sudo dpkg -i ./packages-microsoft-prod.deb
sudo apt-get update
sudo add-apt-repository universe
sudo apt-get install -y powershell
rm ./packages-microsoft-prod.deb
#

# dotnet core
curl -sL https://dot.net/v1/dotnet-install.sh >~/dotnet-install.sh
chmod 755 ~/dotnet-install.sh
./dotnet-install.sh --channel LTS
./dotnet-install.sh --channel Current
rm ~/dotnet-install.sh

# docker
sudo apt install -y docker.io

# azure cli
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
az extension add --name azure-devops
az extension add --name interactive

# keybase
curl --remote-name https://prerelease.keybase.io/keybase_amd64.deb
sudo apt install -y ./keybase_amd64.deb
run_keybase
rm ./keybase_amd64.deb
#

# volta
curl https://get.volta.sh | bash

keybase login

ln -s ~/.ssh ~/dotfiles/ssh/
find ~/.ssh/ -type f -print0 | xargs -0 chmod 600

ln -s ~/dotfiles/gnupg/gpg-agent.conf ~/.gnupg/gpg-agent.conf
find ~/.gnupg/ -type f -print0 | xargs -0 chmod 644

ln -s ~/dotfiles/.bashrc ~/.bashrc
chmod 644 ~/.bashrc
ln -s ~/dotfiles/.inputrc ~/.inputrc
chmod 644 ~/.inputrc
ln -s ~/dotfiles/.bash_aliases ~/.bash_aliases
chmod 644 ~/.bash_aliases
ln -s ~/dotfiles/.config/powershell/Microsoft.PowerShell_profile.ps1 ~/.config/powershell/Microsoft.PowerShell_profile.ps1

ln -s ~/dotfiles/.config/thefuck/ ~/.config/thefuck/
find ~/.config/thefuck/ -type f -print0 | xargs -0 chmod 644

git config --global core.eol lf
git config --global core.autocrlf true
git config --global github.user david-driscoll
git config --global gpg.format ssh
git config --global user.signingkey "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFEZpmeANLSx9Worwn0REmiWKLEkDvGaaz5ZlCVuRc67"
git config --global user.name "David Driscoll"
git config --global user.email "david.driscoll@gmail.com"
git config --global commit.gpgsign true
# TODO: 1Password
git config --global gpg.program "gpg"
git config --global core.editor "vi"
git config --global alias.amend "commit --amend --reuse-message=HEAD"
git config --global url."git@github.com:".insteadOf "https://github.com/"