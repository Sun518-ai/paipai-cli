#!/usr/bin/env bash
# step3_get_watch.sh — 获取推荐视频列表（YouTube Get Watch API）

set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SKILL_DIR}/lib/auth.sh"

VIDEO_ID="${SKILL_ARG_VIDEO_ID:-}"
COOKIE=$(auth_get_cookie)

if [ -z "$VIDEO_ID" ]; then
    echo "[error] video-id is required" >&2
    exit 1
fi

if [ -z "$COOKIE" ]; then
    echo "(推荐视频需要 Cookie)"
    exit 0
fi

BODY=$(python3 -c "
import json
print(json.dumps({
    'context': {
        'client': {
            'hl': 'zh-CN', 'gl': 'SG', 'clientName': 'WEB',
            'clientVersion': '2.20200618.00.00',
            'osName': 'Macintosh', 'osVersion': '10_15_7',
            'platform': 'DESKTOP', 'clientFormFactor': 'UNKNOWN_FORM_FACTOR',
            'userAgent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36,gzip(gfe)'
        },
        'user': {'lockedSafetyMode': False},
        'request': {'useSsl': True, 'internalExperimentFlags': [], 'consistencyTokenJars': []}
    },
    'videoId': '$VIDEO_ID'
})
")

RESULT=$(curl -s --connect-timeout 8 --max-time 15 \
    -X POST \
    -H 'Content-Type: application/json' \
    -H "Cookie: $COOKIE" \
    -H 'X-Youtube-Client-Name: 1' \
    -H 'X-Youtube-Client-Version: 2.20200618.00.00' \
    -H 'Origin: https://www.youtube.com' \
    -H 'Referer: https://www.youtube.com/watch?v='"$VIDEO_ID" \
    -d "$BODY" \
    "https://www.youtube.com/youtubei/v1/get_watch?prettyPrint=false" 2>&1) || {
    echo "(推荐视频获取失败)"
    exit 0
}

echo "$RESULT" | python3 -c "
import json, sys, html

d = json.load(sys.stdin)
items = []

# 遍历所有 compactVideoRenderer
def find_videos(obj):
    if isinstance(obj, dict):
        if 'compactVideoRenderer' in obj:
            v = obj['compactVideoRenderer']
            vid = v.get('videoId', '')
            t = v.get('title', {})
            if isinstance(t, dict):
                title = ''
                for run in t.get('runs', []):
                    title += run.get('text', '')
            else:
                title = str(t)
            title = html.unescape(title)
            channel = ''
            for run in v.get('longBylineText', {}).get('runs', []):
                channel += run.get('text', '')
            channel = html.unescape(channel)
            dur = v.get('lengthText', {}).get('simpleText', 'N/A')
            views = v.get('viewCountText', {}).get('simpleText', 'N/A')
            if vid:
                items.append({'vid': vid, 'title': title, 'channel': channel, 'dur': dur, 'views': views})
        for v in obj.values():
            find_videos(v)
    elif isinstance(obj, list):
        for item in obj:
            find_videos(item)

find_videos(d)

if not items:
    print('(无推荐视频)')
else:
    for i, v in enumerate(items[:8], 1):
        print(f'{i:2}. {v[\"title\"]}')
        print(f'    👤 {v[\"channel\"]}  ⏱ {v[\"dur\"]}  👁 {v[\"views\"]}')
        print(f'    🔗 https://www.youtube.com/watch?v={v[\"vid\"]}')
        print()
" 2>/dev/null || echo "(推荐视频解析失败)"
