#!/bin/bash
set -u

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${PROJECT_DIR:-$(cd -- "$SCRIPT_DIR/.." && pwd)}"
INBOX_DIR="$PROJECT_DIR/.codex-inbox"
CHAT_FILE="$INBOX_DIR/chat.txt"
COMMANDS_FILE="$INBOX_DIR/commands.txt"
CONVERSATION_FILE="$INBOX_DIR/conversation.md"
LOG_FILE="$INBOX_DIR/log.txt"
CONFIG_FILE="$INBOX_DIR/config.json"

FLOW="chat-first"
APPROVAL_LEVEL="standard"
DIALOG_DEFAULT_BUTTON="Run"
NOTIFY_CHATGPT="true"

if command -v python3 >/dev/null 2>&1 && [ -f "$CONFIG_FILE" ]; then
  while IFS='=' read -r key value; do
    case "$key" in
      workflow) FLOW="$value" ;;
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
for key in ("workflow", "approvalLevel", "defaultButton", "notifyChatGPT"):
    if key in data:
        value = data[key]
        if isinstance(value, bool):
            value = str(value).lower()
        print(f"{key}={value}")
PY
  )
fi

mkdir -p "$INBOX_DIR"
touch "$CHAT_FILE" "$COMMANDS_FILE" "$CONVERSATION_FILE" "$LOG_FILE"

cd "$PROJECT_DIR" || exit 1

append_conversation() {
  local section="$1"
  local body="$2"
  {
    echo ""
    echo "## [$section] $(date)"
    echo "$body"
  } >> "$CONVERSATION_FILE"
}

notify_chatgpt_done() {
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
}

run_commands() {
  local command_block="$1"

  {
    echo ""
    echo "[$(date)] Running commands:"
    echo "$command_block"
    echo ""
    bash -lc "$command_block"
    EXIT_CODE=$?
    echo ""
    echo "Exit code: $EXIT_CODE"
    echo "[$(date)] Done"
    echo ""
  } 2>&1 | tee -a "$LOG_FILE" | tee -a "$CONVERSATION_FILE"

  notify_chatgpt_done
}

ask_for_approval() {
  local command_block="$1"

  osascript - "$command_block" "$DIALOG_DEFAULT_BUTTON" "$APPROVAL_LEVEL" <<'EOD'
on run argv
  set theCmd to item 1 of argv
  set defaultButton to item 2 of argv
  set approvalLevel to item 3 of argv
  display dialog "Run terminal commands from commands.txt?" & return & return & theCmd buttons {"Cancel", "Run"} default button defaultButton with title ("Chat-First Approval [" & approvalLevel & "]")
end run
EOD
}

echo "Chat-first daemon running."
echo "Project: $PROJECT_DIR"
echo "Workflow: $FLOW"
echo "Watching chat: $CHAT_FILE"
echo "Watching commands: $COMMANDS_FILE"
echo "Conversation: $CONVERSATION_FILE"
echo ""

if command -v fswatch >/dev/null 2>&1; then
  echo "Using fswatch."
  fswatch -0 "$CHAT_FILE" "$COMMANDS_FILE" | while IFS= read -r -d '' _; do
    if [ -s "$CHAT_FILE" ]; then
      CHAT_PROMPT="$(cat "$CHAT_FILE")"
      : > "$CHAT_FILE"
      append_conversation "prompt" "$CHAT_PROMPT"
      append_conversation "note" "Prompt received. Grow the conversation, inspect the terminal, and write final shell commands into commands.txt when ready."
      echo "Prompt received from chat.txt"
    fi

    if [ -s "$COMMANDS_FILE" ]; then
      COMMAND_BLOCK="$(cat "$COMMANDS_FILE")"
      : > "$COMMANDS_FILE"
      append_conversation "commands" "$COMMAND_BLOCK"

      USER_CHOICE="$(ask_for_approval "$COMMAND_BLOCK" 2>/dev/null || true)"
      if [[ "$USER_CHOICE" == *"button returned:Run"* ]]; then
        run_commands "$COMMAND_BLOCK"
      else
        echo "Cancelled by user."
        append_conversation "status" "User cancelled command execution."
      fi
    fi
  done
else
  echo "fswatch not found; using 1s polling fallback."
  while true; do
    if [ -s "$CHAT_FILE" ]; then
      CHAT_PROMPT="$(cat "$CHAT_FILE")"
      : > "$CHAT_FILE"
      append_conversation "prompt" "$CHAT_PROMPT"
      append_conversation "note" "Prompt received. Grow the conversation, inspect the terminal, and write final shell commands into commands.txt when ready."
      echo "Prompt received from chat.txt"
    fi

    if [ -s "$COMMANDS_FILE" ]; then
      COMMAND_BLOCK="$(cat "$COMMANDS_FILE")"
      : > "$COMMANDS_FILE"
      append_conversation "commands" "$COMMAND_BLOCK"

      USER_CHOICE="$(ask_for_approval "$COMMAND_BLOCK" 2>/dev/null || true)"
      if [[ "$USER_CHOICE" == *"button returned:Run"* ]]; then
        run_commands "$COMMAND_BLOCK"
      else
        echo "Cancelled by user."
        append_conversation "status" "User cancelled command execution."
      fi
    fi

    sleep 1
  done
fi
