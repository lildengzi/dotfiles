#!/bin/sh
# 恢复 podman 容器
set -e
. "$(dirname "$0")/../lib.sh"

RESCUE="/mnt/E/Rescue"
echo "=== 恢复 podman 容器 ==="
# 大数据从 Rescue 恢复（若存在）
if [ -d "$RESCUE/podman-storage" ]; then
    echo "  从 Rescue 拷贝 podman storage..."
    mkdir -p "$HOME/.local/share/containers"
    cp -rn "$RESCUE/podman-storage/." "$HOME/.local/share/containers/"
else
    echo "  未找到 $RESCUE/podman-storage，跳过数据拷贝"
fi
# distrobox 容器提示
if [ -f "$DOTFILES/vms/distrobox/containers.list" ]; then
    echo "  提示: distrobox 容器请运行 restore/distrobox.sh"
fi
echo "  完成。podman 容器可用 'podman ps -a' 检查"