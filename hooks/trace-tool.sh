#!/usr/bin/env bash
# PostToolUse hook: 记录关心的工具调用到 .tool-trace.jsonl
# 高频路径, 保持极简 + 静默失败

input=$(cat 2>/dev/null || echo '{}')
session_id=$(echo "$input" | jq -r '.session_id // empty' 2>/dev/null)
tool=$(echo "$input" | jq -r '.tool_name // empty' 2>/dev/null)

[ -z "$session_id" ] && exit 0
[ -z "$tool" ] && exit 0

trace_file="$HOME/.claude/sessions/$session_id/.tool-trace.jsonl"
mkdir -p "$(dirname "$trace_file")"

ts=$(date -u +%FT%TZ)

case "$tool" in
    Skill)
        skill=$(echo "$input" | jq -r '.tool_input.skill // empty' 2>/dev/null)
        [ -n "$skill" ] && printf '{"ts":"%s","tool":"Skill","skill":"%s"}\n' "$ts" "$skill" >> "$trace_file"
        ;;
    Read)
        path=$(echo "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
        if [ -n "$path" ]; then
            if [[ "$path" == */memory/* ]] || [[ "$path" == */rules/* ]] || [[ "$path" == */skills/* ]] || [[ "$path" == */plans/* ]]; then
                printf '{"ts":"%s","tool":"Read","path":"%s"}\n' "$ts" "$path" >> "$trace_file"
            fi
        fi
        ;;
    Write|Edit)
        path=$(echo "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
        if [ -n "$path" ] && [[ "$path" == */.claude/plans/* ]]; then
            printf '{"ts":"%s","tool":"%s","path":"%s"}\n' "$ts" "$tool" "$path" >> "$trace_file"
        fi
        ;;
esac

exit 0
