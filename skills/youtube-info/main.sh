#!/usr/bin/env bash
# main.sh — YouTube Data API v3（CLI 友好，无需浏览器登录）
# 使用方式:
#   YOUTUBE_API_KEY=xxx paipai run youtube-info --video-id xxx
#   echo 'YOUTUBE_API_KEY=xxx' >> ~/.paipairc

set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

VIDEO_ID="${SKILL_ARG_VIDEO_ID:-}"
SEARCH_QUERY="${SKILL_ARG_SEARCH:-}"
LIMIT="${SKILL_ARG_LIMIT:-10}"

###############################################################################
# 获取 API Key（环境变量 > ~/.paipairc 配置文件）
###############################################################################
get_api_key() {
    local key="${YOUTUBE_API_KEY:-}"
    if [ -n "$key" ]; then echo "$key"; return; fi

    local rc="${HOME}/.paipairc"
    if [ -f "$rc" ]; then
        grep '^YOUTUBE_API_KEY=' "$rc" 2>/dev/null | head -1 | cut -d= -f2 | tr -d '"' | tr -d "'" | tr -d ' ' || true
    fi
}

show_no_key_help() {
    echo "❌ 缺少 YOUTUBE_API_KEY"
    echo ""
    echo "📋 申请 API Key（免费）："
    echo "   1. 访问 https://console.cloud.google.com/apis/credentials"
    echo "   2. 创建项目 → 启用 YouTube Data API v3"
    echo "   3. 创建 API Key → 复制"
    echo ""
    echo "💾 使用方式："
    echo "   # 方式1: 环境变量（当前会话有效）"
    echo "   YOUTUBE_API_KEY=你的key paipai run youtube-info --video-id dQw4w9WgXcQ"
    echo ""
    echo "   # 方式2: 写入配置文件（永久生效，推荐）"
    echo "   echo 'YOUTUBE_API_KEY=你的key' >> ~/.paipairc"
    echo "   paipai run youtube-info --video-id dQw4w9WgXcQ"
    echo ""
    echo "📊 免费配额：10,000 units/天（视频详情=1 unit，搜索=100 units）"
}

