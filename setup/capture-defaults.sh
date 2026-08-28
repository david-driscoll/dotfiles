#!/usr/bin/env bash
# setup/capture-defaults.sh — READ-ONLY macOS `defaults` snapshot/diff helper.
#
# This script NEVER writes, deletes, or changes any macOS setting. It only
# ever calls `defaults read` / `defaults read-type` and writes plain text
# files under its own snapshot directory. It exists so David can discover
# the exact domain/key/type behind a System Settings toggle himself:
#
#   1. snapshot "before"
#   2. change ONE setting in System Settings
#   3. snapshot "after"
#   4. diff before/after — the changed line(s) show exactly which
#      domain + key moved, and by how much
#   5. `capture-defaults.sh type <domain> <key>` confirms the true stored
#      type (bool/int/float/string) before encoding it in
#      .config/mise/config.macos.toml — a bool stored as `1` vs `true`
#      matters for correct `[bootstrap.macos.defaults]` encoding.
#
# Domains covered (fixed list — see #70): com.apple.dock, com.apple.finder,
# NSGlobalDomain, com.apple.AppleMultitouchTrackpad,
# com.apple.driver.AppleBluetoothMultitouch.trackpad, com.apple.screencapture
#
# set -euo pipefail: fail loudly rather than silently continuing on a typo'd
# domain name or missing `defaults` binary. Missing/empty individual
# domains (e.g. no Bluetooth trackpad paired) are NOT treated as fatal —
# `defaults read` legitimately exits non-zero for a domain with no
# preferences file yet, and that's recorded in the snapshot, not aborted on.
set -euo pipefail

readonly SCRIPT_NAME="capture-defaults.sh"

# Fixed domain list — see header. Ordering is stable so snapshot files are
# always named/sorted the same way across runs.
readonly DOMAINS=(
	"com.apple.dock"
	"com.apple.finder"
	"NSGlobalDomain"
	"com.apple.AppleMultitouchTrackpad"
	"com.apple.driver.AppleBluetoothMultitouch.trackpad"
	"com.apple.screencapture"
)

# Default base directory for snapshots. $HOME, not a bare `~`, so it expands
# correctly even when this value ends up inside double quotes later
# (SC2088: tilde does not expand in quotes).
DEFAULT_BASE_DIR="$HOME/.cache/dotfiles-defaults-snapshots"

log() {
	printf '[%s] %s\n' "$SCRIPT_NAME" "$*"
}

die() {
	printf '[%s] ERROR: %s\n' "$SCRIPT_NAME" "$*" >&2
	exit 1
}

usage() {
	cat <<EOF
$SCRIPT_NAME — READ-ONLY macOS 'defaults' snapshot/diff helper.

This script never runs 'defaults write' or 'defaults delete'. It only reads.

USAGE:
  $SCRIPT_NAME snapshot <name> [--dir <base-dir>]
      Capture 'defaults read' for each tracked domain into
      <base-dir>/<name>/<domain>.txt

  $SCRIPT_NAME diff <name-before> <name-after> [--dir <base-dir>]
      Show a unified diff per domain between two snapshots.

  $SCRIPT_NAME type <domain> <key>
      Print the true stored type for one key via 'defaults read-type'
      (e.g. before encoding it in .config/mise/config.macos.toml).

  $SCRIPT_NAME list [--dir <base-dir>]
      List snapshots captured under <base-dir>.

  $SCRIPT_NAME --help
      Show this help.

OPTIONS:
  --dir <base-dir>   Base directory for snapshots.
                      Default: $DEFAULT_BASE_DIR

TRACKED DOMAINS:
$(printf '  - %s\n' "${DOMAINS[@]}")

WORKED EXAMPLE (discovering a new setting):
  \$ $SCRIPT_NAME snapshot before
  ... change one thing in System Settings ...
  \$ $SCRIPT_NAME snapshot after
  \$ $SCRIPT_NAME diff before after
  --- before/com.apple.dock.txt
  +++ after/com.apple.dock.txt
  -    tilesize = 48;
  +    tilesize = 64;
  \$ $SCRIPT_NAME type com.apple.dock tilesize
  Type is integer
EOF
}

