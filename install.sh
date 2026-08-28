#!/usr/bin/env bash
# install.sh — non-interactive, idempotent, mise-first bootstrap for Linux.
#
# This is the GitHub Codespaces convention (Codespaces runs it automatically
# on container creation) and is also used directly by self-hosted Coder
# workspaces and WSL. Both Codespaces and Coder are ephemeral Linux boxes
# with no attached TTY — anything that prompts here will hang the container
# build, so every step in this script must either be silent-safe or degrade
# to a logged warning instead of blocking on input.
#
# Flow: install mise (if absent) -> symlink ~/.config/mise at this repo's
# .config/mise -> `mise trust` the config -> `mise bootstrap --yes`, which
# is the single declarative step that installs OS packages, applies
# [dotfiles], and installs [tools]. See #61 (epic) and #68 for the full
# rationale, and PRs #79/#81 for how [dotfiles]/[bootstrap.packages] got
# populated.
#
# macOS is NOT this script's job — see check_os() below.

set -euo pipefail

log() {
	printf '[install.sh] %s\n' "$*"
}

die() {
	printf '[install.sh] ERROR: %s\n' "$*" >&2
	exit 1
}

# Resolve the repo root from this script's own location rather than
# assuming ~/dotfiles — Codespaces clones to /workspaces/<repo>, Coder
# workspaces vary, and WSL invocations (setup/setup-wsl.ps1) run this via
# a /mnt/c/... path.
resolve_repo_dir() {
	local script_path="${BASH_SOURCE[0]}"
	(cd -- "$(dirname -- "$script_path")" >/dev/null 2>&1 && pwd -P)
}

REPO_DIR="$(resolve_repo_dir)"
readonly REPO_DIR

require_cmd() {
	command -v "$1" >/dev/null 2>&1 || die "required command '$1' not found on PATH"
}

# --- OS guard ---------------------------------------------------------
#
# This script's job is Linux (Codespaces/Coder/WSL — WSL reports as plain
# "linux" via uname, same as mise sees it, so no special-casing is needed
# or possible here). macOS gets its own entry point per #69
# (setup/setup-macos.sh), which does not exist yet as of this rewrite —
# handle that gracefully instead of exec-ing a missing file and dying with
# a confusing "No such file or directory".
check_os() {
	local os
	os="$(uname -s)"
	if [ "$os" != "Linux" ]; then
		if [ "$os" = "Darwin" ]; then
			if [ -x "$REPO_DIR/setup/setup-macos.sh" ]; then
				log "macOS detected — delegating to setup/setup-macos.sh"
				exec "$REPO_DIR/setup/setup-macos.sh"
			fi
			die "macOS detected, but this script only bootstraps Linux (Codespaces/Coder/WSL). setup/setup-macos.sh (#69) doesn't exist yet — for now, run setup/setup-osx.sh instead, or wait for #69."
		fi
		die "unsupported OS '$os' — this script only bootstraps Linux (Codespaces/Coder/WSL)."
	fi
	log "OS: Linux ($(uname -m))"
}

# --- mise install -------------------------------------------------------
#
# Idempotent: skips entirely if mise is already resolvable, either on PATH
# or at its default install location. mise's own installer
# (https://mise.run) is itself safe to re-run — it just re-downloads and
# overwrites the binary — but this skips the network round trip entirely
# when it's not needed.
install_mise() {
	if command -v mise >/dev/null 2>&1; then
		log "mise already on PATH ($(command -v mise)) — skipping install"
		return 0
	fi
	if [ -x "$HOME/.local/bin/mise" ]; then
		log "mise already installed at ~/.local/bin/mise — skipping install"
		return 0
	fi

	require_cmd curl

	log "installing mise via https://mise.run"
	local installer
	installer="$(mktemp)"

	# Download first rather than piping straight into sh: this lets us
	# confirm the download actually completed (curl's own exit code) and
	# sanity-check the content before executing anything, instead of
	# streaming an in-progress (and on a flaky network, possibly
	# truncated) response directly into a shell. mise's installer already
	# validates its own downloaded *tarball* against a baked-in checksum
	# internally — this extra step only covers the installer script
	# itself, which that internal check doesn't cover.
	#
	# mise's docs (https://mise.jdx.dev/installing-mise.html) document a
	# stronger option for confirming the installer hasn't been tampered
	# with: fetch it alongside a detached GPG signature
	# (https://mise.jdx.dev/install.sh.sig) and verify against mise's
	# release key before running it. That's not wired up here because it
	# needs a reachable keyserver, which is one more thing that can hang
	# or fail in a locked-down ephemeral container — if that's wanted,
	# swap the curl call below for the documented gpg --recv-keys /
	# gpg --decrypt sequence.
	if ! curl -fsSL https://mise.run -o "$installer"; then
		rm -f "$installer"
		die "failed to download the mise installer from https://mise.run"
	fi
	if [ ! -s "$installer" ] || ! head -n1 "$installer" | grep -q '^#!'; then
		rm -f "$installer"
		die "mise installer download looks corrupt (empty or missing shebang) — refusing to execute it"
	fi

	if ! sh "$installer"; then
		rm -f "$installer"
		die "mise installer exited non-zero"
	fi
	rm -f "$installer"

	[ -x "$HOME/.local/bin/mise" ] || die "mise installer completed but ~/.local/bin/mise is not present — something changed upstream"
	log "mise installed to ~/.local/bin/mise"
}

