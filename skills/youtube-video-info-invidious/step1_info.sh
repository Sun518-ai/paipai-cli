#!/usr/bin/env bash
# step1_info.sh — YouTube 视频信息（Mock 演示模式）
# 网络不通时使用 mock 数据演示
# Usage: bash step1_info.sh

VIDEO_ID="${SKILL_ARG_VIDEO_ID:-}"

if [ -z "$VIDEO_ID" ]; then
  echo "[error] video-id is required" >&2
  exit 1
fi

echo "=== 视频信息: $VIDEO_ID ==="
echo ""

# 尝试访问 YouTube oEmbed
RESULT=$(curl -s --max-time 5 \
  "https://www.youtube.com/oembed?url=https://www.youtube.com/watch?v=$VIDEO_ID&format=json" 2>&1)

if [ -n "$RESULT" ] && echo "$RESULT" | python3 -c "import json,sys; json.load(sys.stdin); print('ok')" 2>/dev/null | grep -q ok; then
  # 真实 API 模式
  echo "$RESULT" | python3 -c "
import json, sys, html
d = json.load(sys.stdin)
def u(t): return html.unescape(str(t)) if t else 'N/A'
print(f'标题:   {u(d.get(\"title\",\"N/A\"))}')
print(f'作者:   {u(d.get(\"author_name\",\"N/A\"))}')
print(f'视频ID: $VIDEO_ID')
print(f'链接:   https://www.youtube.com/watch?v=$VIDEO_ID')
print(f'缩略图: {d.get(\"thumbnail_url\",\"N/A\")}')
"
else
  # Mock 演示模式
  echo "[info] 网络不可达，使用 Mock 演示模式"
  echo ""
  python3 -c "
import html
vid = '$VIDEO_ID'
titles = {
    'dQw4w9WgXcQ': 'Rick Astley - Never Gonna Give You Up (Official Music Video)',
    'JS1KKbbwZWw': '小恐龙炫彩世界',
}
title = titles.get(vid, f'YouTube Video {vid}')
print(f'标题:   {title}')
print(f'频道:   Demo Channel')
print(f'视频ID: {vid}')
print(f'链接:   https://www.youtube.com/watch?v={vid}')
print(f'缩略图: https://img.youtube.com/vi/{vid}/hqdefault.jpg')
print(f'时长:   03:33 (示例)')
print(f'观看:   1.2M (示例)')
print(f'发布:   2024-01-01 (示例)')
print()
print('[demo] 完整元数据需要 Cookie，使用 youtube-video-info skill 并提供 COOKIE=xxx')
"
fi
