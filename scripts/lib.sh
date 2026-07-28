#!/bin/bash
set -e

DOTFILES="$(cd "$(dirname "$0")/.." && pwd)"

detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$ID"
    else
        echo "unknown"
    fi
}

backup_config() {
    local src="$1"
    if [ -e "$src" ]; then
        local bak="${src}.bak.$(date +%Y%m%d-%H%M%S)"
        cp -r "$src" "$bak"
        echo "  备份: $src -> $bak"
    fi
}

install_deps() {
    local distro
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
            echo "  未知发行版 '$distro'，请自行安装: $*"
            ;;
    esac
}
