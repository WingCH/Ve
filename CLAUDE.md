# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Vē is a notification logger for iOS/iPadOS jailbroken devices built using the Theos framework. It's a native tweak that integrates with SpringBoard to capture and log notifications with support for Bark forwarding.

## Build System

- **Framework**: Theos (iOS tweak development framework)
- **Target**: iOS 14.0+ (arm64/arm64e architecture)
- **Build Command**: `make`
- **Clean Command**: `make clean`
- **Package Creation & Validation**: `make package` (preferred for verification without device installation)
- **Install Command**: `make install` (requires device connection - only for actual deployment)

The project uses a rootless package scheme and targets iPhone SDK 16.5 with iOS 14.0 deployment target.

## Device Testing

For automated device installation, use the included script:

```bash
# Install sshpass if not already installed
brew install sshpass

# Build and install to device (auto-detects latest deb)
make package && ./install-to-device.sh $THEOS_DEVICE_IP $THEOS_DEVICE_PASSWORD

# Or specify a particular deb file
./install-to-device.sh $THEOS_DEVICE_IP $THEOS_DEVICE_PASSWORD codes.aurora.ve_2.0_iphoneos-arm64.deb
```

The script automates:
1. SCP transfer of deb file to device
2. dpkg installation using rootless paths
3. SpringBoard reload (sbreload)
4. Cleanup of temporary files

**Requirements**: 
- Device must be jailbroken with rootless jailbreak
- SSH access enabled on device
- Mobile user password known

## Architecture

The project follows a modular architecture with three main components:

### 1. Core Module (`Tweak/Core/`)
- **VeCore.h/.m**: Main tweak logic and SpringBoard integration
- Handles notification interception and logging
- Manages global preferences and state

### 2. Target Module (`Tweak/Target/`)
- **VeTarget.h/.m**: UI components for the notification viewer
- **Controllers/**: List controllers for different views (logs, attachments, details)
- **Cells/**: Custom table view cells for displaying notification data
- **Views/**: Custom views including biometric protection overlay
- **Sorter/**: Data sorting implementations (by date, application, search)

### 3. Preferences Module (`Preferences/`)
- **Controllers/**: Settings panel controllers
- **Cells/**: Custom preference cells
- **Resources/**: Plist files for preference configuration

### 4. Managers (`Manager/`)
- **LogManager**: Handles notification data persistence
- **BarkManager**: Manages Bark API integration for notification forwarding
- **Log**: Core logging functionality

### 5. Utilities (`Utils/`)
- **DateUtil**: Date formatting and manipulation
- **ImageUtil**: Image processing utilities
- **StringUtil**: String manipulation helpers

## Key Components

- **Notification Logging**: Captures notifications via SpringBoard hooks
- **Biometric Protection**: Optional Touch ID/Face ID protection for viewing logs
- **Bark Integration**: Forward notifications to Bark service
- **Attachment Handling**: Save and display notification attachments
- **Search & Sorting**: Multiple sorting options and search functionality
- **Blocked Senders**: Filter notifications from specific apps/senders

## Development Notes

- The tweak targets SpringBoard and Preferences app processes
- Uses MobileSubstrate for runtime patching
- Preferences are stored using NSUserDefaults
- Log data is managed through the LogManager static methods
- UI follows iOS design patterns with custom cells and controllers