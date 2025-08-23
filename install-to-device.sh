#!/bin/bash

# VE Enhanced automatic device installation script
# Usage: ./install-to-device.sh [device_ip] [ssh_password] [deb_filename(optional)]

set -e  # Exit on error

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
DEB_FILE="$3"

# Check if sshpass is installed
if ! command -v sshpass &> /dev/null; then
    echo -e "${RED}Error: sshpass is not installed${NC}"
    echo "Please install it first: brew install sshpass"
    exit 1
fi

# Check if packages directory exists
if [ ! -d "packages" ]; then
    echo -e "${RED}Error: packages directory does not exist${NC}"
    echo "Please run 'make package' first to create the deb file"
    exit 1
fi

# If no deb file specified, find the latest one
if [ -z "$DEB_FILE" ]; then
    DEB_FILE=$(ls -t packages/*.deb 2>/dev/null | head -n1)
    if [ -z "$DEB_FILE" ]; then
        echo -e "${RED}Error: No .deb files found in packages directory${NC}"
        echo "Please run 'make package' first to create the deb file"
        exit 1
    fi
    echo -e "${YELLOW}Using latest deb file: $(basename "$DEB_FILE")${NC}"
else
    # Check if specified file exists
    if [ ! -f "packages/$DEB_FILE" ]; then
        echo -e "${RED}Error: packages/$DEB_FILE does not exist${NC}"
        exit 1
    fi
    DEB_FILE="packages/$DEB_FILE"
fi

DEB_FILENAME=$(basename "$DEB_FILE")

echo -e "${GREEN}Starting installation of $DEB_FILENAME to device $DEVICE_IP...${NC}"

# Step 1: Copy deb file to device
echo -e "${YELLOW}Step 1: Copying file to device...${NC}"
if ! sshpass -p "$SSH_PASSWORD" scp "$DEB_FILE" mobile@"$DEVICE_IP":/var/mobile/Documents/; then
    echo -e "${RED}Error: Failed to copy file to device${NC}"
    exit 1
fi

# Step 2: Install deb file
echo -e "${YELLOW}Step 2: Installing deb file...${NC}"
if ! sshpass -p "$SSH_PASSWORD" ssh mobile@"$DEVICE_IP" "echo '$SSH_PASSWORD' | sudo -S /var/jb/usr/bin/dpkg -i /var/mobile/Documents/$DEB_FILENAME"; then
    echo -e "${RED}Error: Failed to install deb file${NC}"
    exit 1
fi

# Step 3: Reload SpringBoard
echo -e "${YELLOW}Step 3: Reloading SpringBoard (sbreload)...${NC}"
if ! sshpass -p "$SSH_PASSWORD" ssh mobile@"$DEVICE_IP" "echo '$SSH_PASSWORD' | sudo -S /var/jb/usr/bin/sbreload"; then
    echo -e "${RED}Error: Failed to reload SpringBoard${NC}"
    exit 1
fi

# Step 4: Clean up temporary files
echo -e "${YELLOW}Step 4: Cleaning up temporary files...${NC}"
sshpass -p "$SSH_PASSWORD" ssh mobile@"$DEVICE_IP" "rm -f /var/mobile/Documents/$DEB_FILENAME" || echo -e "${YELLOW}Warning: Could not delete temporary file${NC}"

echo -e "${GREEN}Installation completed! The tweak should now be loaded in SpringBoard.${NC}"
echo -e "${GREEN}You can find the preferences in Settings > VE Enhanced.${NC}"