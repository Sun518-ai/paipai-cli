#!/bin/bash
set -e

# ============================================
# ByteMall Skill - 主脚本
# ============================================

SKILL_NAME="bytemall"
SKILL_DOMAIN="www.byte-mall.cn"
USERDATA_DIR="${MIRA_USERDATA_DIR:-/opt/tiger/mira_nas/userdata/$MIRA_CURRENT_USERID}"
MIRA_COOKIE_DIR="$USERDATA_DIR/$SKILL_NAME"
COOKIE_FILE="$MIRA_COOKIE_DIR/.cookie"
DOMAIN_COOKIE_FILE="$USERDATA_DIR/$SKILL_DOMAIN/.cookie"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ============================================
# Cookie 持久化函数
# ============================================

save_cookie() {
  local val="$1"
  mkdir -p "$MIRA_COOKIE_DIR" 2>/dev/null
  if echo "$val" > "$COOKIE_FILE" 2>/dev/null; then
    return 0
  fi
  echo "[warn] Cookie 持久化失败（userdata 目录不可写），仅在本次会话中使用" >&2
  return 1
}

load_cookie() {
  # 1. 按 skill name 查找
  if [ -f "$COOKIE_FILE" ] && [ -s "$COOKIE_FILE" ]; then
    cat "$COOKIE_FILE"; return
  fi
  # 2. 按域名精确目录查找
  if [ -f "$DOMAIN_COOKIE_FILE" ] && [ -s "$DOMAIN_COOKIE_FILE" ]; then
    cat "$DOMAIN_COOKIE_FILE"; return
  fi
  # 3. 在 userdata 下搜索同域名其他 skill 的 cookie
  if [ -d "$USERDATA_DIR" ]; then
    local found_cookie
    found_cookie=$(find "$USERDATA_DIR" -maxdepth 2 -path "*/$SKILL_DOMAIN*/.cookie" -type f 2>/dev/null | head -1)
    if [ -n "$found_cookie" ] && [ -s "$found_cookie" ]; then
      echo "[info] 复用同域名 cookie: $found_cookie" >&2
      cat "$found_cookie"; return
    fi
  fi
  # 4. 兜底：环境变量
  echo "$COOKIE"
}

# ============================================
# Cookie 初始化
# ============================================

if [ -n "$COOKIE" ]; then
  save_cookie "$COOKIE"
else
  COOKIE="$(load_cookie)"
fi

if [ -z "$COOKIE" ]; then
  echo "Cookie 缺失，请通过以下链接完成授权并获取 Cookie："
  echo ""
  echo "[点击此处授权并获取 Cookie](https://www.byte-mall.cn/search/goods?mira_skill_cookie=1&MIRA_ORIGIN_URL=__MIRA_ORIGIN_URL__)"
  echo ""
  echo "如未安装 Mira 浏览器插件，请先安装：https://bytedance.larkoffice.com/docx/AR2td8ISdoAfkQxcIdxc5LeNnXe"
  echo ""
  echo "或在对话中直接提供 Cookie（如 COOKIE=xxx），将自动持久化。"
  exit 1
fi
export COOKIE

# ============================================
# 工具函数
# ============================================

# 从 JSON 中提取字段
json_extract() {
  local json="$1"
  local key="$2"
  echo "$json" | python3 -c "import sys,json; print(json.load(sys.stdin).get('$key',''))" 2>/dev/null || echo ""
}

# 检查响应是否成功
check_response() {
  local resp="$1"
  local code
  code=$(echo "$resp" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('code', -1))" 2>/dev/null || echo "-1")
  if [ "$code" = "0" ] || [ "$code" = "200" ]; then
    return 0
  fi
  local msg
  msg=$(echo "$resp" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('em', d.get('message', 'Unknown error')))" 2>/dev/null || echo "Request failed")
  echo "Error: $msg (code=$code)" >&2
  return 1
}

# ============================================
# 命令处理
# ============================================

ACTION="${1:-}"

