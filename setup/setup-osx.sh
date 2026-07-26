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

brew bundle --file=./Brewfile
brew bundle --file=./Brewfile.darwin

volta install node

sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

dotnet tool install -g dotnet-try
dotnet try jupyter install

az extension add --name azure-devops
az extension add --name interactive

# path for volta
# path for python / pip

# keybase login

# ~/.ssh, ~/.config/karabiner/karabiner.json, ~/.gnupg/gpg-agent.conf: now
# managed by `[dotfiles]` in .config/mise/config.toml + config.macos.toml
# (#64) — run `mise dotfiles apply` instead of re-adding ln -s lines here.

mkdir -p ~/.config/mise/
rm ~/.config/mise/config.toml
# NOTE: file symlink to the new location, not yet the directory symlink
# (~/.config/mise -> ~/dotfiles/.config/mise) the target layout wants — that
# switch is installer work tracked in #68/#69/#72. This just stops pointing at
# the now-deleted mise.config.toml.
ln -s ~/dotfiles/.config/mise/config.toml ~/.config/mise/config.toml
chmod 644 ~/.config/mise/config.toml

# .bashrc, .inputrc, .bash_aliases, ~/.config/powershell: now managed by
# `[dotfiles]` in .config/mise/config.toml (#64). These lines used to point
# at ~/dotfiles/.config/.bashrc etc, which never existed in this repo —
# the real files are at the repo root (~/dotfiles/.bashrc).

mkdir -p ~/.apm/
rm -f ~/.apm/config.json
ln -s ~/dotfiles/.apm/config.json ~/.apm/config.json
rm -f ~/.apm/marketplaces.json
ln -s ~/dotfiles/.apm/marketplaces.json ~/.apm/marketplaces.json
rm -f ~/.apm/mise.toml
# .apm/mise.toml was folded into the repo-local mise.toml at repo root (#63) —
# this now links to the whole repo-local config (crew tasks/env included, not
# just the apm/skillfile tool pins the old dedicated file had). Harmless for
# mise inside ~/.apm/ (unused tasks/env just sit idle), but worth a second look
# if that ever needs to be its own minimal file again.
ln -s ~/dotfiles/mise.toml ~/.apm/mise.toml

git config --global core.eol lf
git config --global github.user david-driscoll
git config --global gpg.format ssh
git config --global user.signingkey "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFEZpmeANLSx9Worwn0REmiWKLEkDvGaaz5ZlCVuRc67"
git config --global user.name "David Driscoll"
git config --global user.email "david.driscoll@gmail.com"
git config --global commit.gpgsign true
git config --global gpg.ssh.program "/Applications/1Password.app/Contents/MacOS/op-ssh-sign"
# TODO: 1Password
git config --global core.editor "vi"
git config --global alias.amend "commit --amend --reuse-message=HEAD"
git config --global alias.squash '!f() { git rebase -i --autosquash $1; }; f'
# not sure if this is needed, caused issues in code spaces
# git config --global url."git@github.com:".insteadOf "https://github.com/"

gh extension install davidraviv/gh-clean-branches
gh extension install github/gh-codeql
gh extension install mislav/gh-contrib
gh extension install github/gh-copilot
gh extension install dlvhdr/gh-dash
gh extension install meiji163/gh-notify
gh extension install seachicken/gh-poi
gh extension install vilmibm/gh-screensaver
gh extension install AdamVig/gh-watch
gh extension install shuymn/gh-mcp