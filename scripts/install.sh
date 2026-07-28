#!/bin/bash
set -e
SCRIPT_DIR="$(dirname "$0")"

echo "================================"
echo "  lildengzi's dotfiles 安装器"
echo "================================"
echo ""
echo "你想安装什么？"
echo ""
echo "  1) 全部安装（完整桌面环境）"
echo "  2) 仅终端 + 编辑器"
echo "  3) 自定义选择"
echo "  0) 退出"
echo ""

read -rp "选择 [0-3]: " choice

case "$choice" in
    1)
        bash "$SCRIPT_DIR/install-font.sh"
        bash "$SCRIPT_DIR/install-kitty.sh"
        bash "$SCRIPT_DIR/install-nvim.sh"
        bash "$SCRIPT_DIR/install-niri.sh"
        bash "$SCRIPT_DIR/install-fish.sh"
        bash "$SCRIPT_DIR/install-starship.sh"
        ;;
    2)
        bash "$SCRIPT_DIR/install-font.sh"
        bash "$SCRIPT_DIR/install-kitty.sh"
        bash "$SCRIPT_DIR/install-nvim.sh"
        bash "$SCRIPT_DIR/install-starship.sh"
        echo ""
        echo "提示：Kitty + nvim + starship 已安装。"
        echo "如果你用其他终端/shell，手动复制 config 即可。"
        ;;
    3)
        echo ""
        echo "可选的组件（y/n）:"
        components="font kitty nvim niri fish starship"
        declare -A map=(
            [font]="install-font.sh"
            [kitty]="install-kitty.sh"
            [nvim]="install-nvim.sh"
            [niri]="install-niri.sh"
            [fish]="install-fish.sh"
            [starship]="install-starship.sh"
        )
        for c in $components; do
            read -rp "  安装 $c ? [y/N] " yn
            if [[ "$yn" =~ ^[yY] ]]; then
                bash "$SCRIPT_DIR/${map[$c]}"
            fi
        done
        ;;
    0)
        exit 0
        ;;
    *)
        echo "无效选择，退出。"
        exit 1
        ;;
esac

echo ""
echo "完成！重启或重新登录后生效。"
