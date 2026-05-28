#!/bin/bash
set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${PROJECT_DIR:-$(cd -- "$SCRIPT_DIR/.." && pwd)}"
INBOX_DIR="$PROJECT_DIR/.codex-inbox"
CHAT_FILE="$INBOX_DIR/chat.txt"
COMMANDS_FILE="$INBOX_DIR/commands.txt"
CONVERSATION_FILE="$INBOX_DIR/conversation.md"
LAST_OUTPUT_FILE="$INBOX_DIR/last-output.md"
MEMORY_FILE="$INBOX_DIR/memory.md"
LOG_FILE="$INBOX_DIR/log.txt"
STATE_FILE="$INBOX_DIR/watch-state.json"
CONFIG_FILE="$INBOX_DIR/config.json"

FLOW="chat-first"
APPROVAL_LEVEL="standard"
DIALOG_DEFAULT_BUTTON="Run"
NOTIFY_CHATGPT="true"
RUN_MODE="auto"
WATCH_CHAT_ON_SAVE="true"
WATCH_COMMANDS_ON_SAVE="true"

if command -v python3 >/dev/null 2>&1 && [ -f "$CONFIG_FILE" ]; then
  while IFS='=' read -r key value; do
    case "$key" in
      workflow) FLOW="$value" ;;
      approvalLevel) APPROVAL_LEVEL="$value" ;;
      defaultButton) DIALOG_DEFAULT_BUTTON="$value" ;;
      notifyChatGPT) NOTIFY_CHATGPT="$value" ;;
      runMode) RUN_MODE="$value" ;;
      activateWatchOnSaveChat) WATCH_CHAT_ON_SAVE="$value" ;;
      activateWatchOnSaveCommands) WATCH_COMMANDS_ON_SAVE="$value" ;;
    esac
  done < <(
    python3 - "$CONFIG_FILE" <<'PY'
import json, sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text())
for key in ("workflow", "approvalLevel", "defaultButton", "notifyChatGPT", "runMode"):
    if key in data:
        value = data[key]
        if isinstance(value, bool):
            value = str(value).lower()
        print(f"{key}={value}")

save_watch = data.get("activateWatchOnSave", {})
if isinstance(save_watch, dict):
    for key, env_key in (("chat", "activateWatchOnSaveChat"), ("commands", "activateWatchOnSaveCommands")):
        if key in save_watch:
            value = save_watch[key]
            if isinstance(value, bool):
                value = str(value).lower()
            print(f"{env_key}={value}")
PY
  )
fi

mkdir -p "$INBOX_DIR"
touch "$CHAT_FILE" "$COMMANDS_FILE" "$CONVERSATION_FILE" "$LAST_OUTPUT_FILE" "$MEMORY_FILE" "$LOG_FILE" "$STATE_FILE"

if [ ! -s "$MEMORY_FILE" ]; then
  {
    echo "# Memory"
    echo ""
    echo "- title: chatGPTtoTerminalProxy"
    echo "- project_path: $PROJECT_DIR"
    echo "- workflow: chat-first"
    echo "- purpose: move thought into terminal without losing the thread"
    echo "- branch: $(git -C "$PROJECT_DIR" branch --show-current 2>/dev/null || echo unknown)"
  } > "$MEMORY_FILE"
fi

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

read_state() {
  local key="$1"

  if command -v python3 >/dev/null 2>&1 && [ -f "$STATE_FILE" ]; then
    python3 - "$STATE_FILE" "$key" <<'PY'
import json, sys
from pathlib import Path

path = Path(sys.argv[1])
key = sys.argv[2]
try:
    data = json.loads(path.read_text())
except Exception:
    data = {}
value = data.get(key, "")
if isinstance(value, str):
    print(value)
PY
  fi
}

write_state() {
  local key="$1"
  local value="$2"

  python3 - "$STATE_FILE" "$key" "$value" <<'PY'
import json, sys
from pathlib import Path

path = Path(sys.argv[1])
key = sys.argv[2]
value = sys.argv[3]
try:
    data = json.loads(path.read_text()) if path.exists() else {}
except Exception:
    data = {}
data[key] = value
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")
PY
}

hash_text() {
  if command -v shasum >/dev/null 2>&1; then
    printf '%s' "$1" | shasum -a 256 | awk '{print $1}'
  else
    python3 - "$1" <<'PY'
import hashlib, sys
data = sys.argv[1].encode()
print(hashlib.sha256(data).hexdigest())
PY
  fi
}

wait_for_file_stable() {
  local file="$1"
  local delay="${2:-0.7}"
  local attempts="${3:-5}"
  local previous_hash current_hash i

  if [ ! -e "$file" ]; then
    return 1
  fi

  previous_hash="$(hash_text "$(cat "$file" 2>/dev/null)")"
  i=1
  while [ "$i" -le "$attempts" ]; do
    sleep "$delay"
    current_hash="$(hash_text "$(cat "$file" 2>/dev/null)")"
    if [ "$current_hash" = "$previous_hash" ]; then
      return 0
    fi
    previous_hash="$current_hash"
    i=$((i + 1))
  done

  return 1
}

