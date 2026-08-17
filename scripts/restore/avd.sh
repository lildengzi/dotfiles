#!/bin/sh
# 恢复 AVD（Android 模拟器）
set -e
. "$(dirname "$0")/../lib.sh"

RESCUE="/mnt/E/Rescue"
echo "=== 恢复 AVD ==="
mkdir -p "$HOME/.android/avd"
if [ -f "$DOTFILES/vms/avd/test.ini" ]; then
    cp "$DOTFILES/vms/avd/test.ini" "$HOME/.android/avd/test.ini"
    # 展开 ~ 为真实路径
    sed -i "s#^path=~#path=$HOME#" "$HOME/.android/avd/test.ini"
fi
if [ -d "$RESCUE/android-avd" ]; then
    echo "  从 Rescue 拷贝 AVD 数据..."
    cp -rn "$RESCUE/android-avd/test.avd" "$HOME/.android/avd/" 2>/dev/null || true
else
    echo "  未找到 $RESCUE/android-avd，需用 Android Studio 重建 test.avd"
fi
echo "  完成。可用 avdmanager 或 Android Studio 验证。"