# --- ~/.config/mise symlink ---------------------------------------------
#
# The one bootstrap symlink that can't be dotfiles-managed: it's the file
# [dotfiles] itself lives in, so mise can't declare it (chicken-and-egg).
# Handles every state this can be in on a real machine: already correct
# (idempotent no-op), a stale/dangling symlink (relink), or — less likely
# here but possible if something else already created it — a real
# directory (back it up rather than deleting anything).
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
# MISE_AUTO_ENV=1 makes mise also load config.linux.toml alongside
# config.toml (mise's platform config-file layering — see that file's
# header comment, and .zshrc/.bashrc which export the same var ahead of
# `mise activate` for the same reason). Exported here too since this
# script's own `mise trust`/`mise bootstrap` calls need to see the
# Linux-only [dotfiles] entries (currently ~/.wslrc and
# ~/.gitconfig.local) as well as the cross-platform ones.
trust_and_bootstrap() {
	export MISE_AUTO_ENV=1

	log "trusting mise config under ~/.config/mise"
	(cd "$HOME/.config/mise" && mise trust --all) ||
		die "mise trust failed — see output above"

	log "running mise bootstrap --yes (packages, dotfiles, tools)"
	mise bootstrap --yes ||
		die "mise bootstrap failed — see output above. Safe to re-run: 'mise bootstrap --yes', or inspect state first with 'mise bootstrap status'."
}

# --- gh auth: informational only, never interactive ----------------------
#
# Codespaces and most Coder images already export GITHUB_TOKEN or
# GH_TOKEN, which gh picks up automatically — no login step needed at all
# in that case. Where neither is present and gh isn't already
# authenticated, this only logs a reminder; it must never call
# `gh auth login` itself, since that opens an interactive device-code
# flow that would hang a non-interactive container build.
#
# gh extension installation is intentionally NOT handled here — #83 owns
# consolidating the (currently duplicated across install.sh /
# setup-osx.sh / setup.ps1 / setup.sh) `gh extension install` list into
# one auth-guarded task; re-adding any of those lines here would just be
# more of the mess #83 is meant to clean up. `az extension add` was
# duplicated the same way across those same scripts and isn't
# reintroduced here either.
check_gh_auth() {
	if ! command -v gh >/dev/null 2>&1; then
		log "gh CLI not on PATH (should have just been installed by mise bootstrap's [tools] — check 'mise bootstrap status' if this persists) — skipping auth check"
		return 0
	fi

	if gh auth status >/dev/null 2>&1; then
		log "gh CLI already authenticated"
	elif [ -n "${GITHUB_TOKEN:-}" ] || [ -n "${GH_TOKEN:-}" ]; then
		log "gh CLI not authenticated yet, but GITHUB_TOKEN/GH_TOKEN is set in the environment — gh will pick it up automatically"
	else
		log "gh CLI is not authenticated — run 'gh auth login' later (not run automatically here, since it prompts interactively)"
	fi
}

main() {
	check_os

	# Make sure a freshly-installed ~/.local/bin/mise resolves for the
	# rest of THIS script, regardless of whether the current shell's PATH
	# already includes it (see the .bashrc/.zshrc fix in this same PR for
	# why that isn't otherwise guaranteed on a bare Linux image).
	export PATH="$HOME/.local/bin:$PATH"

	install_mise
	link_mise_config
	trust_and_bootstrap

	# mise bootstrap's [tools] step (gh, etc.) lands in the shims dir;
	# pick it up for the rest of this run.
	export PATH="$HOME/.local/share/mise/shims:$PATH"

	check_gh_auth

	log "done. Re-run this script any time — every step here is safe to repeat."
	log "Inspect state with: mise bootstrap status"
}

main "$@"
