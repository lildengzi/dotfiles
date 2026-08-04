#!/bin/sh
set -e
. "$(dirname "$0")/lib.sh"

echo "=== niri Wayland 窗口管理器 ==="
install_deps niri

backup_config "$HOME/.config/niri"
mkdir -p "$HOME/.config/niri/dms"
cp "$DOTFILES/config/niri/config.kdl" "$HOME/.config/niri/"
cp "$DOTFILES/config/niri/dms/"*.kdl "$HOME/.config/niri/dms/" 2>/dev/null || true
echo "  完成！退出登录后选择 niri 会话。"
