#!/bin/sh

set -eu

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <command_name> <legacy_absolute_path>" >&2
    exit 64
fi

command_name="$1"
legacy_absolute_path="$2"

case "$command_name" in
    ""|*[!A-Za-z0-9._+-]*)
        echo "Invalid command name: $command_name" >&2
        exit 64
        ;;
esac

case "$legacy_absolute_path" in
    /*) ;;
    *)
        echo "Legacy path must be absolute: $legacy_absolute_path" >&2
        exit 64
        ;;
esac

resolved_command="$(command -v "$command_name" 2>/dev/null || true)"
if [ -n "$resolved_command" ]; then
    printf '%s\n' "$resolved_command"
    exit 0
fi

if [ -x "$legacy_absolute_path" ]; then
    printf '%s\n' "$legacy_absolute_path"
    exit 0
fi

echo "Unable to resolve bootstrap command: $command_name" >&2
exit 127
