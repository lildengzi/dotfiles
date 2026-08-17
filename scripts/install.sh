#!/bin/sh
set -e
SCRIPT_DIR="$(dirname "$0")"

echo "================================"
echo "      dotfiles 安装器"
echo "================================"

while :; do
    echo ""
    echo "  1) Desktop   — 桌面外观"
    echo "  2) Work      — 工作环境"
    echo "  3) Agent     — AI agent 工具链"
    echo "  4) Packages  — 系统软件（分类）"
    echo "  5) VMs       — 虚拟机恢复"
    echo "  0) 退出"
    printf "选择 [0-5]: "
    read choice

    case "$choice" in
        1) sh "$SCRIPT_DIR/profiles/desktop.sh" ;;
        2) sh "$SCRIPT_DIR/profiles/work.sh" ;;
        3) sh "$SCRIPT_DIR/profiles/agent.sh" ;;
        4)
            echo "包分类:"
            for f in "$SCRIPT_DIR"/../packages/*.txt; do
                echo "  $(basename "$f" .txt)"
            done
            printf "输入要安装的分类（空格分隔，或回车跳过）: "
            read cats
            [ -n "$cats" ] && sh "$SCRIPT_DIR/install-packages.sh" $cats
            ;;
        5)
            echo "虚拟机:"
            for f in "$SCRIPT_DIR"/restore/*.sh; do
                echo "  $(basename "$f" .sh)"
            done
            printf "输入要恢复的虚拟机（空格分隔，或回车跳过）: "
            read vms
            [ -n "$vms" ] && for vm in $vms; do sh "$SCRIPT_DIR/restore/$vm.sh"; done
            ;;
        0) exit 0 ;;
        *) echo "无效选择" ;;
    esac
done