#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_DIR="$HOME/.shell-functions"
ZSHRC="$HOME/.zshrc"

mkdir -p "$TARGET_DIR"

# Symlink each function file
for func_file in "$SCRIPT_DIR"/functions/*.sh; do
  name=$(basename "$func_file")
  target="$TARGET_DIR/$name"

  if [ -e "$target" ] && [ ! -L "$target" ]; then
    echo "Skipping $name (file exists and is not a symlink — back it up first)"
    continue
  fi

  ln -sf "$func_file" "$target"
  echo "Linked $name -> $target"
done

# Add loader to .zshrc if not already present
LOADER='for func_file in ~/.shell-functions/*.sh; do [ -f "$func_file" ] && source "$func_file"; done'

if ! grep -qF 'shell-functions/*.sh' "$ZSHRC" 2>/dev/null; then
  echo "" >> "$ZSHRC"
  echo "# Tern shell functions" >> "$ZSHRC"
  echo "$LOADER" >> "$ZSHRC"
  echo "Added loader to $ZSHRC"
else
  echo "Loader already present in $ZSHRC"
fi

# Check for TERN_REPO_PATH
if ! grep -q 'TERN_REPO_PATH' "$ZSHRC" 2>/dev/null; then
  echo ""
  echo "NOTE: Add this to your .zshrc (adjust the path to your Tern checkout):"
  echo ""
  echo '  export TERN_REPO_PATH="$HOME/tern"'
fi

echo ""
echo "Done! Run 'source ~/.zshrc' or open a new terminal."
