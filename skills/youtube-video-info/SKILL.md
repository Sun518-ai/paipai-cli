# SKILL.md

## name
youtube-video-info

## description
获取 YouTube 视频详细信息（标题/频道/时长/观看数/字幕等），支持 Cookie/OAuth 授权。内置本地缓存（TTL 默认 1 小时），支持 TUI 交互式授权引导。

## triggers
- paipai run youtube
- paipai run youtube-info-cookie

## args
- name: video-id
  type: string
  required: false
  description: YouTube 视频 ID

- name: search
  type: string
  required: false
  description: 搜索关键词

- name: limit
  type: number
  required: false
  default: 10
  description: 搜索结果数量

- name: nocache
  type: boolean
  required: false
  default: false
  description: 跳过缓存，强制刷新

## steps
- step1_player.sh
- step2_search.sh
- step3_get_watch.sh
- step4_captions.sh
