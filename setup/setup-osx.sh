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

# ./Brewfile (formula-only) and ./Brewfile.darwin (cask-only) are no longer
# bundled directly here as of #67 — see the mise-driven block below, after
# the config symlink, for what replaced them. `mise` itself used to come
# from a plain `brew "mise"` entry in the old Brewfile; install it directly
# instead.
brew install mise

sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

az extension add --name azure-devops
az extension add --name interactive

# path for python / pip

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

# Formulae (zsh + plugins, powershell, git, moreutils, mas, azure-cli,
# gitkraken-cli, speedtest-cli) live in config.macos.toml's
# [bootstrap.packages] as of #67; `packages apply`'s own documented
# sequence runs [bootstrap.hooks.post-packages] afterward, which fires the
# brew:casks task (setup/Brewfile.darwin) — one call installs both. This
# script is macOS-only already, so no uname guard is needed here (compare
# install.sh, which is also used on Linux). MISE_AUTO_ENV=1 makes mise load
# config.macos.toml alongside config.toml (see that file's [settings]
# comment for why the setting alone isn't enough during a one-shot script
# run before .zshrc has exported it).
mise trust ~/.config/mise/config.toml
MISE_AUTO_ENV=1 mise bootstrap --only packages --yes

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

# git config: now a committed ~/.gitconfig deployed via `[dotfiles]` in
# .config/mise/config.toml + config.macos.toml (#65) — run `mise dotfiles
# apply` instead of re-adding `git config --global` lines here. The macOS
# 1Password SSH-signing path this script used to set directly now lives at
# git/gitconfig.darwin.

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