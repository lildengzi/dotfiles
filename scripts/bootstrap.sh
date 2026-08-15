#!/bin/sh
# One-line bootstrap: curl -fsSL https://raw.githubusercontent.com/lildengzi/dotfiles/master/scripts/bootstrap.sh | sh
# Downloads the repo and launches the interactive installer.
set -e

REPO="lildengzi/dotfiles"
BRANCH="master"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles-bootstrap"
URL="https://github.com/$REPO/archive/refs/heads/$BRANCH.tar.gz"

echo "==> 下载 dotfiles (branch: $BRANCH) ..."
rm -rf "$CACHE"
mkdir -p "$CACHE"
if ! curl -fsSL "$URL" | tar -xz -C "$CACHE" --strip-components=1; then
    echo "下载失败，请检查网络或手动 git clone。" >&2
    exit 1
fi

exec sh "$CACHE/scripts/install.sh"
