---
description: 扫所有 feedback/user 类型 memory 找重复对, 输出候选提级表
allowed-tools: Bash
---

# /scan-memory-duplicates

扫描所有 `feedback` 与 `user` 类型 memory companion 文件, 用 token Jaccard 相似度找跨项目的重复或近似对.

## 执行流程

1. 跑:
   ```bash
   "$CLAUDE_PLUGIN_ROOT/lib/classify-memory.sh"
   ```

2. 把输出的 markdown 表格直接呈现给用户. 列含义:
   - **File A / B**: 两条 memory 路径 (相对 `Claude/memory/`)
   - **相似度**: Jaccard 系数 (0-1, 越高越像)
   - **推荐目标**: 启发式建议的 rules 文件, 仅供参考

3. 建议用户:
   - 看相似度 ≥ 0.5 的对, 大概率值得提级
   - 0.3-0.5 的对需要人工 review 内容
   - 选好对后, 跑 `/promote-memory <src> <dst-rules>` 实际操作

4. 如果表为空 (所有对低于阈值), 告诉用户当前 memory 没有显著重复, 不必提级.

## 阈值调节

默认阈值 0.30. 想调:
```bash
OB_SCAN_THRESHOLD=0.50 "$CLAUDE_PLUGIN_ROOT/lib/classify-memory.sh"
```
