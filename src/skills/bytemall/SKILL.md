---
name: bytemall
description: 字节商城(ByteMall)商品搜索、下单和支付工具。支持商品搜索（返回SKU ID、名称、价格、库存等完整信息）、搜索建议、结算预览、创建订单和支付。
login_url: https://www.byte-mall.cn/search/goods
---

# ByteMall 字节商城 Skill

## 功能

- **搜索商品**：根据关键词搜索商品，返回商品列表、SKU ID、价格、库存等信息
- **搜索建议**：获取搜索关键词建议
- **商品详情**：获取商品详细信息
- **结算预览**：预览订单结算信息
- **创建订单**：提交订单创建
- **支付**：生成支付二维码/链接

## 使用方法

```bash
# 搜索商品
./main.sh search <关键词>

# 商品详情
./main.sh detail <sku_id>

# 创建订单并支付（完整流程）
./main.sh order <sku_id> <数量>
```

## 参数说明

| 参数 | 说明 | 示例 |
|------|------|------|
| `action` | 操作类型：search | detail | order |
| `keyword/sku_id` | 搜索关键词或商品SKU ID | 耳机 / 100460701 |
| `num` | 购买数量（仅order操作） | 1 |

## Cookie 授权指引

本 Skill 需要 ByteMall 登录 Cookie 才能调用接口。

**首次使用时**，请按以下步骤获取 Cookie：

1. **安装 Mira 浏览器插件**：[点击安装](https://bytedance.larkoffice.com/docx/AR2td8ISdoAfkQxcIdxc5LeNnXe)

2. **完成授权**：[点击此处授权并获取 Cookie](https://www.byte-mall.cn/search/goods?mira_skill_cookie=1&MIRA_ORIGIN_URL=__MIRA_ORIGIN_URL__)

3. 插件会自动提取 Cookie 并完成授权

**或者手动获取**：
1. 打开 https://www.byte-mall.cn/search/goods 并登录
2. 按 F12 打开开发者工具 → Application → Cookies
3. 复制所有 Cookie（格式：`key1=value1; key2=value2`）
4. 在对话中发送 `COOKIE=xxx` 即可自动持久化

Cookie 会自动保存，后续调用无需重复授权。

## 响应格式

所有接口返回 JSON 格式数据，标准响应结构：

```json
{
  "code": 0,
  "data": { ... },
  "em": "success",
  "et": ""
}
```

- `code`: 0 表示成功
- `data`: 业务数据
- `em`: 错误信息（成功时为 "success"）
