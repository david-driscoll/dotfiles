#!/bin/bash
if ! command -v brew >/dev/null 2>&1; then
    if [[ "$(uname)" != "Darwin" ]] && [[ "$(uname -m)" == *"arm"* || "$(uname -m)" == *"aarch64"* ]]; then
        export HOMEBREW_BREW_GIT_REMOTE=https://github.com/huyz/brew-for-linux-arm
        export HOMEBREW_DEVELOPER=1
        NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh | sed '532s/abort/warn/')"
    else
        NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
fi

if [[ "$(uname)" == "Darwin" ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
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

# ~/.ssh: now managed by `[dotfiles]` in .config/mise/config.toml (#64,
# symlink-each mode — see that file for why). This used to `rm -rf ~/.ssh`
# with no `mkdir` first; `mise dotfiles apply` creates the directory safely.

mkdir -p ~/.config/mise/
rm ~/.config/mise/config.toml > /dev/null 2>&1
# NOTE: file symlink to the new location, not yet the directory symlink
# (~/.config/mise -> ~/dotfiles/.config/mise) the target layout wants — that
# switch is installer work tracked in #68/#69/#72. This just stops pointing at
# the now-deleted mise.config.toml.
ln -s ~/dotfiles/.config/mise/config.toml ~/.config/mise/config.toml
chmod 644 ~/.config/mise/config.toml

# ~/.gnupg/gpg-agent.conf, .bashrc, .zprofile, .zshrc, .inputrc, .bash_aliases,
# ~/.config/powershell: now managed by `[dotfiles]` in .config/mise/config.toml
# (#64) — run `mise dotfiles apply` instead of re-adding ln -s lines here.
# (This script previously linked ~/.config/powershell to a single file while
# install.sh linked the whole directory; [dotfiles] resolves that in favor
# of the directory form.)

git config --global core.eol lf
git config --global core.autocrlf true
git config --global github.user david-driscoll
git config --global user.name "David Driscoll"
git config --global user.email "david.driscoll@gmail.com"
# git config --global user.signingkey "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFEZpmeANLSx9Worwn0REmiWKLEkDvGaaz5ZlCVuRc67"
# git config --global gpg.format ssh
# git config --global commit.gpgsign true
# git config --global gpg.ssh.program "/Applications/1Password.app/Contents/MacOS/op-ssh-sign"

# TODO: 1Password
git config --global gpg.program "gpg"
git config --global core.editor "vi"
git config --global alias.amend "commit --amend --reuse-message=HEAD"
git config --global alias.squash '!f() { git rebase -i --autosquash $1; }; f'
# not sure if this is needed, caused issues in code spaces
# git config --global url."git@github.com:".insteadOf "https://github.com/"

# try to handle error: fetch-pack: unexpected disconnect while reading sideband packet
git config --global core.packedGitLimit 512m
git config --global core.packedGitWindowSize 512m
git config --global pack.deltaCacheSize 2047m
git config --global pack.packSizeLimit 2047m
git config --global pack.windowMemory 2047m
