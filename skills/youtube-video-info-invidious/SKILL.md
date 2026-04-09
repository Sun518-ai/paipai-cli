# SKILL.md

## name
youtube-video-info-invidious

## description
获取 YouTube 视频信息（标题、频道、时长、观看数、缩略图）及搜索视频，基于 Invidious 公开 API，无需登录。

## triggers
- paipai run youtube-video-info-invidious
- paipai run yt

## args
- name: video-id
  type: string
  required: false
  default: dQw4w9WgXcQ
  description: YouTube 视频 ID

- name: search
  type: string
  required: false
  default: ""
  description: 搜索关键词，提供则执行搜索

- name: limit
  type: number
  required: false
  default: 10
  description: 返回结果数量上限

## steps
- step1_info.sh
- step2_search.sh
