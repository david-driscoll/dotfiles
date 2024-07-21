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
brew bunlde --file=./Brewfile.darwin

volta install node

sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

dotnet tool install -g dotnet-try
dotnet try jupyter install

az extension add --name azure-devops
az extension add --name interactive

gh extension install davidraviv/gh-clean-branches
gh extension install github/gh-codeql
gh extension install mislav/gh-contrib
gh extension install github/gh-copilot
gh extension install dlvhdr/gh-dash
gh extension install meiji163/gh-notify
gh extension install seachicken/gh-poi
gh extension install vilmibm/gh-screensaver
gh extension install AdamVig/gh-watch

# path for volta
# path for python / pip

# keybase login

ln -s ~/dotfiles/ssh/ ~/.ssh
find .ssh/ -type f -print0 | xargs -0 chmod 600

ln -s ~/dotfiles/gpg-agent.conf ~/.gnupg/gpg-agent.conf
find .gnupg/ -type f -print0 | xargs -0 chmod 644

ln -s ~/dotfiles/.config/.bashrc ~/.bashrc
chmod 644 ~/.bashrc
ln -s ~/dotfiles/.config/.inputrc ~/.inputrc
chmod 644 ~/.inputrc
ln -s ~/dotfiles/.config/.bash_aliases ~/.bash_aliases
chmod 644 ~/.bash_aliases
ln -s ~/dotfiles/.config/powershell/macos.ps1 ~/.config/powershell/Microsoft.PowerShell_profile.ps1

ln -s ~/dotfiles/.config/thefuck/ ~/.config/thefuck/
find ~/.config/thefuck/ -type f -print0 | xargs -0 chmod 644

git config --global core.eol lf
git config --global github.user david-driscoll
git config --global gpg.format ssh
git config --global user.signingkey "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFEZpmeANLSx9Worwn0REmiWKLEkDvGaaz5ZlCVuRc67"
git config --global user.name "David Driscoll"
git config --global user.email "david.driscoll@gmail.com"
git config --global commit.gpgsign true
# TODO: 1Password
git config --global core.editor "vi"
git config --global alias.amend "commit --amend --reuse-message=HEAD"
git config --global url."git@github.com:".insteadOf "https://github.com/"