require_cmd() {
	command -v "$1" >/dev/null 2>&1 || die "required command '$1' not found on PATH"
}

# Snapshot one domain's full 'defaults read' output into $2. Missing/empty
# domains are recorded as such rather than aborting the whole snapshot —
# see header comment.
snapshot_domain() {
	local domain="$1"
	local outfile="$2"
	if defaults read "$domain" >"$outfile" 2>/dev/null; then
		return 0
	fi
	printf '(domain "%s" has no preferences — defaults read exited non-zero)\n' "$domain" >"$outfile"
}

cmd_snapshot() {
	local name="${1:-}"
	[ -n "$name" ] || die "snapshot requires a <name> argument, e.g. '$SCRIPT_NAME snapshot before'"
	shift
	local base_dir="$DEFAULT_BASE_DIR"
	while [ $# -gt 0 ]; do
		case "$1" in
		--dir)
			[ $# -ge 2 ] || die "--dir requires a value"
			base_dir="$2"
			shift 2
			;;
		*)
			die "unrecognized argument to snapshot: $1"
			;;
		esac
	done

	local snap_dir="$base_dir/$name"
	mkdir -p "$snap_dir"

	local domain
	local outfile
	for domain in "${DOMAINS[@]}"; do
		outfile="$snap_dir/$domain.txt"
		snapshot_domain "$domain" "$outfile"
		log "captured $domain -> $outfile"
	done
	log "snapshot '$name' complete: $snap_dir"
}

cmd_diff() {
	local before="${1:-}"
	local after="${2:-}"
	[ -n "$before" ] && [ -n "$after" ] || die "diff requires <name-before> <name-after>, e.g. '$SCRIPT_NAME diff before after'"
	shift 2
	local base_dir="$DEFAULT_BASE_DIR"
	while [ $# -gt 0 ]; do
		case "$1" in
		--dir)
			[ $# -ge 2 ] || die "--dir requires a value"
			base_dir="$2"
			shift 2
			;;
		*)
			die "unrecognized argument to diff: $1"
			;;
		esac
	done

	local before_dir="$base_dir/$before"
	local after_dir="$base_dir/$after"
	[ -d "$before_dir" ] || die "no snapshot named '$before' under $base_dir"
	[ -d "$after_dir" ] || die "no snapshot named '$after' under $base_dir"

	local domain
	local any_diff=0
	for domain in "${DOMAINS[@]}"; do
		local before_file="$before_dir/$domain.txt"
		local after_file="$after_dir/$domain.txt"
		if ! diff -u "$before_file" "$after_file" 2>/dev/null; then
			any_diff=1
		fi
	done

	if [ "$any_diff" -eq 0 ]; then
		log "no differences between '$before' and '$after'"
	fi
}

cmd_type() {
	local domain="${1:-}"
	local key="${2:-}"
	[ -n "$domain" ] && [ -n "$key" ] || die "type requires <domain> <key>, e.g. '$SCRIPT_NAME type com.apple.dock tilesize'"
	defaults read-type "$domain" "$key"
}

cmd_list() {
	local base_dir="$DEFAULT_BASE_DIR"
	while [ $# -gt 0 ]; do
		case "$1" in
		--dir)
			[ $# -ge 2 ] || die "--dir requires a value"
			base_dir="$2"
			shift 2
			;;
		*)
			die "unrecognized argument to list: $1"
			;;
		esac
	done

	[ -d "$base_dir" ] || {
		log "no snapshots yet under $base_dir"
		return 0
	}

	local entry
	for entry in "$base_dir"/*/; do
		[ -d "$entry" ] || continue
		printf '%s\n' "$(basename "$entry")"
	done
}

main() {
	require_cmd defaults

	local sub="${1:-}"
	case "$sub" in
	-h | --help | "" | help)
		usage
		;;
	snapshot)
		shift
		cmd_snapshot "$@"
		;;
	diff)
		shift
		cmd_diff "$@"
		;;
	type)
		shift
		cmd_type "$@"
		;;
	list)
		shift
		cmd_list "$@"
		;;
	*)
		die "unknown subcommand '$sub' — run '$SCRIPT_NAME --help'"
		;;
	esac
}

main "$@"
