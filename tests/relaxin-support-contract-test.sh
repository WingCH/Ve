#!/bin/bash

set -euo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd "$TESTS_DIR/.." && pwd)"

assert_contains() {
    local file_path="$1"
    local expected_text="$2"

    if ! grep -Fq -- "$expected_text" "$file_path"; then
        echo "Expected $file_path to contain: $expected_text" >&2
        exit 1
    fi
}

bash -n "$REPOSITORY_ROOT/install-to-device.sh"
sh -n "$REPOSITORY_ROOT/scripts/resolve-bootstrap-command.sh"

assert_contains "$REPOSITORY_ROOT/Makefile" "THEOS_PACKAGE_SCHEME ?= rootless"
assert_contains "$REPOSITORY_ROOT/Makefile" "rootless roothide"
assert_contains "$REPOSITORY_ROOT/Utils/JailbreakPath.h" "__has_include(<roothide.h>)"
assert_contains "$REPOSITORY_ROOT/Utils/JailbreakPath.h" "return jbroot(path);"
assert_contains "$REPOSITORY_ROOT/Utils/JailbreakPath.h" "return ROOT_PATH_NS_VAR(path);"
assert_contains "$REPOSITORY_ROOT/Manager/LogManager.m" "VEJailbreakRootPath"
assert_contains "$REPOSITORY_ROOT/Preferences/Controllers/VeRootListController.m" "VEJailbreakRootPath"
assert_contains "$REPOSITORY_ROOT/install-to-device.sh" 'REMOTE_STAGE_DIR="/tmp"'
assert_contains "$REPOSITORY_ROOT/install-to-device.sh" "--print-architecture"
assert_contains "$REPOSITORY_ROOT/install-to-device.sh" "iphoneos-arm64e"

echo "Relaxin support contract tests passed"
