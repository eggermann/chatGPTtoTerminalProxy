#!/bin/bash
set -u

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${PROJECT_DIR:-$(cd -- "$SCRIPT_DIR/.." && pwd)}"
INBOX_DIR="$PROJECT_DIR/.codex-inbox"
PROXY_FILE="$INBOX_DIR/command.txt"
LOG_FILE="$INBOX_DIR/log.txt"
CONFIG_FILE="$INBOX_DIR/config.json"
APPROVAL_LEVEL="standard"
DIALOG_DEFAULT_BUTTON="Run"
NOTIFY_CHATGPT="true"

if command -v python3 >/dev/null 2>&1 && [ -f "$CONFIG_FILE" ]; then
  while IFS='=' read -r key value; do
    case "$key" in
      approvalLevel) APPROVAL_LEVEL="$value" ;;
      defaultButton) DIALOG_DEFAULT_BUTTON="$value" ;;
      notifyChatGPT) NOTIFY_CHATGPT="$value" ;;
    esac
  done < <(
    python3 - "$CONFIG_FILE" <<'PY'
import json, sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text())
for key in ("approvalLevel", "defaultButton", "notifyChatGPT"):
    if key in data:
        value = data[key]
        if isinstance(value, bool):
            value = str(value).lower()
        print(f"{key}={value}")
PY
  )
fi

mkdir -p "$INBOX_DIR"
touch "$PROXY_FILE" "$LOG_FILE"

echo "AI/Codex project daemon running."
echo "Project: $PROJECT_DIR"
echo "Approval level: $APPROVAL_LEVEL"
echo "Default action: $DIALOG_DEFAULT_BUTTON"
echo "Watching: $PROXY_FILE"
echo ""

cd "$PROJECT_DIR" || exit 1

run_command() {
  CMD="$1"

  echo ""
  echo "----------------------------------------"
  echo "Command received:"
  echo "$CMD"
  echo "----------------------------------------"

  USER_CHOICE="$(osascript - "$CMD" "$DIALOG_DEFAULT_BUTTON" "$APPROVAL_LEVEL" <<'EOD' 2>/dev/null || true
on run argv
  set theCmd to item 1 of argv
  set defaultButton to item 2 of argv
  set approvalLevel to item 3 of argv
  display dialog "Run this command in project folder?" & return & return & theCmd buttons {"Cancel", "Run"} default button defaultButton with title ("Codex Command Approval [" & approvalLevel & "]")
end run
EOD
)"

  if [[ "$USER_CHOICE" == *"button returned:Run"* ]]; then
    {
      echo ""
      echo "[$(date)] Running:"
      echo "$CMD"
      echo ""
      bash -lc "$CMD"
      EXIT_CODE=$?
      echo ""
      echo "Exit code: $EXIT_CODE"
      echo "[$(date)] Done"
      echo ""
    } 2>&1 | tee -a "$LOG_FILE"

    if [ "$NOTIFY_CHATGPT" = "true" ] && command -v pbcopy >/dev/null 2>&1; then
      printf '%s\n' "Done executing. Please read my terminal window now." | pbcopy

      osascript <<'EOD' 2>/dev/null || true
tell application "ChatGPT" to activate
delay 0.4
tell application "System Events"
  keystroke "v" using {command down}
  delay 0.2
  key code 36
end tell
EOD

      osascript -e "display notification \"Command finished. ChatGPT was notified.\" with title \"Codex Daemon\"" 2>/dev/null || true
    fi
  else
    echo "Cancelled by user."
    osascript -e "display notification \"Command cancelled.\" with title \"Codex Daemon\"" 2>/dev/null || true
  fi
}

if command -v fswatch >/dev/null 2>&1; then
  echo "Using fswatch."
  fswatch -0 "$PROXY_FILE" | while IFS= read -r -d '' _; do
    if [ -s "$PROXY_FILE" ]; then
      CMD="$(cat "$PROXY_FILE")"
      : > "$PROXY_FILE"
      run_command "$CMD"
    fi
  done
else
  echo "fswatch not found; using 1s polling fallback."
  while true; do
    if [ -s "$PROXY_FILE" ]; then
      CMD="$(cat "$PROXY_FILE")"
      : > "$PROXY_FILE"
      run_command "$CMD"
    fi

    sleep 1
  done
fi
