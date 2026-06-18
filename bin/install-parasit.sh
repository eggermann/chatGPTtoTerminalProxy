#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
INSTALL_DIR="${INSTALL_DIR:-$HOME/.cargo/bin}"
INSTALL_NAME="parasit"
TARGET="$INSTALL_DIR/$INSTALL_NAME"

die() {
  echo "$*" >&2
  exit 1
}

mkdir -p "$INSTALL_DIR"

cat > "$TARGET" <<EOF
#!/bin/bash
exec "$REPO_ROOT/parasit.sh" "\$@"
EOF

chmod +x "$TARGET"

echo "Installed: $TARGET"
echo "Target: $REPO_ROOT/parasit.sh"
