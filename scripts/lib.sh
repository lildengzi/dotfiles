#!/bin/sh
set -e

DOTFILES="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT_DIR="$(dirname "$0")"

detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        printf '%s\n' "$ID"
    else
        printf '%s\n' "unknown"
    fi
}

backup_config() {
    src="$1"
    if [ -e "$src" ]; then
        bak="${src}.bak.$(date +%Y%m%d-%H%M%S)"
        cp -r "$src" "$bak"
        printf '%s\n' "  备份: $src -> $bak"
    fi
}

install_deps() {
    distro=$(detect_distro)
    case "$distro" in
        arch|archarm|cachyos|endeavouros|manjaro)
            sudo pacman -S --needed --noconfirm "$@"
            ;;
        fedora)
            sudo dnf install -y "$@"
            ;;
        debian|ubuntu|pop|linuxmint)
            sudo apt install -y "$@"
            ;;
        opensuse*)
            sudo zypper install -y "$@"
            ;;
        *)
            printf '%s\n' "  未知发行版 '$distro'，请自行安装: $*"
            ;;
    esac
}

# 按分类安装包清单：官方仓库用 pacman，AUR 用 paru
install_pkg_category() {
    category="$1"
    list="$DOTFILES/packages/$category.txt"
    [ -f "$list" ] || { echo "  未知分类: $category" >&2; return 1; }
    count=$(grep -v '^#' "$list" | grep -v '^[[:space:]]*$' | wc -l)
    echo "=== 安装 $category 包 ($count 个) ==="
    # 过滤注释/空行
    pkgs=$(grep -v '^#' "$list" | grep -v '^[[:space:]]*$')
    [ -n "$pkgs" ] || { echo "  $category 列表为空"; return 0; }
    case "$category" in
        aur)
            if command -v paru >/dev/null 2>&1; then
                paru -S --needed $pkgs
            elif command -v yay >/dev/null 2>&1; then
                yay -S --needed $pkgs
            else
                echo "  未找到 paru/yay，无法安装 AUR 包" >&2
                echo "  请先安装 paru: sudo pacman -S paru" >&2
                return 1
            fi
            ;;
        *)
            install_deps $pkgs
            ;;
    esac
}