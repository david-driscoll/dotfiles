#!/usr/bin/env bash
# setup/setup-macos.sh — non-interactive, idempotent, mise-first bootstrap
# for macOS (David's daily driver).
#
# This is install.sh's macOS twin: install.sh's check_os() detects Darwin
# and `exec`s straight into this script (same process, so this script's
# exit code IS install.sh's exit code — see check_os() in install.sh).
# Nothing here should assume it was invoked any other way, but it's also
# safe to run directly.
#
# Flow: upstream Homebrew installer (NONINTERACTIVE=1, no patches) -> `brew
# install mise` -> oh-my-zsh (see install_oh_my_zsh() for why) -> symlink
# ~/.config/mise at this repo's .config/mise -> `mise trust` -> `mise
# bootstrap --yes`, which is the single declarative step that installs
# [bootstrap.packages] brew formulae, runs the brew:casks task
# (setup/Brewfile.darwin) via [bootstrap.hooks.post-packages], applies
# [dotfiles], and installs [tools]. See #61 (epic) and #69 for the full
# rationale, and #64/#65/#67 for how [dotfiles]/[bootstrap.packages] got
# populated.
#
# Linux/Codespaces/Coder/WSL is NOT this script's job — see install.sh.

set -euo pipefail

log() {
    printf '[setup-macos.sh] %s\n' "$*"
}

die() {
    printf '[setup-macos.sh] ERROR: %s\n' "$*" >&2
    exit 1
}

# Resolve the repo root from this script's own location rather than
# assuming ~/dotfiles — mirrors install.sh's resolve_repo_dir() (this file
# lives one directory deeper, at setup/setup-macos.sh, hence the extra
# `/..`).
resolve_repo_dir() {
    local script_dir
    script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"
    (cd -- "$script_dir/.." >/dev/null 2>&1 && pwd -P)
}

REPO_DIR="$(resolve_repo_dir)"
readonly REPO_DIR

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || die "required command '$1' not found on PATH"
}

# --- OS guard ---------------------------------------------------------
#
# install.sh only execs into this script on Darwin, but this script should
# fail loudly (not do something wrong) if it's ever run directly on the
# wrong OS.
check_os() {
    local os
    os="$(uname -s)"
    [ "$os" = "Darwin" ] || die "this script only bootstraps macOS (got '$os') — use install.sh on Linux (Codespaces/Coder/WSL)."
    log "OS: macOS $(sw_vers -productVersion 2>/dev/null || echo '(version unknown)') ($(uname -m))"
}

# --- Homebrew install ----------------------------------------------------
#
# Idempotent: skips entirely if brew is already resolvable, either on PATH
# or at its default install location for either architecture.
install_homebrew() {
    if command -v brew >/dev/null 2>&1; then
        log "Homebrew already on PATH ($(command -v brew)) — skipping install"
        return 0
    fi
    if [ -x /opt/homebrew/bin/brew ] || [ -x /usr/local/bin/brew ]; then
        log "Homebrew already installed but not yet on PATH for this shell — shellenv will fix that below"
        return 0
    fi

    require_cmd curl

    log "installing Homebrew via the upstream installer (NONINTERACTIVE=1)"
    # Plain upstream installer, unmodified — deliberately NOT patched with
    # the `sed '532s/abort/warn/'` hardcoded-line-number hack that used to
    # live here (and in the deleted setup.sh/setup-osx.sh, #68/#69): that
    # patch targeted a script this repo doesn't control, and was guaranteed
    # to silently stop doing whatever it was for the moment upstream
    # reflows the file. NONINTERACTIVE=1 is Homebrew's own documented flag
    # for the same goal done properly: skip all prompts, fail loudly
    # instead of hanging.
    #
    # Download first rather than piping straight into bash, same reasoning
    # as install_mise() in install.sh (#68): confirms the download actually
    # completed and gives a chance to sanity-check the content before
    # executing anything, instead of streaming a possibly-truncated
    # in-progress response straight into a shell.
    local installer
    installer="$(mktemp)"
    if ! curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh -o "$installer"; then
        rm -f "$installer"
        die "failed to download the Homebrew installer"
    fi
    if [ ! -s "$installer" ] || ! head -n1 "$installer" | grep -q '^#!'; then
        rm -f "$installer"
        die "Homebrew installer download looks corrupt (empty or missing shebang) — refusing to execute it"
    fi
    if ! NONINTERACTIVE=1 /bin/bash "$installer"; then
        rm -f "$installer"
        die "Homebrew installer exited non-zero"
    fi
    rm -f "$installer"

    if [ ! -x /opt/homebrew/bin/brew ] && [ ! -x /usr/local/bin/brew ]; then
        die "Homebrew installer completed but brew is not present at /opt/homebrew or /usr/local — something changed upstream"
    fi
    log "Homebrew installed"
}

