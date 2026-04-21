#!/usr/bin/env bash
# Claude Code PreToolUse hook - blocks dangerous bash commands
# Reads JSON from stdin, exits 2 to block, 0 to allow
INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
[ -z "$CMD" ] && exit 0

# Block patterns
if echo "$CMD" | grep -qE 'rm\s+-rf\s+/\b|rm\s+-rf\s+~\b|rm\s+--force.*\s+/'; then
  echo "Blocked: recursive delete of root or home" >&2
  exit 2
fi
if echo "$CMD" | grep -qE 'git\s+push.*--force\s+(origin\s+)?(main|master)\b'; then
  echo "Blocked: force push to main/master" >&2
  exit 2
fi
if echo "$CMD" | grep -qE 'chmod\s+(777|a\+rwx)\s+'; then
  echo "Blocked: chmod 777" >&2
  exit 2
fi
if echo "$CMD" | grep -qE '>\s*/etc/(passwd|shadow|hosts)\b'; then
  echo "Blocked: overwrite of sensitive system file" >&2
  exit 2
fi
exit 0