if [ -z "$ACTION" ]; then
  echo "用法:"
  echo "  $0 search <关键词>           # 搜索商品"
  echo "  $0 suggest <关键词>          # 搜索建议"
  echo "  $0 detail <sku_id>          # 商品详情"
  echo "  $0 order <sku_id> <数量>    # 创建订单并支付"
  echo ""
  echo "示例:"
  echo "  $0 search 耳机"
  echo "  $0 detail 100460701"
  echo "  $0 order 100460701 1"
  exit 1
fi

case "$ACTION" in
  search)
    KEYWORD="${2:-}"
    if [ -z "$KEYWORD" ]; then
      echo "Error: 请提供搜索关键词"
      exit 1
    fi
    echo "[info] 搜索商品: $KEYWORD" >&2
    "$SCRIPT_DIR/step_search.sh" "$KEYWORD"
    ;;

  suggest)
    KEYWORD="${2:-}"
    if [ -z "$KEYWORD" ]; then
      echo "Error: 请提供搜索关键词"
      exit 1
    fi
    echo "[info] 获取搜索建议: $KEYWORD" >&2
    "$SCRIPT_DIR/step_suggest.sh" "$KEYWORD"
    ;;

  detail)
    SKU_ID="${2:-}"
    if [ -z "$SKU_ID" ]; then
      echo "Error: 请提供 SKU ID"
      exit 1
    fi
    echo "[info] 获取商品详情: $SKU_ID" >&2
    "$SCRIPT_DIR/step_detail.sh" "$SKU_ID"
    ;;

  order)
    SKU_ID="${2:-}"
    NUM="${3:-1}"
    if [ -z "$SKU_ID" ]; then
      echo "Error: 请提供 SKU ID"
      exit 1
    fi
    echo "[info] 开始创建订单流程..." >&2
    echo "[info] SKU ID: $SKU_ID, 数量: $NUM" >&2

    # 步骤1: 获取地址列表
    echo "[info] 步骤1: 获取地址列表..." >&2
    ADDRESS_RESP=$("$SCRIPT_DIR/step_address.sh")
    if ! check_response "$ADDRESS_RESP"; then
      echo "获取地址列表失败"
      exit 1
    fi

    # 步骤2: 结算预览
    echo "[info] 步骤2: 结算预览..." >&2
    CHECKOUT_RESP=$("$SCRIPT_DIR/step_checkout.sh" "$SKU_ID" "$NUM")
    if ! check_response "$CHECKOUT_RESP"; then
      echo "结算预览失败"
      exit 1
    fi

    # 步骤3: 创建订单
    echo "[info] 步骤3: 创建订单..." >&2
    ORDER_RESP=$("$SCRIPT_DIR/step_order_create.sh")
    if ! check_response "$ORDER_RESP"; then
      echo "创建订单失败"
      exit 1
    fi

    # 提取订单号
    ORDER_TRADE_ID=$(echo "$ORDER_RESP" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('data',{}).get('order_trade_id',''))" 2>/dev/null)
    if [ -z "$ORDER_TRADE_ID" ]; then
      echo "Error: 无法获取订单号"
      exit 1
    fi
    echo "[info] 订单创建成功: $ORDER_TRADE_ID" >&2

    # 步骤4: 获取支付信息
    echo "[info] 步骤4: 获取支付信息..." >&2
    PAY_INFO_RESP=$("$SCRIPT_DIR/step_pay_info.sh" "$ORDER_TRADE_ID")
    if ! check_response "$PAY_INFO_RESP"; then
      echo "获取支付信息失败"
      exit 1
    fi

    # 步骤5: 创建支付
    echo "[info] 步骤5: 创建支付..." >&2
    PAY_CREATE_RESP=$("$SCRIPT_DIR/step_pay_create.sh" "$ORDER_TRADE_ID")
    if ! check_response "$PAY_CREATE_RESP"; then
      echo "创建支付失败"
      exit 1
    fi

    # 输出最终结果
    echo ""
    echo "==========================================="
    echo "订单创建成功！"
    echo "订单号: $ORDER_TRADE_ID"
    echo "==========================================="
    echo ""
    echo "$PAY_CREATE_RESP"
    ;;

  *)
    echo "Error: 未知操作类型: $ACTION"
    echo "支持的操作: search, suggest, detail, order"
    exit 1
    ;;
esac
