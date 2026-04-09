#!/usr/bin/env bash
# step2_search.sh — YouTube 搜索（Cookie 授权）
# Usage: bash step2_search.sh <QUERY>

set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SKILL_DIR}/lib/auth.sh"

SEARCH_QUERY="${SKILL_ARG_SEARCH:-${1:-}}"
LIMIT="${SKILL_ARG_LIMIT:-10}"
COOKIE=$(auth_get_cookie)

if [ -z "$SEARCH_QUERY" ]; then
    echo "[info] no search query" >&2
    exit 0
fi

if [ -z "$COOKIE" ]; then
    echo "[error] 未设置 Cookie" >&2
    exit 1
fi

ENCODED_Q=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$SEARCH_QUERY'))")

BODY=$(python3 -c "
import json, sys
body = {
    'context': {
        'client': {
            'hl': 'zh-CN', 'gl': 'SG', 'clientName': 'WEB',
            'clientVersion': '2.20200618.00.00',
            'osName': 'Macintosh', 'osVersion': '10_15_7',
            'platform': 'DESKTOP', 'clientFormFactor': 'UNKNOWN_FORM_FACTOR',
            'userAgent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36,gzip(gfe)'
        },
        'user': {'lockedSafetyMode': False},
        'request': {
            'useSsl': True, 'internalExperimentFlags': [], 'consistencyTokenJars': []
        }
    },
    'query': sys.argv[1]
}
print(json.dumps(body))
" "$SEARCH_QUERY")

RESULT=$(curl -s --connect-timeout 8 --max-time 15 \
    -X POST \
    -H 'Content-Type: application/json' \
    -H "Cookie: $COOKIE" \
    -H 'X-Youtube-Client-Name: 1' \
    -H 'X-Youtube-Client-Version: 2.20200618.00.00' \
    -H 'Origin: https://www.youtube.com' \
    -H 'Referer: https://www.youtube.com/results?search_query='"$ENCODED_Q" \
    -d "$BODY" \
    "https://www.youtube.com/youtubei/v1/search?prettyPrint=false" 2>&1) || {
    echo "[error] 搜索请求失败" >&2
    exit 1
}

# 解析搜索结果
echo "$RESULT" | python3 -c "
import json, sys, html

d = json.load(sys.stdin)

items = []
for sec in d.get('contents', {}).get('twoColumnSearchResultsRenderer', {}).get('primaryContents', {}).get('sectionListRenderer', {}).get('contents', []):
    for item in sec.get('itemSectionRenderer', {}).get('contents', []):
        vr = item.get('videoRenderer', {})
        if vr:
            vid = vr.get('videoId', '')
            title_runs = vr.get('title', {}).get('runs', [])
            title = html.unescape(title_runs[0].get('text', 'N/A')) if title_runs else 'N/A'
            channel_runs = vr.get('ownerText', {}).get('runs', [])
            channel = html.unescape(channel_runs[0].get('text', 'N/A')) if channel_runs else 'N/A'
            view_text = vr.get('viewCountText', {}).get('simpleText', 'N/A')
            pub_text = vr.get('publishedTimeText', {}).get('simpleText', 'N/A')
            dur_text = vr.get('lengthText', {}).get('simpleText', 'N/A')
            items.append({'vid': vid, 'title': title, 'channel': channel,
                         'views': view_text, 'pub': pub_text, 'dur': dur_text})

if not items:
    print('(未找到结果)')
else:
    print(f'找到 {len(items)} 条结果：')
    print()
    for i, v in enumerate(items[:10], 1):
        print(f'{i:2}. {v[\"title\"]}')
        print(f'    👤 {v[\"channel\"]}  ⏱ {v[\"dur\"]}  👁 {v[\"views\"]}  📅 {v[\"pub\"]}')
        print(f'    🔗 https://www.youtube.com/watch?v={v[\"vid\"]}')
        print()
" 2>&1 || {
    echo "[error] 搜索结果解析失败" >&2
    exit 1
}
