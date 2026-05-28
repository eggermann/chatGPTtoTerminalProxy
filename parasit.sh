#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

if [ "$#" -eq 0 ]; then
  exec "$SCRIPT_DIR/bin/watch-chat-first.sh"
fi

exec "$SCRIPT_DIR/bin/chatgpt-parasit.sh" "$@"
