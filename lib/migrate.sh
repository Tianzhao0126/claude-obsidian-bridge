#!/usr/bin/env bash
# 清理本地老 hook 与 setup 脚本 (plugin 接管)

set -euo pipefail

OLD_HOOK="$HOME/.claude/hooks/auto-link.sh"
OLD_SETUP="$HOME/.claude/scripts/setup-obsidian-link.sh"
SETTINGS="$HOME/.claude/settings.json"

cleaned=0

if [ -f "$OLD_HOOK" ]; then
    rm "$OLD_HOOK"
    echo "✓ removed $OLD_HOOK"
    cleaned=$((cleaned + 1))
fi

if [ -f "$OLD_SETUP" ]; then
    rm "$OLD_SETUP"
    echo "✓ removed $OLD_SETUP"
    cleaned=$((cleaned + 1))
fi

# 从 settings.json 移除 SessionStart hook 中所有 auto-link.sh 引用
if [ -f "$SETTINGS" ]; then
    tmp=$(mktemp)
    jq '
        if .hooks.SessionStart then
            .hooks.SessionStart |= (
                map(
                    .hooks |= map(select(.command | test("auto-link.sh") | not)) |
                    select((.hooks // []) | length > 0)
                )
            ) |
            if (.hooks.SessionStart | length) == 0 then
                del(.hooks.SessionStart)
            else . end
        else . end
    ' "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
    echo "✓ cleaned SessionStart hook in $SETTINGS"
    cleaned=$((cleaned + 1))
fi

echo ""
if [ $cleaned -eq 0 ]; then
    echo "无清理. 看起来没安装过本地 hook."
else
    echo "Migration 完成. plugin 接管 hooks 与 setup. 现有 Stop/Notification hook 未动."
fi
