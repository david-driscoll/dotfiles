# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"
export STARSHIP_CONFIG=~/dotfiles/starship.toml
export COPILOT_CUSTOM_INSTRUCTIONS_DIRS=~/dotfiles/ai

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time oh-my-zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="robbyrussell"

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
HYPHEN_INSENSITIVE="true"

# Uncomment the following line to disable bi-weekly auto-update checks.
# DISABLE_AUTO_UPDATE="true"

# Uncomment the following line to automatically update without prompting.
DISABLE_UPDATE_PROMPT="true"

# Uncomment the following line to change how often to auto-update (in days).
# export UPDATE_ZSH_DAYS=13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
ENABLE_CORRECTION="false"

# Uncomment the following line to display red dots whilst waiting for completion.
COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(
  1password
  aws
  aliases
  alias-finder
  azure
  brew
  colored-man-pages
  colorize
  common-aliases
  command-not-found
  copyfile
  cp
  direnv
  docker
  podman
  eza
  kubectl
  helm
  encode64
  extract
  emoji
  emoji-clock
  # gpg-agent
  # ssh-agent
  macos
  git
  gh
  git-auto-fetch
  git-escape-magic
  z
  starship
  thefuck
  themes
  terraform
  lol
  fzf
  # zsh_reload
  zoxide
)

if [ $WT_SESSION ]; then
  alias op="op.exe"
fi

if [[ "$OSTYPE" == "darwin"* ]]; then
  eval $(/opt/homebrew/bin/brew shellenv)
else
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi

source $HOMEBREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source $HOMEBREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh
# source $HOMEBREW_PREFIX/share/zsh-autocomplete/zsh-autocomplete.plugin.zsh
FPATH="$HOMEBREW_PREFIX/share/zsh/site-functions:${FPATH}"
FPATH="$HOMEBREW_PREFIX/share/zsh-completions:${FPATH}"

# Remove any existing mise paths before activating
export PATH=$(echo $PATH | tr ':' '\n' | grep -v "mise" | paste -sd: -)

source $ZSH/oh-my-zsh.sh

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='mvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"

zstyle ':completion:*:*:docker:*' option-stacking yes
zstyle ':completion:*:*:docker-*:*' option-stacking yes

# zstyle ':omz:plugins:alias-finder' autoload yes # disabled by default
# zstyle ':omz:plugins:alias-finder' longer yes # disabled by default
# zstyle ':omz:plugins:alias-finder' exact yes # disabled by default
# zstyle ':omz:plugins:alias-finder' cheaper yes # disabled by default

zstyle ':omz:plugins:eza' 'dirs-first' yes
zstyle ':omz:plugins:eza' 'git-status' yes
# zstyle ':omz:plugins:eza' 'header' yes
# zstyle ':omz:plugins:eza' 'show-group' yes|no
zstyle ':omz:plugins:eza' 'icons' yes
# zstyle ':omz:plugins:eza' 'size-prefix' (binary|none|si)
# zstyle ':omz:plugins:eza' 'time-style' $TIME_STYLE
zstyle ':omz:plugins:eza' 'hyperlink' yes

if [ -x "$(command -v gh)" ]; then
  eval "$(gh completion --shell zsh)"
fi
if [ -x "$(command -v kubectl)" ]; then
  eval "$(kubectl completion zsh)"
fi
if [ -x "$(command -v helm)" ]; then
  eval "$(helm completion zsh)"
fi
if [ -x "$(command -v op)" ]; then
  eval "$(op completion zsh)"
fi
if [ -x "$(command -v mise)" ]; then
  eval "$(mise activate zsh)"
fi
if [ -x "$(command -v pulumi)" ]; then
  eval "$(pulumi completion zsh)"
fi
if [ -x "$(command -v kubectl)" ]; then
  export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"
fi


autoload -U +X bashcompinit && bashcompinit
export PATH="/opt/homebrew/opt/libpq/bin:$PATH"

. "$HOME/.local/bin/env"
# The following lines have been added by Docker Desktop to enable Docker CLI completions.
fpath=(/Users/david/.docker/completions $fpath)
autoload -Uz compinit
compinit
# End of Docker CLI completions

# OpenClaw Completion
source "/Users/david/.openclaw/completions/openclaw.zsh"

# Added by LM Studio CLI (lms)
export PATH="$PATH:/Users/david/.lmstudio/bin"
# End of LM Studio CLI section

complete -o nospace -C /opt/homebrew/bin/terraform terraform
