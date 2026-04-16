#!/bin/bash
# 步骤: 获取用户地址列表

REQUEST_ID=$(uuidgen 2>/dev/null || cat /proc/sys/kernel/random/uuid 2>/dev/null || echo "$(date +%s)-$$")

# 从 Cookie 中提取 token
TOKEN=$(echo "$COOKIE" | tr ';' '\n' | sed 's/^ *//' | grep '^__token=' | head -1 | cut -d= -f2-)

curl -sS --compressed \
  -H "X-Request-Id: $REQUEST_ID" \
  -H "Authorization: $TOKEN" \
  -H 'sec-ch-ua-platform: "macOS"' \
  -H 'sec-ch-ua: "Google Chrome";v="147", "Not.A/Brand";v="8", "Chromium";v="147"' \
  -H 'sec-ch-ua-mobile: ?0' \
  -H 'Agw-Js-Conv: str' \
  -H 'x-tt-env: ' \
  -H 'User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/147.0.0.0 Safari/537.36' \
  -H 'Accept: application/json, text/plain, */*' \
  -H 'Sec-Fetch-Site: same-origin' \
  -H 'Sec-Fetch-Mode: cors' \
  -H 'Sec-Fetch-Dest: empty' \
  -H 'Referer: https://www.byte-mall.cn/' \
  -H 'Accept-Encoding: gzip, deflate' \
  -H 'Accept-Language: zh-CN,zh;q=0.9,en;q=0.8' \
  -H "Cookie: $COOKIE" \
  'https://www.byte-mall.cn/api/user/v1/address/list?channel_id=1001'
