#!/bin/sh
# 恢复 agent 相关 npm 全局工具（codex 等）
# 清单来自 packages/toolchain.txt 中以 '# npm-global:' 标记的行。
set -e
. "$(dirname "$0")/lib.sh"

echo "=== Agent npm 全局工具 ==="
if [ -f "$DOTFILES/packages/toolchain.txt" ]; then
    npm_pkgs=$(grep '^# npm-global:' "$DOTFILES/packages/toolchain.txt" \
               | sed 's/^# npm-global:[[:space:]]*//')
    [ -n "$npm_pkgs" ] || { echo "  toolchain.txt 中没有 npm-global 标记"; exit 0; }
    # npm-global 行格式: 包名 npm包名，例如 "codex @openai/codex"
    for entry in $npm_pkgs; do
        printf "  安装 %s ...\n" "$entry"
        npm install -g "$entry"
    done
else
    echo "  缺少 packages/toolchain.txt" >&2
    exit 1
fi