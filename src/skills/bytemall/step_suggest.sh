#!/bin/bash
# 步骤: 获取搜索建议
# 参数: $1 - 关键词

KEYWORD="${1:-}"

if [ -z "$KEYWORD" ]; then
  echo "Error: 缺少关键词参数" >&2
  exit 1
fi

REQUEST_ID=$(uuidgen 2>/dev/null || cat /proc/sys/kernel/random/uuid 2>/dev/null || echo "$(date +%s)-$$")

# 从 Cookie 中提取 token
TOKEN=$(echo "$COOKIE" | tr ';' '\n' | sed 's/^ *//' | grep '^__token=' | head -1 | cut -d= -f2-)

curl -sS --compressed \
  -X POST \
  -H 'Accept: application/json, text/plain, */*' \
  -H 'Content-Type: application/json; charset=UTF-8' \
  -H 'Agw-Js-Conv: str' \
  -H "Authorization: $TOKEN" \
  -H 'x-tt-env: ' \
  -H "X-Request-Id: $REQUEST_ID" \
  -H 'User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/147.0.0.0 Safari/537.36' \
  -H 'Referer: https://www.byte-mall.cn/' \
  -H 'Origin: https://www.byte-mall.cn' \
  -H 'Accept-Language: zh-CN,zh;q=0.9,en;q=0.8' \
  -H 'sec-ch-ua-platform: "macOS"' \
  -H 'sec-ch-ua: "Google Chrome";v="147", "Not.A/Brand";v="8", "Chromium";v="147"' \
  -H 'sec-ch-ua-mobile: ?0' \
  -H 'Sec-Fetch-Site: same-origin' \
  -H 'Sec-Fetch-Mode: cors' \
  -H 'Sec-Fetch-Dest: empty' \
  -H 'Accept-Encoding: gzip, deflate' \
  -H "Cookie: $COOKIE" \
  -d "{\"keywords\":\"$KEYWORD\"}" \
  'https://www.byte-mall.cn/api/product/v1/search/suggest?channel_id=1001'
