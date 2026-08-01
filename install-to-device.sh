#!/bin/bash

# VE Enhanced automatic device installation script
# Usage: ./install-to-device.sh [device_ip] [ssh_password] [deb_filename(optional)]

set -euo pipefail

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Parameter validation
if [ $# -lt 2 ]; then
    echo -e "${RED}Usage: $0 <device_ip> <ssh_password> [deb_filename]${NC}"
    echo "Example: $0 192.168.1.100 alpine"
    echo "Example: $0 192.168.1.100 alpine codes.wingchan.ve-enhanced_2.0_iphoneos-arm64.deb"
    exit 1
fi

DEVICE_IP="$1"
SSH_PASSWORD="$2"
DEB_FILE="${3:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMAND_RESOLVER="$SCRIPT_DIR/scripts/resolve-bootstrap-command.sh"
SSH_TARGET="mobile@$DEVICE_IP"
REMOTE_STAGE_DIR="/tmp"

resolve_remote_command() {
    local command_name="$1"
    local legacy_absolute_path="$2"

    sshpass -p "$SSH_PASSWORD" ssh "$SSH_TARGET" \
        "sh -s -- '$command_name' '$legacy_absolute_path'" < "$COMMAND_RESOLVER"
}

validate_remote_command_path() {
    local command_path="$1"

    case "$command_path" in
        /*) ;;
        *)
            echo -e "${RED}Error: Resolved remote command is not an absolute path: $command_path${NC}"
            return 1
            ;;
    esac

    case "$command_path" in
        *[!A-Za-z0-9._/+-]*)
            echo -e "${RED}Error: Resolved remote command contains unsupported characters: $command_path${NC}"
            return 1
            ;;
    esac
}

# Check if sshpass is installed
if ! command -v sshpass &> /dev/null; then
    echo -e "${RED}Error: sshpass is not installed${NC}"
    echo "Please install it first: brew install sshpass"
    exit 1
fi

if [ ! -f "$COMMAND_RESOLVER" ]; then
    echo -e "${RED}Error: Bootstrap command resolver does not exist: $COMMAND_RESOLVER${NC}"
    exit 1
fi

# Check if packages directory exists
if [ ! -d "$SCRIPT_DIR/packages" ]; then
    echo -e "${RED}Error: packages directory does not exist${NC}"
    echo "Please run 'make package' first to create the deb file"
    exit 1
fi

echo -e "${YELLOW}Detecting remote bootstrap...${NC}"
if ! REMOTE_DPKG="$(resolve_remote_command dpkg /var/jb/usr/bin/dpkg)"; then
    echo -e "${RED}Error: Could not find dpkg in the remote bootstrap${NC}"
    exit 1
fi
if ! REMOTE_SBRELOAD="$(resolve_remote_command sbreload /var/jb/usr/bin/sbreload)"; then
    echo -e "${RED}Error: Could not find sbreload in the remote bootstrap${NC}"
    exit 1
fi

validate_remote_command_path "$REMOTE_DPKG"
validate_remote_command_path "$REMOTE_SBRELOAD"

if ! REMOTE_ARCHITECTURE="$(sshpass -p "$SSH_PASSWORD" ssh "$SSH_TARGET" "'$REMOTE_DPKG' --print-architecture" | tr -d '\r\n')"; then
    echo -e "${RED}Error: Could not determine the remote package architecture${NC}"
    exit 1
fi

case "$REMOTE_ARCHITECTURE" in
    iphoneos-arm64)
        BOOTSTRAP_NAME="standard rootless"
        ;;
    iphoneos-arm64e)
        BOOTSTRAP_NAME="RootHide / Relaxin"
        ;;
    *)
        echo -e "${RED}Error: Unsupported remote package architecture: $REMOTE_ARCHITECTURE${NC}"
        exit 1
        ;;
esac

echo -e "${GREEN}Detected $BOOTSTRAP_NAME bootstrap ($REMOTE_ARCHITECTURE)${NC}"

# If no deb file specified, find the latest one
if [ -z "$DEB_FILE" ]; then
    shopt -s nullglob
    PACKAGE_CANDIDATES=("$SCRIPT_DIR"/packages/*_"$REMOTE_ARCHITECTURE".deb)
    shopt -u nullglob

    if [ "${#PACKAGE_CANDIDATES[@]}" -eq 0 ]; then
        echo -e "${RED}Error: No $REMOTE_ARCHITECTURE .deb files found in packages directory${NC}"
        echo "Please create the matching package before installing it"
        exit 1
    fi

    DEB_FILE="${PACKAGE_CANDIDATES[0]}"
    for package_candidate in "${PACKAGE_CANDIDATES[@]:1}"; do
        if [ "$package_candidate" -nt "$DEB_FILE" ]; then
            DEB_FILE="$package_candidate"
        fi
    done

    echo -e "${YELLOW}Using latest deb file: $(basename "$DEB_FILE")${NC}"
else
    # Check if specified file exists
    if [ ! -f "$SCRIPT_DIR/packages/$DEB_FILE" ]; then
        echo -e "${RED}Error: packages/$DEB_FILE does not exist${NC}"
        exit 1
    fi
    DEB_FILE="$SCRIPT_DIR/packages/$DEB_FILE"
fi

DEB_FILENAME=$(basename "$DEB_FILE")

case "$DEB_FILENAME" in
    *[!A-Za-z0-9._+-]*)
        echo -e "${RED}Error: Package filename contains unsupported characters: $DEB_FILENAME${NC}"
        exit 1
        ;;
esac

case "$DEB_FILENAME" in
    *_"$REMOTE_ARCHITECTURE".deb) ;;
    *)
        echo -e "${RED}Error: $DEB_FILENAME does not match remote architecture $REMOTE_ARCHITECTURE${NC}"
        exit 1
        ;;
esac

REMOTE_DEB_PATH="$REMOTE_STAGE_DIR/$DEB_FILENAME"

echo -e "${GREEN}Starting installation of $DEB_FILENAME to device $DEVICE_IP...${NC}"

# Step 1: Copy deb file to device
echo -e "${YELLOW}Step 1: Copying file to device...${NC}"
if ! sshpass -p "$SSH_PASSWORD" scp "$DEB_FILE" "$SSH_TARGET:$REMOTE_DEB_PATH"; then
    echo -e "${RED}Error: Failed to copy file to device${NC}"
    exit 1
fi

# Step 2: Install deb file
echo -e "${YELLOW}Step 2: Installing deb file...${NC}"
if ! printf '%s\n' "$SSH_PASSWORD" | sshpass -p "$SSH_PASSWORD" ssh "$SSH_TARGET" "sudo -S '$REMOTE_DPKG' -i '$REMOTE_DEB_PATH'"; then
    echo -e "${RED}Error: Failed to install deb file${NC}"
    exit 1
fi

# Step 3: Reload SpringBoard
echo -e "${YELLOW}Step 3: Reloading SpringBoard (sbreload)...${NC}"
if ! printf '%s\n' "$SSH_PASSWORD" | sshpass -p "$SSH_PASSWORD" ssh "$SSH_TARGET" "sudo -S '$REMOTE_SBRELOAD'"; then
    echo -e "${RED}Error: Failed to reload SpringBoard${NC}"
    exit 1
fi

# Step 4: Clean up temporary files
echo -e "${YELLOW}Step 4: Cleaning up temporary files...${NC}"
sshpass -p "$SSH_PASSWORD" ssh "$SSH_TARGET" "rm -f '$REMOTE_DEB_PATH'" || echo -e "${YELLOW}Warning: Could not delete temporary file${NC}"

echo -e "${GREEN}Installation completed! The tweak should now be loaded in SpringBoard.${NC}"
echo -e "${GREEN}You can find the preferences in Settings > VE Enhanced.${NC}"
