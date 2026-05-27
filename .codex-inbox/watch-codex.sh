#!/bin/bash
set -u

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${PROJECT_DIR:-$(cd -- "$SCRIPT_DIR/.." && pwd)}"
INBOX_DIR="$PROJECT_DIR/.codex-inbox"
PROXY_FILE="$INBOX_DIR/command.txt"
LOG_FILE="$INBOX_DIR/log.txt"

mkdir -p "$INBOX_DIR"
touch "$PROXY_FILE" "$LOG_FILE"

echo "AI/Codex project daemon running."
echo "Project: $PROJECT_DIR"
echo "Watching: $PROXY_FILE"
echo ""

cd "$PROJECT_DIR" || exit 1

while true; do
  if [ -s "$PROXY_FILE" ]; then
    CMD="$(cat "$PROXY_FILE")"
    : > "$PROXY_FILE"

    echo ""
    echo "----------------------------------------"
    echo "Command received:"
    echo "$CMD"
    echo "----------------------------------------"

    USER_CHOICE="$(osascript - "$CMD" <<'EOD' 2>/dev/null || true
on run argv
  set theCmd to item 1 of argv
  display dialog "Run this command in project folder?" & return & return & theCmd buttons {"Cancel", "Run"} default button "Cancel" with title "Codex Command Approval"
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

      if command -v pbcopy >/dev/null 2>&1; then
        printf '%s\n' "Done executing. Please read my terminal window now." | pbcopy
      fi

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
    else
      echo "Cancelled by user."
      osascript -e "display notification \"Command cancelled.\" with title \"Codex Daemon\"" 2>/dev/null || true
    fi
  fi

  sleep 1
done
