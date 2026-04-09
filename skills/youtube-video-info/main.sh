#!/usr/bin/env bash
# main.sh — YouTube Video Info Skill
# Orchestrates: player API → captions → get_watch → search
# Usage:
#   bash main.sh --video-id <VIDEO_ID> [--caption-lang <LANG>]
#   bash main.sh --search "<QUERY>"
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

###############################################################################
# Cookie & Auth Header Persistence
###############################################################################
SKILL_NAME="youtube-video-info"
SKILL_DOMAIN="www.youtube.com"

# Support both Mira NAS path patterns
if [ -n "${MIRA_CURRENT_USERID:-}" ]; then
  USERDATA_DIR="/opt/tiger/mira_nas/userdata/$MIRA_CURRENT_USERID"
else
  USERDATA_DIR="${SCRIPT_DIR}/.userdata"
fi
MIRA_COOKIE_DIR="$USERDATA_DIR/$SKILL_NAME"
COOKIE_FILE="$MIRA_COOKIE_DIR/.cookie"
DOMAIN_COOKIE_FILE="$USERDATA_DIR/$SKILL_DOMAIN/.cookie"

save_cookie() {
  local val="$1"
  mkdir -p "$MIRA_COOKIE_DIR" 2>/dev/null || true
  if echo "$val" > "$COOKIE_FILE" 2>/dev/null; then
    return 0
  fi
  echo "[warn] Cookie 持久化失败，仅在本次会话中使用" >&2
  return 1
}

load_cookie() {
  if [ -f "$COOKIE_FILE" ] && [ -s "$COOKIE_FILE" ]; then
    cat "$COOKIE_FILE"; return
  fi
  if [ -f "$DOMAIN_COOKIE_FILE" ] && [ -s "$DOMAIN_COOKIE_FILE" ]; then
    cat "$DOMAIN_COOKIE_FILE"; return
  fi
  echo "${COOKIE:-}"
}

if [ -n "${COOKIE:-}" ]; then
  save_cookie "$COOKIE"
else
  COOKIE="$(load_cookie)"
fi

if [ -z "$COOKIE" ]; then
  echo "Cookie 缺失，请通过以下链接完成授权并获取 Cookie（安装了 Mira 插件会自动提取）："
  echo "https://www.youtube.com/watch?mira_skill_cookie=1&MIRA_ORIGIN_URL=__MIRA_ORIGIN_URL__"
  echo "或在对话中直接提供 Cookie（如 COOKIE=xxx），将自动持久化。"
  exit 1
fi
export COOKIE

# Auth headers persistence
AUTH_HEADERS_FILE="$MIRA_COOKIE_DIR/.auth_headers"
DOMAIN_AUTH_HEADERS_FILE="$USERDATA_DIR/$SKILL_DOMAIN/.auth_headers"

_AUTH_FILE=""
if [ -f "$AUTH_HEADERS_FILE" ] && [ -s "$AUTH_HEADERS_FILE" ]; then
  _AUTH_FILE="$AUTH_HEADERS_FILE"
elif [ -f "$DOMAIN_AUTH_HEADERS_FILE" ] && [ -s "$DOMAIN_AUTH_HEADERS_FILE" ]; then
  _AUTH_FILE="$DOMAIN_AUTH_HEADERS_FILE"
fi
if [ -n "$_AUTH_FILE" ]; then
  AUTHORIZATION="${AUTHORIZATION:-$(jq -r '.AUTHORIZATION // empty' "$_AUTH_FILE" 2>/dev/null || true)}"
fi

# Save auth headers if provided via env
if [ -n "${AUTHORIZATION:-}" ]; then
  mkdir -p "$MIRA_COOKIE_DIR" 2>/dev/null || true
  printf '{"AUTHORIZATION": "%s"}\n' "$AUTHORIZATION" > "$AUTH_HEADERS_FILE" 2>/dev/null || true
fi

export AUTHORIZATION="${AUTHORIZATION:-}"

