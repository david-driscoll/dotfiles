
export VOLTA_HOME="$HOME/.volta"
export PATH="$VOLTA_HOME/bin:$HOME/.jetbrains:$HOME/.dotnet/:$HOME/.dotnet/tools:$PATH"
export STARSHIP_CONFIG=~/.cmder/config/starship.toml

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

bindkey -M emacs '\e\e' kill-whole-line
