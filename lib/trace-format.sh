#!/usr/bin/env bash
# 把 tool-trace.jsonl 转成 markdown (维度 C 的 plan 末尾写回)
# 用法: trace-format.sh <jsonl-file>  →  stdout

set -e
TRACE_FILE="${1:-}"
[ -z "$TRACE_FILE" ] && exit 0
[ ! -f "$TRACE_FILE" ] && exit 0

# 提取时间格式: 2026-05-12T10:23:01Z → 10:23:01
ob_extract_time() {
    echo "$1" | sed -E 's/.*T([0-9:]+)Z.*/\1/'
}

declare -a skills_lines memory_lines skill_lines plan_lines mermaid_lines

while IFS= read -r line; do
    tool=$(echo "$line" | jq -r '.tool')
    ts=$(echo "$line" | jq -r '.ts')
    time=$(ob_extract_time "$ts")

    case "$tool" in
        Skill)
            skill=$(echo "$line" | jq -r '.skill')
            skills_lines+=("- $time \`$skill\`")
            mermaid_name=$(echo "$skill" | tr ':/' '_')
            mermaid_lines+=("    $mermaid_name :done, $time, 1s")
            ;;
        Read)
            path=$(echo "$line" | jq -r '.path')
            rel=${path##*/Claude/}
            rel_nomd=${rel%.md}
            case "$path" in
                */memory/*) memory_lines+=("- [[../$rel_nomd|$rel_nomd]]") ;;
                */skills/*) skill_lines+=("- [[../$rel_nomd|$rel_nomd]]") ;;
                */plans/*)  plan_lines+=("- [[../$rel_nomd|$rel_nomd]]") ;;
            esac
            ;;
    esac
done < "$TRACE_FILE"

printf '\n---\n\n## 制作过程 (auto-generated)\n\n'
printf '> 由 claude-obsidian-bridge 在 session 结束时自动追加. 反映本 plan 形成时实际加载/调用的资源.\n\n'

printf '**Skills 调用 (按时间):**\n'
if [ ${#skills_lines[@]} -gt 0 ]; then
    printf '%s\n' "${skills_lines[@]}"
else
    printf -- '- (无)\n'
fi

printf '\n**Memory 主动读取:**\n'
if [ ${#memory_lines[@]} -gt 0 ]; then
    printf '%s\n' "${memory_lines[@]}" | sort -u
else
    printf -- '- (无)\n'
fi

printf '\n**Skills 全文加载:**\n'
if [ ${#skill_lines[@]} -gt 0 ]; then
    printf '%s\n' "${skill_lines[@]}" | sort -u
else
    printf -- '- (无)\n'
fi

printf '\n**Plans 引用:**\n'
if [ ${#plan_lines[@]} -gt 0 ]; then
    printf '%s\n' "${plan_lines[@]}" | sort -u
else
    printf -- '- (无)\n'
fi

printf '\n**Rules:** 全量 eager (Phase 4), 见 [[../docs/session-loading-flow]]\n'

if [ ${#mermaid_lines[@]} -gt 0 ]; then
    printf '\n```mermaid\ngantt\n    dateFormat HH:mm:ss\n    title plan 制作时间轴\n    section Skills\n'
    printf '%s\n' "${mermaid_lines[@]}"
    printf '```\n'
fi
