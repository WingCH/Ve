#!/bin/bash
set -euo pipefail
TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DIRECTORY="$(mktemp -d /tmp/ve-ai-filter.XXXXXX)"
trap 'rm -rf -- "$TEST_DIRECTORY"' EXIT
export VE_TEST_DIRECTORY="$TEST_DIRECTORY/state"
mkdir -p "$VE_TEST_DIRECTORY"
"${CC:-clang}" -fobjc-arc -fblocks -DVE_HOST_TEST=1 -Wall -Wextra \
  -Wno-unused-variable -Wno-unused-parameter -Wno-incomplete-implementation \
  "$TESTS_DIR/ai-filter-test.m" \
  "$TESTS_DIR/../Manager/VEAIStore.m" "$TESTS_DIR/../Manager/VEAIPolicy.m" \
  "$TESTS_DIR/../Manager/VEAIGate.m" "$TESTS_DIR/../Manager/VEAIClient.m" \
  "$TESTS_DIR/../Manager/VEAIManager.m" -framework Foundation -o "$TEST_DIRECTORY/test"
"$TEST_DIRECTORY/test" --unit
"$TEST_DIRECTORY/test" --write-ai &
AI_WRITER=$!
"$TEST_DIRECTORY/test" --write-correction &
CORRECTION_WRITER=$!
wait "$AI_WRITER"
wait "$CORRECTION_WRITER"
"$TEST_DIRECTORY/test" --verify-concurrency
"$TEST_DIRECTORY/test" --manager
