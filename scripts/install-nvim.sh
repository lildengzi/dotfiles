#!/bin/sh
set -e
. "$(dirname "$0")/lib.sh"

echo "=== Neovim (LazyVim) ==="

distro=$(detect_distro)
case "$distro" in
    arch|archarm|cachyos|endeavouros|manjaro)
        install_deps neovim
        ;;
    *)
        install_deps neovim || true
        echo "  如果你的发行版 neovim < 0.10，请从 GitHub 安装:"
        echo "  https://github.com/neovim/neovim/releases"
        ;;
esac

backup_config "$HOME/.config/nvim"
mkdir -p "$HOME/.config/nvim"
cp -r "$DOTFILES/config/nvim/." "$HOME/.config/nvim/"
echo "  完成！打开 nvim 自动安装插件。"
