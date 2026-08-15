#!/bin/sh
# Copy the whole .config tree from the repo into ~/.config
# The repo's .config/ is the actual ~/.config tree (privacy-sensitive items removed).
set -e
. "$(dirname "$0")/lib.sh"

echo "=== 复制全部配置 (.config) ==="

backup_config "$HOME/.config"
mkdir -p "$HOME/.config"
cp -r "$DOTFILES/.config/." "$HOME/.config/"
echo "  完成！所有配置已合并到 ~/.config/"
echo "  注意：这只是复制配置，不会安装软件本体。"
