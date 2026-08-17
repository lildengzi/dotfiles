#!/bin/sh
# 重建 distrobox 容器
set -e
. "$(dirname "$0")/../lib.sh"

LIST="$DOTFILES/vms/distrobox/containers.list"
[ -f "$LIST" ] || { echo "缺少 $LIST" >&2; exit 1; }

echo "=== 重建 distrobox 容器 ==="
grep -v '^#' "$LIST" | grep -v '^[[:space:]]*$' | while read -r name image; do
    if distrobox list 2>/dev/null | grep -qw "$name"; then
        echo "  $name 已存在，跳过"
    else
        echo "  创建 $name ($image)..."
        distrobox create --name "$name" --image "$image"
    fi
done