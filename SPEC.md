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
├── SKILLS.md                      # Skill 开发者指南
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
│   │   ├── skill.ts              # skill list / run / init / remove
│   │   └── doctor.ts             # 环境检查
│   └── utils/
│       └── log.ts               # 彩色日志工具
└── skills/                       # 技能包目录（贡献的 SKILL 在此）
    ├── example/                   # 示例技能
    ├── youtube-info/             # YouTube Data API v3（API Key 认证）
    └── youtube-video-info/        # YouTube 内部 API（Cookie 认证）
        ├── lib/
        │   ├── auth.sh           # TUI 授权管理
        │   └── cache.sh          # 本地缓存管理
        ├── main.sh
        └── stepN_*.sh
```

### 2.2 CLI 命令接口

| 命令 | 说明 | 状态 |
|------|------|------|
| `paipai skill list` | 列出所有技能 | ✅ |
| `paipai run <name> [--arg val]` | 执行指定技能，参数注入环境变量 | ✅ |
| `paipai skill:init <name>` | 创建标准 Skill 骨架 | ✅ |
| `paipai skill:remove <name>` | 删除技能目录 | ✅ |
| `paipai doctor` | 环境检查 | ✅ |
| `paipai help` | 显示帮助 | ✅ |

### 2.3 Skill 目录格式

每个 Skill 是 `skills/<name>/` 下的独立包：

```
skills/<name>/
├── SKILL.md       # 技能元数据
├── main.sh        # 入口脚本（二选一）
├── stepN_*.sh     # 可选，runner 自动按顺序执行
└── lib/           # 可选，共享工具库
    ├── cache.sh
    └── auth.sh
```

**SKILL.md 格式规范**：frontmatter 仅放 `name`/`description`，其余 `args`/`triggers`/`steps` 必须在 markdown body 区段。

### 2.4 环境变量规范

| 变量 | 说明 |
|------|------|
| `SKILL_NAME` | 当前技能名称 |
| `SKILL_DIR` | 当前技能目录路径 |
| `SKILL_ARG_<NAME>` | 传入的参数值（连字符转下划线，如 `video-id` → `SKILL_ARG_VIDEO_ID`） |
| `PAIPAI_DEBUG` | 调试模式（=1） |
| `PAIPAI_CACHE_DIR` | 缓存目录（默认 `~/.cache/paipai/`） |
| `PAIPAI_CACHE_TTL` | 缓存 TTL 秒数（默认 3600） |
| `YOUTUBE_API_KEY` | YouTube Data API v3 的 API Key |

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
- [x] `paipai skill:remove <name>` — 删除技能
- [x] `paipai doctor` — 环境检查

### M3：示例技能 ✅
- [x] `skills/example/` — 完整示例（SKILL.md + main.sh + 2个 step）

### M4：YouTube Skill 生态 ✅
- [x] `youtube-info` — YouTube Data API v3（API Key，无需登录）
- [x] `youtube-video-info` — YouTube 内部 API（Cookie 认证 + TUI 授权 + 本地缓存）
- [x] `youtube-video-info-invidious` — 降级 Mock 模式

### M5：CI / 发布
- [ ] GitHub Actions 自动构建
- [ ] 发布脚本（npm / homebrew）

---

## 5. 已知问题（v0.1.0）

| # | 问题 | 严重程度 | 状态 |
|---|------|----------|------|
| 1 | 必填参数不校验（已修复报错，但可进一步增强） | 中 | 已友好报错 |
| 2 | `SKILL.md` 裸文本值解析逻辑脆弱 | 中 | 临时代码 |
| 3 | 直接执行 `bash main.sh` 时 SKILL_DIR/SKILL_NAME 为空 | 低 | 已知限制 |
| 4 | 无配置文件，无法自定义 skills 目录路径 | 低 | 待开发 |
| 5 | frontmatter 解析器不支持 args/triggers/steps | 中 | 规范已明确 |

## 6. 架构决策记录（ADR）

### ADR-001：参数环境变量命名规范
- **决定**：参数名中的连字符转下划线注入环境变量（`video-id` → `SKILL_ARG_VIDEO_ID`）
- **原因**：bash 不支持连字符作为环境变量名
- **影响**：SKILL.md 中参数名避免使用连字符，或使用驼峰

### ADR-002：SKILL.md 解析策略
- **决定**：frontmatter 仅支持 `name`/`description`，其余 `args`/`triggers`/`steps` 必须在 markdown body 区段声明
- **原因**：feishu cli 用 frontmatter，OpenClaw 用 Markdown 格式，统一规范避免混淆
- **风险**：解析逻辑复杂，边界情况多

### ADR-003：Skill 执行方式
- **决定**：优先执行 `main.sh`，无 main.sh 时按顺序执行 `stepN_*.sh`
- **原因**：main.sh 适合复杂流程编排，stepN 适合简单顺序执行

### ADR-004：授权方案分层
- **决定**：按场景分三层
  1. `youtube-info`（API Key）：无需登录，免费配额 10000 units/天
  2. `youtube-video-info`（Cookie）：完整数据，需登录，TUI 引导 + 缓存
  3. `youtube-video-info-invidious`（Mock）：网络不通时的降级

## 7. Skill 授权方案对比

| Skill | 认证方式 | TUI 授权 | 本地缓存 | 适用场景 |
|-------|---------|---------|---------|---------|
| `youtube-info` | API Key | ❌ | ❌ | CLI首选，无需登录 |
| `youtube-video-info` | Cookie/OAuth | ✅ TUI引导 | ✅ TTL缓存 | 完整数据，需登录 |
| `youtube-video-info-invidious` | 无 | ❌ | ❌ | 降级/Mock |

### TUI 授权流程（youtube-video-info）

```
1. 检测 ~/.config/paipai/youtube-video-info/.cookie 是否存在
2. 不存在 → 交互式选择：
   a) 粘贴 Cookie（推荐，最简单）
   b) OAuth 浏览器授权（自动回调）
   c) 查看状态 / 清除授权
3. 验证 Cookie 有效性
4. 持久化到配置文件
```

### 缓存策略

```
路径: ~/.cache/paipai/youtube/<key>.json
TTL:  默认 3600 秒（可配置 PAIPAI_CACHE_TTL）
跳过: --nocache 参数强制刷新
```

## 8. 下一步改进方向

| 优先级 | 改进项 | 说明 |
|--------|--------|------|
| P1 | args 参数校验 | 必填参数缺失时友好报错 |
| P2 | 配置文件 | `.paipairc` 自定义 skills 路径 |
| P2 | skill trigger 运行 | `paipai run <trigger>` 按触发词运行 |
| P3 | `--json` 结构化输出 | 便于程序消费 |
| P3 | skill 别名 | `paipai run yt` 代替长名 |
| P3 | skill update | 远程更新技能包 |
| P3 | skill search | 技能列表过滤 |

---

## 9. 参考来源

- feishu cli（GitHub: larksuite/cli）：命令分组架构
- OpenClaw skills：SKILL.md + main.sh 模式
