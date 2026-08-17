#!/bin/sh
# 恢复 winboat（Windows 虚拟机）
set -e
. "$(dirname "$0")/../lib.sh"

RESCUE="/mnt/E/Rescue"
echo "=== 恢复 winboat ==="

# 1. 配置
mkdir -p "$HOME/.winboat" "$HOME/winboat"
cp -rn "$DOTFILES/vms/winboat/." "$HOME/.winboat/" 2>/dev/null || true
# 2. 数据（从 Rescue 拷贝）
if [ -d "$RESCUE/home_core/winboat" ]; then
    echo "  从 Rescue 拷贝 winboat 数据..."
    cp -rn "$RESCUE/home_core/winboat/." "$HOME/winboat/"
else
    echo "  未找到 $RESCUE/home_core/winboat，跳过数据拷贝"
fi
echo "  完成。启动前请检查 ~/.winboat/podman-compose.yml（__USER__ / __CHANGE_ME__ 需替换）"
echo "  运行: cd ~/winboat && podman compose up -d"