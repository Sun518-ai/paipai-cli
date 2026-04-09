#!/bin/bash
set -e

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Skill: review-test"
bash "$SKILL_DIR/step1_hello.sh"
