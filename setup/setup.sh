if ! command -v brew >/dev/null 2>&1; then
    if [[ "$(uname)" != "Darwin" ]] && [[ "$(uname -m)" == *"arm"* || "$(uname -m)" == *"aarch64"* ]]; then
        export HOMEBREW_BREW_GIT_REMOTE=https://github.com/huyz/brew-for-linux-arm
        export HOMEBREW_DEVELOPER=1
        NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh | sed '532s/abort/warn/')"
    else
        NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
fi

if [[ "$(uname)" == "Darwin" ]] then
    eval $(/opt/homebrew/bin/brew shellenv)
else
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi

brew bunlde --file=./Brewfile

sudo apt-get update
sudo update-alternatives --install /usr/bin/python python /usr/bin/python3 10
sudo update-alternatives --install /usr/bin/pip pip /usr/bin/pip3 10


# azure cli
az extension add --name azure-devops
az extension add --name interactive

# volta
curl https://get.volta.sh | bash

# keybase login

ln -s ~/dotfiles/ssh/ ~/.ssh
find ~/.ssh/ -type f -print0 | xargs -0 chmod 600

mkdir ~/.gnupg/
ln -s ~/dotfiles/gpg-agent.conf ~/.gnupg/gpg-agent.conf
find ~/.gnupg/ -type f -print0 | xargs -0 chmod 644

rm ~/.bashrc
ln -s ~/dotfiles/.bashrc ~/.bashrc
chmod 644 ~/.bashrc

rm ~/.zprofile
ln -s ~/dotfiles/.zprofile ~/.zprofile
chmod 644 ~/.zprofile

rm ~/.zshrc
ln -s ~/dotfiles/.zshrc ~/.zshrc
chmod 644 ~/.zshrc

rm ~/.inputrc
ln -s ~/dotfiles/.inputrc ~/.inputrc
chmod 644 ~/.inputrc

rm ~/.bash_aliases
ln -s ~/dotfiles/.bash_aliases ~/.bash_aliases
chmod 644 ~/.bash_aliases

mkdir -p ~/.config/powershell/
ln -s ~/dotfiles/powershell/Microsoft.PowerShell_profile.ps1 ~/.config/powershell/Microsoft.PowerShell_profile.ps1

ln -s ~/dotfiles/thefuck ~/.config/thefuck
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

# try to handle error: fetch-pack: unexpected disconnect while reading sideband packet
git config --global core.packedGitLimit 512m
git config --global core.packedGitWindowSize 512m
git config --global pack.deltaCacheSize 2047m
git config --global pack.packSizeLimit 2047m
git config --global pack.windowMemory 2047m