# Loads `brew shellenv` into THIS script's environment (not just the
# user's shell rc, which [dotfiles] already handles separately) so the
# rest of this run can see `brew`/`mise`/formula binaries regardless of
# whether Homebrew was already on this shell's PATH coming in. Same two
# paths Homebrew's own post-install instructions point at: /opt/homebrew
# on Apple Silicon, /usr/local on Intel.
load_brew_shellenv() {
    local brew_bin
    if [ -x /opt/homebrew/bin/brew ]; then
        brew_bin="/opt/homebrew/bin/brew"
    elif [ -x /usr/local/bin/brew ]; then
        brew_bin="/usr/local/bin/brew"
    else
        die "brew not found at /opt/homebrew or /usr/local — install_homebrew should have caught this"
    fi
    eval "$("$brew_bin" shellenv)"
}

# --- mise install ---------------------------------------------------------
#
# Idempotent: skips if mise is already resolvable on PATH (covers both a
# prior `brew install mise` run and, e.g., mise having been installed via
# install.sh's `https://mise.run` method on a machine that runs both
# scripts — no reason to fight that or install it twice).
install_mise() {
    if command -v mise >/dev/null 2>&1; then
        log "mise already on PATH ($(command -v mise)) — skipping install"
        return 0
    fi
    log "installing mise via Homebrew"
    brew install mise || die "brew install mise failed — see output above"
    command -v mise >/dev/null 2>&1 || die "brew install mise completed but mise is still not on PATH"
    log "mise installed ($(command -v mise))"
}

# --- oh-my-zsh -------------------------------------------------------------
#
# Not asked for by #69 directly, but discovered while walking what
# setup-osx.sh used to do end-to-end (see PR body): .zshrc unconditionally
# runs `source $ZSH/oh-my-zsh.sh` and sets `plugins=(...)` for it — nothing
# else in this repo's mise config installs the oh-my-zsh framework itself
# (it's a git clone into ~/.oh-my-zsh, not a brew formula or a mise tool).
# Dropping this step silently would leave a genuinely fresh mac with a
# .zshrc that errors on every new shell. Idempotent (skips if already
# installed) and safe to re-run on David's already-configured mac, where
# this is a no-op.
install_oh_my_zsh() {
    if [ -d "$HOME/.oh-my-zsh" ]; then
        log "oh-my-zsh already installed at ~/.oh-my-zsh — skipping"
        return 0
    fi

    require_cmd curl

    log "installing oh-my-zsh (.zshrc depends on \$ZSH/oh-my-zsh.sh; not something brew/mise manages)"
    # --unattended: oh-my-zsh's own documented non-interactive flag — skips
    # the "change your default shell?" prompt and doesn't exec into a new
    # zsh afterward (both of which would otherwise stall/misbehave in a
    # non-interactive run here). KEEP_ZSHRC=yes: if a ~/.zshrc already
    # exists (e.g. this step somehow runs after [dotfiles] already applied
    # it), don't let the installer back it up and replace it with its
    # default template — this repo's [dotfiles]-managed .zshrc wins either
    # way, but there's no reason to make the installer fight it.
    if ! RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended; then
        die "oh-my-zsh installer failed"
    fi
    [ -d "$HOME/.oh-my-zsh" ] || die "oh-my-zsh installer completed but ~/.oh-my-zsh is not present — something changed upstream"
    log "oh-my-zsh installed to ~/.oh-my-zsh"
}

