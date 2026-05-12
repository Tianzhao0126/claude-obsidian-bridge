#!/usr/bin/env bash
# cwd → Claude Code encoded project name
# 用法: ob_encode_path /Users/x/work/foo  →  -Users-x-work-foo

ob_encode_path() {
    echo "$1" | sed 's|/|-|g'
}