###############################################################################
# 搜索模式
###############################################################################
run_search() {
    echo "=== 搜索: $SEARCH_QUERY ==="
    echo ""

    local encoded_q
    encoded_q=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$SEARCH_QUERY'))")
    local url="https://www.googleapis.com/youtube/v3/search?part=snippet&q=${encoded_q}&type=video&maxResults=${LIMIT}&key=${API_KEY}"

    local result
    result=$(curl -s --connect-timeout 5 --max-time 10 "$url") || {
        echo "❌ 网络请求失败" >&2
        exit 1
    }

    local error_msg
    error_msg=$(echo "$result" | python3 -c "
import json, sys
d = json.load(sys.stdin)
if 'error' in d:
    print(d['error'].get('message', str(d['error'])))
" 2>/dev/null || true)

    if [ -n "$error_msg" ]; then
        echo "❌ API 错误: $error_msg" >&2
        exit 1
    fi

    local count
    count=$(echo "$result" | python3 -c "import json,sys; d=json.load(sys.stdin); print(len(d.get('items',[])))" 2>/dev/null || echo "0")
    echo "✅ 找到 $count 条结果："
    echo ""

    echo "$result" | python3 -c "
import json, sys, html
d = json.load(sys.stdin)
for i, item in enumerate(d.get('items', []), 1):
    vid = item['id']['videoId']
    sn = item['snippet']
    title = html.unescape(sn.get('title','N/A'))
    channel = html.unescape(sn.get('channelTitle','N/A'))
    pub = sn.get('publishedAt','')[:10]
    desc = html.unescape(sn.get('description',''))[:80]
    print(f'{i:2}. {title}')
    print(f'    👤 {channel}  📅 {pub}')
    print(f'    🔗 https://www.youtube.com/watch?v={vid}')
    if desc:
        print(f'    💬 {desc}...')
    print()
"
}

###############################################################################
# 视频详情模式
###############################################################################
run_video() {
    echo "=== 视频信息: $VIDEO_ID ==="
    echo ""

    local url="https://www.googleapis.com/youtube/v3/videos?part=snippet,contentDetails,statistics&id=${VIDEO_ID}&key=${API_KEY}"

    local result
    result=$(curl -s --connect-timeout 5 --max-time 10 "$url") || {
        echo "❌ 网络请求失败" >&2
        exit 1
    }

    local error_msg
    error_msg=$(echo "$result" | python3 -c "
import json, sys
d = json.load(sys.stdin)
if 'error' in d:
    print(d['error'].get('message', str(d['error'])))
" 2>/dev/null || true)

    if [ -n "$error_msg" ]; then
        echo "❌ API 错误: $error_msg" >&2
        exit 1
    fi

    local total
    total=$(echo "$result" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('pageInfo',{}).get('totalResults',0))" 2>/dev/null || echo "0")

    if [ "$total" = "0" ]; then
        echo "❌ 未找到视频: $VIDEO_ID" >&2
        exit 1
    fi

    echo "$result" | python3 -c "
import json, sys, html, re

d = json.load(sys.stdin)
items = d.get('items', [])
if not items:
    print('❌ 未找到视频')
    sys.exit(1)

item = items[0]
sn = item.get('snippet', {})
cs = item.get('contentDetails', {})
st = item.get('statistics', {})

vid = item.get('id', 'N/A')
title = html.unescape(sn.get('title', 'N/A'))
channel = html.unescape(sn.get('channelTitle', 'N/A'))
desc = html.unescape(sn.get('description', '') or '')
tags = ', '.join(sn.get('tags', [])[:5])
pub = sn.get('publishedAt', '')[:10]

def fmt_dur(pt):
    if not pt: return 'N/A'
    h = re.findall(r'(\d+)H', pt)
    m = re.findall(r'(\d+)M', pt)
    s = re.findall(r'(\d+)S', pt)
    h = int(h[0]) if h else 0
    m = int(m[0]) if m else 0
    s = int(s[0]) if s else 0
    if h: return f'{h}:{m:02d}:{s:02d}'
    return f'{m}:{s:02d}'

dur = fmt_dur(cs.get('duration', ''))

def fmt(n):
    try:
        n = int(n)
        if n >= 1e9: return f'{n/1e9:.1f}B'
        if n >= 1e6: return f'{n/1e6:.1f}M'
        if n >= 1e3: return f'{n/1e3:.1f}K'
        return str(n)
    except: return str(n)

views = st.get('viewCount', '0')
likes = st.get('likeCount', '0')
comments = st.get('commentCount', '0')

print(f'📹 标题: {title}')
print(f'👤 频道: {channel}')
print(f'🆔 视频ID: {vid}')
print(f'⏱ 时长: {dur}')
print(f'👁 观看: {fmt(views)}')
if likes and likes != '0': print(f'👍 点赞: {fmt(likes)}')
if comments and comments != '0': print(f'💬 评论: {fmt(comments)}')
print(f'📅 发布: {pub}')
if tags: print(f'🏷 标签: {tags}')
print()
print(f'🔗 链接: https://www.youtube.com/watch?v={vid}')
print()
print('📝 简介:')
lines = [l for l in desc.split('\n') if l.strip()]
for line in lines[:8]:
    print('  ' + line[:200])
if len(lines) > 8:
    print('  ... (省略)')
"
    echo ""
    echo "💡 提示：字幕获取需 OAuth，API Key 模式不可用"
    echo "   如需字幕，使用 Cookie 模式: youtube-video-info skill"
}

###############################################################################
# 主逻辑
###############################################################################
API_KEY=$(get_api_key)

if [ -z "$API_KEY" ]; then
    show_no_key_help
    exit 1
fi

echo "🔑 API Key: ${API_KEY:0:8}...（已设置）"
echo ""

if [ -n "$SEARCH_QUERY" ]; then
    run_search
else
    if [ -z "$VIDEO_ID" ]; then
        echo "❌ 请提供 --video-id 或 --search 参数"
        echo ""
        echo "示例："
        echo "  paipai run youtube-info --video-id dQw4w9WgXcQ"
        echo "  paipai run youtube-info --search 'python tutorial'"
        exit 1
    fi
    run_video
fi

echo ""
echo "✅ 完成"
