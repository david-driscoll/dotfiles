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
# Flow: install mise (if absent) -> symlink ~/dotfiles at this checkout ->
# link this repo's mise config files into ~/.config/mise -> in a Coder
# workspace, select the config.coder.toml layer and move the workspace's own
# ~/.gitconfig out of [dotfiles]' way -> `mise trust` the configs by
# explicit path -> `mise bootstrap --yes`, which
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

# --- ~/dotfiles symlink ---------------------------------------------------
#
# Everything downstream addresses this repo as ~/dotfiles: every [dotfiles]
# source and `dotfiles.root` in .config/mise/config*.toml, STARSHIP_CONFIG
# and COPILOT_CUSTOM_INSTRUCTIONS_DIRS in .bashrc/.zshrc. Only a hand-made
# clone actually lands there -- Coder's dotfiles module clones to
# ~/.config/coderv2/dotfiles and Codespaces to /workspaces/.codespaces/...,
# where `mise bootstrap` fails with "sources do not exist" for all 16
# entries. Point ~/dotfiles at the real checkout instead of teaching every
# consumer a second path.
link_repo_home() {
	local target="$HOME/dotfiles"

	if [ "$REPO_DIR" = "$target" ]; then
		return 0
	fi
	if [ -L "$target" ]; then
		if [ "$(readlink "$target")" = "$REPO_DIR" ]; then
			log "~/dotfiles already links to $REPO_DIR"
			return 0
		fi
		log "~/dotfiles is a symlink to '$(readlink "$target")' — relinking to $REPO_DIR"
		rm -f "$target"
	elif [ -e "$target" ]; then
		# A real second checkout. Leave it alone: [dotfiles] will resolve
		# against IT, which is at least self-consistent, and deleting or
		# moving a git checkout from a bootstrap script is not.
		log "WARNING: ~/dotfiles already exists and is not this checkout ($REPO_DIR) — [dotfiles] sources will resolve against it"
		return 0
	fi

	ln -s "$REPO_DIR" "$target"
	log "linked ~/dotfiles -> $REPO_DIR"
}

# --- ~/.config/mise config links ------------------------------------------
#
# The bootstrap links that can't be left to [dotfiles]: config.toml is the
# file [dotfiles] itself lives in, so mise can't declare it before it can
# read it (chicken-and-egg), and config.<os>.toml is not a [dotfiles] entry
# at all.
#
# ~/.config/mise is a REAL directory holding per-file symlinks -- the same
# shape [dotfiles] itself produces ("~/.config/mise/config.toml" and
# "~/.config/mise/scripts" are both entries). This used to symlink the whole
# directory at the checkout, which made those two entries self-referential:
# the target already existed as the source file seen through the directory
# link, and `mise bootstrap` stopped at "refusing to overwrite existing
# files". It also meant ensure_age_key() below generated the age PRIVATE
# key inside the git checkout.
#
# Links are spelled via ~/dotfiles (see link_repo_home) so they are
# byte-identical to the [dotfiles] `source` strings and mise treats them as
# already applied.
link_mise_config() {
	local target="$HOME/.config/mise"
	local source="$HOME/dotfiles/.config/mise"

	[ -d "$source" ] || die "expected $source to exist (this repo's mise config) but it doesn't"

	mkdir -p "$HOME/.config"

	if [ -L "$target" ]; then
		log "~/.config/mise is a whole-directory symlink to '$(readlink "$target")' (the old layout) — replacing it with a real directory of per-file links"
		rm -f "$target"
	elif [ -e "$target" ] && [ ! -d "$target" ]; then
		die "~/.config/mise exists and is neither a directory nor a symlink — refusing to touch it, please move it aside manually"
	fi
	mkdir -p "$target"

	local cfg name link
	# config.toml + this platform's layer + the workspace layer, if one was
	# detected; config.macos*.toml has no business in a Linux home.
	for cfg in "$source/config.toml" "$source/config.linux.toml" ${WORKSPACE_ENV:+"$source/config.$WORKSPACE_ENV.toml"}; do
		[ -f "$cfg" ] || continue
		name="$(basename -- "$cfg")"
		link="$target/$name"
		if [ -L "$link" ]; then
			[ "$(readlink "$link")" = "$cfg" ] && continue
			rm -f "$link"
		elif [ -e "$link" ]; then
			local backup
			backup="${link}.bak.$(date +%Y%m%d%H%M%S)"
			log "$link is a real file — moving it aside to $backup rather than overwriting it"
			mv "$link" "$backup"
		fi
		ln -s "$cfg" "$link"
		log "linked $link -> $cfg"
	done
}

