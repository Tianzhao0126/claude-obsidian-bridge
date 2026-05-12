#!/usr/bin/env bash
# SessionStart hook
# 维度 A: cwd 对应 memory 未建 symlink 时自动建
# 维度 A: 项目级 CLAUDE.md 反向 symlink
# 维度 B: 写本次启动清单到 vault _sessions/

CLAUDE_PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
source "$CLAUDE_PLUGIN_ROOT/lib/config.sh"
source "$CLAUDE_PLUGIN_ROOT/lib/encode-path.sh"
source "$CLAUDE_PLUGIN_ROOT/lib/friendly-name.sh"

ob_load_config || exit 0

input=$(cat 2>/dev/null || echo '{}')
cwd=$(echo "$input" | jq -r '.cwd // empty')
session_id=$(echo "$input" | jq -r '.session_id // empty')

[ -z "$cwd" ] && exit 0
[ ! -d "$OB_VAULT_ROOT" ] && exit 0

memory_root="$OB_VAULT_ROOT/memory"
project_claudes="$OB_VAULT_ROOT/project-claudes"
mkdir -p "$memory_root" "$project_claudes"

# ===== 维度 A: memory symlink 自动接入 =====
encoded=$(ob_encode_path "$cwd")
project_dir="$HOME/.claude/projects/$encoded"
memory_path="$project_dir/memory"

if [ -L "$memory_path" ]; then
    # 已接入: 用 symlink target 反推 friendly
    friendly=$(basename "$(readlink "$memory_path")")
elif [ ! -e "$memory_path" ]; then
    # 新接入
    friendly=$(ob_friendly_name "$cwd" "$memory_root")
    target="$memory_root/$friendly"
    mkdir -p "$project_dir" "$target"
    ln -s "$target" "$memory_path"
else
    # memory_path 已是真实目录而非 symlink (异常状态)
    friendly=$(basename "$cwd")
fi

# ===== 项目级 CLAUDE.md 反向 symlink =====
project_claude="$cwd/CLAUDE.md"
if [ -f "$project_claude" ]; then
    name=$(basename "$cwd")
    link="$project_claudes/${name}.md"
    [ ! -e "$link" ] && ln -s "$project_claude" "$link"
fi

# ===== 维度 B: 启动加载清单 =====
if [ "$OB_SESSION_LOG_ENABLED" = "true" ] && [ -n "$session_id" ]; then
    log_dir="$OB_VAULT_ROOT/_sessions"
    mkdir -p "$log_dir"
    log_file="$log_dir/$(date +%F)_${session_id:0:8}.md"

    rules_list=""
    if [ -d "$OB_VAULT_ROOT/rules" ]; then
        rules_list=$(find "$OB_VAULT_ROOT/rules" -type f -name '*.md' 2>/dev/null | while read -r f; do
            rel=${f#$OB_VAULT_ROOT/}
            rel_nomd=${rel%.md}
            lines=$(wc -l < "$f" 2>/dev/null | tr -d ' ')
            echo "- [[$rel_nomd|$rel_nomd]] ($lines lines)"
        done)
    fi

    memory_index="memory/$friendly/MEMORY.md"
    memory_entries=0
    if [ -f "$OB_VAULT_ROOT/$memory_index" ]; then
        memory_entries=$(wc -l < "$OB_VAULT_ROOT/$memory_index" | tr -d ' ')
    fi

    local_skills=$(find "$OB_VAULT_ROOT/skills" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ' || echo "0")

    hooks_registered=$(jq -r '.hooks | keys[]?' "$HOME/.claude/settings.json" 2>/dev/null | sed 's/^/- /')

    cat > "$log_file" <<EOF
---
session_id: $session_id
date: $(date +%F)
cwd: $cwd
tags:
  - claude-session
---

# Session ${session_id:0:8} ($(date '+%F %T'))

**cwd:** \`$cwd\`
**Friendly project:** \`$friendly\`

## Rules 加载 (eager, Phase 4)
${rules_list:-- (vault 内无 rules)}

## Memory index (eager)
- [[$memory_index|$friendly/MEMORY]] ($memory_entries entries)

## Skills 可用 (lazy)
- 本地 vault: $local_skills 个
- plugin / marketplace skill: 见 system reminder 当前会话快照

## Hooks 注册 (settings.json)
${hooks_registered:-- (无)}
EOF

    # 清理过期日志
    find "$log_dir" -type f -name '*.md' -mtime "+$OB_SESSION_LOG_RETENTION" -delete 2>/dev/null || true
fi

exit 0
