---
name: youtube-video-info
description: >-
  获取 YouTube 视频详细信息，包括元数据（标题、作者、时长、观看数、关键词、缩略图）、
  字幕/transcript 提取、搜索视频、推荐视频列表。当用户需要查询 YouTube 视频信息、
  获取字幕文本、搜索 YouTube 内容、查看相关推荐时使用此 Skill。
  支持关键词触发：YouTube、视频信息、字幕、transcript、subtitle、推荐视频、
  搜索视频、video info、captions。
login_url: https://www.youtube.com/watch?mira_skill_cookie=1&MIRA_ORIGIN_URL=__MIRA_ORIGIN_URL__
---

# YouTube 视频信息获取 Skill

获取 YouTube 视频的详细元数据（标题、描述、时长、观看数、字幕等）以及相关推荐视频信息。

## Cookie 获取指引

**首次运行需要提供 Cookie，提供后自动持久化，后续运行无需重复操作。**

如果 Cookie 缺失或过期（接口返回 401/403），请通过以下链接完成授权：
[点击此处授权并获取 Cookie](https://www.youtube.com/watch?mira_skill_cookie=1&MIRA_ORIGIN_URL=__MIRA_ORIGIN_URL__)

> **注意**：安装了 Mira 浏览器插件会自动提取 Cookie 和认证请求头。

若未安装插件，可手动获取：
1. 打开上述链接并确保已登录 YouTube
2. 打开浏览器开发者工具（F12）→ Application → Cookies
3. 复制该站点下的所有 Cookie（格式为 `key1=value1; key2=value2; ...`）
4. 在对话中提供 `COOKIE=xxx`，将自动持久化

## 认证请求头

| 请求头 | 变量名 | 说明 |
|--------|--------|------|
| `authorization` | `$AUTHORIZATION` | YouTube OAuth token，运行时自动注入或由用户手动提供 |

## 参数说明

| 参数 | 必填 | 说明 |
|------|------|------|
| `--video-id` | 否 | YouTube 视频 ID（如 `dQw4w9WgXcQ`），不提供则使用默认值 |
| `--search` | 否 | 搜索关键词，若提供则执行搜索 |
| `--caption-lang` | 否 | 字幕语言代码，默认 `en` |

## 使用示例

```bash
# 获取视频信息
bash main.sh --video-id dQw4w9WgXcQ

# 搜索视频
bash main.sh --search "火影忍者"

# 获取视频信息 + 中文字幕
bash main.sh --video-id dQw4w9WgXcQ --caption-lang zh-Hans
```
