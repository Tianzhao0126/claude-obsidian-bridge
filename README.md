# claude-obsidian-bridge

把 Claude Code 的 memory / rules / skills / plans / CLAUDE.md **白盒化**到你的 Obsidian vault, 让人类能 see / review / 共同维护 AI agent 的知识与决策.

## 为什么

AI agent (Claude Code) 默认是**黑盒**:
- 每次 session 加载了什么? 不知道
- 制作 plan 时参考了哪些 memory/skill? 不可追溯
- 积累的 memory/rules 在哪里? 散在 `~/.claude/` 隐藏目录
- memory 怎么沉淀为 rules? 没有工具

接入 Obsidian 后:
- 所有知识资产在 vault 内, Obsidian backlink/tag/search/Bases 即开即用
- 每次 session 自动写"启动加载清单"到 vault
- 每个 plan 末尾自动追加"制作过程 trace" (Mermaid 时间轴 + 资源清单)
- 跨项目重复的 memory 一键扫描 + 半自动提级到 rules

## 安装

```
/plugin install Tianzhao0126/claude-obsidian-bridge
/obsidian-bridge-setup <vault-path> [<work-path>]
```

不传参数则交互式询问. 重启 Claude Code 后 hook 生效.

## 4 个核心能力

### 1. 知识资产 vault 透传 (维度 A)

`~/.claude/{rules,skills,CLAUDE.md}` 物理迁移到 vault, 原位置变 symlink. `~/.claude/projects/<encoded>/memory/` 同理. plans 反过来 — vault 内放反向 symlink 指向 `~/.claude/plans/`. **单向 symlink, 永远不双拷贝**.

### 2. 启动加载清单 (维度 B)

每个 session 启动后, vault 内自动写入 `Claude/_sessions/<date>_<id>.md`:
- 本次加载的 rules 列表 + 行数
- memory index 路径与 entries 数
- 可用 skills 数量
- hooks 注册情况

30 天自动清理.

### 3. Plan 决策追溯 (维度 C/D)

写 plan 时照常写. 退出会话后, plan 末尾自动追加:

````markdown
## 制作过程 (auto-generated)

**Skills 调用 (按时间):**
- 10:00:00 `superpowers:brainstorming`

**Memory 主动读取:**
- [[../memory/data-integrator/MEMORY|data-integrator/MEMORY]]

**Rules:** 全量 eager (Phase 4)

```mermaid
gantt
    dateFormat HH:mm:ss
    section Skills
    brainstorming :done, 10:00:00, 1s
```
````

Obsidian 里 mermaid 渲染为时间轴, wikilink 可跳转.

### 4. Memory → Rules 提级 (维度 E, 半自动)

```
/scan-memory-duplicates
```

输出候选表:

| File A | File B | 相似度 | 推荐目标 |
|---|---|---|---|
| `tscs/feedback_go_build` | `iam/feedback_go_lint` | 0.62 | rules/golang/coding-style.md |

选好对后:
```
/promote-memory <src> <dst-rules> --dry-run    # 先 dry-run 看 diff
/promote-memory <src> <dst-rules>              # 实际执行
```

工具只机械搬运 (改 rules + 删 memory + 改 MEMORY.md), **抽象表述由 Claude 在调用前完成**.

## 命令清单

| 命令 | 用途 |
|---|---|
| `/obsidian-bridge-setup` | 首次安装/重新配置, 指定 vault 与 work |
| `/obsidian-bridge-migrate` | 从手动安装的 auto-link.sh 迁移到 plugin |
| `/scan-memory-duplicates` | 扫所有 feedback/user 类型 memory 找跨项目重复 |
| `/promote-memory` | 把单条 memory 提级到指定 rules |

## 配置

`~/.claude/plugins/claude-obsidian-bridge/config.json` (由 setup 命令生成):

```json
{
  "vault_path": "/Users/zhaotian/work/note/work",
  "vault_subdir": "Claude",
  "scan_paths_for_project_claudemd": ["/Users/zhaotian/work"],
  "trace_writeback": "inline",
  "session_log_enabled": true,
  "session_log_retention_days": 30,
  "memory_promote_dry_run_default": false
}
```

完整字段说明见 [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md#configuration).

## 设计原则

**单一真相源 + 单向 symlink, 永远不双拷贝.** 详情 [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## 平台

v1.0 仅 macOS 测试通过. Linux 适配在 v1.1 (`date` / `find` / `stat` 等 GNU vs BSD 差异).

## License

MIT
