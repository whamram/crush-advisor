#!/usr/bin/env bash
# session-dump.sh — extract full session transcript from Crush's SQLite DB.
#
# Usage: ./session-dump.sh [session_id] [project_dir]
#
# Session: session_id arg, else $CRUSH_SESSION_ID, else the most recently
# updated session in the DB.
#
# Database resolution (first match wins):
#   1. $CRUSH_DB — explicit path to a crush.db, used verbatim.
#   2. Walk up from the anchor dir looking for .crush/crush.db, stopping at
#      the git worktree root — mirroring how Crush (v0.88+) resolves its
#      data directory. Anchor: project_dir arg, else $CRUSH_PROJECT_DIR,
#      else $CRUSH_CWD, else $PWD.
#   3. ~/.config/crush/.crush/crush.db — legacy single-DB layout.
set -euo pipefail

SESSION_ID="${1:-${CRUSH_SESSION_ID:-}}"
ANCHOR="${2:-${CRUSH_PROJECT_DIR:-${CRUSH_CWD:-$PWD}}}"

resolve_db() {
  if [[ -n "${CRUSH_DB:-}" ]]; then
    printf '%s\n' "$CRUSH_DB"
    return
  fi

  local dir boundary d
  dir="$ANCHOR"
  while [[ ! -d "$dir" && "$dir" != "/" ]]; do
    dir="$(dirname -- "$dir")"
  done
  dir="$(cd -- "$dir" && pwd)"
  boundary="$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null)" || boundary="$dir"

  d="$dir"
  while :; do
    if [[ -d "$d/.crush" ]]; then
      if [[ -f "$d/.crush/crush.db" ]]; then
        printf '%s\n' "$d/.crush/crush.db"
      else
        echo "warning: $d/.crush has no crush.db; falling back to legacy DB" >&2
        printf '%s\n' "$HOME/.config/crush/.crush/crush.db"
      fi
      return
    fi
    [[ "$d" == "$boundary" || "$d" == "/" ]] && break
    d="$(dirname -- "$d")"
  done

  printf '%s\n' "$HOME/.config/crush/.crush/crush.db"
}

DB="$(resolve_db)"

if [[ ! -f "$DB" ]]; then
  echo "crush.db not found at $DB" >&2
  echo "  (anchor: $ANCHOR — pass a project dir as the 2nd arg, or set CRUSH_DB)" >&2
  exit 1
fi

if [[ -z "$SESSION_ID" ]]; then
  SESSION_ID=$(sqlite3 "$DB" "SELECT id FROM sessions ORDER BY updated_at DESC LIMIT 1;")
fi

if [[ -z "$SESSION_ID" ]]; then
  echo "No session found" >&2
  exit 1
fi

format_timestamp() {
  date -d "@$(($1 / 1000))" '+%Y-%m-%d %H:%M:%S' 2>/dev/null \
    || date -r "$(($1 / 1000))" '+%Y-%m-%d %H:%M:%S' 2>/dev/null \
    || echo "$1"
}

echo "================ SESSION ================"
sqlite3 "$DB" "SELECT id, title, message_count, created_at, updated_at FROM sessions WHERE id='$(printf '%q' "$SESSION_ID")';" | while IFS='|' read -r id title count created updated; do
  echo "id:        $id"
  echo "title:     $title"
  echo "messages:  $count"
  echo "created:   $(format_timestamp "$created")"
  echo "updated:   $(format_timestamp "$updated")"
done

echo ""
echo "================ MESSAGES ================"
sqlite3 -json "$DB" \
  "SELECT role, parts, created_at FROM messages WHERE session_id='$(printf '%q' "$SESSION_ID")' ORDER BY created_at ASC, rowid ASC;" \
| jq -r '
  .[] |
  "──── \(.role)  \(.created_at / 1000 | strftime("%Y-%m-%d %H:%M:%S")) ────\n" +
  ( .parts | fromjson | map(
      if .type == "text" then
        "TEXT:\n" + .data.text
      elif .type == "reasoning" then
        "REASONING (truncated):\n" + ((.data.thinking // "") | .[0:500]) + "…"
      elif .type == "tool_call" then
        "TOOL_CALL \(.data.name):\n" + (.data.input | tostring)
      elif .type == "tool_result" then
        (([.data.content] | tostring | length) as $len |
         "TOOL_RESULT \(.data.name) (\($len) chars, first 400):\n" +
         (.data.content | if type == "array" then (map(if type == "string" then . else tostring end) | join("\n")) else tostring end | .[0:400]))
      else
        "PART_\(.type | ascii_upcase): " + (.data | tostring | .[0:200])
      end
    ) | join("\n\n") )
'

echo ""
echo "================ FILES ================"
sqlite3 "$DB" \
  "SELECT path, version, length(content), updated_at FROM files WHERE session_id='$(printf '%q' "$SESSION_ID")' ORDER BY updated_at DESC;" \
| while IFS='|' read -r path version bytes updated; do
  echo "$path  v$version  $bytes bytes  ($(format_timestamp "$updated"))"
done

echo ""
echo "================ READ_FILES ================"
sqlite3 "$DB" \
  "SELECT path, read_at FROM read_files WHERE session_id='$(printf '%q' "$SESSION_ID")' ORDER BY read_at ASC;" \
| while IFS='|' read -r path read_at; do
  echo "$path  ($(format_timestamp "$read_at"))"
done
