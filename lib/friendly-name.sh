#!/usr/bin/env bash
# path → friendly name (取末段, 冲突时附加上一级)
# 用法: ob_friendly_name <cwd> <memory_root>
# 副作用: 检测 memory_root/<friendly> 已存在且不是指向本 cwd 的 symlink 时, 附加上级名

ob_friendly_name() {
    local path="$1"
    local memory_root="$2"
    local cwd_encoded
    local friendly

    friendly=$(basename "$path")

    if [ -e "$memory_root/$friendly" ]; then
        local existing
        existing=$(readlink "$memory_root/$friendly" 2>/dev/null || true)
        if [ -z "$existing" ] || [ "$existing" != "$path" ]; then
            local parent
            parent=$(basename "$(dirname "$path")")
            friendly="${parent}-${friendly}"
        fi
    fi

    echo "$friendly"
}
