---
description: 清理本机老 hook 与 setup 脚本, 让 plugin 接管 (从手动安装迁移到 plugin)
allowed-tools: Bash, Read
---

# /obsidian-bridge-migrate

如果你之前手动装过 `~/.claude/hooks/auto-link.sh` 或 `~/.claude/scripts/setup-obsidian-link.sh`, 跑这个命令把它们清掉, 让 plugin 接管.

## 执行流程

1. 执行迁移脚本:
   ```bash
   "$CLAUDE_PLUGIN_ROOT/lib/migrate.sh"
   ```

2. 汇报清理了什么.

## 做了什么

- 删 `~/.claude/hooks/auto-link.sh` (如存在)
- 删 `~/.claude/scripts/setup-obsidian-link.sh` (如存在)
- 从 `~/.claude/settings.json` 的 `hooks.SessionStart` 中移除引用 `auto-link.sh` 的 hook 条目
- **保留**用户其他 hook (Stop/Notification 的 terminal-notifier 等)

## 安全性

只删上面 2 个特定文件 + 1 个特定 hook 条目, 不动其他.
