#!/bin/sh
set -e

DOTFILES="$(cd "$(dirname "$0")/.." && pwd)"

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
