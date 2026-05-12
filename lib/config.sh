#!/usr/bin/env bash
# 读 plugin config.json 并 export 字段
# 用法: source "$CLAUDE_PLUGIN_ROOT/lib/config.sh" && ob_load_config || exit 0

ob_config_file() {
    echo "$HOME/.claude/plugins/claude-obsidian-bridge/config.json"
}

ob_load_config() {
    local cfg
    cfg=$(ob_config_file)

    [ -f "$cfg" ] || return 1

    OB_VAULT_PATH=$(jq -r '.vault_path // empty' "$cfg")
    [ -z "$OB_VAULT_PATH" ] && return 1

    OB_VAULT_SUBDIR=$(jq -r '.vault_subdir // "Claude"' "$cfg")
    OB_TRACE_WRITEBACK=$(jq -r '.trace_writeback // "inline"' "$cfg")
    OB_SESSION_LOG_ENABLED=$(jq -r '.session_log_enabled // true' "$cfg")
    OB_SESSION_LOG_RETENTION=$(jq -r '.session_log_retention_days // 30' "$cfg")
    OB_PROMOTE_DRY_RUN_DEFAULT=$(jq -r '.memory_promote_dry_run_default // false' "$cfg")
    OB_VAULT_ROOT="$OB_VAULT_PATH/$OB_VAULT_SUBDIR"

    return 0
}

ob_scan_paths() {
    local cfg
    cfg=$(ob_config_file)
    jq -r '.scan_paths_for_project_claudemd[]?' "$cfg"
}
