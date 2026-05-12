---
description: 安装/配置 claude-obsidian-bridge — 指定 vault 与 work 路径, 完成迁移与建链
allowed-tools: Bash, Read
---

# /obsidian-bridge-setup [<vault-path>] [<work-path>]

把 Claude Code 的 memory/rules/skills 接入指定 Obsidian vault, 让人类能 see / review / 共同维护.

## 执行流程

1. **解析参数** `$ARGUMENTS`. 如果用户传入了 `<vault-path>` 与可选的 `<work-path>`, 直接用. 否则交互式询问:
   - "请提供 Obsidian vault 绝对路径? (e.g. /Users/x/Documents/MyVault)"
   - "请提供 work 根目录? 用于扫描项目级 CLAUDE.md (e.g. /Users/x/work, 可留空跳过)"

2. **执行 setup**:
   ```bash
   "$CLAUDE_PLUGIN_ROOT/lib/setup.sh" "<vault-path>" "<work-path>" "Claude"
   ```

3. **汇报 setup.sh 输出** — 每行以 `✓` 开头的是成功步骤, 以 `-` 开头的是 skip.

4. **提醒用户**:
   - 重启 Claude Code 让 SessionStart hook 生效
   - 如果之前手动装过老 `auto-link.sh`, 跑 `/obsidian-bridge-migrate` 清理

## Setup 做了什么 (供用户理解)

- 在 vault 内建 `Claude/{memory,plans,rules,skills,project-claudes,docs,_sessions}/`
- 物理迁移 `~/.claude/{rules,skills,CLAUDE.md}` 到 vault, 原位置变成 symlink
- 为现存 `~/.claude/projects/<encoded>/memory` 建 symlink 到 vault
- 在 vault 内建 `Claude/plans` 反向 symlink → `~/.claude/plans`
- 扫描 work-path 下 CLAUDE.md 建反向 symlink
- 写 plugin config 到 `~/.claude/plugins/claude-obsidian-bridge/config.json`
- 自动修复 skills 目录里因为路径相对 symlink 失效的链接

## 幂等性

重跑 setup 安全 — 已迁移过的会 skip, 不破坏现有结构.

## 错误处理

- vault 路径不存在: 报错并退出
- 关键 jq/find 不可用: 报错并提示安装
