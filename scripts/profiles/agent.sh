#!/bin/sh
# Agent: opencode + agents skills + claude + superpowers + agent npm 工具
set -e
. "$(dirname "$0")/../lib.sh"

echo "=== Agent 工具链 ==="

ask() {
    printf "%s [%s] " "$1" "$2"
    read ans; [ -z "$ans" ] && ans="$2"
    case "$ans" in y|Y) return 0;; *) return 1;; esac
}

if ask "复制 opencode 配置?" y; then
    backup_config "$HOME/.config/opencode"
    mkdir -p "$HOME/.config/opencode"
    cp -r "$DOTFILES/.config/opencode/." "$HOME/.config/opencode/"
fi
if ask "复制 agents skills?" y; then
    backup_config "$HOME/.agents"
    mkdir -p "$HOME/.agents"
    cp -r "$DOTFILES/.agents/." "$HOME/.agents/"
fi
if ask "复制 claude 配置?" y; then
    backup_config "$HOME/.claude/settings.json"
    mkdir -p "$HOME/.claude"
    [ -f "$DOTFILES/.claude/settings.json" ] && cp "$DOTFILES/.claude/settings.json" "$HOME/.claude/"
fi
if ask "安装 agent npm 全局工具 (codex 等)?" y; then
    sh "$SCRIPT_DIR/install-agent-tools.sh"
fi
echo "  Agent 配置完成"