###############################################################################
# Parse arguments
###############################################################################
VIDEO_ID=""
SEARCH_QUERY=""
CAPTION_LANG="en"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --video-id)
      VIDEO_ID="$2"; shift 2 ;;
    --search)
      SEARCH_QUERY="$2"; shift 2 ;;
    --caption-lang)
      CAPTION_LANG="$2"; shift 2 ;;
    *)
      echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

# Default video ID if none provided and no search
if [ -z "$VIDEO_ID" ] && [ -z "$SEARCH_QUERY" ]; then
  VIDEO_ID="JS1KKbbwZWw"
fi

###############################################################################
# Mode 1: Search
###############################################################################
if [ -n "$SEARCH_QUERY" ]; then
  echo "=== 搜索: $SEARCH_QUERY ==="
  SEARCH_RESULT=$(bash "$SCRIPT_DIR/step2_search.sh" "$SEARCH_QUERY" 2>&1) || true
  HTTP_ERR=$(echo "$SEARCH_RESULT" | jq -r '.error.code // empty' 2>/dev/null || true)
  if [ -n "$HTTP_ERR" ] && [ "$HTTP_ERR" != "null" ]; then
    echo "[error] Search API 返回错误 code=$HTTP_ERR" >&2
    echo "$SEARCH_RESULT" | jq -r '.error.message // .' 2>/dev/null || echo "$SEARCH_RESULT"
    exit 1
  fi

  # Extract search results
  echo "$SEARCH_RESULT" | jq -r '
    [.contents.twoColumnSearchResultsRenderer.primaryContents.sectionListRenderer.contents[].itemSectionRenderer.contents[]? |
      select(.videoRenderer) |
      .videoRenderer |
      {
        videoId: .videoId,
        title: (.title.runs[0].text // "N/A"),
        channel: (.ownerText.runs[0].text // "N/A"),
        viewCount: (.viewCountText.simpleText // "N/A"),
        publishedTime: (.publishedTimeText.simpleText // "N/A"),
        duration: (.lengthText.simpleText // "N/A")
      }
    ] | .[:10]' 2>/dev/null || echo "$SEARCH_RESULT" | head -200

  # If no video ID, exit after search
  if [ -z "$VIDEO_ID" ]; then
    exit 0
  fi
fi

###############################################################################
# Mode 2: Video Info
###############################################################################
echo "=== 获取视频信息: $VIDEO_ID ==="

# Step 1: Player API
echo "[step1] Calling Player API..."
PLAYER_RESULT=$(bash "$SCRIPT_DIR/step1_player.sh" "$VIDEO_ID" 2>&1) || true

# Check for errors
PLAY_STATUS=$(echo "$PLAYER_RESULT" | jq -r '.playabilityStatus.status // empty' 2>/dev/null || true)
if [ "$PLAY_STATUS" = "ERROR" ]; then
  echo "[error] Player API 错误: status=$PLAY_STATUS" >&2
  echo "$PLAYER_RESULT" | jq -r '.playabilityStatus.reason // .' 2>/dev/null || echo "$PLAYER_RESULT" | head -200
  exit 1
fi
if [ "$PLAY_STATUS" = "LOGIN_REQUIRED" ]; then
  echo "[warn] 该视频需要登录才能访问完整信息 (LOGIN_REQUIRED)" >&2
  echo "[warn] 当前 Cookie 可能已过期或无效，部分数据（字幕、推荐）可能不可用" >&2
  REASON=$(echo "$PLAYER_RESULT" | jq -r '.playabilityStatus.reason // ""' 2>/dev/null || true)
  [ -n "$REASON" ] && echo "[warn] 原因: $REASON" >&2
fi

# Extract video metadata
HAS_DETAILS=$(echo "$PLAYER_RESULT" | jq -r '.videoDetails.videoId // empty' 2>/dev/null || true)

echo ""
echo "--- 视频元数据 ---"
if [ -n "$HAS_DETAILS" ]; then
  echo "$PLAYER_RESULT" | jq '{
    videoId: .videoDetails.videoId,
    title: .videoDetails.title,
    author: .videoDetails.author,
    channelId: .videoDetails.channelId,
    lengthSeconds: .videoDetails.lengthSeconds,
    viewCount: .videoDetails.viewCount,
    description: (.videoDetails.shortDescription // "N/A"),
    keywords: (.videoDetails.keywords // []),
    isPrivate: .videoDetails.isPrivate,
    isLiveContent: .videoDetails.isLiveContent,
    thumbnail: (.videoDetails.thumbnail.thumbnails[-1].url // "N/A"),
    publishDate: (.microformat.playerMicroformatRenderer.publishDate // "N/A"),
    category: (.microformat.playerMicroformatRenderer.category // "N/A")
  }' 2>/dev/null
else
  echo "(videoDetails 为空，该视频可能不存在、已下架或需要登录)"
  echo "$PLAYER_RESULT" | jq -r '.playabilityStatus // .' 2>/dev/null | head -20
fi

# Step 2: Try to get captions
echo ""
echo "--- 字幕信息 ---"
CAPTION_TRACKS=$(echo "$PLAYER_RESULT" | jq -r '.captions.playerCaptionsTracklistRenderer.captionTracks // []' 2>/dev/null || echo "[]")
TRACK_COUNT=$(echo "$CAPTION_TRACKS" | jq 'length' 2>/dev/null || echo "0")

if [ "$TRACK_COUNT" -gt 0 ] 2>/dev/null; then
  echo "可用字幕轨道:"
  echo "$CAPTION_TRACKS" | jq -r '.[] | "  - [\(.languageCode)] \(.name.simpleText // "N/A") (kind: \(.kind // "manual"))"' 2>/dev/null || true

  # Find the requested language or fallback to first track
  CAPTION_URL=$(echo "$CAPTION_TRACKS" | jq -r --arg lang "$CAPTION_LANG" '
    (map(select(.languageCode == $lang)) | first // .[0]).baseUrl // empty
  ' 2>/dev/null || true)

  if [ -n "$CAPTION_URL" ]; then
    echo ""
    echo "[step4] 获取字幕 (lang=$CAPTION_LANG)..."
    CAPTION_RESULT=$(bash "$SCRIPT_DIR/step4_captions.sh" "$CAPTION_URL" 2>&1) || true
    # Extract caption text
    echo "$CAPTION_RESULT" | jq -r '
      .events[]? |
      select(.segs) |
      (.tStartMs / 1000 | floor | "\(. / 60 | floor):\(. % 60 | tostring | if length == 1 then "0" + . else . end)") as $ts |
      "\($ts) \([.segs[]?.utf8] | join(""))"
    ' 2>/dev/null | head -50 || true
    TOTAL_LINES=$(echo "$CAPTION_RESULT" | jq '[.events[]? | select(.segs)] | length' 2>/dev/null || echo "0")
    echo "... (共 $TOTAL_LINES 条字幕)"
  else
    echo "未找到 lang=$CAPTION_LANG 的字幕"
  fi
else
  echo "该视频无字幕或无法获取字幕信息"
fi

# Step 3: Get Watch (recommendations)
echo ""
echo "--- 推荐视频 ---"
echo "[step3] Calling Get Watch API..."
WATCH_RESULT=$(bash "$SCRIPT_DIR/step3_get_watch.sh" "$VIDEO_ID" 2>&1) || true

# Try to extract recommended videos from secondaryResults
echo "$WATCH_RESULT" | jq -r '
  [.. | .compactVideoRenderer? // empty |
    {
      videoId: .videoId,
      title: (.title.simpleText // (.title.runs[0].text // "N/A")),
      channel: (.longBylineText.runs[0].text // "N/A"),
      viewCount: (.viewCountText.simpleText // "N/A"),
      duration: (.lengthText.simpleText // "N/A")
    }
  ] | unique_by(.videoId) | .[:10]
' 2>/dev/null || echo "(推荐视频解析失败，可能返回格式变化)"

echo ""
echo "=== 完成 ==="
