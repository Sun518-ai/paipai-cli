#!/usr/bin/env bash
# step4_captions.sh — YouTube Timed Text API: 获取视频字幕
# Usage: bash step4_captions.sh <CAPTION_BASE_URL>
# Env: COOKIE
# CAPTION_BASE_URL: 从 player API 返回的 captions.playerCaptionsTracklistRenderer.captionTracks[].baseUrl 获取
set -euo pipefail

CAPTION_URL="${1:?CAPTION_BASE_URL is required}"

# Append fmt=json3 to get JSON format
if [[ "$CAPTION_URL" == *"?"* ]]; then
  CAPTION_URL="${CAPTION_URL}&fmt=json3"
else
  CAPTION_URL="${CAPTION_URL}?fmt=json3"
fi

curl -sS --compressed \
  -H 'X-YouTube-Client-Name: 1' \
  -H 'X-YouTube-Client-Version: 2.20260325.08.00' \
  -H 'User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36' \
  -H 'Referer: https://www.youtube.com/' \
  -H 'Origin: https://www.youtube.com' \
  -H 'Accept-Language: zh-CN,zh;q=0.9,en;q=0.8' \
  -H 'sec-ch-ua-platform: "macOS"' \
  -H 'device-memory: 8' \
  -H 'sec-ch-ua: "Chromium";v="146", "Not-A.Brand";v="24", "Google Chrome";v="146"' \
  -H 'sec-ch-ua-mobile: ?0' \
  -H 'Accept: */*' \
  -H 'X-Browser-Channel: stable' \
  -H 'X-Browser-Year: 2026' \
  -H 'Sec-Fetch-Site: same-origin' \
  -H 'Sec-Fetch-Mode: cors' \
  -H 'Sec-Fetch-Dest: empty' \
  -H 'Accept-Encoding: gzip, deflate' \
  -H 'Cookie: '"$COOKIE" \
  "$CAPTION_URL"
