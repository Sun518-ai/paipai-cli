#!/usr/bin/env bash
# lib/cache.sh — 本地缓存管理
# 提供 get/put 缓存接口，TTL 默认 3600 秒

CACHE_DIR="${PAIPAI_CACHE_DIR:-${HOME}/.cache/paipai/youtube}"
CACHE_TTL="${PAIPAI_CACHE_TTL:-3600}"  # 秒

cache_init() {
    mkdir -p "$CACHE_DIR" 2>/dev/null || {
        echo "[cache] 警告: 无法创建缓存目录 $CACHE_DIR" >&2
        return 1
    }
}

# 读取缓存，返回 0 如果命中（输出内容），返回 1 如果未命中或过期
cache_get() {
    local key="$1"
    local file="${CACHE_DIR}/${key}.json"
    local now
    now=$(date +%s)

    if [ ! -f "$file" ]; then
        return 1
    fi

    # 检查 TTL
    if [ -n "$CACHE_TTL" ] && [ "$CACHE_TTL" -gt 0 ]; then
        local mtime
        mtime=$(stat -f %m "$file" 2>/dev/null || stat -c %Y "$file" 2>/dev/null || echo "$now")
        local age=$((now - mtime))
        if [ "$age" -gt "$CACHE_TTL" ]; then
            [ "${PAIPAI_DEBUG:-}" = "1" ] && echo "[cache] 过期: $key (${age}s > ${CACHE_TTL}s)" >&2
            return 1
        fi
    fi

    cat "$file"
    return 0
}

# 写入缓存
cache_put() {
    local key="$1"
    local content
    content=$(cat)
    local file="${CACHE_DIR}/${key}.json"

    cache_init || return 1

    printf '%s' "$content" > "$file"
    [ "${PAIPAI_DEBUG:-}" = "1" ] && echo "[cache] 写入: $key (${#content} bytes)" >&2
}

# 清除指定 key 的缓存
cache_rm() {
    local key="$1"
    rm -f "${CACHE_DIR}/${key}.json"
}

# 清除所有缓存
cache_clear() {
    rm -rf "$CACHE_DIR"/* 2>/dev/null
    echo "缓存已清除: $CACHE_DIR"
}

# 打印缓存统计
cache_stats() {
    if [ ! -d "$CACHE_DIR" ]; then
        echo "缓存目录不存在: $CACHE_DIR"
        return
    fi

    local count
    local total_size
    count=$(find "$CACHE_DIR" -name "*.json" 2>/dev/null | wc -l | tr -d ' ')
    total_size=$(du -sh "$CACHE_DIR" 2>/dev/null | cut -f1 || echo "?")

    echo "📦 缓存目录: $CACHE_DIR"
    echo "   文件数: $count"
    echo "   总大小: $total_size"
    echo "   TTL: ${CACHE_TTL}s"
}

# 缓存 key 生成：safe filename
cache_key() {
    # 简单 hash：把特殊字符替换掉
    echo "$1" | tr '/?&=:' '_'
}
