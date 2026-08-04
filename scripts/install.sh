#!/bin/sh
set -e
SCRIPT_DIR="$(dirname "$0")"

echo "================================"
echo "      dotfiles 安装器"
echo "================================"
echo ""
echo "你想安装什么？"
echo ""
echo "  1) 全部安装（完整桌面环境）"
echo "  2) 仅终端 + 编辑器"
echo "  3) 自定义选择"
echo "  4) 仅复制全部配置（不装软件）"
echo "  0) 退出"
echo ""

printf "选择 [0-4]: "
read choice

case "$choice" in
    1)
        sh "$SCRIPT_DIR/install-font.sh"
        sh "$SCRIPT_DIR/install-kitty.sh"
        sh "$SCRIPT_DIR/install-nvim.sh"
        sh "$SCRIPT_DIR/install-yazi.sh"
        sh "$SCRIPT_DIR/install-niri.sh"
        sh "$SCRIPT_DIR/install-fish.sh"
        sh "$SCRIPT_DIR/install-starship.sh"
        sh "$SCRIPT_DIR/install-vscode.sh"
        sh "$SCRIPT_DIR/install-config.sh"
        ;;
    2)
        sh "$SCRIPT_DIR/install-font.sh"
        sh "$SCRIPT_DIR/install-kitty.sh"
        sh "$SCRIPT_DIR/install-nvim.sh"
        sh "$SCRIPT_DIR/install-yazi.sh"
        sh "$SCRIPT_DIR/install-starship.sh"
        echo ""
        echo "提示：Kitty + nvim + yazi + starship 已安装。"
        echo "如果你用其他终端/shell，手动复制 config 即可。"
        ;;
    3)
        echo ""
        echo "可选的组件（y/n）:"
        for c in font kitty nvim yazi niri fish starship vscode config; do
            printf "  安装 %s ? [y/N] " "$c"
            read yn
            case "$yn" in
                y|Y)
                    case "$c" in
                        font)    sh "$SCRIPT_DIR/install-font.sh" ;;
                        kitty)   sh "$SCRIPT_DIR/install-kitty.sh" ;;
                        nvim)    sh "$SCRIPT_DIR/install-nvim.sh" ;;
                        yazi)    sh "$SCRIPT_DIR/install-yazi.sh" ;;
                        niri)    sh "$SCRIPT_DIR/install-niri.sh" ;;
                        fish)    sh "$SCRIPT_DIR/install-fish.sh" ;;
                        starship) sh "$SCRIPT_DIR/install-starship.sh" ;;
                        vscode)  sh "$SCRIPT_DIR/install-vscode.sh" ;;
                        config)  sh "$SCRIPT_DIR/install-config.sh" ;;
                    esac
                    ;;
                *)
                    ;;
            esac
        done
        ;;
    4)
        sh "$SCRIPT_DIR/install-config.sh"
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
