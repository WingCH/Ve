#!/bin/bash

set -euo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd "$TESTS_DIR/.." && pwd)"
RESOLVER="$REPOSITORY_ROOT/scripts/resolve-bootstrap-command.sh"
TEST_DIRECTORY="$(mktemp -d /tmp/ve-bootstrap-resolver.XXXXXX)"

cleanup() {
    rm -rf "$TEST_DIRECTORY"
}
trap cleanup EXIT

assert_equals() {
    local expected="$1"
    local actual="$2"

    if [ "$actual" != "$expected" ]; then
        echo "Expected '$expected', got '$actual'" >&2
        exit 1
    fi
}

mkdir -p "$TEST_DIRECTORY/bin"
touch "$TEST_DIRECTORY/bin/dpkg"
chmod 755 "$TEST_DIRECTORY/bin/dpkg"

resolved_from_path="$(PATH="$TEST_DIRECTORY/bin:/usr/bin:/bin" "$RESOLVER" dpkg "$TEST_DIRECTORY/legacy-dpkg")"
assert_equals "$TEST_DIRECTORY/bin/dpkg" "$resolved_from_path"

touch "$TEST_DIRECTORY/legacy-sbreload"
chmod 755 "$TEST_DIRECTORY/legacy-sbreload"
resolved_from_legacy_path="$(PATH="/usr/bin:/bin" "$RESOLVER" ve-missing-sbreload "$TEST_DIRECTORY/legacy-sbreload")"
assert_equals "$TEST_DIRECTORY/legacy-sbreload" "$resolved_from_legacy_path"

if PATH="/usr/bin:/bin" "$RESOLVER" ve-missing-command "$TEST_DIRECTORY/missing" >/dev/null 2>&1; then
    echo "Expected a missing command to fail" >&2
    exit 1
fi

if "$RESOLVER" 'invalid command' /usr/bin/false >/dev/null 2>&1; then
    echo "Expected an invalid command name to fail" >&2
    exit 1
fi

echo "Bootstrap command resolver tests passed"
