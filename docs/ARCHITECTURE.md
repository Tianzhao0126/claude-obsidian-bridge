# Architecture

## 设计原则

**单一真相源 + 单向 symlink, 永远不双拷贝, 永远不写双向同步 hook.**

- memory / rules / skills / CLAUDE.md 真实文件物理在 vault, Claude 端通过 symlink 透传
- plans 反之: 文件物理在 `~/.claude/plans/` (Claude Code 默认写入位置), vault 内放反向 symlink

**Wiki 是 LLM-owned, 人类 review 不直接 patch.** 沿用 [Karpathy LLM Wiki](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f) 的契约: agent 的知识资产 (memory / rules / skills / CLAUDE.md) 由 agent 自身维护, 人类负责 read / nav / 指出问题, 而非手动编辑. 维度 E (memory → rules 提级) 是这个契约的体现 — 工具机械搬运, 语义抽象由 LLM 自己完成.

## 6 个白盒化维度

| 维度 | 含义 | Karpathy 类比 (含 caveat) | 实现 | 状态 |
|---|---|---|---|---|
| **A** 知识资产 | memory/rules/skills/CLAUDE.md | 让 wiki + schema 从隐藏目录走到 vault 前台 — 仅 file plumbing, **非** Karpathy 语义级 ingest | symlink 透传 | v1.0 ✅ |
| **B** 启动加载清单 | 本次 session 实际加载了什么 | log.md 的局部视图 (一文件一 session, **不是** 单一 append-only md log) | `auto-link.sh` 在 `_sessions/` 写每次启动摘要 | v1.0 ✅ |
| **C** 决策过程 | plan 制作时引用了哪些 memory/skill | query trace 的简化形态 — 直接嵌 plan 末尾, 不是 query 答案回写为新 page | `trace-tool.sh` 收集 + `finalize-plan.sh` 写回 | v1.0 ✅ |
| **D** 工具流水 | session 内每次工具调用 | tool-level 时间线 (jsonl 非 md, 非 Karpathy log.md 风格) | `~/.claude/sessions/<id>/.tool-trace.jsonl` | v1.0 ✅ |
| **E** 知识演化 | memory → rules 提级 | lint pass 中"找重复 + 抽象提升"一项, **不含** 矛盾 / orphan / stale / cross-ref 检测 | `/scan-memory-duplicates` + `/promote-memory` | v1.0 ✅ |
| **F** 规则触发归因 | 哪条 rule 对这次输出起作用 | (Karpathy 未覆盖, agent-side 特有) | LLM 自报 + token 归因 | v2 探索 |

## Hook 数据流

```
SessionStart  (auto-link.sh)
    ├─ 维度 A: cwd 对应 memory symlink (若未建)
    ├─ 项目级 CLAUDE.md 反向 symlink (若 cwd 含 CLAUDE.md)
    └─ 维度 B: 启动清单到 _sessions/<date>_<id-prefix>.md

PostToolUse  (trace-tool.sh, 每次工具调用)
    └─ append 一行 jsonl 到 ~/.claude/sessions/<id>/.tool-trace.jsonl
        - Skill 调用 (始终记)
        - Read 路径含 /memory|rules|skills|plans/ (才记)
        - Write/Edit 路径含 /plans/ (才记)

Stop  (finalize-plan.sh, 会话结束)
    └─ 若本 session 含 Write 到 /plans/, 把 trace 写回 plan 末尾
        - inline 模式 (默认): append "## 制作过程" 到 plan 末尾
        - sidecar 模式: 写 <plan>.trace.md 旁边文件
        - off 模式: 不写
```

## Configuration

`~/.claude/plugins/claude-obsidian-bridge/config.json`:

| 字段 | 必填 | 默认 | 说明 |
|---|---|---|---|
| `vault_path` | ✅ | — | Obsidian vault 绝对路径 |
| `vault_subdir` | ❌ | `"Claude"` | vault 内子目录名 (避开 `.claude` 因 Obsidian 默认隐藏 dotfolder) |
| `scan_paths_for_project_claudemd` | ✅ | — | 字符串数组, 扫项目级 CLAUDE.md 的路径, 深度 3 |
| `trace_writeback` | ❌ | `"inline"` | `"inline"` / `"sidecar"` / `"off"` |
| `session_log_enabled` | ❌ | `true` | 是否写启动清单 |
| `session_log_retention_days` | ❌ | `30` | 启动清单保留天数 |
| `memory_promote_dry_run_default` | ❌ | `false` | `/promote-memory` 默认是否 dry-run |

## Vault 目录布局

```
<vault>/<vault_subdir>/                  默认 Claude/ — agent wiki 根目录
├── CLAUDE.md                           schema 层 — 全局指令 (Claude 端 ~/.claude/CLAUDE.md → 此)
├── memory/                              wiki 层 — agent 各项目经验沉淀
│   └── <friendly>/MEMORY.md + *.md     MEMORY.md ≈ Karpathy index.md (各项目自己的 entry 索引)
├── plans                                symlink → ~/.claude/plans (LLM 工作产物归档)
├── rules/                               wiki 层 — 跨项目通用约束
│   ├── common/*.md
│   └── <lang>/*.md
├── skills/                              wiki 层 — 可复用能力
│   └── <skill-name>/SKILL.md + ...
├── project-claudes/                     schema 层补充 — 各仓库 CLAUDE.md 的反向 symlink
│   └── <project-name>.md → /path/to/repo/CLAUDE.md
├── docs/                                项目自身文档
└── _sessions/                           ≈ Karpathy log.md (每次 session 启动一条, 30 天清理)
```