# --- ~/.config/mise symlink ---------------------------------------------
#
# Same logic as install.sh's link_mise_config() — duplicated rather than
# shared (there's no existing "lib" convention in setup/ to source a
# function from without inventing one; flagged in the PR as worth
# factoring into e.g. setup/lib/link-mise-config.sh if a third caller ever
# shows up). Handles every state this can be in on a real machine: already
# correct (idempotent no-op), a stale/dangling symlink (relink — this is
# David's current state today), or a real directory (back it up rather
# than deleting anything).
link_mise_config() {
    local target="$HOME/.config/mise"
    local source="$REPO_DIR/.config/mise"

    [ -d "$source" ] || die "expected $source to exist (this repo's mise config) but it doesn't"

    mkdir -p "$HOME/.config"

    if [ -L "$target" ]; then
        local current
        current="$(readlink "$target")"
        if [ "$current" = "$source" ]; then
            log "~/.config/mise already links to $source"
            return 0
        fi
        log "~/.config/mise is a symlink to '$current' (stale, dangling, or pointing at a different checkout) — relinking to $source"
        rm -f "$target"
    elif [ -d "$target" ]; then
        local backup
        backup="${target}.bak.$(date +%Y%m%d%H%M%S)"
        log "~/.config/mise exists as a real directory (not a symlink) — moving it aside to $backup rather than overwriting it"
        mv "$target" "$backup"
    elif [ -e "$target" ]; then
        die "~/.config/mise exists and is neither a directory nor a symlink — refusing to touch it, please move it aside manually"
    fi

    ln -s "$source" "$target"
    log "linked ~/.config/mise -> $source"
}

# --- mise trust + bootstrap ----------------------------------------------
#
# MISE_AUTO_ENV=1 makes mise also load config.macos.toml alongside
# config.toml (mise's platform config-file layering — see that file's
# header comment, and .zshrc which exports the same var ahead of `mise
# activate` for the same reason). Exported here too since this script's own
# `mise trust`/`mise bootstrap` calls need to see the macOS-only
# [bootstrap.packages]/[dotfiles] entries (karabiner, the 1Password SSH
# agent config, gitconfig.local) as well as the cross-platform ones. `mise
# bootstrap --yes` (not `--only packages`, unlike the old setup-osx.sh) is
# what actually closes the gap #69 exists to close: one call now covers
# packages, Brewfile.darwin's casks (via [bootstrap.hooks.post-packages] ->
# the brew:casks task), [dotfiles], and [tools] — none of which install.sh
# alone ever reached on macOS.
trust_and_bootstrap() {
    export MISE_AUTO_ENV=1

    log "trusting mise config under ~/.config/mise"
    (cd "$HOME/.config/mise" && mise trust --all) \
        || die "mise trust failed — see output above"

    log "running mise bootstrap --yes (packages, Brewfile.darwin casks, dotfiles, tools)"
    mise bootstrap --yes \
        || die "mise bootstrap failed — see output above. Safe to re-run: 'mise bootstrap --yes', or inspect state first with 'mise bootstrap status'."
}

main() {
    check_os

    install_homebrew
    load_brew_shellenv
    install_mise
    install_oh_my_zsh
    link_mise_config
    trust_and_bootstrap

    log "done. Re-run this script any time — every step here is safe to repeat."
    log "Inspect state with: mise bootstrap status"
}

main "$@"
