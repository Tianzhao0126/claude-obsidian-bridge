#!/usr/bin/env bash
# Stop hook: 检测本 session 是否 Write 到 plans/, 是则把 trace 写回 plan 末尾

CLAUDE_PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
source "$CLAUDE_PLUGIN_ROOT/lib/config.sh"

ob_load_config || exit 0

input=$(cat 2>/dev/null || echo '{}')
session_id=$(echo "$input" | jq -r '.session_id // empty')
[ -z "$session_id" ] && exit 0

trace_file="$HOME/.claude/sessions/$session_id/.tool-trace.jsonl"
[ ! -f "$trace_file" ] && exit 0

[ "$OB_TRACE_WRITEBACK" = "off" ] && exit 0

plans=$(jq -r 'select((.tool=="Write" or .tool=="Edit") and (.path | test("/plans/"))) | .path' "$trace_file" 2>/dev/null | sort -u)
[ -z "$plans" ] && exit 0

trace_md=$("$CLAUDE_PLUGIN_ROOT/lib/trace-format.sh" "$trace_file")
[ -z "$trace_md" ] && exit 0

while IFS= read -r plan; do
    [ -z "$plan" ] && continue
    [ ! -f "$plan" ] && continue
    grep -q "^## 制作过程" "$plan" && continue

    if [ "$OB_TRACE_WRITEBACK" = "sidecar" ]; then
        echo "$trace_md" > "${plan%.md}.trace.md"
    else
        echo "$trace_md" >> "$plan"
    fi
done <<< "$plans"

exit 0
