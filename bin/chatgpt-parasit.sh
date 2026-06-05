#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TOOL_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
PROJECT_DIR="$(cd -- "$PROJECT_DIR" && pwd)"
PROJECT_NAME="$(basename "$PROJECT_DIR")"
INBOX_DIR="$PROJECT_DIR/.codex-inbox"
INNER_GIT_DIR="$INBOX_DIR"
STATE_FILE="$INBOX_DIR/session.json"
CHAT_TEMPLATE="$SCRIPT_DIR/chat-template.md"
SESSION_PREFIX="${SESSION_PREFIX:-codex/session}"
DEFAULT_BASE_BRANCH="${DEFAULT_BASE_BRANCH:-main}"
ARCHIVE_DIR="$INBOX_DIR/.archive"
WATCHER_SCRIPT="$TOOL_ROOT/bin/watch-chat-first.sh"
WATCH_PID_FILE="$INBOX_DIR/watch.pid"

die() {
  echo "$*" >&2
  exit 1
}

inbox_git() {
  git -C "$INNER_GIT_DIR" "$@"
}

require_project_dir() {
  [ -d "$PROJECT_DIR" ] || die "Project directory not found: $PROJECT_DIR"
}

seed_git_identity() {
  local name email

  name="$(git -C "$PROJECT_DIR" config --get user.name 2>/dev/null || git config --global --get user.name 2>/dev/null || true)"
  email="$(git -C "$PROJECT_DIR" config --get user.email 2>/dev/null || git config --global --get user.email 2>/dev/null || true)"

  if [ -n "$name" ]; then
    inbox_git config user.name "$name"
  fi

  if [ -n "$email" ]; then
    inbox_git config user.email "$email"
  fi
}

watcher_pid() {
  [ -f "$WATCH_PID_FILE" ] || return 1
  cat "$WATCH_PID_FILE" 2>/dev/null || return 1
}

watcher_is_running() {
  local pid

  pid="$(watcher_pid)" || return 1
  case "$pid" in
    ''|*[!0-9]*)
      return 1
      ;;
  esac
  kill -0 "$pid" >/dev/null 2>&1
}

start_watcher() {
  if watcher_is_running; then
    echo "Watcher already running: $(watcher_pid)"
    return 0
  fi

  if [ -x "$WATCHER_SCRIPT" ]; then
    PROJECT_DIR="$PROJECT_DIR" nohup "$WATCHER_SCRIPT" >/dev/null 2>&1 &
    echo $! > "$WATCH_PID_FILE"
  fi
}

slugify() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//; s/-+/-/g'
}

current_branch() {
  inbox_git branch --show-current 2>/dev/null || true
}

branch_exists() {
  inbox_git show-ref --verify --quiet "refs/heads/$1"
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

ensure_inbox_repo() {
  if [ ! -d "$INBOX_DIR/.git" ]; then
    git -C "$INBOX_DIR" init -b main >/dev/null 2>&1 || git -C "$INBOX_DIR" init >/dev/null 2>&1
  fi

  seed_git_identity

  if ! inbox_git rev-parse --verify HEAD >/dev/null 2>&1; then
    if [ -n "$(inbox_git status --porcelain 2>/dev/null || true)" ]; then
      inbox_git add -A
      inbox_git commit -m "Initial inbox snapshot" >/dev/null 2>&1 || true
    fi
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

- title: $PROJECT_NAME
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
  write_state "$branch" "$base" "$(basename "$branch")"
  update_memory "$branch" "$base"
}

new_session() {
  local raw_name="${1:-}"
  local session_name branch base

  base="$(base_branch)"
  session_name="$(slugify "${raw_name:-$PROJECT_NAME}")"
  [ -n "$session_name" ] || session_name="$(date +%Y%m%d-%H%M%S)"
  branch="$SESSION_PREFIX/$session_name"

  if branch_exists "$branch"; then
    branch="$branch-$(date +%Y%m%d-%H%M%S)"
  fi

  if [ -n "$(inbox_git status --porcelain 2>/dev/null || true)" ]; then
    inbox_git add -A
    inbox_git commit -m "Snapshot before fresh: $session_name" >/dev/null 2>&1 || true
  fi

  inbox_git switch -c "$branch" "$base"
  archive_current_inbox "$session_name"
  sync_session_files "$branch" "$base"
  seed_fresh_inbox "$branch" "$base"
  start_watcher

  echo "Created session branch: $branch"
  echo "Base branch: $base"
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
  if [ -n "$(inbox_git status --porcelain 2>/dev/null || true)" ]; then
    inbox_git add -A
    inbox_git commit -m "Snapshot before switch: $target" >/dev/null 2>&1 || true
  fi
  inbox_git switch "$target"
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
  inbox_git branch -D "$target"
  echo "Deleted session branch: $target"
}

list_sessions() {
  inbox_git for-each-ref --format='%(refname:short)' "refs/heads/$SESSION_PREFIX" | sort
}

status() {
  echo "Project: $PROJECT_DIR"
  if git -C "$PROJECT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Outer branch: $(git -C "$PROJECT_DIR" branch --show-current 2>/dev/null || true)"
  else
    echo "Outer branch: none (project is not a git repo)"
  fi
  echo "Inner branch: $(current_branch)"
  echo "Base branch: $(base_branch)"
  echo "Inner repo: $INNER_GIT_DIR"
  echo "Session state: $STATE_FILE"
  echo
  echo "Sessions:"
  list_sessions || true
  echo
  echo "Git status:"
  if git -C "$PROJECT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git -C "$PROJECT_DIR" status --short
  else
    echo "(not a git repo)"
  fi
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
  require_project_dir
  ensure_inbox
  ensure_inbox_repo

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
