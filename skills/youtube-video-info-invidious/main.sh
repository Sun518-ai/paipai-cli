#!/usr/bin/env bash
# main.sh — YouTube 视频信息/搜索 via Invidious
# 支持两种模式：搜索关键词 / 获取视频信息
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

VIDEO_ID="${SKILL_ARG_VIDEO_ID:-}"
SEARCH_QUERY="${SKILL_ARG_SEARCH:-}"
LIMIT="${SKILL_ARG_LIMIT:-10}"

if [ -n "$SEARCH_QUERY" ]; then
  # 搜索模式
  bash "$SKILL_DIR/step2_search.sh"
else
  # 视频信息模式
  bash "$SKILL_DIR/step1_info.sh"
fi
