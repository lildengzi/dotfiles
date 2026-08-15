#!/bin/sh
set -e
. "$(dirname "$0")/lib.sh"

echo "=== VSCode 配置 ==="

# VSCode (Code) and VSCodium both read ~/.config/Code/User/settings.json / ~/.config/VSCodium/User/settings.json
backup_config "$HOME/.config/Code/User/settings.json"
mkdir -p "$HOME/.config/Code/User"
cp "$DOTFILES/.config/Code/User/settings.json" "$HOME/.config/Code/User/settings.json"
echo "  VSCode 配置已写入 ~/.config/Code/User/settings.json"
echo "  注意：VSCode 本体请自行安装（GUI 应用，不通过脚本安装）"
