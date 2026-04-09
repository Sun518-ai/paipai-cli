#!/usr/bin/env bash
# step1_info.sh — YouTube 视频信息 via oEmbed（无需登录）
# Usage: bash step1_info.sh

VIDEO_ID="${SKILL_ARG_VIDEO_ID:-}"

if [ -z "$VIDEO_ID" ]; then
  echo "[error] video-id is required" >&2
  exit 1
fi

echo "=== 视频信息: $VIDEO_ID ==="
echo ""

# Try oEmbed API first (no cookie needed)
RESULT=$(curl -s --connect-timeout 5 --max-time 10 \
  "https://www.youtube.com/oembed?url=https://www.youtube.com/watch?v=$VIDEO_ID&format=json" 2>&1)

if [ -n "$RESULT" ] && echo "$RESULT" | python3 -c "import json,sys; json.load(sys.stdin)" 2>/dev/null | grep -q "ok"; then
  echo "$RESULT" | python3 -c "
import json, sys, html
d = json.load(sys.stdin)
def u(t): return html.unescape(str(t)) if t else 'N/A'
print(f'标题:   {u(d.get(\"title\",\"N/A\"))}')
print(f'作者:   {u(d.get(\"author_name\",\"N/A\"))}')
print(f'视频ID: $VIDEO_ID')
print(f'链接:   https://www.youtube.com/watch?v=$VIDEO_ID')
print(f'缩略图: {d.get(\"thumbnail_url\",\"N/A\")}')
print(f'提供者: {d.get(\"provider_name\",\"N/A\")}')
print()
print('提示: 完整元数据（时长/观看数/字幕）需要提供 Cookie')
print('      使用: COOKIE=xxx paipai run youtube-video-info --video-id $VIDEO_ID')
"
else
  # 网络不通，降级为 Mock 演示
  echo "[warn] 无法连接 YouTube，使用 Mock 数据演示"
  python3 -c "
vid = '$VIDEO_ID'
titles = {
    'dQw4w9WgXcQ': 'Rick Astley - Never Gonna Give You Up (Official Music Video)',
    'JS1KKbbwZWw': '小恐龙炫彩世界',
}
title = titles.get(vid, f'YouTube Video {vid}')
print(f'标题:   {title}')
print(f'频道:   Demo Channel (Mock)')
print(f'视频ID: {vid}')
print(f'链接:   https://www.youtube.com/watch?v={vid}')
print(f'缩略图: https://img.youtube.com/vi/{vid}/hqdefault.jpg')
print(f'时长:   03:33 (Mock)')
print(f'观看:   1.2M (Mock)')
"
fi
