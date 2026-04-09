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
