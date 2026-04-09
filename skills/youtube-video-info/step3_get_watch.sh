#!/usr/bin/env bash
# step3_get_watch.sh — YouTube Get Watch API: 获取视频观看页数据（推荐、评论等）
# Usage: bash step3_get_watch.sh <VIDEO_ID>
# Env: COOKIE, AUTHORIZATION
set -euo pipefail

VIDEO_ID="${1:?VIDEO_ID is required}"

BODY=$(cat <<EOF
{
  "context": {
    "client": {
      "hl": "zh-CN",
      "gl": "SG",
      "clientName": "WEB",
      "clientVersion": "2.20260325.08.00",
      "osName": "Macintosh",
      "osVersion": "10_15_7",
      "platform": "DESKTOP",
      "clientFormFactor": "UNKNOWN_FORM_FACTOR",
      "userAgent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36,gzip(gfe)"
    },
    "user": {
      "lockedSafetyMode": false
    },
    "request": {
      "useSsl": true,
      "internalExperimentFlags": [],
      "consistencyTokenJars": []
    }
  },
  "videoId": "${VIDEO_ID}",
  "racyCheckOk": false,
  "contentCheckOk": false
}
EOF
)

curl -sS --compressed \
  -X POST \
  -H 'Content-Type: application/json' \
  -H 'Authorization: '"${AUTHORIZATION:-}" \
  -H 'X-Goog-AuthUser: 0' \
  -H 'X-Origin: https://www.youtube.com' \
  -H 'X-Youtube-Bootstrap-Logged-In: true' \
  -H 'X-Youtube-Client-Name: 1' \
  -H 'X-Youtube-Client-Version: 2.20260325.08.00' \
  -H 'User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36' \
  -H 'Referer: https://www.youtube.com/watch?v='"$VIDEO_ID" \
  -H 'Origin: https://www.youtube.com' \
  -H 'Accept-Language: zh-CN,zh;q=0.9,en;q=0.8' \
  -H 'sec-ch-ua-platform: "macOS"' \
  -H 'device-memory: 8' \
  -H 'sec-ch-ua: "Chromium";v="146", "Not-A.Brand";v="24", "Google Chrome";v="146"' \
  -H 'sec-ch-ua-mobile: ?0' \
  -H 'sec-ch-ua-arch: "arm"' \
  -H 'Accept: */*' \
  -H 'X-Browser-Channel: stable' \
  -H 'X-Browser-Year: 2026' \
  -H 'Sec-Fetch-Site: same-origin' \
  -H 'Sec-Fetch-Mode: same-origin' \
  -H 'Sec-Fetch-Dest: empty' \
  -H 'Accept-Encoding: gzip, deflate' \
  -H 'Cookie: '"$COOKIE" \
  -d "$BODY" \
  'https://www.youtube.com/youtubei/v1/get_watch?prettyPrint=false'
