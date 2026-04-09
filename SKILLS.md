# Skill 开发者指南

## 概述

paipai-cli 的 Skill 本质上是**带元数据的 shell 脚本**，由统一的 runner 执行。元数据（SKILL.md）声明参数，runner 负责环境注入和执行调度。

---

## SKILL.md 格式规范

### 最小示例

```markdown
# SKILL.md

## name
hello-world

## description
输出 Hello World

## triggers
- paipai run hello

## steps
- step1.sh
```

### 完整示例（带参数）

```markdown
# SKILL.md

## name
youtube-info

## description
获取 YouTube 视频信息

## triggers
- paipai run yt
- paipai run youtube-info

## args
- name: video-id
  type: string
  required: false
  default: dQw4w9WgXcQ
  description: YouTube 视频 ID

- name: format
  type: string
  required: false
  default: json
  description: 输出格式（json/text）

## steps
- step1_info.sh
- step2_format.sh
```

### 字段说明

| 字段 | 必填 | 说明 |
|------|------|------|
| `name` | 是 | 技能唯一标识（ kebab-case） |
| `description` | 否 | 一句话说明 |
| `triggers` | 否 | 别名列表（用 `paipai run <alias>` 触发） |
| `args` | 否 | 参数定义列表 |
| `steps` | 否 | 显式声明要执行的步骤文件 |

---

## 参数传递机制

CLI 调用：`paipai run my-skill --arg1 value1 --arg2 value2`

runner 注入的环境变量格式：
- `SKILL_NAME` = 技能名称
- `SKILL_DIR` = 技能目录绝对路径
- `SKILL_ARG_ARG1` = `value1`（大写，连字符转下划线）
- `SKILL_ARG_ARG2` = `value2`

**bash 中读取参数：**
```bash
ARG1="${SKILL_ARG_ARG1:-default_value}"
```

---

## 网络请求规范（重要）

### 公共 API（首选）

优先使用**无需认证的公共 API**：

| 服务 | API 端点 | 认证 |
|------|----------|------|
| YouTube | `youtube.com/oembed` | 无 |
| YouTube | `yewtu.be/api/v1/` (Invidious) | 无 |
| GitHub | `api.github.com/` | 可选 |
| 百度 | `api.map.baidu.com/` | 需要 AK |

### 认证 API 处理

如果必须使用认证 API（Cookie / API Key）：

1. **优先通过环境变量传入**（不硬编码）
2. **支持 Cookie 持久化**：
   ```bash
   COOKIE_FILE="$HOME/.paipai/cookies/$SKILL_NAME.txt"
   [ -f "$COOKIE_FILE" ] && COOKIE=$(cat "$COOKIE_FILE")
   ```
3. **Graceful Degradation**：无 Cookie 时给出友好提示，不直接报错

### 网络超时处理

**必须设置超时**，防止卡死：

```bash
# ✅ 正确
RESULT=$(curl -s --connect-timeout 5 --max-time 15 "https://api.example.com/...")

# ❌ 错误（无超时，可能永远卡住）
RESULT=$(curl -s "https://api.example.com/...")
```

### 网络不可达的 Graceful Degradation

```bash
RESULT=$(curl -s --connect-timeout 3 --max-time 10 "https://api.example.com/..." 2>&1)
if [ -z "$RESULT" ] || echo "$RESULT" | grep -q "Connection refused"; then
    echo "[warn] 网络不可达，使用缓存数据"
    # 降级处理
fi
```

---

## 错误处理规范

### 必须检查退出码

```bash
# ✅ 正确
set -euo pipefail
RESULT=$(curl -s --connect-timeout 5 "https://api.example.com/" 2>&1) || {
    echo "[error] 请求失败: $RESULT" >&2
    exit 1
}

# 或者捕获错误
set +e
RESULT=$(curl -s "https://api.example.com/")
CODE=$?
set -e
if [ $CODE -ne 0 ]; then
    echo "[error] HTTP 请求失败，退出码: $CODE" >&2
    exit 1
fi
```

### JSON 解析错误处理

```bash
# 检查 JSON 是否有效
if ! echo "$RESULT" | python3 -c "import json,sys; json.load(sys.stdin)" 2>/dev/null; then
    echo "[error] JSON 解析失败" >&2
    exit 1
fi
```

---

## 依赖管理

### 最小化依赖

Skill 脚本应该尽量使用系统自带工具：
- `curl` / `wget` — HTTP 请求
- `python3` — JSON 解析（系统自带）
- `jq` — 可选，更好的 JSON 处理
- **不要依赖 `jq`**，优先用 `python3 -c "import json; ..."`

### 依赖检测

```bash
for cmd in curl python3 jq; do
    if ! command -v $cmd &>/dev/null; then
        echo "[error] 缺少依赖: $cmd" >&2
        exit 1
    fi
done
```

---

## 输出规范

### 人类可读输出

```bash
echo "=== 视频信息: $VIDEO_ID ==="
echo ""
echo "标题:   $TITLE"
echo "频道:   $AUTHOR"
echo "时长:   $DURATION"
echo "观看:   $VIEWS"
```

### 调试模式

```bash
if [ "${PAIPAI_DEBUG:-}" = "1" ]; then
    echo "[debug] VIDEO_ID=$VIDEO_ID" >&2
    echo "[debug] COOKIE=${#COOKIE} chars" >&2
fi
```

---

## SKILL.md 解析兼容性

目前 loader 支持：

| 格式 | 示例 | 支持状态 |
|------|------|----------|
| YAML frontmatter | `---name: xxx---` | ✅ |
| YAML `>-` 折叠 | `description: >-` | ✅ |
| Markdown `## name` | `## name\nmy-skill` | ✅ |
| `- key: value` | `- name: my-skill` | ✅ |
| 缩进字段 | `  type: string` | ✅ |

**参数名建议使用 kebab-case**（如 `video-id`），runner 会自动转成 `SKILL_ARG_VIDEO_ID`。

---

## 测试清单

提交 Skill 前自测：

```bash
# 1. 框架级测试
paipai skill list  # Skill 必须出现在列表中

# 2. 参数测试
paipai run <skill> --arg1 value1  # 正常参数
paipai run <skill>                 # 默认参数

# 3. 错误处理测试
paipai run <skill> --invalid-arg  # 未知参数应被忽略
paipai run nonexistent-skill      # 应报错 "Skill not found"

# 4. 网络测试（有网络依赖时）
curl -s --connect-timeout 5 "https://..."  # API 可达性
```
