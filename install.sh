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

# volta
# volta install node

az extension add --name azure-devops
az extension add --name interactive

# bash and others

mkdir -p ~/.config/mise/
rm ~/.config/mise/config.toml > /dev/null 2>&1
ln -s ~/dotfiles/mise.config.toml ~/.config/mise/config.toml
chmod 644 ~/.config/mise/config.toml

rm ~/.bashrc > /dev/null 2>&1
ln -s ~/dotfiles/.bashrc ~/.bashrc
chmod 644 ~/.bashrc

rm ~/.zshrc > /dev/null 2>&1
ln -s ~/dotfiles/.zshrc ~/.zshrc
chmod 644 ~/.zshrc

rm ~/.zprofile > /dev/null 2>&1
ln -s ~/dotfiles/.zprofile ~/.zprofile
chmod 644 ~/.zprofile

rm ~/.inputrc > /dev/null 2>&1
ln -s ~/dotfiles/.inputrc ~/.inputrc
chmod 644 ~/.inputrc

rm ~/.bash_aliases > /dev/null 2>&1
ln -s ~/dotfiles/.bash_aliases ~/.bash_aliases
chmod 644 ~/.bash_aliases

rm -rf ~/.ssh > /dev/null 2>&1
ln -s ~/dotfiles/ssh/ ~/.ssh
find ~/.ssh/ -type f -print0 | xargs -0 chmod 600

mkdir ~/.config/ > /dev/null 2>&1

rm ~/.config/thefuck/ > /dev/null 2>&1
ln -s ~/dotfiles/thefuck/ ~/.config/thefuck
find ~/.config/thefuck/ -type f -print0 | xargs -0 chmod 644

rm ~/.config/powershell/ > /dev/null 2>&1
ln -s ~/dotfiles/powershell/ ~/.config/powershell
find ~/.config/powershell/ -type f -print0 | xargs -0 chmod 644

# Claude Code user-level config
mkdir ~/.claude/ > /dev/null 2>&1
rm ~/.claude/CLAUDE.md > /dev/null 2>&1
ln -s ~/dotfiles/ai/claude/CLAUDE.md ~/.claude/CLAUDE.md
chmod 644 ~/.claude/CLAUDE.md
rm ~/.claude/settings.json > /dev/null 2>&1
ln -s ~/dotfiles/ai/claude/settings.json ~/.claude/settings.json
chmod 644 ~/.claude/settings.json
rm -rf ~/.claude/agents > /dev/null 2>&1
ln -s ~/dotfiles/ai/agents/ ~/.claude/agents
rm -rf ~/.claude/skills > /dev/null 2>&1
ln -s ~/dotfiles/ai/skills/ ~/.claude/skills

# GitHub Copilot user-level config
mkdir ~/.copilot/ > /dev/null 2>&1
rm ~/.copilot/copilot-instructions.md > /dev/null 2>&1
ln -s ~/dotfiles/ai/copilot/copilot-instructions.md ~/.copilot/copilot-instructions.md
chmod 644 ~/.copilot/copilot-instructions.md
rm -rf ~/.copilot/agents > /dev/null 2>&1
ln -s ~/dotfiles/ai/agents/ ~/.copilot/agents
rm -rf ~/.copilot/skills > /dev/null 2>&1
ln -s ~/dotfiles/ai/skills/ ~/.copilot/skills
rm -rf ~/.copilot/hooks > /dev/null 2>&1
ln -s ~/dotfiles/ai/copilot/hooks/ ~/.copilot/hooks
rm -rf ~/.copilot/prompts > /dev/null 2>&1
ln -s ~/dotfiles/ai/copilot/prompts/ ~/.copilot/prompts

if [ $WT_SESSION ]; then
    # ssh forwarding
    ln -s ~/dotfiles/.wslrc ~/.wslrc
    chmod 644 ~/.wslrc
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
