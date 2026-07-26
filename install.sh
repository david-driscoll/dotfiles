#!/bin/bash
# check if brew is installed


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


brew bundle --file ./setup/Brewfile

# sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
# wget https://dot.net/v1/dotnet-install.sh \
#     && chmod +x dotnet-install.sh \
#     && ./dotnet-install.sh --channel LTS \
#     && rm dotnet-install.sh
# wget -qO- https://aka.ms/install-artifacts-credprovider.sh | bash

az extension add --name azure-devops
az extension add --name interactive

# bash and others

mkdir -p ~/.config/mise/
rm ~/.config/mise/config.toml > /dev/null 2>&1
# NOTE: file symlink to the new location, not yet the directory symlink
# (~/.config/mise -> ~/dotfiles/.config/mise) the target layout wants — that
# switch is installer work tracked in #68/#69/#72. This just stops pointing at
# the now-deleted mise.config.toml.
ln -s ~/dotfiles/.config/mise/config.toml ~/.config/mise/config.toml
chmod 644 ~/.config/mise/config.toml

# .bashrc, .zshrc, .zprofile, .inputrc, .bash_aliases, ~/.ssh, ~/.config/powershell,
# ~/.claude/{rules,skills}: now managed by `[dotfiles]` in .config/mise/config.toml
# (#64) — run `mise dotfiles apply` instead of re-adding ln -s lines here.
# The old Claude Code (ai/claude/*, ai/agents/) and GitHub Copilot (ai/copilot/*)
# targets below this comment never existed in this repo and are not carried
# forward; see PR #64's description for what real paths replace them.

mkdir ~/.config/ > /dev/null 2>&1

if [ $WT_SESSION ]; then
    # ssh forwarding
    # todo configure for current wsl user
    git config --global gpg."ssh".program "/mnt/c/Program Files/1Password/app/8/op-ssh-sign-wsl"
elif [[ "$(uname)" != "Darwin" ]]; then
    ARCH=$(uname -m)
    case $ARCH in
        x86_64) ARCH="amd64" ;;
        armv6l) ARCH="arm" ;;
        armv7l) ARCH="arm" ;;
        aarch64) ARCH="arm64" ;;
        *) echo "Unsupported architecture"; exit 1 ;;
    esac
    wget "https://cache.agilebits.com/dist/1P/op2/pkg/v2.29.0/op_linux_${ARCH}_v2.29.0.zip" -O op.zip && \
        unzip -d op op.zip && \
        sudo mv op/op /usr/local/bin/ && \
        rm -rf op.zip op && \
        sudo groupadd -f onepassword-cli && \
        sudo chgrp onepassword-cli /usr/local/bin/op && \
        sudo chmod g+s /usr/local/bin/op
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
git config --global alias.squash '!f() { git rebase -i --autosquash $1; }; f'
# not sure if this is needed, caused issues in code spaces
# git config --global url."git@github.com:".insteadOf "https://github.com/"

gh auth login
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