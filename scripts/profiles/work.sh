#!/bin/sh
# Work: nvim + yazi + kitty + fish + starship + 终端工具 + 字体 + JDK
set -e
. "$(dirname "$0")/../lib.sh"

echo "=== Work 工作环境 ==="

ask() {
    printf "%s [%s] " "$1" "$2"
    read ans; [ -z "$ans" ] && ans="$2"
    case "$ans" in y|Y) return 0;; *) return 1;; esac
}

if ask "安装 Neovim?" y; then sh "$SCRIPT_DIR/install-nvim.sh"; fi
if ask "安装 Yazi?" y; then sh "$SCRIPT_DIR/install-yazi.sh"; fi
if ask "安装 Kitty?" y; then sh "$SCRIPT_DIR/install-kitty.sh"; fi
if ask "安装 Fish?" y; then sh "$SCRIPT_DIR/install-fish.sh"; fi
if ask "安装 Starship?" y; then sh "$SCRIPT_DIR/install-starship.sh"; fi
if ask "复制终端工具配置 (alacritty/btop/cava/mpv/MangoHud/fastfetch/env)?" y; then
    for d in alacritty btop cava mpv MangoHud fastfetch environment.d; do
        backup_config "$HOME/.config/$d"
        mkdir -p "$HOME/.config/$d"
        cp -r "$DOTFILES/.config/$d/." "$HOME/.config/$d/" 2>/dev/null || true
    done
fi
if ask "安装 Nerd Font 字体?" y; then sh "$SCRIPT_DIR/install-font.sh"; fi
if ask "安装最新 JDK (jdk-openjdk)?" n; then
    install_deps jdk-openjdk
    mkdir -p "$HOME/.config/environment.d"
    if ! grep -q JAVA_HOME "$HOME/.config/environment.d/java.conf" 2>/dev/null; then
        cat >> "$HOME/.config/environment.d/java.conf" << 'EOF'
JAVA_HOME=/usr/lib/jvm/java-openjdk
PATH=$HOME/.cargo/bin:/usr/lib/jvm/java-openjdk/bin:$PATH
EOF
        echo "  已写入 JAVA_HOME 到 environment.d/java.conf"
    fi
fi
echo "  工作环境配置完成"