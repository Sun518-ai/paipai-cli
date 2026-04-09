#!/usr/bin/env bash
# step1_player.sh — YouTube Player API（Cookie 授权）
# 获取视频元数据：标题/频道/时长/观看数等

set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SKILL_DIR}/lib/auth.sh"
source "${SKILL_DIR}/lib/cache.sh"

VIDEO_ID="${SKILL_ARG_VIDEO_ID:-}"
COOKIE=$(auth_get_cookie)

if [ -z "$VIDEO_ID" ]; then
    echo "[error] video-id is required" >&2
    exit 1
fi

if [ -z "$COOKIE" ]; then
    echo "[error] 未设置 Cookie，无法获取视频信息" >&2
    echo "请先运行: paipai run youtube 进行授权设置" >&2
    exit 1
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
    'videoId': '$VIDEO_ID',
    'playbackContext': {'contentPlaybackContext': {'signatureTimestamp': 20189}},
    'racyCheckOk': False, 'contentCheckOk': False
}))
")

RESULT=$(curl -s --connect-timeout 8 --max-time 15 \
    -X POST \
    -H 'Content-Type: application/json' \
    -H "Cookie: $COOKIE" \
    -H 'X-Youtube-Client-Name: 1' \
    -H 'X-Youtube-Client-Version: 2.20200618.00.00' \
    -H 'Origin: https://www.youtube.com' \
    -H 'Referer: https://www.youtube.com/' \
    -d "$BODY" \
    "https://www.youtube.com/youtubei/v1/player?prettyPrint=false" 2>&1) || {
    echo "[error] 网络请求失败" >&2
    exit 1
}

# 解析 JSON 并格式化输出
echo "$RESULT" | python3 -c "
import json, sys, re, html

d = json.load(sys.stdin)

status = d.get('playabilityStatus', {}).get('status', '')
if status == 'ERROR':
    reason = d.get('playabilityStatus', {}).get('reason', '未知错误')
    print(f'[error] 播放错误: {reason}')
    sys.exit(1)

if status == 'LOGIN_REQUIRED':
    print('[warn] 该视频需要登录才能访问完整信息')
    reason = d.get('playabilityStatus', {}).get('reason', '')
    if reason:
        print(f'  原因: {reason}')

vd = d.get('videoDetails', {})
if not vd:
    print('[error] 无法获取视频信息，可能 Cookie 已过期')
    sys.exit(1)

def u(t): return html.unescape(str(t)) if t else 'N/A'
def fmt(n):
    try:
        n = int(n)
        if n >= 1e9: return f'{n/1e9:.1f}B'
        if n >= 1e6: return f'{n/1e6:.1f}M'
        if n >= 1e3: return f'{n/1e3:.1f}K'
        return str(n)
    except: return str(n)

def dur(s):
    try:
        s = int(s)
        h = s // 3600; m = (s % 3600) // 60; ss = s % 60
        if h: return f'{h}:{m:02d}:{ss:02d}'
        return f'{m}:{ss:02d}'
    except: return s

meta = d.get('microformat', {}).get('playerMicroformatRenderer', {})
tags = ', '.join(vd.get('keywords', [])[:5])

print(f'📹 标题:   {u(vd.get(\"title\", \"N/A\"))}')
print(f'👤 频道:   {u(vd.get(\"author\", \"N/A\"))}')
print(f'🆔 视频ID: {vd.get(\"videoId\", \"N/A\")}')
print(f'⏱ 时长:   {dur(vd.get(\"lengthSeconds\", 0))}')
print(f'👁 观看:   {fmt(vd.get(\"viewCount\", 0))}')
if vd.get('likes'):
    print(f'👍 点赞:   {fmt(vd.get(\"likes\", 0))}')
print(f'📅 发布:   {meta.get(\"publishDate\", \"N/A\")}')
print(f'🏷 标签:   {tags if tags else \"无\"}')
print()
print(f'🔗 链接:   https://www.youtube.com/watch?v={vd.get(\"videoId\", \"\")}')
print()
print('📝 简介:')
desc = u(vd.get('shortDescription', '') or ''
for line in desc.split('\n')[:8]:
    if line.strip():
        print('  ' + line[:200])
if len(desc.split('\n')) > 8:
    print('  ... (省略)')
" 2>&1 || {
    echo "[error] 解析失败，可能是 Cookie 无效" >&2
    exit 1
}