ack_prompt_to_chatgpt() {
  local prompt_text="$1"

  if [ "$NOTIFY_CHATGPT" != "true" ] || ! command -v pbcopy >/dev/null 2>&1; then
    return 0
  fi

  {
    printf '%s\n\n%s\n' "Prompt received." "$prompt_text"
  } | pbcopy

  osascript <<'EOD' 2>/dev/null || true
tell application "ChatGPT" to activate
delay 0.4
tell application "System Events"
  keystroke "v" using {command down}
  delay 0.2
  key code 36
end tell
EOD
}

notify_chatgpt_done() {
  if [ "$NOTIFY_CHATGPT" = "true" ] && command -v pbcopy >/dev/null 2>&1; then
    printf '%s\n' "Done executing. Check .codex-inbox/last-output.md now." | pbcopy

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

process_chat_prompt() {
  local chat_prompt="$1"
  local prompt_hash
  prompt_hash="$(hash_text "$chat_prompt")"

  append_conversation "prompt" "$chat_prompt"
  append_conversation "note" "Prompt received. Grow the conversation, inspect the terminal, and write final shell commands into commands.txt when ready."
  write_state "last_chat_hash" "$prompt_hash"
  echo "Prompt received from chat.txt"
  ack_prompt_to_chatgpt "$chat_prompt"
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
  } 2>&1 | tee -a "$LOG_FILE" | tee -a "$CONVERSATION_FILE" | tee "$LAST_OUTPUT_FILE"

  notify_chatgpt_done
}

run_commands_in_new_terminal() {
  local command_block="$1"
  local tmp_command tmp_runner

  tmp_command="$(mktemp -t codex-command.XXXXXXXXXX.sh)" || {
    echo "Could not create temporary command file." | tee -a "$LOG_FILE" | tee -a "$CONVERSATION_FILE"
    return 1
  }

  tmp_runner="$(mktemp -t codex-runner.XXXXXXXXXX.sh)" || {
    echo "Could not create temporary runner file." | tee -a "$LOG_FILE" | tee -a "$CONVERSATION_FILE"
    rm -f "$tmp_command"
    return 1
  }

  printf '%s\n' "$command_block" > "$tmp_command"

  cat > "$tmp_runner" <<EOF
#!/usr/bin/env bash
set -uo pipefail
COMMAND_FILE=$(printf '%q' "$tmp_command")
LOG_FILE=$(printf '%q' "$LOG_FILE")
CONVERSATION_FILE=$(printf '%q' "$CONVERSATION_FILE")
LAST_OUTPUT_FILE=$(printf '%q' "$LAST_OUTPUT_FILE")
PROJECT_DIR=$(printf '%q' "$PROJECT_DIR")
NOTIFY_CHATGPT=$(printf '%q' "$NOTIFY_CHATGPT")

if [ ! -s "\$COMMAND_FILE" ] || ! grep -q '[^[:space:]]' "\$COMMAND_FILE"; then
  echo "Ignored empty command file."
  exit 0
fi

{
  echo "Latest command output snapshot."
  echo
  echo "Started: \$(date)"
  echo
  echo "## Commands"
  cat "\$COMMAND_FILE"
  echo
  echo "## Output"
  cd "\$PROJECT_DIR" || exit 1
  bash "\$COMMAND_FILE"
  status=\$?
  echo
  echo "Exit code: \$status"
  echo "Finished: \$(date)"
  exit "\$status"
} 2>&1 | tee -a "\$LAST_OUTPUT_FILE" | tee -a "\$CONVERSATION_FILE" | tee -a "\$LOG_FILE"
status=\${PIPESTATUS[0]}

if [ "\$NOTIFY_CHATGPT" = "true" ] && command -v pbcopy >/dev/null 2>&1; then
  printf '%s\n' "Done executing. Check .codex-inbox/last-output.md now." | pbcopy
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

exit "\$status"
EOF

  chmod +x "$tmp_runner"

  osascript - "$tmp_runner" <<'EOD' 2>/dev/null || true
on run argv
  set theScript to item 1 of argv
  tell application "Terminal"
    activate
    if (count of windows) is 0 then
      do script "bash " & quoted form of theScript
    else
      do script "bash " & quoted form of theScript in front window
    end if
  end tell
end run
EOD

  append_conversation "status" "Command dispatched to a new Terminal session."
  echo "Command dispatched to a new Terminal session."
}

should_run_in_new_terminal() {
  local command_block="$1"
  local normalized

  normalized="$(printf '%s' "$command_block" | tr '[:upper:]' '[:lower:]')"

  case "$RUN_MODE" in
    new-terminal) return 0 ;;
    inline) return 1 ;;
    background) return 0 ;;
    auto|*)
      case "$normalized" in
        *"npm start"*|*"npm run dev"*|*"npm run start"*|*"vite"*|*"next dev"*|*"tail -f"*|*"python -m http.server"*|*"python3 -m http.server"*|*"bun run dev"*|*"pnpm dev"*|*"yarn dev"*)
          return 0
          ;;
      esac
      return 1
      ;;
  esac
}

