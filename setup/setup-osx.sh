/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew 

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