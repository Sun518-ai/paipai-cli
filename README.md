# paipai-cli

基于 bun 的 AI Skill CLI 框架 — 插件化、跨平台，每个业务 Skill 独立目录。

## 安装

```bash
# 确保 bun 已安装（>= 1.0.0）
bun --version

# 软链到 PATH（可选）
ln -sf "$(pwd)/src/index.ts" /usr/local/bin/paipai
```

## 快速开始

```bash
# 列出所有技能
bun run src/index.ts skill list

# 运行示例技能
bun run src/index.ts run example

# 传参运行
bun run src/index.ts run example --target paipai

# 创建新技能
bun run src/index.ts skill:init my-skill

# 环境检查
bun run src/index.ts doctor
```

## 核心命令

| 命令 | 说明 |
|------|------|
| `paipai skill list` | 列出所有已注册的技能 |
| `paipai run <name>` | 执行指定技能，支持 `--key value` 传参 |
| `paipai skill:init <name>` | 在 `skills/` 下创建标准 Skill 骨架 |
| `paipai doctor` | 检查 bun / node / skills 目录是否就绪 |

## 技能目录格式

```
skills/<name>/
├── SKILL.md       # 技能元数据（名称、描述、参数、步骤）
├── main.sh        # 入口脚本（二选一）
└── stepN_*.sh     # 可选步骤脚本
```

详情参见 [SPEC.md](./SPEC.md)。

## 目录结构

```
paipai-cli/
├── src/
│   ├── index.ts            # CLI 入口
│   ├── core/
│   │   ├── types.ts        # 类型定义
│   │   ├── loader.ts       # 扫描与解析 SKILL.md
│   │   └── runner.ts       # 脚本执行引擎
│   ├── commands/
│   │   ├── skill.ts        # skill list / run / init
│   │   └── doctor.ts       # 环境检查
│   └── utils/
│       └── log.ts          # 彩色日志
└── skills/                 # 技能包目录
    └── example/             # 示例
```

## 开发

```bash
bun run src/index.ts help     # 查看帮助
bun run src/index.ts doctor   # 环境检查
```

## 贡献新技能

1. 运行 `paipai skill:init my-skill`
2. 编辑 `skills/my-skill/SKILL.md` 填入元数据
3. 实现 `main.sh` 或 `stepN_*.sh`
4. 测试：`paipai run my-skill`