# --- workspace environment layer -------------------------------------------
#
# Coder and Codespaces are both plain "linux" to mise, so anything that
# differs between them and a bare-metal box can't live in config.linux.toml.
# Each gets its own layer instead: config.<env>.toml, an explicitly selected
# mise environment, which outranks the platform layers. Only
# config.coder.toml exists today -- a Codespace is recognised but, with no
# layer to select, bootstraps exactly as plain Linux does.
#
# Called before link_mise_config, which links the layer's file.
WORKSPACE_ENV=""

detect_workspace_env() {
	local env=""
	# CODER is set by the Coder agent for every process it starts (the
	# dotfiles module's script included); CODESPACES by GitHub.
	if [ "${CODER:-}" = "true" ]; then
		env="coder"
	elif [ "${CODESPACES:-}" = "true" ]; then
		env="codespaces"
	fi
	[ -n "$env" ] || return 0

	if [ ! -f "$REPO_DIR/.config/mise/config.$env.toml" ]; then
		log "$env workspace detected, but there is no config.$env.toml layer — bootstrapping as plain Linux"
		return 0
	fi
	WORKSPACE_ENV="$env"
	log "$env workspace detected — using the config.$env.toml layer"
}

# trust_and_bootstrap exports MISE_ENV for this script's own mise calls, but
# every later `mise` in the workspace has to resolve the same layer or it
# sees config.linux.toml's entries again. miserc.local.toml is mise's
# per-machine place for that selection, read before any config file and by
# every shell. A real file, not a link: it describes this machine, not the
# repo.
select_workspace_env() {
	[ -n "$WORKSPACE_ENV" ] || return 0

	local miserc="$HOME/.config/mise/miserc.local.toml"
	if [ -e "$miserc" ]; then
		grep -q "\"$WORKSPACE_ENV\"" "$miserc" ||
			log "WARNING: $miserc exists and doesn't select '$WORKSPACE_ENV' — leaving it alone; add env = [\"$WORKSPACE_ENV\"] to it, or later mise runs won't load config.$WORKSPACE_ENV.toml"
		return 0
	fi
	printf 'env = ["%s"]\n' "$WORKSPACE_ENV" >"$miserc"
	log "wrote $miserc (env = [\"$WORKSPACE_ENV\"])"
}

# --- workspace-provisioned ~/.gitconfig -----------------------------------
#
# Coder (like Codespaces) writes a real ~/.gitconfig before this script
# runs. "~/.gitconfig" is a [dotfiles] entry, so `mise bootstrap` stops at
# "refusing to overwrite existing files", and --force-dotfiles would throw
# the workspace's settings away.
#
# Move it to ~/.gitconfig.workspace instead, which the layer's
# ~/.gitconfig.local (git/gitconfig.<env>) includes last, so whatever the
# workspace set still wins. Not to ~/.gitconfig.local itself: that is a
# [dotfiles] entry too, so a real file there only moves the same refusal
# one file over.
#
# Only with a layer selected. Anywhere else nothing includes the moved
# file, and a real ~/.gitconfig is one somebody wrote by hand -- mise's
# refusal is the right answer there.
adopt_workspace_gitconfig() {
	local gitconfig="$HOME/.gitconfig"
	local adopted="$HOME/.gitconfig.workspace"

	[ -n "$WORKSPACE_ENV" ] || return 0
	# A symlink is already [dotfiles]' own (a re-run); absent, nothing to keep.
	if [ -L "$gitconfig" ] || [ ! -f "$gitconfig" ]; then
		return 0
	fi

	local stamp
	stamp="$(date +%Y%m%d%H%M%S)"
	if grep -qF '.gitconfig.local' "$gitconfig"; then
		# Not the workspace's file but this repo's own, with its link
		# replaced by a copy (`sed -i` does that). Including it from itself
		# is fatal to every git command ("exceeded maximum include depth"),
		# so it gets a plain backup name instead.
		adopted="${gitconfig}.bak.${stamp}"
	elif [ -e "$adopted" ] || [ -L "$adopted" ]; then
		log "$adopted already exists — moving it aside to ${adopted}.bak.${stamp} rather than overwriting it"
		mv "$adopted" "${adopted}.bak.${stamp}"
	fi

	mv "$gitconfig" "$adopted"
	log "moved the workspace's ~/.gitconfig to $adopted so [dotfiles] can link ~/.gitconfig"
}

