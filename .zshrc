# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH

# mise (https://mise.run) installs to ~/.local/bin by default. Most distros'
# default /etc/skel/.profile adds ~/.local/bin to PATH, but this file
# replaces ~/.zshrc wholesale (see #64/[dotfiles]) so that default doesn't
# apply here — make it explicit instead of relying on it. Without this,
# `command -v mise` below never finds mise on a bare Linux image (Codespaces,
# Coder), and `mise activate`/its shims (~/.local/share/mise/shims) never
# make it onto PATH for future shells. (#68)
export PATH="$HOME/.local/bin:$PATH"

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
  starship
  themes
  terraform
  lol
  # zsh_reload
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

# Enables mise's platform config-file layering (config.macos.toml /
# config.linux.toml alongside .config/mise/config.toml) so [dotfiles]
# entries can be scoped per-OS. Must be a real env var, not just
# settings.auto_env in the toml — see that file for why. (#64)
export MISE_AUTO_ENV=1
if [ -x "$(command -v mise)" ]; then
  eval "$(mise activate zsh)"
fi

load_completion() {
  local executable="$1"
  shift
  if ! command -v "$executable" >/dev/null 2>&1; then
    return
  fi
  MISE_AUTO_INSTALL=false "$@" 2>/dev/null
}

if [ -x "$(command -v fzf)" ]; then
  eval "$(load_completion fzf fzf --zsh)"
fi
if [ -x "$(command -v uv)" ]; then
  eval "$(load_completion uv uv generate-shell-completion zsh)"
fi
if [ -x "$(command -v yq)" ]; then
  eval "$(load_completion yq yq shell-completion zsh)"
fi
if [ -x "$(command -v sops)" ]; then
  eval "$(load_completion sops sops completion zsh)"
fi
if [ -x "$(command -v copilot)" ]; then
  eval "$(load_completion copilot copilot completion zsh)"
fi
if [ -x "$(command -v dotnet)" ]; then
  eval "$(load_completion dotnet dotnet completions script zsh)"
fi
if [ -x "$(command -v gh)" ]; then
  eval "$(load_completion gh gh completion --shell zsh)"
fi
if [ -x "$(command -v op)" ]; then
  eval "$(load_completion op op completion zsh)"
fi
if [ -x "$(command -v pulumi)" ]; then
  eval "$(load_completion pulumi pulumi gen-completion zsh)"
fi
if [ -x "$(command -v kubectl)" ]; then
  eval "$(load_completion kubectl kubectl completion zsh)"
fi
if [ -x "$(command -v helm)" ]; then
  eval "$(load_completion helm helm completion zsh)"
fi
if [ -x "$(command -v kustomize)" ]; then
  eval "$(load_completion kustomize kustomize completion zsh)"
fi
if [ -x "$(command -v flux)" ]; then
  eval "$(load_completion flux flux completion zsh)"
fi
if [ -x "$(command -v starship)" ]; then
  eval "$(load_completion starship starship completions zsh)"
fi
if [ -x "$(command -v talosctl)" ]; then
  eval "$(load_completion talosctl talosctl completion zsh)"
fi
if [ -x "$(command -v talhelper)" ]; then
  eval "$(load_completion talhelper talhelper completion zsh)"
fi
if [ -x "$(command -v zoxide)" ]; then
  eval "$(load_completion zoxide zoxide init zsh)"
fi
if [ -x "$(command -v kubectl)" ]; then
  export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"
fi


autoload -U +X bashcompinit && bashcompinit
export PATH="/opt/homebrew/opt/libpq/bin:$PATH"

# Only present on machines where some other installer (rustup, uv's own
# curl installer, etc.) dropped this file — nothing in this repo writes it.
# Was previously sourced unconditionally, which errors on any box (e.g. a
# fresh Codespace/Coder Linux box) where it doesn't exist. (#68)
[ -f "$HOME/.local/bin/env" ] && . "$HOME/.local/bin/env"
# The following lines have been added by Docker Desktop to enable Docker CLI completions.
fpath=(/Users/david/.docker/completions $fpath)
autoload -Uz compinit
compinit
# End of Docker CLI completions

# Added by LM Studio CLI (lms)
export PATH="$PATH:/Users/david/.lmstudio/bin"
# End of LM Studio CLI section
export DOTNET_ROOT="/usr/local/share/dotnet"
export PATH="/usr/local/share/dotnet:$PATH"

if [ -x "$(command -v terraform)" ]; then
  complete -C "$(command -v terraform)" terraform
fi