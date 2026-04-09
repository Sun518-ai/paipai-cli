#!/usr/bin/env bash
# main.sh — YouTube 视频信息（Cookie 授权版）
# 特性：TUI 授权引导 + 本地缓存 + Cookie 持久化

set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SKILL_DIR}/lib/cache.sh"
source "${SKILL_DIR}/lib/auth.sh"

VIDEO_ID="${SKILL_ARG_VIDEO_ID:-}"
SEARCH_QUERY="${SKILL_ARG_SEARCH:-}"
LIMIT="${SKILL_ARG_LIMIT:-10}"
NOCACHE="${SKILL_ARG_NOCACHE:-false}"

# 全局 cookie（由 auth 填充）
COOKIE=""

###############################################################################
# 初始化
###############################################################################
init() {
    cache_init

    if ! auth_has_valid; then
        echo ""
        echo "⚠️  未检测到有效授权"
        if [ -t 0 ]; then  # 如果是终端，尝试交互
            auth_interactive
        else
            echo "  💡 非交互模式，请先配置授权："
            echo "  方式1（推荐）："
            echo "    COOKIE='SID=xxx; HSID=yyy; ...' paipai run youtube --video-id xxx"
            echo ""
            echo "  方式2：设置持久化 Cookie"
            echo "    echo 'COOKIE=SID=xxx' >> ~/.config/paipai/youtube-video-info/.cookie"
        fi
    fi

    # 加载 cookie（优先级：环境变量 > 文件）
    COOKIE=$(auth_get_cookie)
}

###############################################################################
# 搜索模式
###############################################################################
do_search() {
    echo "=== 搜索: $SEARCH_QUERY ==="
    echo ""

    local cache_key
    cache_key="search_$(echo "$SEARCH_QUERY" | tr ' ' '_')_${LIMIT}"

    if [ "$NOCACHE" != "true" ]; then
        local cached
        cached=$(cache_get "$(cache_key "$cache_key")" 2>/dev/null || true)
        if [ -n "$cached" ]; then
            echo "📦 使用缓存（无 cache: --nocache 跳过）"
            echo "$cached"
            return 0
        fi
    fi

    local result
    result=$("${SKILL_DIR}/step2_search.sh" 2>&1) || {
        echo "❌ 搜索失败: $result" >&2
        exit 1
    }

    echo "$result"
    echo "$result" | cache_put "$(cache_key "$cache_key")"
}

###############################################################################
# 视频详情模式
###############################################################################
do_video() {
    if [ -z "$VIDEO_ID" ]; then
        echo "❌ 请提供 --video-id 参数" >&2
        echo "示例: paipai run youtube --video-id dQw4w9WgXcQ" >&2
        exit 1
    fi

    echo "=== 视频信息: $VIDEO_ID ==="
    echo ""

    # 检查缓存
    local cache_key
    cache_key="video_${VIDEO_ID}"

    if [ "$NOCACHE" != "true" ]; then
        local cached
        cached=$(cache_get "$(cache_key "$cache_key")" 2>/dev/null || true)
        if [ -n "$cached" ]; then
            echo "📦 使用缓存（无 cache: --nocache 跳过）"
            echo "$cached"
            echo ""
            echo "💡 提示: 使用 --nocache 强制刷新"
            return 0
        fi
    fi

    # Step 1: Player API
    local player_result
    player_result=$("${SKILL_DIR}/step1_player.sh" 2>&1) || true

    # Step 3: Watch (推荐视频)
    local watch_result
    watch_result=$("${SKILL_DIR}/step3_get_watch.sh" 2>&1) || true

    # Step 4: Captions
    local captions_result
    captions_result=$("${SKILL_DIR}/step4_captions.sh" 2>&1) || true

    # 组装输出
    echo "$player_result"
    echo ""
    echo "--- 推荐视频 ---"
    echo "$watch_result"
    echo ""
    echo "--- 字幕 ---"
    echo "$captions_result"

    # 缓存完整输出
    local full_output
    full_output=$(echo "$player_result"; echo ""; echo "--- 推荐视频 ---"; echo "$watch_result"; echo ""; echo "--- 字幕 ---"; echo "$captions_result")
    echo "$full_output" | cache_put "$(cache_key "$cache_key")"
}

###############################################################################
# 主入口
###############################################################################
init

if [ -n "$SEARCH_QUERY" ]; then
    do_search
elif [ -n "$VIDEO_ID" ]; then
    do_video
else
    echo "❌ 请提供 --video-id 或 --search 参数"
    echo ""
    echo "示例："
    echo "  paipai run youtube --video-id dQw4w9WgXcQ"
    echo "  paipai run youtube --search 'python tutorial'"
    echo "  paipai run youtube --video-id dQw4w9WgXcQ --nocache  # 强制刷新"
    exit 1
fi

echo ""
echo "✅ 完成"
