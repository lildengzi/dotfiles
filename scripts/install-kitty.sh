#!/bin/sh
set -e
. "$(dirname "$0")/lib.sh"

echo "=== Kitty 终端 ==="
install_deps kitty
backup_config "$HOME/.config/kitty"
mkdir -p "$HOME/.config/kitty"
cp -r "$DOTFILES/config/kitty/." "$HOME/.config/kitty/"
echo "  完成！"
