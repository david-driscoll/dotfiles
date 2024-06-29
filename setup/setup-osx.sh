/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

brew tap homebrew/cask-fonts
brew tap isen-ng/dotnet-sdk-versions
brew tap hashicorp/tap

brew install --cask powershell
brew install azure-cli
brew install starship
brew install karabiner-elements
brew install python
brew install --cask miniconda
brew install --cask iterm2
brew install --cask stats
brew install ruby
brew install --cask google-chrome
brew install --cask google-chrome-beta
brew install --cask firefox
brew install --cask firefox-beta
brew install --cask microsoft-edge
brew install --cask microsoft-edge-beta
brew install --cask keybase
brew install --cask eul
brew install gh
brew install --cask git
brew install --cask gitkraken
brew install --cask royal-tsx
brew install --cask slack
brew install --cask microsoft-teams
brew install --cask dotnet-sdk
brew install --cask dotnet-sdk3-1-400
brew install --cask gpg-suite
brew install jq
brew install --cask font-fira-code
brew install --cask font-fira-code-nerd-font
brew install --cask font-fira-mono-nerd-font
brew install --cask font-jetbrains-mono-nerd-font
brew install --cask font-jetbrains-mono
brew install --cask font-caskaydia-cove-nerd-font
brew install --cask font-cascadia-mono-pl
brew install --cask font-cascadia-code-pl
brew install --cask font-cascadia-mono
brew install --cask font-cascadia-code

brew install --cask visual-studio
brew install --cask visual-studio-code
brew install --cask visual-studio-code-insiders
brew install hashicorp/tap/terraform
brew install pulumi/tap/pulumi
brew install --cask 1password/tap/1password-cli
brew install kubernetes-cli
brew install helm

wget -qO- https://aka.ms/install-artifacts-credprovider.sh | bash
curl https://get.volta.sh | bash
volta install node

sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions

curl https://bootstrap.pypa.io/get-pip.py -o ~/get-pip.py
python3 ~/get-pip.py
rm ~/get-pip.py

pip install thefuck
conda install -c conda-forge notebook jupyterlab
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