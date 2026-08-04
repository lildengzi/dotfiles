#!/bin/sh
set -e
. "$(dirname "$0")/lib.sh"

echo "=== Yazi 文件管理器 ==="

distro=$(detect_distro)
case "$distro" in
    arch|archarm|cachyos|endeavouros|manjaro)
        install_deps yazi
        ;;
    *)
        install_deps yazi || true
        echo "  如果你的发行版没有 yazi，请参考官方安装文档:"
        echo "  https://yazi-rs.github.io/docs/installation"
        ;;
esac

backup_config "$HOME/.config/yazi"
mkdir -p "$HOME/.config/yazi"
cp -r "$DOTFILES/.config/yazi/." "$HOME/.config/yazi/"
echo "  完成！"
