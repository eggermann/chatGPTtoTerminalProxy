#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${PROJECT_DIR:-$(cd -- "$SCRIPT_DIR/.." && pwd)}"
INBOX_DIR="$PROJECT_DIR/.codex-inbox"
STATE_FILE="$INBOX_DIR/session.json"
BASE_TEMPLATE="$SCRIPT_DIR/conversation-base.md"
CHAT_TEMPLATE="$SCRIPT_DIR/chat-template.md"
SESSION_BASE_FILE="$INBOX_DIR/conversation-base.md"
SESSION_PREFIX="${SESSION_PREFIX:-codex/session}"
DEFAULT_BASE_BRANCH="${DEFAULT_BASE_BRANCH:-main}"
ARCHIVE_DIR="$INBOX_DIR/.archive"
WATCHER_SCRIPT="$PROJECT_DIR/bin/watch-chat-first.sh"

die() {
  echo "$*" >&2
  exit 1
}

require_repo() {
  git -C "$PROJECT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "Not a git repo: $PROJECT_DIR"
}

slugify() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//; s/-+/-/g'
}

current_branch() {
  git -C "$PROJECT_DIR" branch --show-current 2>/dev/null || true
}

branch_exists() {
  git -C "$PROJECT_DIR" show-ref --verify --quiet "refs/heads/$1"
}

base_branch() {
  if branch_exists "$DEFAULT_BASE_BRANCH"; then
    printf '%s\n' "$DEFAULT_BASE_BRANCH"
  else
    current_branch
  fi
}

ensure_inbox() {
  mkdir -p "$INBOX_DIR" "$ARCHIVE_DIR"
  touch "$STATE_FILE"
}

copy_base_template() {
  if [ -f "$BASE_TEMPLATE" ]; then
    cp "$BASE_TEMPLATE" "$SESSION_BASE_FILE"
  fi
}

archive_current_inbox() {
  local session_name="${1:-$(date +%Y%m%d-%H%M%S)}"
  local target_dir="$ARCHIVE_DIR/$session_name"

  mkdir -p "$target_dir"

  for file in \
    "$INBOX_DIR/chat.txt" \
    "$INBOX_DIR/commands.txt" \
    "$INBOX_DIR/conversation.md" \
    "$INBOX_DIR/conversation-base.md" \
    "$INBOX_DIR/last-output.md" \
    "$INBOX_DIR/log.txt" \
    "$INBOX_DIR/memory.md" \
    "$INBOX_DIR/session.json" \
    "$INBOX_DIR/watch-state.json"
  do
    if [ -e "$file" ]; then
      mv "$file" "$target_dir/"
    fi
  done
}

seed_fresh_inbox() {
  local branch="$1"
  local base="$2"

  if [ -f "$CHAT_TEMPLATE" ]; then
    cp "$CHAT_TEMPLATE" "$INBOX_DIR/chat.txt"
  else
    cat > "$INBOX_DIR/chat.txt" <<'EOF'
You are working in a chat-first local project bridge.
Read `.codex-inbox/memory.md` first.
Write prompts and investigation notes into `.codex-inbox/chat.txt`.
Grow the conversation in `.codex-inbox/conversation.md` as you learn more.
Use `.codex-inbox/last-output.md` before deciding the next step.
Only expose final shell commands in `.codex-inbox/commands.txt` at the end.
Do not put terminal commands in `chat.txt` unless you are still exploring.
Keep commands project-local unless I explicitly ask otherwise.
Wait for terminal output before continuing after a command run.
EOF
  fi

  : > "$INBOX_DIR/commands.txt"
  : > "$INBOX_DIR/conversation.md"
  : > "$INBOX_DIR/last-output.md"
  : > "$INBOX_DIR/log.txt"
  : > "$INBOX_DIR/watch-state.json"

  cat > "$INBOX_DIR/memory.md" <<EOF
# Project Memory

- title: chatGPTtoTerminalProxy
- project_path: $PROJECT_DIR
- workflow: chat-first
- purpose: move thought into terminal without losing the thread
- branch: $branch
- base_branch: $base
EOF
}

write_state() {
  local branch="$1"
  local base="$2"
  local session_name="$3"

  python3 - "$STATE_FILE" "$branch" "$base" "$session_name" "$PROJECT_DIR" <<'PY'
import json, sys
from datetime import datetime, timezone
from pathlib import Path

path = Path(sys.argv[1])
data = {
    "branch": sys.argv[2],
    "base_branch": sys.argv[3],
    "session_name": sys.argv[4],
    "project_path": sys.argv[5],
    "updated_at": datetime.now(timezone.utc).isoformat(),
}
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")
PY
}

