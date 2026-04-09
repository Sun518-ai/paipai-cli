#!/bin/bash
set -e

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

TARGET="${SKILL_ARG_TARGET:-paipai}"

echo ""
echo "🐲 Running skill: example"
echo "   target: $TARGET"
echo ""

bash "$SKILL_DIR/step1_hello.sh"
bash "$SKILL_DIR/step2_info.sh"

# 注意：SKILL_NAME 和 SKILL_DIR 由 runner.ts 在运行时通过环境变量注入
# 直接执行 ./main.sh 时这些变量为空，通过 paipai run 调用时正常
