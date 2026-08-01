#!/bin/bash

set -euo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd "$TESTS_DIR/.." && pwd)"
TEST_DIRECTORY="$(mktemp -d /tmp/ve-installer.XXXXXX)"
MOCK_LOG="$TEST_DIRECTORY/remote-commands.log"

cleanup() {
    rm -rf "$TEST_DIRECTORY"
}
trap cleanup EXIT

assert_contains() {
    local file_path="$1"
    local expected_text="$2"

    if ! grep -Fq -- "$expected_text" "$file_path"; then
        echo "Expected $file_path to contain: $expected_text" >&2
        exit 1
    fi
}

assert_not_contains() {
    local file_path="$1"
    local unexpected_text="$2"

    if grep -Fq -- "$unexpected_text" "$file_path"; then
        echo "Expected $file_path not to contain: $unexpected_text" >&2
        exit 1
    fi
}

sshpass() {
    if [ "$1" != "-p" ] || [ "$#" -lt 3 ]; then
        echo "Unexpected sshpass arguments" >&2
        return 64
    fi

    shift 2
    local transport="$1"
    shift

    case "$transport" in
        ssh)
            local target="$1"
            local remote_command="${2:-}"

            if [ "$target" != "mobile@relaxin.test" ]; then
                echo "Unexpected SSH target: $target" >&2
                return 64
            fi

            case "$remote_command" in
                "sh -s -- 'dpkg' '/var/jb/usr/bin/dpkg'")
                    cat >/dev/null
                    if [ "$MOCK_REMOTE_ARCHITECTURE" = 'iphoneos-arm64' ]; then
                        printf '%s\n' '/var/jb/usr/bin/dpkg'
                    else
                        printf '%s\n' '/private/preboot/VE-JBROOT/procursus/usr/bin/dpkg'
                    fi
                    ;;
                "sh -s -- 'sbreload' '/var/jb/usr/bin/sbreload'")
                    cat >/dev/null
                    if [ "$MOCK_REMOTE_ARCHITECTURE" = 'iphoneos-arm64' ]; then
                        printf '%s\n' '/var/jb/usr/bin/sbreload'
                    else
                        printf '%s\n' '/private/preboot/VE-JBROOT/procursus/usr/bin/sbreload'
                    fi
                    ;;
                *"--print-architecture")
                    printf '%s\n' "$MOCK_REMOTE_ARCHITECTURE"
                    ;;
                "sudo -S "*)
                    local supplied_password
                    IFS= read -r supplied_password
                    if [ "$supplied_password" != "test-password" ]; then
                        echo "Unexpected sudo password" >&2
                        return 64
                    fi
                    printf 'ssh:%s\n' "$remote_command" >> "$MOCK_LOG"
                    ;;
                "rm -f "*)
                    printf 'ssh:%s\n' "$remote_command" >> "$MOCK_LOG"
                    ;;
                *)
                    echo "Unexpected remote command: $remote_command" >&2
                    return 64
                    ;;
            esac
            ;;
        scp)
            printf 'scp:%s\n' "$*" >> "$MOCK_LOG"
            ;;
        *)
            echo "Unexpected transport: $transport" >&2
            return 64
            ;;
    esac
}
export -f sshpass
export MOCK_LOG

mkdir -p "$TEST_DIRECTORY/scripts" "$TEST_DIRECTORY/packages"
cp "$REPOSITORY_ROOT/install-to-device.sh" "$TEST_DIRECTORY/install-to-device.sh"
cp "$REPOSITORY_ROOT/scripts/resolve-bootstrap-command.sh" "$TEST_DIRECTORY/scripts/resolve-bootstrap-command.sh"
touch "$TEST_DIRECTORY/packages/codes.wingchan.ve-enhanced_2.2_iphoneos-arm64.deb"
touch "$TEST_DIRECTORY/packages/codes.wingchan.ve-enhanced_2.2_iphoneos-arm64e.deb"

export MOCK_REMOTE_ARCHITECTURE='iphoneos-arm64e'
: > "$MOCK_LOG"
PATH="/usr/bin:/bin" "$TEST_DIRECTORY/install-to-device.sh" relaxin.test test-password >/dev/null

assert_contains "$MOCK_LOG" 'codes.wingchan.ve-enhanced_2.2_iphoneos-arm64e.deb mobile@relaxin.test:/tmp/codes.wingchan.ve-enhanced_2.2_iphoneos-arm64e.deb'
assert_contains "$MOCK_LOG" "ssh:sudo -S '/private/preboot/VE-JBROOT/procursus/usr/bin/dpkg' -i '/tmp/codes.wingchan.ve-enhanced_2.2_iphoneos-arm64e.deb'"
assert_contains "$MOCK_LOG" "ssh:sudo -S '/private/preboot/VE-JBROOT/procursus/usr/bin/sbreload'"
assert_contains "$MOCK_LOG" "ssh:rm -f '/tmp/codes.wingchan.ve-enhanced_2.2_iphoneos-arm64e.deb'"
assert_not_contains "$MOCK_LOG" 'iphoneos-arm64.deb mobile@relaxin.test'

: > "$MOCK_LOG"
if PATH="/usr/bin:/bin" "$TEST_DIRECTORY/install-to-device.sh" \
    relaxin.test test-password codes.wingchan.ve-enhanced_2.2_iphoneos-arm64.deb >/dev/null 2>&1; then
    echo "Expected an architecture-mismatched package to fail" >&2
    exit 1
fi
assert_not_contains "$MOCK_LOG" 'scp:'

export MOCK_REMOTE_ARCHITECTURE='iphoneos-arm64'
: > "$MOCK_LOG"
PATH="/usr/bin:/bin" "$TEST_DIRECTORY/install-to-device.sh" relaxin.test test-password >/dev/null

assert_contains "$MOCK_LOG" 'codes.wingchan.ve-enhanced_2.2_iphoneos-arm64.deb mobile@relaxin.test:/tmp/codes.wingchan.ve-enhanced_2.2_iphoneos-arm64.deb'
assert_contains "$MOCK_LOG" "ssh:sudo -S '/var/jb/usr/bin/dpkg' -i '/tmp/codes.wingchan.ve-enhanced_2.2_iphoneos-arm64.deb'"
assert_contains "$MOCK_LOG" "ssh:sudo -S '/var/jb/usr/bin/sbreload'"
assert_not_contains "$MOCK_LOG" 'iphoneos-arm64e.deb mobile@relaxin.test'

export MOCK_REMOTE_ARCHITECTURE='iphoneos-armv7'
: > "$MOCK_LOG"
if PATH="/usr/bin:/bin" "$TEST_DIRECTORY/install-to-device.sh" relaxin.test test-password >/dev/null 2>&1; then
    echo "Expected an unsupported remote architecture to fail" >&2
    exit 1
fi
assert_not_contains "$MOCK_LOG" 'scp:'

echo "Installer integration tests passed"
