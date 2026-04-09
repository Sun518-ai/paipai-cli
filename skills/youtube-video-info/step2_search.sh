#!/usr/bin/env bash
# step2_search.sh — YouTube Search API: 搜索视频
# Usage: bash step2_search.sh <SEARCH_QUERY>
# Env: COOKIE, AUTHORIZATION
set -euo pipefail

SEARCH_QUERY="${1:?SEARCH_QUERY is required}"

# URL-encode search query safely using sys.argv (no shell injection)
ENCODED_QUERY=$(python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.argv[1]))" "$SEARCH_QUERY")

# Build JSON body safely using python3 (handles special chars in query)
BODY=$(python3 -c "
import json, sys
body = {
    'context': {
        'client': {
            'hl': 'zh-CN',
            'gl': 'SG',
            'clientName': 'WEB',
            'clientVersion': '2.20260325.08.00',
            'osName': 'Macintosh',
            'osVersion': '10_15_7',
            'platform': 'DESKTOP',
            'clientFormFactor': 'UNKNOWN_FORM_FACTOR',
            'userAgent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36,gzip(gfe)'
        },
        'user': {'lockedSafetyMode': False},
        'request': {
            'useSsl': True,
            'internalExperimentFlags': [],
            'consistencyTokenJars': []
        }
    },
    'query': sys.argv[1]
}
print(json.dumps(body))
" "$SEARCH_QUERY")

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
  -H 'Referer: https://www.youtube.com/results?search_query='"$ENCODED_QUERY" \
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
  'https://www.youtube.com/youtubei/v1/search?prettyPrint=false'
