#!/usr/bin/env bash
# lib/auth.sh — TUI 授权管理（Cookie 持久化 + OAuth 回调）
# 两种模式：
#   1. 直接粘贴 Cookie（最简单）
#   2. OAuth 回调（本机起 HTTP server 完成授权）

AUTH_DIR="${HOME}/.config/paipai/youtube-video-info"
AUTH_COOKIE_FILE="${AUTH_DIR}/.cookie"
AUTH_TOKEN_FILE="${AUTH_DIR}/.auth_headers"
AUTH_CONFIG_FILE="${AUTH_DIR}/config.sh"

auth_init() {
    mkdir -p "$AUTH_DIR" 2>/dev/null || {
        echo "[auth] 错误: 无法创建配置目录 $AUTH_DIR" >&2
        return 1
    }
    chmod 700 "$AUTH_DIR" 2>/dev/null || true
}

# 检查是否已有有效认证
auth_has_valid() {
    auth_init || return 1
    if [ -f "$AUTH_COOKIE_FILE" ] && [ -s "$AUTH_COOKIE_FILE" ]; then
        return 0
    fi
    return 1
}

# 显示 TUI 授权引导
auth_tui() {
    auth_init

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  🎬 YouTube 授权设置"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "  请选择授权方式："
    echo ""
    echo "  1️⃣  直接粘贴 Cookie（最简单，推荐）"
    echo "  2️⃣  OAuth 浏览器授权（本机自动完成）"
    echo "  3️⃣  查看当前授权状态"
    echo "  4️⃣  清除授权"
    echo "  0️⃣  跳过（使用公共 API 降级）"
    echo ""
    printf "  请输入选项 [1-4, 0]: "
}

# 交互式选择授权方式
auth_interactive() {
    local choice

    while true; do
        auth_tui
        read -r choice
        echo ""

        case "$choice" in
            1) auth_paste_cookie; return $? ;;
            2) auth_oauth; return $? ;;
            3) auth_status; return 0 ;;
            4) auth_clear; echo "  ✅ 授权已清除"; return 0 ;;
            0) echo "  跳过授权，使用公共 API 降级"; return 0 ;;
            *) echo "  无效选项，请重试"; echo "" ;;
        esac
    done
}

# 方式1: 粘贴 Cookie
auth_paste_cookie() {
    echo ""
    echo "  📋 Cookie 获取方法："
    echo ""
    echo "  1. 打开 Chrome/Edge，登录 YouTube"
    echo "  2. 按 F12 → Application → Cookies → youtube.com"
    echo "  3. 复制所有 Cookie，格式: key1=value1; key2=value2; ..."
    echo "  4. 或安装 Cookie-Editor 插件导出"
    echo ""
    echo "  请粘贴 Cookie（回车结束）："
    echo -n "  > "
    local cookie
    cookie=$(cat)
    cookie=$(echo "$cookie" | tr -d '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

    if [ -z "$cookie" ]; then
        echo "  ❌ Cookie 不能为空"
        return 1
    fi

    auth_init || return 1
    printf '%s' "$cookie" > "$AUTH_COOKIE_FILE"
    chmod 600 "$AUTH_COOKIE_FILE" 2>/dev/null || true

    echo "  ✅ Cookie 已保存（有效期请自行注意）"
    echo ""
    echo "  💡 提示: Cookie 可能会过期，过期后请重新粘贴"

    # 验证一下
    echo ""
    echo "  验证 Cookie 是否有效..."
    local test_result
    test_result=$(curl -s --connect-timeout 5 --max-time 10 \
        -H "Cookie: $cookie" \
        "https://www.youtube.com/youtubei/v1/player?prettyPrint=false" \
        -d '{"context":{"client":{"hl":"zh-CN","clientName":"WEB","clientVersion":"2.20200618.00.00"}},"videoId":"dQw4w9WgXcQ"}' 2>/dev/null || echo "")

    if echo "$test_result" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('playabilityStatus',{}).get('status',''))" 2>/dev/null | grep -q "OK"; then
        echo "  ✅ Cookie 有效！"
        return 0
    else
        echo "  ⚠️  Cookie 可能无效或已过期（视频可能无法播放）"
        echo "  💡 提示: 部分视频需要完整 Cookie，仅 SID 不够"
        return 0  # 仍然保存，让用户自己判断
    fi
}

