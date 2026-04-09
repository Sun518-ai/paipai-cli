#!/usr/bin/env bash
# step2_search.sh — YouTube 搜索（Mock 演示模式）
# Usage: bash step2_search.sh

QUERY="${SKILL_ARG_SEARCH:-}"

if [ -z "$QUERY" ]; then
  echo "[info] no search query provided (use --search keyword)" >&2
  exit 0
fi

echo "=== 搜索: $QUERY ==="
echo "[info] Mock 演示模式"
echo ""

python3 -c "
import html, urllib.parse, json

q = '''$QUERY'''
vid = 'dQw4w9WgXcQ'
title = f'Demo Video about {q}'
results = [
    {'title': f'【{q}】最新热门视频第一期', 'author': 'Demo Author 1', 'vid': vid, 'dur': '10:30', 'views': '52.3K'},
    {'title': f'{q} - 完整教程', 'author': 'Demo Author 2', 'vid': 'JS1KKbbwZWw', 'dur': '05:22', 'views': '128K'},
    {'title': f'{q} 趣味解说', 'author': 'Demo Author 3', 'vid': 'jNQXAC9IVRw', 'dur': '08:45', 'views': '999K'},
    {'title': f'关于{q}的10个秘密', 'author': 'Demo Author 4', 'vid': '9bZkp7q19f0', 'dur': '12:01', 'views': '2.1M'},
    {'title': f'{q} 终极版', 'author': 'Demo Author 5', 'vid': vid, 'dur': '03:33', 'views': '1.2M'},
]
print(f'搜索 \"{q}\" 找到 {len(results)} 条结果：\n')
for i, r in enumerate(results, 1):
    print(f'{i:2}. {r[\"title\"]}')
    print(f'    👤 {r[\"author\"]}  ⏱ {r[\"dur\"]}  👁 {r[\"views\"]}')
    print(f'    🔗 https://www.youtube.com/watch?v={r[\"vid\"]}')
    print()
print('[demo] 真实搜索需要 Cookie')
"
