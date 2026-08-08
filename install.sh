#!/bin/bash
set -euo pipefail

# Install the advisor skill and wire up its PreToolUse hook in Crush's config.
#   --json      merge the hook into $CONFIG/crush.json (default)
#   --crushrc   append the hook to $CONFIG/crushrc
# CONFIG defaults to ${XDG_CONFIG_HOME:-$HOME/.config}/crush

TYPE=json
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/crush"
SKILL_DIR="$HOME/.agents/skills"

for arg in "$@"; do
  case "$arg" in
    --json)    TYPE=json ;;
    --crushrc) TYPE=crushrc ;;
    --config-dir=*) CONFIG="${arg#--config-dir=}" ;;
    --skill-dir=*)  SKILL_DIR="${arg#--skill-dir=}" ;;
    -h|--help)
      echo "Usage: install.sh [--json|--crushrc] [--config-dir=DIR] [--skill-dir=DIR]"
      exit 0
      ;;
    *) echo "Unknown option: $arg" >&2; exit 1 ;;
  esac
done

# Expand a leading ~ in user-supplied paths; shell arguments are not
# subject to tilde expansion.
SKILL_DIR="${SKILL_DIR/#\~/$HOME}"
CONFIG="${CONFIG/#\~/$HOME}"

HOOK_CMD="$SKILL_DIR/advisor/scripts/ask-advisor.sh"
LEGACY_CMD="~/.agents/skills/advisor/scripts/ask-advisor.sh"

mkdir -p "$CONFIG"

# 1. Install the skill.
mkdir -p "$SKILL_DIR"
cp -r advisor "$SKILL_DIR/"

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

  # hook-schema.json is a bare "hooks": {...} fragment; inject the hook
  # command path, then wrap it so jq can read it.
  HOOKS_FRAG=$(printf '{%s}' "$(sed "s|__HOOK_CMD__|$HOOK_CMD|g" hook-schema.json | tr -d '\n')")
  MERGED=$(jq --argjson frag "$HOOKS_FRAG" --arg cmd "$HOOK_CMD" --arg legacy "$LEGACY_CMD" \
    'walk(if type == "object" and (.command? == $cmd or .command? == $legacy) then del(.command, .matcher) else . end)
     | .hooks.PreToolUse //= [] | .hooks.PreToolUse |= map(select(type == "object" and length > 0))
     | .hooks.PreToolUse += $frag.hooks.PreToolUse' \
    "$CRUSH_JSON")
  printf '%s\n' "$MERGED" > "$CRUSH_JSON"
else
  CRUSHRC="$CONFIG/crushrc"
  if [ ! -f "$CRUSHRC" ]; then
    printf '#!/usr/bin/env bash\n' > "$CRUSHRC"
  fi
  if grep -qF -- "$HOOK_CMD" "$CRUSHRC"; then
    echo "Advisor hook already present in $CRUSHRC"
  elif grep -qF -- "$LEGACY_CMD" "$CRUSHRC"; then
    # Migrate the pre-skill-dir hook path in place (GNU sed).
    sed -i "s|$LEGACY_CMD|$HOOK_CMD|g" "$CRUSHRC"
  else
    printf '\n# PreToolUse hook: consult the advisor before tool calls.\n' >> "$CRUSHRC"
    sed "s|__HOOK_CMD__|$HOOK_CMD|g" hook-schema.crushrc >> "$CRUSHRC"
  fi
fi

echo "Advisor installed (type=$TYPE config=$CONFIG)"
