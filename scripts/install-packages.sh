#!/bin/sh
# 按分类安装包。用法: sh install-packages.sh system desktop aur ...
# 无参数时列出所有分类。
set -e
. "$(dirname "$0")/lib.sh"

if [ $# -eq 0 ]; then
    echo "可用分类:"
    for f in "$DOTFILES"/packages/*.txt; do
        echo "  $(basename "$f" .txt)"
    done
    exit 0
fi

for category in "$@"; do
    install_pkg_category "$category"
done