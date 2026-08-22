#!/bin/sh
# 恢复 waydroid（配置 + 数据）
set -e
. "$(dirname "$0")/../lib.sh"

RESCUE="/mnt/E/Rescue"
echo "=== 恢复 waydroid ==="

# 配置
if [ -d "$DOTFILES/vms/waydroid" ]; then
    mkdir -p "$HOME/.config/waydroid"
    cp -rn "$DOTFILES/vms/waydroid/." "$HOME/.config/waydroid/"
fi
# 数据（若 Rescue 有备份）
if [ -d "$RESCUE/waydroid-data" ]; then
    echo "  从 Rescue 拷贝 waydroid 数据..."
    mkdir -p "$HOME/.local/share/waydroid"
    cp -rn "$RESCUE/waydroid-data/." "$HOME/.local/share/waydroid/"
else
    echo "  未找到 $RESCUE/waydroid-data，跳过数据拷贝"
fi
echo "  完成。启动前: sudo systemctl start waydroid-container"
echo "  然后: waydroid session start"