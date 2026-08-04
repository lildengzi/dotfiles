#!/bin/sh
set -e
. "$(dirname "$0")/lib.sh"

echo "=== FantasqueSansM Nerd Font ==="

FONT_DIR="${FONT_DIR:-$HOME/.local/share/fonts}"
VERSION="v3.3.0"
NAME="FantasqueSansM"
URL="https://github.com/ryanoasis/nerd-fonts/releases/download/${VERSION}/${NAME}.tar.xz"

if [ -f "$FONT_DIR/FantasqueSansMNerdFontMono-Regular.ttf" ]; then
    echo "  字体已存在，跳过。"
    exit 0
fi

echo "  下载中..."
curl -L "$URL" -o /tmp/font.tar.xz

mkdir -p "$FONT_DIR"
echo "  解压中..."
tar -xJf /tmp/font.tar.xz -C "$FONT_DIR" --wildcards "*.ttf" "*.otf" 2>/dev/null || \
tar -xJf /tmp/font.tar.xz -C "$FONT_DIR" 2>/dev/null

echo "  刷新字体缓存..."
fc-cache -fv "$FONT_DIR" 2>/dev/null | tail -1

rm -f /tmp/font.tar.xz
echo "  完成！重启终端使字体生效。"