dispatch_command() {
  local command_block="$1"

  case "$RUN_MODE" in
    background)
      {
        nohup bash -lc "$command_block" >/dev/null 2>&1 &
        echo "Command started in background."
      } 2>&1 | tee -a "$LOG_FILE" | tee -a "$CONVERSATION_FILE"
      append_conversation "status" "Command started in background."
      notify_chatgpt_done
      ;;
    *)
      if should_run_in_new_terminal "$command_block"; then
        run_commands_in_new_terminal "$command_block"
      else
        run_commands "$command_block"
      fi
      ;;
  esac
}

has_meaningful_command() {
  local command_block="$1"

  printf '%s' "$command_block" | grep -q '[^[:space:]]'
}

process_commands_file() {
  local command_block="$1"
  local command_hash last_command_hash

  command_hash="$(hash_text "$command_block")"
  last_command_hash="$(read_state last_command_hash)"

  if [ "$command_hash" = "$last_command_hash" ]; then
    return 0
  fi

  if ! has_meaningful_command "$command_block"; then
    echo "Ignored empty commands.txt"
    append_conversation "status" "Ignored empty commands.txt"
    write_state "last_command_hash" "$command_hash"
    return 0
  fi

  append_conversation "commands" "$command_block"

  USER_CHOICE="$(ask_for_approval "$command_block" 2>/dev/null || true)"
  if [[ "$USER_CHOICE" == *"button returned:Run"* ]]; then
    dispatch_command "$command_block"
  else
    echo "Cancelled by user."
    append_conversation "status" "User cancelled command execution."
  fi

  write_state "last_command_hash" "$command_hash"
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
echo "Run mode: $RUN_MODE"
echo "Watch chat on save: $WATCH_CHAT_ON_SAVE"
echo "Watch commands on save: $WATCH_COMMANDS_ON_SAVE"
echo "Memory: $MEMORY_FILE"
echo "Watching chat: $CHAT_FILE"
echo "Watching commands: $COMMANDS_FILE"
echo "Conversation: $CONVERSATION_FILE"
echo ""

if command -v fswatch >/dev/null 2>&1; then
  echo "Using fswatch."
  fswatch -0 "$CHAT_FILE" "$COMMANDS_FILE" | while IFS= read -r -d '' changed_path; do
    if [ "$changed_path" = "$CHAT_FILE" ] && [ "$WATCH_CHAT_ON_SAVE" = "true" ] && [ -s "$CHAT_FILE" ]; then
      if wait_for_file_stable "$CHAT_FILE" 0.7 5; then
        CHAT_PROMPT="$(cat "$CHAT_FILE")"
        CHAT_HASH="$(hash_text "$CHAT_PROMPT")"
        LAST_CHAT_HASH="$(read_state last_chat_hash)"
        if [ "$CHAT_HASH" != "$LAST_CHAT_HASH" ]; then
          process_chat_prompt "$CHAT_PROMPT"
        fi
      fi
    fi

    if [ "$changed_path" = "$COMMANDS_FILE" ] && [ "$WATCH_COMMANDS_ON_SAVE" = "true" ]; then
      if wait_for_file_stable "$COMMANDS_FILE" 0.2 5; then
        COMMAND_BLOCK="$(cat "$COMMANDS_FILE")"
        process_commands_file "$COMMAND_BLOCK"
      fi
    fi
  done
else
  echo "fswatch not found; using 1s polling fallback."
  LAST_CHAT_HASH="$(read_state last_chat_hash)"
  LAST_COMMAND_HASH="$(read_state last_command_hash)"

  while true; do
    if [ "$WATCH_CHAT_ON_SAVE" = "true" ] && [ -s "$CHAT_FILE" ]; then
      if wait_for_file_stable "$CHAT_FILE" 0.7 5; then
        CHAT_PROMPT="$(cat "$CHAT_FILE")"
        CHAT_HASH="$(hash_text "$CHAT_PROMPT")"
        if [ "$CHAT_HASH" != "$LAST_CHAT_HASH" ]; then
          LAST_CHAT_HASH="$CHAT_HASH"
          process_chat_prompt "$CHAT_PROMPT"
        fi
      fi
    fi

    if [ "$WATCH_COMMANDS_ON_SAVE" = "true" ]; then
      if wait_for_file_stable "$COMMANDS_FILE" 0.2 5; then
        COMMAND_BLOCK="$(cat "$COMMANDS_FILE")"
        COMMAND_HASH="$(hash_text "$COMMAND_BLOCK")"
        if [ "$COMMAND_HASH" != "$LAST_COMMAND_HASH" ]; then
          LAST_COMMAND_HASH="$COMMAND_HASH"
          process_commands_file "$COMMAND_BLOCK"
        fi
      fi
    fi

    sleep 1
  done
fi
