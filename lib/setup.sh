#!/usr/bin/env bash
# 用法: setup.sh <vault-path> [<work-path>] [<vault-subdir>]

set -euo pipefail

VAULT_PATH="${1:-}"
WORK_PATH="${2:-}"
VAULT_SUBDIR="${3:-Claude}"

if [ -z "$VAULT_PATH" ]; then
    echo "Usage: setup.sh <vault-path> [<work-path>] [<vault-subdir>]" >&2
    exit 1
fi

if [ ! -d "$VAULT_PATH" ]; then
    echo "ERROR: vault $VAULT_PATH 不存在" >&2
    exit 1
fi

# 1. 写 config.json
config_dir="$HOME/.claude/plugins/claude-obsidian-bridge"
config_file="$config_dir/config.json"
mkdir -p "$config_dir"

scan_paths_json="[]"
[ -n "$WORK_PATH" ] && scan_paths_json="[\"$WORK_PATH\"]"

jq -n \
    --arg vault "$VAULT_PATH" \
    --arg subdir "$VAULT_SUBDIR" \
    --argjson paths "$scan_paths_json" \
    '{
        vault_path: $vault,
        vault_subdir: $subdir,
        scan_paths_for_project_claudemd: $paths,
        trace_writeback: "inline",
        session_log_enabled: true,
        session_log_retention_days: 30,
        memory_promote_dry_run_default: false
    }' > "$config_file"

echo "✓ config 写入 $config_file"

# 2. vault 目录骨架
VAULT_ROOT="$VAULT_PATH/$VAULT_SUBDIR"
mkdir -p "$VAULT_ROOT/memory" "$VAULT_ROOT/project-claudes" "$VAULT_ROOT/docs" "$VAULT_ROOT/_sessions"
echo "✓ vault 目录骨架: $VAULT_ROOT"

# 3. rules 迁移
rules_src="$HOME/.claude/rules"
rules_dst="$VAULT_ROOT/rules"
if [ -L "$rules_src" ]; then
    echo "- rules: already linked, skip"
elif [ -d "$rules_src" ] && [ ! -e "$rules_dst" ]; then
    mv "$rules_src" "$rules_dst"
    ln -s "$rules_dst" "$rules_src"
    echo "✓ rules: migrated"
elif [ ! -e "$rules_src" ] && [ ! -e "$rules_dst" ]; then
    mkdir -p "$rules_dst"
    ln -s "$rules_dst" "$rules_src"
    echo "✓ rules: 创建空目录 + link"
else
    echo "- rules: skip (src/dst 状态不符合迁移条件)"
fi

# 4. skills 迁移
skills_src="$HOME/.claude/skills"
skills_dst="$VAULT_ROOT/skills"
if [ -L "$skills_src" ]; then
    echo "- skills: already linked, skip"
elif [ -d "$skills_src" ] && [ ! -e "$skills_dst" ]; then
    mv "$skills_src" "$skills_dst"
    ln -s "$skills_dst" "$skills_src"
    # 修复迁移后相对 symlink 失效问题
    find "$skills_dst" -maxdepth 1 -type l 2>/dev/null | while read -r broken; do
        if [ ! -e "$broken" ]; then
            name=$(basename "$broken")
            for candidate in "$HOME/.agents/skills/$name" "$HOME/.claude/agents/skills/$name"; do
                if [ -d "$candidate" ]; then
                    rm "$broken"
                    ln -s "$candidate" "$broken"
                    echo "  fixed dangling skill link: $name → $candidate"
                    break
                fi
            done
        fi
    done
    echo "✓ skills: migrated"
elif [ ! -e "$skills_src" ] && [ ! -e "$skills_dst" ]; then
    mkdir -p "$skills_dst"
    ln -s "$skills_dst" "$skills_src"
    echo "✓ skills: 创建空目录 + link"
else
    echo "- skills: skip (src/dst 状态不符合迁移条件)"
fi

# 5. 全局 CLAUDE.md
claude_md_src="$HOME/.claude/CLAUDE.md"
claude_md_dst="$VAULT_ROOT/CLAUDE.md"
if [ ! -e "$claude_md_dst" ]; then
    cat > "$claude_md_dst" <<'EOF'
# Claude 全局指令

> 这里是写给 Claude 的全局指令 (跨所有项目). 在此添加你希望 Claude 在任何会话都遵循的偏好/规则.
> 项目级指令请放在各仓库的 `CLAUDE.md`, 它们会出现在 `Claude/project-claudes/` 集中页.
EOF
    echo "✓ CLAUDE.md: skeleton created"
fi
if [ -L "$claude_md_src" ]; then
    echo "- CLAUDE.md: already linked"
elif [ ! -e "$claude_md_src" ]; then
    ln -s "$claude_md_dst" "$claude_md_src"
    echo "✓ CLAUDE.md: linked"
else
    echo "- CLAUDE.md: 已存在为真实文件, 跳过 link (手动决定是否替换)"
fi

# 6. plans 反向 symlink
plans_link="$VAULT_ROOT/plans"
if [ ! -e "$plans_link" ]; then
    mkdir -p "$HOME/.claude/plans"
    ln -s "$HOME/.claude/plans" "$plans_link"
    echo "✓ plans: linked vault → ~/.claude/plans"
else
    echo "- plans: link 已存在"
fi

# 7. 现存 memory 迁移
migrated_memory=0
for encoded_dir in "$HOME"/.claude/projects/*/; do
    [ -d "$encoded_dir" ] || continue
    encoded=$(basename "$encoded_dir")
    mem="${encoded_dir%/}/memory"

    [ -L "$mem" ] && continue
    [ ! -d "$mem" ] && continue

    # decode: - → /
    path="${encoded//-//}"
    [[ "$path" != /* ]] && continue

    friendly=$(basename "$path")
    [ -z "$friendly" ] && continue

    dst="$VAULT_ROOT/memory/$friendly"
    if [ -e "$dst" ]; then
        parent=$(basename "$(dirname "$path")")
        friendly="${parent}-${friendly}"
        dst="$VAULT_ROOT/memory/$friendly"
    fi

    mkdir -p "$dst"
    find "$mem" -mindepth 1 -maxdepth 1 -exec mv {} "$dst"/ \;
    rmdir "$mem"
    ln -s "$dst" "$mem"
    echo "  memory $friendly: migrated"
    migrated_memory=$((migrated_memory + 1))
done
echo "✓ memory: 迁移 $migrated_memory 个项目"

# 8. 项目级 CLAUDE.md
if [ -n "$WORK_PATH" ] && [ -d "$WORK_PATH" ]; then
    found=0
    while IFS= read -r repo; do
        [ -z "$repo" ] && continue
        repo_dir=$(dirname "$repo")
        name=$(basename "$repo_dir")
        link="$VAULT_ROOT/project-claudes/${name}.md"
        [ -e "$link" ] && continue
        ln -s "$repo" "$link"
        found=$((found + 1))
    done < <(find "$WORK_PATH" -maxdepth 3 -type f -name CLAUDE.md 2>/dev/null)
    echo "✓ project-claudes: linked $found"
fi

echo ""
echo "Setup 完成! 重启 Claude Code 让 SessionStart hook 生效."
echo "如果之前装过本地 auto-link.sh, 跑 /obsidian-bridge-migrate 清理."
