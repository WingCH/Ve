#!/bin/bash
set -euo pipefail
TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DIRECTORY="$(mktemp -d /tmp/ve-notification-replay.XXXXXX)"
trap 'rm -rf "$TEST_DIRECTORY"' EXIT
compiler="${CC:-clang}"
case "$(uname -s)" in
    Darwin)
        "$compiler" -Wall -Wextra -Wno-unused-variable "$TESTS_DIR/notification-replay-test.m" -framework Foundation -o "$TEST_DIRECTORY/test"
        ;;
    Linux)
        # Install GNUstep Foundation and Objective-C development headers, or
        # point GNUSTEP_PREFIX / OBJC_INCLUDE_DIR to a local package extraction.
        prefix="${GNUSTEP_PREFIX:-/usr}"
        triple="$(gcc -dumpmachine)"
        objc_include="${OBJC_INCLUDE_DIR:-$(gcc -print-file-name=include)}"
        "$compiler" -Wall -Wextra -Wno-unused-variable -fobjc-exceptions -fconstant-string-class=NSConstantString -fuse-ld=/usr/bin/ld \
            -DGNUSTEP -DGNUSTEP_BASE_LIBRARY=1 -DGNU_RUNTIME=1 \
            -I"$prefix/include/GNUstep" -I"$prefix/include/$triple/GNUstep" -I"$objc_include" \
            "$TESTS_DIR/notification-replay-test.m" -L"$prefix/lib/$triple" -L"$(dirname "$objc_include")" \
            -lgnustep-base -lobjc -o "$TEST_DIRECTORY/test"
        export LD_LIBRARY_PATH="$prefix/lib/$triple${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
        ;;
    *) printf 'This test requires macOS Foundation or Linux GNUstep.\n' >&2; exit 1 ;;
esac
# Separate invocations exercise persisted history across a process restart.
"$TEST_DIRECTORY/test" --record "$TEST_DIRECTORY/history.json"
"$TEST_DIRECTORY/test" --verify "$TEST_DIRECTORY/history.json"
