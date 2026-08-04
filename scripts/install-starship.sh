#!/bin/sh
set -e
. "$(dirname "$0")/lib.sh"

echo "=== Starship 提示符 ==="

if ! command -v starship >/dev/null 2>&1; then
    echo "  安装 starship..."
    curl -sS https://starship.rs/install.sh | sh -s -- -y
fi

backup_config "$HOME/.config/starship.toml"
mkdir -p "$HOME/.config"
cp "$DOTFILES/.config/starship.toml" "$HOME/.config/"
cp "$DOTFILES/.config/starship.tty.toml" "$HOME/.config/"
cp "$DOTFILES/.config/starship.bash.toml" "$HOME/.config/"
echo "  完成！确保 shell init 中加了 'starship init'。"
