#!/bin/sh
# 恢复 OSX-KVM（macOS 虚拟机）
set -e
. "$(dirname "$0")/../lib.sh"

RESCUE="/mnt/E/Rescue"
echo "=== 恢复 OSX-KVM ==="
if [ -d "$DOTFILES/vms/osx-kvm" ]; then
    mkdir -p "$HOME/osx-kvm"
    cp -rn "$DOTFILES/vms/osx-kvm/." "$HOME/osx-kvm/"
fi
if [ -d "$RESCUE/osx-kvm" ]; then
    echo "  从 Rescue 拷贝 OSX-KVM 数据..."
    cp -rn "$RESCUE/osx-kvm/." "$HOME/osx-kvm/" 2>/dev/null || true
else
    echo "  未找到 $RESCUE/osx-kvm，跳过数据拷贝"
fi
echo "  完成。macOS 镜像需重新下载: cd ~/osx-kvm && python3 fetch-macOS-v2.py"