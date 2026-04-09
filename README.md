# paipai-cli

基于 bun 的 AI Skill CLI 框架 — 插件化、跨平台，每个业务 Skill 独立目录。

**GitHub:** https://github.com/Sun518-ai/paipai-cli

## 安装

```bash
git clone https://github.com/Sun518-ai/paipai-cli.git
cd paipai-cli
bun install

# 软链到 PATH（可选）
ln -sf "$(pwd)/src/index.ts" /usr/local/bin/paipai
```

## 快速开始

```bash
bun run src/index.ts skill list                    # 列出所有技能
bun run src/index.ts run example                    # 运行示例
bun run src/index.ts run example --target paipai   # 传参运行
bun run src/index.ts skill:init my-skill          # 创建新技能
bun run src/index.ts doctor                        # 环境检查
```

## 核心命令

| 命令 | 说明 |
|------|------|
| `paipai skill list` | 列出所有已注册的技能 |
| `paipai run <name>` | 执行指定技能，支持 `--key value` 传参 |
| `paipai skill:init <name>` | 在 `skills/` 下创建标准 Skill 骨架 |
| `paipai skill:remove <name>` | 删除技能（待实现） |
| `paipai doctor` | 检查 bun / node / skills 目录是否就绪 |
| `paipai help` | 显示帮助 |

## 技能目录格式

```
skills/<name>/
├── SKILL.md       # 技能元数据
├── main.sh        # 入口脚本（二选一）
└── stepN_*.sh    # 可选步骤脚本（按数字顺序执行）
```

### SKILL.md 格式

支持两种格式混用：

**格式一：YAML frontmatter**
```yaml
---
name: my-skill
description: 我的技能
---
# 这里可以写 Markdown 说明
```

**格式二：Markdown 段落**
```markdown
# SKILL.md

## name
my-skill

## description
我的技能描述

## triggers
- paipai run my-skill

## args
- name: target
  type: string
  required: false
  default: world
  description: 问候对象

## steps
- step1_hello.sh
- step2_bye.sh
```

### main.sh 格式

```bash
#!/bin/bash
set -e

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 从环境变量读取参数（由 runner.ts 注入）
TARGET="${SKILL_ARG_TARGET:-world}"

bash "$SKILL_DIR/step1_hello.sh"
```

**runner 注入的环境变量：**

| 变量 | 说明 |
|------|------|
| `SKILL_NAME` | 当前技能名称 |
| `SKILL_DIR` | 当前技能目录路径 |
| `SKILL_ARG_<NAME>` | 传入的参数值（连字符转下划线） |

## 目录结构

```
paipai-cli/
├── src/
│   ├── index.ts            # CLI 入口
│   ├── core/
│   │   ├── types.ts        # 类型定义
│   │   ├── loader.ts       # 扫描 + 解析 SKILL.md
│   │   └── runner.ts       # 脚本执行引擎
│   ├── commands/
│   │   ├── skill.ts        # skill list / run / init
│   │   └── doctor.ts       # 环境检查
│   └── utils/
│       └── log.ts          # 彩色日志
└── skills/                 # 技能包目录
    ├── example/            # 示例
    └── youtube-video-info-invidious/  # YouTube 视频信息
```

## 开发

```bash
bun run src/index.ts help          # 查看帮助
bun run src/index.ts doctor        # 环境检查
bun run src/index.ts skill list    # 列出技能
```

## 贡献新技能

1. `paipai skill:init my-skill` 创建骨架
2. 编辑 `skills/my-skill/SKILL.md` 填入元数据
3. 实现 `main.sh` 或 `stepN_*.sh`
4. 测试：`paipai run my-skill`

## 已知限制

- 直接执行 `bash main.sh` 时 `SKILL_NAME` / `SKILL_DIR` 为空（仅通过 CLI 调用时正常）
- 必填参数目前不校验（计划 v0.2.0 修复）
- 参数名建议避免连字符（使用驼峰），连字符会被转成下划线注入环境变量