# 方式2: OAuth 回调（本机起 HTTP server）
auth_oauth() {
    echo ""
    echo "  🌐 OAuth 浏览器授权流程"
    echo ""
    echo "  即将打开浏览器进行授权..."
    echo "  授权完成后会自动保存到本地"
    echo ""
    echo "  按 Enter 继续，或 Ctrl+C 取消..."

    local dummy
    read -r dummy

    # 生成随机 state
    local state
    state=$(python3 -c "import secrets,base64; print(base64.urlsafe_b64encode(secrets.token_bytes(16)).decode())")

    # 启动本地回调 server（后台）
    local port=8765
    local callback_url="http://localhost:${port}/callback"

    echo "  启动本地授权服务器 :${port} ..."

    # 构建 OAuth URL
    local client_id="299858008408-7pkp6g5lq9d6h0d2q5j0vvh9b4u7i8d.apps.googleusercontent.com"
    local redirect_uri="http://localhost:${port}"
    local scope="https://www.googleapis.com/auth/youtube+https://www.googleapis.com/auth/youtubepartner"
    local oauth_url="https://accounts.google.com/o/oauth2/v2/auth?client_id=${client_id}&redirect_uri=${redirect_uri}&response_type=code&scope=${scope}&state=${state}&access_type=offline&prompt=consent"

    echo "  打开浏览器..."
    if command -v open &>/dev/null; then
        open "$oauth_url" 2>/dev/null &
    elif command -v xdg-open &>/dev/null; then
        xdg-open "$oauth_url" 2>/dev/null &
    fi

    echo "  🔗 或者手动访问: $oauth_url"
    echo ""
    echo "  等待授权回调..."
    echo "  （服务器在 :${port} 监听，完成后会显示结果）"
    echo ""

    # 用 Python 起一个简单的 HTTP server 处理回调
    python3 -c "
import http.server, urllib.parse, time, subprocess, os, sys

class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if '/callback' in self.path:
            params = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
            code = params.get('code', [''])[0]
            state = params.get('state', [''])[0]
            error = params.get('error', [''])[0]

            self.send_response(200)
            self.send_header('Content-Type', 'text/html; charset=utf-8')
            self.end_headers()

            if error:
                self.wfile.write(b'<html><body><h2>授权失败: ' + error.encode() + b'</h2></body></html>')
                sys.exit(1)
            elif code:
                self.wfile.write(b'<html><body><h2>✅ 授权成功！可以关闭此窗口了。</h2></body></html>')
                print('OAUTH_CODE:' + code, flush=True)
                sys.exit(0)
            return

    def log_message(self, format, *args):
        pass  # 静默

server = http.server.HTTPServer(('localhost', $port), Handler)
# 30秒超时
server.timeout = 30
while True:
    try:
        server.handle_request()
        break
    except Exception as e:
        break
" 2>&1 | {
        local oauth_code=""
        local line
        while IFS= read -r line; do
            if echo "$line" | grep -q "OAUTH_CODE:"; then
                oauth_code=$(echo "$line" | cut -d: -f2)
                break
            fi
            echo "  $line"
        done

        if [ -n "$oauth_code" ]; then
            echo ""
            echo "  ✅ 授权码获取成功，正在获取 Token..."
            # TODO: 用 code 换 token
            echo "  ⚠️  Token 交换功能开发中，请暂时使用 Cookie 模式"
        else
            echo "  ⚠️  授权超时或取消"
            return 1
        fi
    }
}

# 查看授权状态
auth_status() {
    auth_init || return 1

    echo ""
    if [ -f "$AUTH_COOKIE_FILE" ] && [ -s "$AUTH_COOKIE_FILE" ]; then
        local size
        size=$(wc -c < "$AUTH_COOKIE_FILE" | tr -d ' ')
        echo "  ✅ Cookie: 已设置 (${size} bytes)"
    else
        echo "  ❌ Cookie: 未设置"
    fi

    if [ -f "$AUTH_TOKEN_FILE" ] && [ -s "$AUTH_TOKEN_FILE" ]; then
        echo "  ✅ Auth Headers: 已设置"
    else
        echo "  ❌ Auth Headers: 未设置"
    fi

    echo ""
    cache_stats
}

# 清除授权
auth_clear() {
    rm -rf "$AUTH_DIR" 2>/dev/null
}

# 获取当前有效 Cookie（环境变量优先，否则读文件）
auth_get_cookie() {
    if [ -n "${COOKIE:-}" ]; then
        echo "$COOKIE"
        return
    fi
    if [ -f "$AUTH_COOKIE_FILE" ] && [ -s "$AUTH_COOKIE_FILE" ]; then
        cat "$AUTH_COOKIE_FILE"
        return
    fi
    echo ""
}
