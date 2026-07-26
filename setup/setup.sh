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

# git config: now a committed ~/.gitconfig deployed via `[dotfiles]` in
# .config/mise/config.toml (#65) — run `mise dotfiles apply` instead of
# re-adding `git config --global` lines here. This script's own
# core.autocrlf=true (vs. install.sh's false) was one of the exact
# conflicts #65 resolved — settled to false everywhere.
