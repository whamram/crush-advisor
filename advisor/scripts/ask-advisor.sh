#!/usr/bin/env bash
set -euo pipefail

if [ "${CRUSH_TOOL_INPUT_COMMAND:-}" != "echo advisor" ]; then
  echo '{}'
  exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MODEL=$(sed -n 's/^model=//p' "$SCRIPT_DIR/../crush-config/config.txt")

ADVISOR_OUTPUT=$("$SCRIPT_DIR/session-dump.sh" "${CRUSH_SESSION_ID:-}" "${CRUSH_CWD:-$PWD}" \
  | crush run --quiet -m "$MODEL" -c "$SCRIPT_DIR/../crush-config/" -D /tmp/crush-advisor/ \
  "You are advising another agent. Here is its session transcript. Provide a concise response in under 1000 words, providing a concrete plan forward, risks and edge cases the model may run into, and any necessary corrections to the agents current thought process or actions.")

jq -n --arg ctx "$ADVISOR_OUTPUT" '{context: $ctx}'