update_memory() {
  local branch="$1"
  local base="$2"

  if [ ! -f "$INBOX_DIR/memory.md" ]; then
    return 0
  fi

  python3 - "$INBOX_DIR/memory.md" "$branch" "$base" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
branch = sys.argv[2]
base = sys.argv[3]
lines = path.read_text().splitlines()
updated = []
seen_branch = False
seen_base = False

for line in lines:
    if line.startswith("- branch:"):
        updated.append(f"- branch: {branch}")
        seen_branch = True
    elif line.startswith("- base_branch:"):
        updated.append(f"- base_branch: {base}")
        seen_base = True
    else:
        updated.append(line)

if not seen_branch:
    updated.append(f"- branch: {branch}")
if not seen_base:
    updated.append(f"- base_branch: {base}")

path.write_text("\n".join(updated) + "\n")
PY
}

sync_session_files() {
  local branch="$1"
  local base="$2"
  copy_base_template
  write_state "$branch" "$base" "$(basename "$branch")"
  update_memory "$branch" "$base"
}

new_session() {
  local raw_name="${1:-}"
  local session_name branch base

  base="$(base_branch)"
  session_name="$(slugify "${raw_name:-$(date +%Y%m%d-%H%M%S)}")"
  [ -n "$session_name" ] || session_name="$(date +%Y%m%d-%H%M%S)"
  branch="$SESSION_PREFIX/$session_name"

  if branch_exists "$branch"; then
    branch="$branch-$(date +%Y%m%d-%H%M%S)"
  fi

  git -C "$PROJECT_DIR" switch -c "$branch" "$base"
  archive_current_inbox "$session_name"
  sync_session_files "$branch" "$base"
  seed_fresh_inbox "$branch" "$base"
  if [ -x "$WATCHER_SCRIPT" ]; then
    nohup "$WATCHER_SCRIPT" >/dev/null 2>&1 &
    echo $! > "$INBOX_DIR/watch.pid"
  fi

  echo "Created session branch: $branch"
  echo "Base branch: $base"
  echo "Session base copied to: $SESSION_BASE_FILE"
  echo "Archived previous inbox to: $ARCHIVE_DIR/$session_name"
  echo "Watcher started: $WATCHER_SCRIPT"
}

switch_session() {
  local target="${1:-}"
  [ -n "$target" ] || die "Missing session branch."

  if [ "${target#${SESSION_PREFIX}/}" = "$target" ] && branch_exists "$SESSION_PREFIX/$target"; then
    target="$SESSION_PREFIX/$target"
  fi

  branch_exists "$target" || die "Session branch not found: $target"
  git -C "$PROJECT_DIR" switch "$target"
  sync_session_files "$target" "$(base_branch)"
  echo "Switched to session branch: $target"
}

delete_session() {
  local target="${1:-}"
  [ -n "$target" ] || die "Missing session branch."

  if [ "${target#${SESSION_PREFIX}/}" = "$target" ] && branch_exists "$SESSION_PREFIX/$target"; then
    target="$SESSION_PREFIX/$target"
  fi

  branch_exists "$target" || die "Session branch not found: $target"
  [ "$(current_branch)" != "$target" ] || die "Refuse to delete current branch."
  git -C "$PROJECT_DIR" branch -D "$target"
  echo "Deleted session branch: $target"
}

list_sessions() {
  git -C "$PROJECT_DIR" for-each-ref --format='%(refname:short)' "refs/heads/$SESSION_PREFIX" | sort
}

status() {
  echo "Project: $PROJECT_DIR"
  echo "Current branch: $(current_branch)"
  echo "Base branch: $(base_branch)"
  echo "Session state: $STATE_FILE"
  echo "Session base: $SESSION_BASE_FILE"
  echo
  echo "Sessions:"
  list_sessions || true
  echo
  echo "Git status:"
  git -C "$PROJECT_DIR" status --short
}

usage() {
  cat <<'EOF'
Usage:
  parasit.sh fresh [name]
  parasit.sh open <branch>
  parasit.sh delete <branch>
  parasit.sh list
  parasit.sh status
EOF
}

main() {
  require_repo
  ensure_inbox

  case "${1:-}" in
    fresh|new-session)
      new_session "${2:-}"
      ;;
    open|open-session|switch-session)
      [ $# -ge 2 ] || die "Missing session branch."
      switch_session "$2"
      ;;
    delete|delete-session)
      [ $# -ge 2 ] || die "Missing session branch."
      delete_session "$2"
      ;;
    list|list-sessions)
      list_sessions
      ;;
    status)
      status
      ;;
    help|-h|--help|"")
      usage
      ;;
    *)
      die "Unknown command: $1"
      ;;
  esac
}

main "$@"
