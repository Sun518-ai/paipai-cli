#!/usr/bin/env bash
# step4_captions.sh — 获取字幕/Transcript
# Usage: bash step4_captions.sh [CAPTION_URL]

set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SKILL_DIR}/lib/auth.sh"

CAPTION_URL="${1:-${SKILL_ARG_CAPTION_URL:-}}"
COOKIE=$(auth_get_cookie)

if [ -z "$COOKIE" ]; then
    echo "字幕获取需要 Cookie。方式："
    echo "  1. 使用 Cookie 模式: COOKIE='xxx' paipai run youtube --video-id xxx"
    echo "  2. 或者运行: paipai run youtube 进行授权设置"
    exit 0
fi

if [ -z "$CAPTION_URL" ]; then
    # 需要先从 Player API 获取 caption track URL
    echo "(字幕 URL 未提供，请在 Player API 响应中获取)"
    exit 0
fi

RESULT=$(curl -s --connect-timeout 8 --max-time 15 \
    -H "Cookie: $COOKIE" \
    -H 'User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36' \
    -H 'Referer: https://www.youtube.com/' \
    "$CAPTION_URL" 2>&1) || {
    echo "(字幕获取失败)"
    exit 0
}

echo "$RESULT" | python3 -c "
import sys, json

try:
    d = json.load(sys.stdin)
    events = d.get('events', [])

    if not events:
        print('(无字幕)')
        sys.exit(0)

    lines = 0
    for ev in events:
        segs = ev.get('segs', [])
        if not segs:
            continue
        t_ms = ev.get('tStartMs', 0)
        t_sec = t_ms // 1000
        m = t_sec // 60
        s = t_sec % 60
        ts = f'{m:02d}:{s:02d}'
        text = ''.join(seg.get('utf8', '') for seg in segs if seg.get('utf8'))
        if text.strip():
            print(f'{ts}  {text}')
            lines += 1

    print()
    print(f'(共 {lines} 条字幕)')

except json.JSONDecodeError:
    # 字幕可能是 WebVTT 格式
    sys.exit(0)
" 2>&1 || echo "(字幕解析失败)"
