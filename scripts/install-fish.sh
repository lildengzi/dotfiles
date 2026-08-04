#!/bin/sh
set -e
. "$(dirname "$0")/lib.sh"

echo "=== Fish Shell ==="
install_deps fish

backup_config "$HOME/.config/fish"
mkdir -p "$HOME/.config/fish"
cp -r "$DOTFILES/.config/fish/." "$HOME/.config/fish/"
echo "  完成！运行 chsh -s /usr/bin/fish 设为默认 shell。"
