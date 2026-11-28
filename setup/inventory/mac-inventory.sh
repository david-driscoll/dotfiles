#!/usr/bin/env bash
# setup/inventory/mac-inventory.sh — wrapper behind the mac:* mise tasks
# (.config/mise/config.macos.toml). READ-ONLY: never installs or removes
# anything; it only reads this Mac (or another one over SSH) and writes
# snapshot/report files under the inventory directory.
#
#   collect           snapshot this Mac + write its report
#   remote <host>     snapshot another Mac over SSH + write its report
#   diff [a] [b]      compare two Macs' latest snapshots
#   status            mise's own view of drift from [bootstrap.packages]
#
# Inventory directory layout (one folder per Mac, named by LocalHostName):
#   <dir>/<host>/latest.json        newest snapshot
#   <dir>/<host>/YYYY-MM-DD.json    history, one per day it was collected
#   <dir>/<host>/report.md          report for latest.json
#   <dir>/diff-<a>-vs-<b>.md        output of `diff`
#
# <dir> is $MAC_INVENTORY_DIR, else iCloud Drive/mac-inventory (shared by both
# Macs and private), else ~/.local/state/mac-inventory. Snapshots list
# installed software, so they are deliberately kept out of the dotfiles repo,
# which is public.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"
DOTFILES="$(cd -- "$SCRIPT_DIR/../.." && pwd -P)"
PY_SCRIPT="$SCRIPT_DIR/mac_inventory.py"
ICLOUD="$HOME/Library/Mobile Documents/com~apple~CloudDocs"

log() { printf '[mac-inventory] %s\n' "$*" >&2; }
die() {
	printf '[mac-inventory] ERROR: %s\n' "$*" >&2
	exit 1
}

inventory_dir() {
	if [ -n "${MAC_INVENTORY_DIR:-}" ]; then
		printf '%s\n' "$MAC_INVENTORY_DIR"
	elif [ -d "$ICLOUD" ]; then
		printf '%s\n' "$ICLOUD/mac-inventory"
	else
		printf '%s\n' "$HOME/.local/state/mac-inventory"
	fi
}

# `report`/`diff` read the dotfiles TOML with tomllib (Python 3.11+). mise's
# python is preferred; the system python3 (3.9) still works, minus drift checks.
python_bin() {
	local py
	py="$(mise which python3 2>/dev/null || true)"
	[ -n "$py" ] && [ -x "$py" ] && {
		printf '%s\n' "$py"
		return
	}
	command -v python3 || die "python3 not found"
}

# Third-party-tap casks need Ruby 3+ for mise to evaluate them in
# `bootstrap status`; Homebrew vendors one. See config.macos.toml.
use_portable_ruby() {
	local prefix ruby_bin
	prefix="$(brew --prefix 2>/dev/null || echo /opt/homebrew)"
	ruby_bin="$prefix/Library/Homebrew/vendor/portable-ruby/current/bin"
	[ -x "$ruby_bin/ruby" ] && export PATH="$ruby_bin:$PATH"
	return 0
}

write_report() { # <snapshot.json> <report.md>
	"$(python_bin)" "$PY_SCRIPT" report "$1" --dotfiles "$DOTFILES" -o "$2"
}

store_snapshot() { # <host> <tmp-json>  -> stores latest + dated copy, writes report
	local host="$1" tmp="$2" dir
	dir="$(inventory_dir)/$host"
	mkdir -p "$dir"
	cp "$tmp" "$dir/$(date +%F).json"
	mv "$tmp" "$dir/latest.json"
	write_report "$dir/latest.json" "$dir/report.md"
	log "snapshot: $dir/latest.json"
	log "report:   $dir/report.md"
}

cmd_collect() {
	local host tmp
	host="$(scutil --get LocalHostName)"
	tmp="$(mktemp)"
	/usr/bin/env python3 "$PY_SCRIPT" collect -o "$tmp"
	store_snapshot "$host" "$tmp"
}

cmd_remote() {
	local target="${1:-}" host tmp
	[ -n "$target" ] || die "usage: mise run mac:inventory:remote <ssh-host>"
	log "connecting to $target ..."
	# BatchMode: fail instead of prompting. Login shell so Homebrew/mise are on PATH.
	host="$(ssh -o BatchMode=yes "$target" 'scutil --get LocalHostName')" ||
		die "cannot ssh to '$target' non-interactively (check Remote Login / Tailscale SSH and your key)"
	tmp="$(mktemp)"
	# Stream the collector over stdin: nothing needs to be installed on the
	# other Mac beyond the system python3 that Homebrew's prerequisites provide.
	ssh -o BatchMode=yes "$target" 'zsh -lc "python3 - collect"' <"$PY_SCRIPT" >"$tmp" ||
		die "collector failed on $target"
	store_snapshot "$host" "$tmp"
}

cmd_diff() {
	local dir a="${1:-}" b="${2:-}" out
	dir="$(inventory_dir)"
	[ -n "$a" ] || a="$(scutil --get LocalHostName)"
	if [ -z "$b" ]; then
		b="$(cd "$dir" && for d in */latest.json; do dirname "$d"; done | grep -vx "$a" | head -n1 || true)"
		[ -n "$b" ] || die "no other Mac's snapshot under $dir yet — run 'mise run mac:inventory' on it (or mac:inventory:remote <host> from here)"
	fi
	for h in "$a" "$b"; do
		[ -f "$dir/$h/latest.json" ] || die "no snapshot at $dir/$h/latest.json"
	done
	out="$dir/diff-$a-vs-$b.md"
	"$(python_bin)" "$PY_SCRIPT" diff "$dir/$a/latest.json" "$dir/$b/latest.json" --dotfiles "$DOTFILES" -o "$out"
	log "diff: $out"
}

cmd_status() {
	use_portable_ruby
	export MISE_AUTO_ENV=1
	echo "== [bootstrap.packages] (brew, brew-cask, mas) =="
	mise bootstrap packages status --missing || true
	echo
	echo "== [tools] not installed =="
	mise ls --missing || true
	echo
	echo "Installed-but-undeclared software is in the inventory report: mise run mac:inventory"
}

case "${1:-}" in
collect)
	shift
	cmd_collect "$@"
	;;
remote)
	shift
	cmd_remote "$@"
	;;
diff)
	shift
	cmd_diff "$@"
	;;
status)
	shift
	cmd_status "$@"
	;;
*) die "usage: $0 {collect|remote <host>|diff [a] [b]|status}" ;;
esac
