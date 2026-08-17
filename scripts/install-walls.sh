#!/bin/sh
# 壁纸 → ~/Pictures/wallpapers
set -e
. "$(dirname "$0")/lib.sh"

echo "=== 安装壁纸 ==="
DEST="$HOME/Pictures/wallpapers"
mkdir -p "$DEST"
for f in "$DOTFILES"/wallpapers/*.png "$DOTFILES"/wallpapers/*.jpg "$DOTFILES"/wallpapers/*.jpeg "$DOTFILES"/wallpapers/*.webp; do
    [ -f "$f" ] || continue
    cp -n "$f" "$DEST/"
done
count=$(ls "$DEST" 2>/dev/null | wc -l)
echo "  已复制壁纸到 $DEST (共 $count 张)"