## Symlink 方向矩阵

| 资产 | 真实文件位置 | symlink 在哪一侧 | 方向 |
|---|---|---|---|
| Memory | vault | Claude 端 (`~/.claude/projects/<encoded>/memory`) | Claude → vault |
| Plans | `~/.claude/plans/` | vault 端 (`<vault>/Claude/plans`) | vault → Claude |
| Rules | vault | Claude 端 (`~/.claude/rules`) | Claude → vault |
| Skills | vault | Claude 端 (`~/.claude/skills`) | Claude → vault |
| 全局 CLAUDE.md | vault | Claude 端 (`~/.claude/CLAUDE.md`) | Claude → vault |
| 项目级 CLAUDE.md | 各项目仓库 | vault 端 (`<vault>/Claude/project-claudes/<name>.md`) | vault → repo |

## 命名映射 (cwd → friendly name)

默认取 cwd 末段 (`basename`). 冲突 (vault 内同名 friendly 目录已存在且非本 cwd) 时附加上一级目录名, 例如 `~/work/foo` 与 `~/personal/foo` 冲突, 第二个变 `personal-foo`.

## 维度 E 算法 (memory 重复检测)

`/scan-memory-duplicates`:

1. 枚举 `memory/<project>/*.md` (跳过 `MEMORY.md`)
2. 解析 frontmatter, 仅留 `type: feedback` 与 `type: user`
3. 用 Python3 + regex `[\w\-]{3,}` 提取 token (支持中文 UTF-8), 过停用词
4. 两两 Jaccard 相似度, 阈值默认 0.30 (`OB_SCAN_THRESHOLD` 环境变量覆盖)
5. 推荐目标 rule 按 token 关键词启发式 (go/test/commit/security/perform/deploy/principle 等)
6. 输出 markdown 表格, sorted by similarity desc

`/promote-memory`:

工具机械操作: 改 rules + 删 memory + 改 MEMORY.md 索引. **不做语义抽象** — Claude 在调用前应该 Edit src 文件把项目特异部分抽象化. 这是 "E1 半自动" 设计.

## Tool trace 路径过滤

PostToolUse hook 仅记录"对决策有信息量"的 tool 调用. 不记录:
- Bash 命令 (执行细节, 不是决策依据)
- TaskCreate/TaskUpdate (进度跟踪, 不是知识)
- 任意路径的 Read (避免噪音, 仅记 /memory|rules|skills|plans/)
- Glob/Grep (搜索行为, 非显式知识)

记录的:
- Skill 调用 (决策性, 反映 Claude 选择了哪个能力)
- Read /memory|rules|skills|plans/ (主动加载知识)
- Write/Edit /plans/ (产出 plan)

## 与 Karpathy LLM Wiki 的 gap

ARCHITECTURE 引入了 Karpathy 词汇, 但 v1.0 实现并未完整 cover Karpathy pattern. 差异:

1. **没有单一 `log.md`** — `_sessions/` 一文件一 session. 跨 session 时间线视图缺失. Karpathy 那种"统一前缀 + grep tail"的能力本项目不具备.
2. **没有完整 lint** — 维度 E 仅做跨项目 token Jaccard 相似度. 矛盾对检测 / orphan page / stale claim / 缺失 cross-ref / data gap 建议都未实现.
3. **没有 ingest 流水** — Karpathy 的 ingest = LLM 读源 + 抽取实体 + 整合到 entity / concept 页 + 更新 index + append log. 本项目维度 A 只是 file plumbing (symlink). 实际写 memory 由 Claude 在 session 内手动完成, plugin 不参与.
4. **没有 query 入口** — Karpathy 强调"好 query 的答案应该 file 回 wiki 成新 page". 本项目无 query / writeback 工具.
5. **没有 vault 内 schema 文档** — 缺一份描述"如何维护这份 agent wiki"的协议. memory format 由 Claude 系统级 prompt 隐式定义, 不在 vault 里显式.

v2 roadmap 建议优先补:
- 单一 `_log.md` 汇总 (跨 session 时间线, Karpathy 风格前缀)
- lint 维度扩展 (至少 "orphan 页 + missing cross-ref")
- 一份 vault 内 schema 文档 (描述本项目自己的 wiki maintenance protocol)

## 风险与边界

1. **Hook stdin schema 假设** — `session_id` / `tool_name` / `tool_input.file_path` / `tool_input.skill`. 字段格式由 Claude Code 决定, schema 变更需适配
2. **Stop hook 在 Ctrl-C 不可靠** — 如发现 plan trace 没写回, 手工跑 `$CLAUDE_PLUGIN_ROOT/hooks/finalize-plan.sh <<< '{"session_id":"..."}'` 补救
3. **PostToolUse 频率高** — 单次 ~5ms 开销, session 全程通常 < 300ms 总开销, 不显著
4. **多 vault 不支持 v1** — v2 计划支持 per-project 路由
5. **维度 F (rule 归因) 不在本期** — 现阶段任何"哪条 rule 起作用"都是猜测
6. **跨平台** — v1 macOS only (BSD `find`/`date`/`stat`). Linux 用户得改 `find -mtime` 与 `stat` 差异

## License

MIT
