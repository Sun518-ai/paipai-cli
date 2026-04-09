# SKILL.md

## name
youtube-info

## description
获取 YouTube 视频详细信息，基于 YouTube Data API v3。提供 API Key 即可使用，无需浏览器登录。

## triggers
- paipai run youtube-info
- paipai run yt

## args
- name: video-id
  type: string
  required: false
  description: YouTube 视频 ID（如 dQw4w9WgXcQ）

- name: search
  type: string
  required: false
  description: 搜索关键词，提供则执行搜索

- name: limit
  type: number
  required: false
  default: 10
  description: 搜索结果数量上限