# --- age.key for fnox and mise decryption --------------------------------
#
# Repository secrets in fnox.toml are encrypted against the age recipients.
# Ensure ~/.config/mise/age.key and ~/.config/fnox/age.key exist.
ensure_age_key() {
	local mise_age_key="$HOME/.config/mise/age.key"
	local mise_age_txt="$HOME/.config/mise/age.txt"
	local fnox_age_key="$HOME/.config/fnox/age.key"
	local fnox_age_txt="$HOME/.config/fnox/age.txt"
	local sops_age_key="$HOME/.config/sops/age/keys.txt"

	mkdir -p "$HOME/.config/fnox"

	if [ ! -f "$mise_age_key" ]; then
		if [ -f "$fnox_age_key" ]; then
			ln -sf "$fnox_age_key" "$mise_age_key"
			log "linked $fnox_age_key -> $mise_age_key"
		elif [ -f "$mise_age_txt" ]; then
			ln -sf "$mise_age_txt" "$mise_age_key"
			log "linked $mise_age_txt -> $mise_age_key"
		elif [ -f "$sops_age_key" ]; then
			ln -sf "$sops_age_key" "$mise_age_key"
			log "linked $sops_age_key -> $mise_age_key"
		else
			log "no age key found — generating new age key at $mise_age_key"
			mkdir -p "$HOME/.config/mise"
			if command -v age-keygen >/dev/null 2>&1; then
				age-keygen -o "$mise_age_key"
			fi
		fi
	fi
	if [ -f "$mise_age_key" ] && [ ! -f "$mise_age_txt" ]; then
		ln -sf "$mise_age_key" "$mise_age_txt"
	fi
	if [ -f "$mise_age_key" ] && [ ! -f "$fnox_age_key" ]; then
		ln -sf "$mise_age_key" "$fnox_age_key"
		log "linked $mise_age_key -> $fnox_age_key"
	fi
	if [ -f "$fnox_age_key" ] && [ ! -f "$fnox_age_txt" ]; then
		ln -sf "$fnox_age_key" "$fnox_age_txt"
	fi
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
	# The workspace layer, for this script's own calls (see
	# select_workspace_env for everything after it).
	if [ -n "$WORKSPACE_ENV" ]; then
		export MISE_ENV="$WORKSPACE_ENV"
	fi

	# Trust each config by explicit path -- NOT `mise trust --all`. `--all`
	# loops "until nothing under cwd is untrusted", and every file under
	# ~/.config/mise resolves to the trust root `~`. Run from that dir it
	# also sees this repo's own mise.toml one level up (the symlink
	# canonicalises into the checkout), which trusting `~` never satisfies,
	# so it re-trusts `~` forever: a Coder workspace logged 306,321
	# `mise trusted ~` lines in five minutes and never reached bootstrap
	# (mise 2026.9.11). The repo-root mise.toml is the one that actually
	# needs trusting -- it is a project config, and its postinstall hooks
	# are what `mise bootstrap` runs from this checkout.
	log "trusting mise config: $REPO_DIR"
	local cfg
	for cfg in "$REPO_DIR/mise.toml" "$REPO_DIR"/.config/mise/config*.toml; do
		[ -f "$cfg" ] || continue
		mise trust --quiet "$cfg" ||
			die "mise trust failed for $cfg — see output above"
	done

	log "running mise bootstrap --yes (packages, dotfiles, tools)"
	mise bootstrap --yes --force-dotfiles ||
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
	link_repo_home
	detect_workspace_env
	link_mise_config
	select_workspace_env
	adopt_workspace_gitconfig
	ensure_age_key
	trust_and_bootstrap

	# mise bootstrap's [tools] step (gh, etc.) lands in the shims dir;
	# pick it up for the rest of this run.
	export PATH="$HOME/.local/share/mise/shims:$PATH"

	check_gh_auth

	log "done. Re-run this script any time — every step here is safe to repeat."
	log "Inspect state with: mise bootstrap status"
}

main "$@"
