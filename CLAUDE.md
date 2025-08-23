# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Vē is a comprehensive notification logger for iOS/iPadOS jailbroken devices built using the Theos framework. It's a native tweak that integrates with SpringBoard to capture, log, and manage notifications with advanced features including Bark forwarding, biometric protection, and rich attachment handling.

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

The project follows a modular architecture with five main components:

### 1. Core Module (`Tweak/Core/`)
- **VeCore.h/.m**: Main tweak logic and SpringBoard integration
- Handles notification interception and logging
- Manages global preferences and state
- Integrates with BarkManager for notification forwarding

### 2. Target Module (`Tweak/Target/`)
- **VeTarget.h/.m**: UI components for the notification viewer
- **Controllers/**: List controllers for different views
  - `AbstractListController`: Base class for all list controllers
  - `VeLogsListController`: Main notification logs view
  - `VeAttachmentListController`: Attachment browser
  - `VeDetailListController`: Detailed notification view
- **Cells/**: Custom table view cells for displaying notification data
  - `VeLogCell`: Main notification entry cell
  - `VeAttachmentCell`: Attachment preview cell
  - `VeFullAttachmentCell`: Full-size attachment display
  - `VeDetailCell`: Detailed notification information cell
- **Sorter/**: Data sorting implementations
  - `AbstractSorter`: Base sorting protocol
  - `DateSorter`: Sort by timestamp
  - `ApplicationSorter`: Sort by app/bundle identifier
  - `SearchSorter`: Filter and search functionality

### 3. Preferences Module (`Preferences/`)
- **Controllers/**: Settings panel controllers
  - `VeRootListController`: Main preferences panel
  - `VeBlockedSendersListController`: Manage blocked senders
  - `VeCreditsListController`: Credits and acknowledgments
- **Cells/**: Custom preference cells
  - `LinkCell`: External link buttons
  - `SingleContactCell`: Developer contact information
- **Resources/**: Plist files for preference configuration

### 4. Managers (`Manager/`)
- **LogManager**: Handles notification data persistence and retrieval
- **BarkManager**: Advanced Bark API integration with features:
  - iTunes API caching for app icons
  - Encryption support for secure forwarding
  - Notification level mapping
  - Bulletin ID generation
- **Log**: Core logging and data structures

### 5. Utilities (`Utils/`)
- **DateUtil**: Date formatting and manipulation with localization support
- **ImageUtil**: Image processing utilities for attachments
- **StringUtil**: String manipulation and validation helpers

## Key Features

### Core Functionality
- **Notification Logging**: Captures notifications via SpringBoard hooks with BBBulletin integration
- **Rich Attachment Support**: Save and display both local and remote notification attachments
- **Advanced Search & Sorting**: Multiple sorting options (date, application, search) with real-time filtering
- **Blocked Senders Management**: Filter notifications from specific apps/senders with easy management interface

### Privacy & Security
- **Secure Storage**: Notification data stored securely with automatic cleanup options
- **Privacy Controls**: Options to log notifications without content for privacy
- **Content Filtering**: Smart filtering to avoid logging empty or blocked notifications

### External Integration  
- **Bark Forwarding**: Advanced integration with Bark notification service featuring:
  - Encrypted message forwarding with custom encryption keys
  - App icon retrieval via iTunes API with intelligent caching
  - Notification level mapping (Active, Passive based on bulletin existence)
  - Custom bulletin ID generation for tracking

### User Experience
- **Configurable Log Limits**: Adjustable storage limits (200-1000 notifications via UI slider)
- **Automatic Cleanup**: Optional automatic deletion of logs after 7 days
- **Date Format Options**: Support for American and international date formats
- **Rich UI**: Custom cells and controllers following iOS design patterns with segmented sliders

## Development Notes

### Technical Implementation
- The tweak targets SpringBoard and Preferences app processes via INSTALL_TARGET_PROCESSES
- Uses MobileSubstrate for runtime patching and method swizzling
- Preferences stored using NSUserDefaults with suite name: `codes.aurora.ve.preferences`
- Log data managed through LogManager static methods with automatic persistence
- UI follows iOS design patterns with custom cells and controllers

### Project Configuration
- **Package**: codes.aurora.ve
- **Version**: 2.0
- **Architecture**: iphoneos-arm64 (supports arm64/arm64e)
- **Dependencies**: firmware (>= 14.0), mobilesubstrate, preferenceloader
- **Scheme**: Rootless package format for modern jailbreaks

### Key Preference Keys
- `Enabled`: Toggle tweak functionality
- `LogLimit`: Maximum number of stored notifications (200-1000)
- `SaveLocalAttachments`/`SaveRemoteAttachments`: Attachment handling
- `LogWithoutContent`: Privacy mode for content-less logging
- `BlockedSenders`: Array of blocked bundle identifiers
- `AutomaticallyDeleteLogs`: Enable 7-day cleanup
- `BarkForwardingEnabled`: Enable Bark integration
- `BarkAPIKey`/`BarkEncryptionKey`: Bark configuration
- `UseAmericanDateFormat`: Date formatting preference
- `Sorting`: Default sorting method (Date/Application/Search)

### Development Workflow
1. Use `make` for building
2. Use `make package` for validation without installation
3. Use automated script `./install-to-device.sh` for device deployment
4. Preferences changes trigger `codes.aurora.ve.preferences.reload` notification