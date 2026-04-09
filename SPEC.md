# paipai-cli 技术规格说明书

> AI Skill CLI — 基于 bun 的跨平台命令行工具
> 本文档为**技术设计文档**，定义架构、目录结构、接口契约及开发阶段。

---

## 1. 背景与目标

**解决的问题**：业务 Skill 贡献散乱，缺乏统一封装规范，导致能力无法复用。

**目标用户**：内部开发者 / AI Agent，通过 `paipai run <skill>` 调用各种业务技能。

**核心价值**：框架（src）与技能（skills）分离，技能可独立发布、组合执行。

---

## 2. 技术架构

### 2.1 项目结构（与实现完全对应）

```
paipai-cli/
├── SPEC.md                        # 本文档
├── README.md                      # 使用说明
├── package.json                   # bun 项目配置
├── tsconfig.json
├── bun.lockb
├── src/
│   ├── index.ts                  # CLI 入口，bin 声明为 paipai
│   ├── core/
│   │   ├── types.ts              # Skill, Step, RunContext 类型定义
│   │   ├── loader.ts             # 扫描 skills/ 目录，解析 SKILL.md
│   │   └── runner.ts             # 执行 main.sh 或 stepN_*.sh
│   ├── commands/
│   │   ├── skill.ts              # skill list / run / skill:init
│   │   └── doctor.ts             # 环境检查
│   └── utils/
│       └── log.ts                # 彩色日志工具
└── skills/                       # 技能包目录（贡献的 SKILL 在此）
    ├── example/                   # 示例技能
    │   ├── SKILL.md              # 元数据
    │   ├── main.sh               # 入口
    │   └── stepN_*.sh            # 步骤脚本
    └── <name>/                   # 其他技能
        ├── SKILL.md
        └── main.sh
```

### 2.2 CLI 命令接口

| 命令 | 说明 | 状态 |
|------|------|------|
| `paipai skill list` | 列出所有技能 | ✅ 已实现 |
| `paipai run <name> [--arg val]` | 执行指定技能，参数注入环境变量 | ✅ 已实现 |
| `paipai skill:init <name>` | 创建标准 Skill 骨架 | ✅ 已实现 |
| `paipai doctor` | 环境检查（bun/node/skills） | ✅ 已实现 |
| `paipai help` | 显示帮助 | ✅ 已实现 |

### 2.3 Skill 目录格式

每个 Skill 是 `skills/<name>/` 下的独立包：

```
skills/<name>/
├── SKILL.md       # 技能元数据
├── main.sh        # 入口脚本（二选一）
└── stepN_*.sh     # 可选，runner 自动按顺序执行
```

**SKILL.md 格式规范**：

```markdown
# SKILL.md

## name
example-skill

## description
示例技能：演示 CLI 技能框架的用法

## triggers
- paipai run example

## args
- name: target
  type: string
  required: false
  default: world
  description: 问候对象

## steps
- step1_hello.sh
- step2_process.sh
```

**main.sh 格式规范**：

```bash
#!/bin/bash
set -e

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

TARGET="${SKILL_ARG_TARGET:-world}"
echo "Hello, $TARGET"

bash "$SKILL_DIR/step1_hello.sh"
```

**runner.ts 注入的环境变量**：

| 变量 | 说明 |
|------|------|
| `SKILL_NAME` | 当前技能名称 |
| `SKILL_DIR` | 当前技能目录路径 |
| `SKILL_ARG_<NAME>` | 传入的参数值 |

---

## 3. 飞书多维表格字段

| 字段 ID | 字段名 | 类型 |
|---------|--------|------|
| fld72aX1K8 | 技能名称 | 文本 |
| fldq1r4C7i | 描述 | 文本 |
| fldjEaY2GG | 状态 | 单选 |
| fldv0eztpY | 优先级 | 数字 |
| fldFmOwxAR | 负责人 | 文本 |
| fldmDDG7zF | 触发命令 | 文本 |
| fldItWrDgS | 依赖 | 文本 |
| fldShXeDAi | 备注 | 文本 |

状态选项：`待开发` / `开发中` / `已完成` / `测试通过`

---

## 4. 开发阶段

### M1：框架搭建 ✅
- [x] bun 1.0.0 环境（macOS 12.2 + Intel 兼容）
- [x] `src/core/types.ts` — 类型定义
- [x] `src/core/loader.ts` — SKILL.md 扫描与解析
- [x] `src/core/runner.ts` — main.sh / stepN 执行引擎

### M2：基础命令 ✅
- [x] `paipai skill list` — 列出所有技能
- [x] `paipai run <skill>` — 执行指定技能
- [x] `paipai skill:init <name>` — 创建技能骨架
- [x] `paipai doctor` — 环境检查

### M3：示例技能 ✅
- [x] `skills/example/` — 完整示例（SKILL.md + main.sh + 2个 step）

### M4：CI / 发布
- [ ] GitHub Actions 自动构建
- [ ] 发布脚本（npm / homebrew）

---

## 5. 已知问题（v0.1.0）

| # | 问题 | 严重程度 | 状态 |
|---|------|----------|------|
| 1 | 必填参数不校验，缺失时报 runner 错误而非友好的提示 | 中 | 待修复 |
| 2 | `SKILL.md` 裸文本值（无 `-` 前缀）解析逻辑脆弱 | 中 | 临时代码 |
| 3 | 直接执行 `bash main.sh` 时 SKILL_DIR/SKILL_NAME 为空 | 低 | 已知限制 |
| 4 | 无配置文件，无法自定义 skills 目录路径 | 低 | 待开发 |
| 5 | `skill remove` 命令缺失，无法删除技能 | 低 | 待开发 |

## 6. 架构决策记录（ADR）

### ADR-001：参数环境变量命名规范
- **决定**：参数名中的连字符转下划线注入环境变量（`video-id` → `SKILL_ARG_VIDEO_ID`）
- **原因**：bash 不支持连字符作为环境变量名
- **影响**：SKILL.md 中参数名避免使用连字符，或使用驼峰

### ADR-002：SKILL.md 解析策略
- **决定**：兼容两种格式 —— YAML frontmatter（`---...---`）+ 裸 Markdown `## section` 段落
- **原因**：feishu cli 使用 frontmatter，OpenClaw 使用 Markdown 格式，保留两者兼容
- **风险**：解析逻辑复杂，边界情况多

### ADR-003：Skill 执行方式
- **决定**：优先执行 `main.sh`，无 main.sh 时按顺序执行 `stepN_*.sh`
- **原因**：main.sh 适合复杂流程编排，stepN 适合简单顺序执行

## 7. 下一步改进方向

| 优先级 | 改进项 | 说明 |
|--------|--------|------|
| P1 | args 参数校验 | 必填参数缺失时友好报错 |
| P2 | skill remove 命令 | 删除技能目录 |
| P2 | 配置文件 | `.paipairc` 自定义 skills 路径 |
| P3 | `--json` 结构化输出 | 便于程序消费 |
| P3 | skill 别名 | `paipai run yt` 代替长名 |
| P3 | skill update | 远程更新技能包 |
| P3 | skill search | 技能列表过滤 |

---

## 5. 参考来源

- feishu cli（GitHub: larksuite/cli）：命令分组架构
- OpenClaw skills：SKILL.md + main.sh 模式
