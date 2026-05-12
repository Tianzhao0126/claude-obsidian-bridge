#!/usr/bin/env bash
# 单条 memory 提级到 rules
# 用法: promote-impl.sh <src-memory> <dst-rules> [--anchor <section>] [--dry-run]
# src-memory: 相对 vault/Claude/memory/ 或绝对路径
# dst-rules: 相对 vault/Claude/ 或绝对路径
# --anchor: 在 dst 中查找该行 (字面匹配, e.g. "## Build") 后插入
# --dry-run: 仅 print diff, 不动文件

set -euo pipefail
CLAUDE_PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
source "$CLAUDE_PLUGIN_ROOT/lib/config.sh"

ob_load_config || { echo "ERROR: config 未配置" >&2; exit 1; }

SRC=""
DST=""
ANCHOR=""
DRY_RUN=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --anchor) ANCHOR="$2"; shift 2 ;;
        --dry-run) DRY_RUN=1; shift ;;
        --)        shift ;;
        -*)        echo "Unknown option: $1" >&2; exit 1 ;;
        *)
            if [ -z "$SRC" ]; then SRC="$1"
            elif [ -z "$DST" ]; then DST="$1"
            else echo "Too many args: $1" >&2; exit 1
            fi
            shift
            ;;
    esac
done

if [ -z "$SRC" ] || [ -z "$DST" ]; then
    echo "Usage: promote-memory <src-mem> <dst-rules> [--anchor SECTION] [--dry-run]" >&2
    exit 1
fi

src_abs="$SRC"
[[ "$src_abs" != /* ]] && src_abs="$OB_VAULT_ROOT/memory/$SRC"
dst_abs="$DST"
[[ "$dst_abs" != /* ]] && dst_abs="$OB_VAULT_ROOT/$DST"

[ -f "$src_abs" ] || { echo "ERROR: src $src_abs 不存在" >&2; exit 1; }
[ -f "$dst_abs" ] || { echo "ERROR: dst $dst_abs 不存在" >&2; exit 1; }

# 提取 body (skip frontmatter)
body=$(awk '/^---$/{c++;next} c>=2{print}' "$src_abs")
[ -z "$body" ] && { echo "ERROR: src $src_abs body 为空" >&2; exit 1; }

project_dir=$(dirname "$src_abs")
memory_index="$project_dir/MEMORY.md"
src_name=$(basename "$src_abs")
[ ! -f "$memory_index" ] && memory_index=""

if [ "${OB_PROMOTE_DRY_RUN_DEFAULT:-false}" = "true" ] && [ -z "$DRY_RUN" ]; then
    DRY_RUN=1
fi

if [ -n "$DRY_RUN" ]; then
    echo "=== DRY RUN ==="
    echo ""
    echo "[1] 将追加到: $dst_abs"
    if [ -n "$ANCHOR" ]; then
        echo "    (anchor: '$ANCHOR' 后)"
    else
        echo "    (文末)"
    fi
    echo "----"
    echo "$body"
    echo "----"
    echo ""
    echo "[2] 将删除: $src_abs"
    if [ -n "$memory_index" ]; then
        echo "[3] 将从 $memory_index 移除引用 '$src_name' 的行"
    fi
    exit 0
fi

# 实际执行
if [ -n "$ANCHOR" ]; then
    if ! grep -qF "$ANCHOR" "$dst_abs"; then
        echo "ERROR: anchor '$ANCHOR' 在 $dst_abs 中未找到" >&2
        exit 1
    fi
    tmp=$(mktemp)
    awk -v anchor="$ANCHOR" -v body="$body" '
        $0 == anchor {
            print
            print ""
            print body
            next
        }
        { print }
    ' "$dst_abs" > "$tmp"
    mv "$tmp" "$dst_abs"
else
    printf '\n%s\n' "$body" >> "$dst_abs"
fi
echo "✓ 追加到 $dst_abs"

rm "$src_abs"
echo "✓ 删除 $src_abs"

if [ -n "$memory_index" ] && [ -f "$memory_index" ]; then
    tmp=$(mktemp)
    grep -v "$src_name" "$memory_index" > "$tmp" || true
    mv "$tmp" "$memory_index"
    echo "✓ MEMORY.md 同步: $memory_index"
fi
