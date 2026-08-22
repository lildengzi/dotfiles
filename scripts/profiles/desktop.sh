#!/bin/sh
# Desktop: niri + DMS + 壁纸 + 自启动 + 外观
set -e
. "$(dirname "$0")/../lib.sh"

echo "=== Desktop 桌面配置 ==="

ask() { # $1=提示 $2=默认(y/n)
    printf "%s [%s] " "$1" "$2"
    read ans; [ -z "$ans" ] && ans="$2"
    case "$ans" in y|Y) return 0;; *) return 1;; esac
}

if ask "安装 niri 窗口管理器?" y; then
    sh "$SCRIPT_DIR/install-niri.sh"
fi
if ask "复制 DMS 配置?" y; then
    backup_config "$HOME/.config/DankMaterialShell"
    mkdir -p "$HOME/.config/DankMaterialShell"
    cp -r "$DOTFILES/.config/DankMaterialShell/." "$HOME/.config/DankMaterialShell/"
fi
if ask "安装壁纸?" y; then
    sh "$SCRIPT_DIR/install-walls.sh"
fi
if ask "复制 autostart?" y; then
    backup_config "$HOME/.config/autostart"
    mkdir -p "$HOME/.config/autostart"
    cp -r "$DOTFILES/.config/autostart/." "$HOME/.config/autostart/"
fi
if ask "复制外观配置 (gtk/fontconfig)?" y; then
    for d in gtk-3.0 gtk-4.0 fontconfig; do
        backup_config "$HOME/.config/$d"
        mkdir -p "$HOME/.config/$d"
        cp -r "$DOTFILES/.config/$d/." "$HOME/.config/$d/"
    done
fi
echo "  桌面配置完成"