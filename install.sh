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

# gh
GHVERSION=`curl  "https://api.github.com/repos/cli/cli/releases/latest" | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/' | cut -c2-` 

curl -sSL https://github.com/cli/cli/releases/download/v${GHVERSION}/gh_${GHVERSION}_linux_amd64.deb -o gh.deb
sudo apt install ./gh.deb
rm gh.deb

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
mkdir ~/.config/powershell/ > /dev/null 2>&1
cp -rf ~/dotfiles/powershell/ ~/.config/
find ~/.config/thefuck/ -type f -print0 | xargs -0 chmod 644
echo '. "~/dotfiles/profile.ps1"' >~/.config/powershell/Microsoft.PowerShell_profile.ps1

if [ $WT_SESSION ]; then
    WINDOWS_USER=$(/mnt/c/Windows/System32/cmd.exe /c 'echo %USERNAME%' | sed -e 's/\r//g') > /dev/null 2>&1

    cp -rf /mnt/c/Users/$WINDOWS_USER/.ssh/ ~/.ssh/
    find ~/.ssh/ -type f -print0  | xargs -0 chmod 600
    
    mkdir ~/.config/gh/ > /dev/null 2>&1
    cp -rf /mnt/c/Users/$WINDOWS_USER/.config/gh/ ~/.config/gh/
    find ~/.config/gh/ -type f -print0  | xargs -0 chmod 600
    pushd ~/dotfiles/
    git remote remove origin
    git remote add origin git@github.com:david-driscoll/dotfiles.git
    popd
fi

git config --global core.eol lf
git config --global core.autocrlf false
git config --global github.user david-driscoll
git config --global user.name "David Driscoll"
git config --global user.email "david.driscoll@gmail.com"
git config --global core.editor "vi"
git config --global alias.amend "commit --amend --reuse-message=HEAD"
