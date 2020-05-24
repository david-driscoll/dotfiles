# dotfiles installer
sudo apt-get update

curl -fsSL https://starship.rs/install.sh | bash -s --yes
sudo apt-get install -y python3 python3-pip
sudo update-alternatives --install /usr/bin/python python /usr/bin/python3 10
sudo update-alternatives --install /usr/bin/pip pip /usr/bin/pip3 10
sudo pip install thefuck

cp -f ./.bashrc ~/.bashrc
chmod 644 ~/.bashrc
cp -f ./.inputrc ~/.inputrc
chmod 644 ~/.inputrc
cp -f ./.bash_aliases ~/.bash_aliases
chmod 644 ~/.bash_aliases

mkdir ~/.config/
cp -rf ~/dotfiles/thefuck/ ~/.config/thefuck/
cp -rf ~/dotfiles/powershell/ ~/.config/powershell/
find ~/.config/thefuck/ -type f -print0 | xargs -0 chmod 644
echo '. "~/dotfiles/profile.ps1"' >~/.config/powershell/Microsoft.PowerShell_profile.ps1

git config --global core.eol lf
git config --global core.autocrlf true
git config --global github.user david-driscoll
git config --global user.name "David Driscoll"
git config --global user.email "david.driscoll@gmail.com"
git config --global core.editor "vi"
git config --global alias.amend "commit --amend --reuse-message=HEAD"
