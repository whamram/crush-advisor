#!/bin/bash
set -euo pipefail

# Install the advisor skill and wire up its PreToolUse hook in Crush's config.
#   --json      merge the hook into $CONFIG/crush.json (default)
#   --crushrc   append the hook to $CONFIG/crushrc
# CONFIG defaults to ${XDG_CONFIG_HOME:-$HOME/.config}/crush

TYPE=json
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/crush"

for arg in "$@"; do
  case "$arg" in
    --json)    TYPE=json ;;
    --crushrc) TYPE=crushrc ;;
    --config=*) CONFIG="${arg#--config=}" ;;
    -h|--help)
      echo "Usage: install.sh [--json|--crushrc] [--config=DIR]"
      exit 0
      ;;
    *) echo "Unknown option: $arg" >&2; exit 1 ;;
  esac
done

mkdir -p "$CONFIG"

# 1. Install the skill.
mkdir -p "$HOME/.agents/skills"
cp -r advisor "$HOME/.agents/skills/"

# 2. Add the CRUSH.md advice
if [ -f "$CONFIG/CRUSH.md" ]; then
  printf '\n' >> "$CONFIG/CRUSH.md"
  cat CRUSH.md >> "$CONFIG/CRUSH.md"
else
  cp CRUSH.md "$CONFIG/CRUSH.md"
fi

# 2. Wire up the hook in the chosen config format.
if [ "$TYPE" = json ]; then
  CRUSH_JSON="$CONFIG/crush.json"
  if [ ! -f "$CRUSH_JSON" ]; then
    printf '{\n  "$schema": "https://charm.land/crush.json"\n}\n' > "$CRUSH_JSON"
  fi

  # hook-schema.json is a bare "hooks": {...} fragment; wrap it so jq can read it.
  HOOKS_FRAG=$(printf '{%s}' "$(tr -d '\n' < hook-schema.json)")
  MERGED=$(jq --argjson frag "$HOOKS_FRAG" \
    'walk(if type == "object" and (.command? == "~/.agents/skills/advisor/scripts/ask-advisor.sh") then del(.command, .matcher) else . end)
     | .hooks.PreToolUse //= [] | .hooks.PreToolUse |= map(select(type == "object" and length > 0))
     | .hooks.PreToolUse += $frag.hooks.PreToolUse' \
    "$CRUSH_JSON")
  printf '%s\n' "$MERGED" > "$CRUSH_JSON"
else
  CRUSHRC="$CONFIG/crushrc"
  if [ ! -f "$CRUSHRC" ]; then
    printf '#!/usr/bin/env bash\n' > "$CRUSHRC"
  fi
  if ! grep -q -- "~/.agents/skills/advisor/scripts/ask-advisor.sh" "$CRUSHRC"; then
    printf '\n# PreToolUse hook: consult the advisor before tool calls.\n' >> "$CRUSHRC"
    cat hook-schema.crushrc >> "$CRUSHRC"
  else
    echo "Advisor hook already present in $CRUSHRC"
  fi
fi

echo "Advisor installed (type=$TYPE config=$CONFIG)"
