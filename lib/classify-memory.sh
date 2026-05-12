#!/usr/bin/env bash
# 维度 E 诊断: 扫所有 feedback/user 类型 memory 找重复对
# 输出 markdown 表格到 stdout, sorted by 相似度 desc

set -euo pipefail
CLAUDE_PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
source "$CLAUDE_PLUGIN_ROOT/lib/config.sh"

ob_load_config || { echo "ERROR: config 未配置, 跑 /obsidian-bridge-setup 先" >&2; exit 1; }

MEMORY_ROOT="$OB_VAULT_ROOT/memory"
[ -d "$MEMORY_ROOT" ] || { echo "ERROR: $MEMORY_ROOT 不存在" >&2; exit 1; }

THRESHOLD="${OB_SCAN_THRESHOLD:-0.30}"

ob_tokenize_filter() {
    python3 -c "
import sys, re
STOPWORDS = set('the and for that with this from when will should which what about have been are was its not into onto out off etc just very more less use using used user 已 是 的 在 也 等 与 跟 或 而 之 这 那 一些 任何 通过 不要 不是 应该 必须'.split())
tokens = set()
for line in sys.stdin:
    for t in re.findall(r'[\w\-]{3,}', line.lower(), re.UNICODE):
        t = t.strip('-_')
        if len(t) >= 3 and t not in STOPWORDS:
            tokens.add(t)
for t in sorted(tokens):
    print(t)
" 2>/dev/null
}

ob_jaccard() {
    local fa="$1" fb="$2"
    local inter=$(comm -12 "$fa" "$fb" | wc -l | tr -d ' ')
    local union=$(cat "$fa" "$fb" | sort -u | wc -l | tr -d ' ')
    [ "$union" -eq 0 ] && { echo "0.00"; return; }
    awk "BEGIN { printf \"%.2f\", $inter / $union }"
}

ob_recommend_rule() {
    local tokens="$1"
    case "$tokens" in
        *' go '*|*' golang '*|*' gofmt '*) echo "rules/golang/coding-style.md" ;;
        *' test '*|*' tdd '*|*' mock '*|*' coverage '*) echo "rules/common/testing.md" ;;
        *' commit '*|*' pr '*|*' workflow '*|*' branch '*) echo "rules/common/development-workflow.md" ;;
        *' security '*|*' auth '*|*' secret '*|*' xss '*|*' sql '*) echo "rules/common/security.md" ;;
        *' perform '*|*' optim '*|*' cache '*|*' latency '*) echo "rules/common/performance.md" ;;
        *' deploy '*|*' helm '*|*' k8s '*|*' config '*) echo "rules/common/development-workflow.md" ;;
        *' first '*|*' principle '*|*' assume '*) echo "rules/common/behavior.md" ;;
        *) echo "rules/common/?.md" ;;
    esac
}

# 收集所有 candidate file → temp dir 存 tokens
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

declare -a files

while IFS= read -r f; do
    [ -z "$f" ] && continue
    type=$(awk '/^---$/{c++;next} c==1 && /^type:/{sub(/^type: */,""); print; exit}' "$f" 2>/dev/null | tr -d ' "')
    case "$type" in
        feedback|user) ;;
        *) continue ;;
    esac

    desc=$(awk '/^---$/{c++;next} c==1 && /^description:/{sub(/^description: */,""); print; exit}' "$f" 2>/dev/null || true)
    body=$(awk '/^---$/{c++;next} c>=2{print}' "$f" 2>/dev/null | head -c 2000)

    token_file="$TMPDIR/$(echo "$f" | tr / _).tokens"
    echo "$desc $body" | ob_tokenize_filter > "$token_file"

    files+=("$f|$token_file|$type")
done < <(find "$MEMORY_ROOT" -mindepth 2 -maxdepth 2 -type f -name '*.md' ! -name 'MEMORY.md' 2>/dev/null)

n=${#files[@]}

if [ "$n" -lt 2 ]; then
    echo "memory feedback/user 候选不足 2 条 (找到 $n), 无可比较对."
    exit 0
fi

echo "| File A | File B | 相似度 | 推荐目标 |"
echo "|---|---|---|---|"

declare -a rows

for ((i=0; i<n; i++)); do
    for ((j=i+1; j<n; j++)); do
        IFS='|' read -r fa ta type_a <<< "${files[$i]}"
        IFS='|' read -r fb tb type_b <<< "${files[$j]}"

        # 不同项目才有提级意义 (同项目内重复另起一个流程)
        proj_a=$(basename "$(dirname "$fa")")
        proj_b=$(basename "$(dirname "$fb")")

        sim=$(ob_jaccard "$ta" "$tb")
        keep=$(awk "BEGIN { print ($sim >= $THRESHOLD) ? 1 : 0 }")
        [ "$keep" != "1" ] && continue

        # 拼 token 字符串供推荐用
        all_tokens=" $(cat "$ta" "$tb" | tr '\n' ' ') "
        rec=$(ob_recommend_rule "$all_tokens")

        rel_a=${fa#$MEMORY_ROOT/}
        rel_b=${fb#$MEMORY_ROOT/}
        rows+=("$sim|$rel_a|$rel_b|$rec|$proj_a vs $proj_b")
    done
done

if [ ${#rows[@]} -eq 0 ]; then
    echo "_(无重复对超过阈值 $THRESHOLD)_"
    exit 0
fi

printf '%s\n' "${rows[@]}" | sort -t'|' -k1,1 -nr | while IFS='|' read -r sim a b rec note; do
    printf "| \`%s\` | \`%s\` | %s | %s |\n" "$a" "$b" "$sim" "$rec"
done

echo ""
echo "_阈值 $THRESHOLD; ${#rows[@]} 对超阈值. 选好哪些提级后跑 \`/promote-memory <src> <dst-rules>\`._"
