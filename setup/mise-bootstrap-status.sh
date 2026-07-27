#!/usr/bin/env bash
# setup/mise-bootstrap-status.sh — periodic, READ-ONLY mise bootstrap drift
# check. Invoked by the (opt-in, disabled-by-default) dev.mise.mise-sync
# launchd agent declared in .config/mise/config.macos.toml
# ([bootstrap.macos.launchd.agents.mise-sync]) — see that file's comment
# block for the full reasoning (#74, part of epic #61).
#
# This script NEVER runs `mise up`, `mise install`, `mise bootstrap`, or any
# other bootstrap *apply* subcommand — only `mise bootstrap status`, which
# mise's own docs mark read-only. An unattended background agent on David's
# daily driver must not change pinned tool versions or any other machine
# state; it only ever reports drift so David can decide what to do about it
# by hand. See the PR body for the full argument against `mise up` here.
#
# Also handles the two things launchd doesn't give you for free:
#   1. PATH — launchd agents get a minimal environment
#      (/usr/bin:/bin:/usr/sbin:/sbin) with no Homebrew directory, so `mise`
#      (and `brew`, which `mise bootstrap status` shells out to for
#      [bootstrap.packages] drift) would not resolve without this. The
#      plist's own `environment.PATH` already sets this too — belt and
#      suspenders, and it means this script behaves the same when run by
#      hand from a normal shell.
#   2. Log rotation — StandardOutPath/StandardErrorPath just append forever
#      with no rotation of their own. Trimming here keeps a year of daily
#      runs from growing the log file without bound.
set -euo pipefail

readonly LOG_FILE="$HOME/Library/Logs/mise-bootstrap-status.log"
# ~5000 lines is roughly a year of daily runs at this command's typical
# output size (a few dozen lines per run) — generous enough to look back
# over weeks of history, capped so the file doesn't grow forever.
readonly MAX_LOG_LINES=5000
readonly TRIM_TO_LINES=4000

# Homebrew (both architectures) + standard system dirs. Not templated with
# `~`/`{{config_root}}` — bootstrap.macos.launchd's `environment` table is
# not documented as expanding either, so this is a literal, redundant copy
# of the plist's own PATH, not the source of truth for it.
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

mkdir -p "$(dirname "$LOG_FILE")"

if [ -f "$LOG_FILE" ]; then
    line_count="$(wc -l <"$LOG_FILE" | tr -d ' ')"
    if [ "$line_count" -gt "$MAX_LOG_LINES" ]; then
        tail -n "$TRIM_TO_LINES" "$LOG_FILE" >"$LOG_FILE.tmp" && mv "$LOG_FILE.tmp" "$LOG_FILE"
    fi
fi

{
    printf '===== %s =====\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    if ! command -v mise >/dev/null 2>&1; then
        printf 'ERROR: mise not found on PATH (%s)\n' "$PATH"
    elif mise bootstrap status --missing; then
        printf '\nSUMMARY: OK — no drift detected\n'
    else
        printf '\nSUMMARY: DRIFT DETECTED — review the table above, then decide by hand whether to run "mise bootstrap" (this agent never applies anything itself)\n'
    fi
    printf '\n'
} >>"$LOG_FILE" 2>&1
