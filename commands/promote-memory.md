---
description: 把单条 memory 提级到 rules. 工具只机械搬运, Claude 负责抽象表述.
allowed-tools: Bash, Read, Edit
---

# /promote-memory <src-memory> <dst-rules> [--anchor <section>] [--dry-run]

把指定 memory companion 提级为 rules 中的条目.

## 参数

- `<src-memory>`: 相对 `Claude/memory/` 的路径 (e.g. `tscs/feedback_go_build.md`)
- `<dst-rules>`: 相对 `Claude/` 的路径 (e.g. `rules/golang/coding-style.md`)
- `--anchor <section>`: 在 dst 中找到该行 (字面匹配) 后插入, 例如 `--anchor "## Build"`. 不指定则文末追加.
- `--dry-run`: 仅 print diff, 不动文件

## 执行流程 (E1 半自动)

**关键设计:** 工具只做机械搬运 (改 rules + 删 memory + 改 MEMORY.md). 抽象表述由你 (Claude) 负责.

1. **读 src memory 内容**, 看是否含项目名/特定路径/会话 ID 等不适合放进通用 rules 的内容.

2. **如有项目特异内容**:
   - 先 `Edit` src 文件, 把内容抽象化 (移除项目名等)
   - 把改写预览给用户确认
   - 用户确认后才进入下一步

3. **建议 dry-run 一遍**:
   ```bash
   "$CLAUDE_PLUGIN_ROOT/lib/promote-impl.sh" <src> <dst> --dry-run
   ```
   把 diff 呈现给用户.

4. **正式执行**:
   ```bash
   "$CLAUDE_PLUGIN_ROOT/lib/promote-impl.sh" <src> <dst> [--anchor X]
   ```

5. **汇报结果**: 哪个 rules 文件被改, 删了什么, MEMORY.md 同步情况.

## 安全

- src 与 dst 必须都存在, 否则报错退出
- `--anchor` 找不到则报错, 不写
- `--dry-run` 模式不修改任何文件

## 提示

如果你不确定该提级到哪个 rules 文件, 先跑 `/scan-memory-duplicates` 看推荐目标.
