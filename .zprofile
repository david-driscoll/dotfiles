
export VOLTA_HOME="$HOME/.volta"
export PATH="$VOLTA_HOME/bin:$HOME/.jetbrains:$HOME/.dotnet/:$HOME/.dotnet/tools:$PATH"
export STARSHIP_CONFIG=~/dotfiles/starship.toml
unset SSH_AUTH_SOCK
export SSH_AUTH_SOCK=~/Library/Group\ Containers/2BUA8C4S2C.com.1password/t/agent.sock

alias cls=clear
alias icode=$(which code-insiders)
alias vscode=$(which code)
alias rcode=$(which code)
alias code=$(which code-insiders)

if type brew &>/dev/null; then
  FPATH=$(brew --prefix)/share/zsh/site-functions:$FPATH

  autoload -Uz compinit
  compinit
fi
if type terraform &>/dev/null; then
  terraform -install-autocomplete
fi

bindkey -M emacs '\e\e' kill-whole-line
