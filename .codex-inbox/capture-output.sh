#!/bin/bash
set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${PROJECT_DIR:-$(cd -- "$SCRIPT_DIR/.." && pwd)}"
LAST_OUTPUT_FILE="$PROJECT_DIR/.codex-inbox/last-output.md"
CONVERSATION_FILE="$PROJECT_DIR/.codex-inbox/conversation.md"
LOG_FILE="$PROJECT_DIR/.codex-inbox/log.txt"

generate_session_id() {
  if command -v uuidgen >/dev/null 2>&1; then
    uuidgen
  else
    printf '%s-%s-%s' "$(date +%s)" "$$" "$RANDOM"
  fi
}

if [ "$#" -eq 0 ]; then
  echo "Usage: $0 <shell command>" >&2
  exit 1
fi

cd "$PROJECT_DIR" || exit 1

COMMAND_BLOCK="$*"
SESSION_ID="$(generate_session_id)"

{
  echo "session_id: $SESSION_ID"
  echo "source: external-terminal"
  echo "command:"
  printf '%s\n' "$COMMAND_BLOCK"
  echo
  echo "Command dispatched from an external terminal."
  echo
  echo "Latest command output snapshot."
  echo
  echo "Started: $(date)"
  echo
  echo "## Commands"
  printf '%s\n' "$COMMAND_BLOCK"
  echo
  echo "## Output"
  bash -lc "$COMMAND_BLOCK"
  status=$?
  echo
  echo "Exit code: $status"
  echo "Finished: $(date)"
  exit "$status"
} 2>&1 | tee "$LAST_OUTPUT_FILE" | tee -a "$CONVERSATION_FILE" | tee -a "$LOG_FILE"

exit "${PIPESTATUS[0]}"
