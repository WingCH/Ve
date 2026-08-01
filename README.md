# VE Enhanced
Enhanced notification logger with notification forwarding capabilities.

## About
This is a fork of [Ve](https://github.com/rrk567301/Ve) with added notification forwarding features. The original Ve is a natively integrated notification logger for jailbroken iOS devices.

## New Features in VE Enhanced
- **Bark Integration**: Forward notifications to Bark server with encryption support
- **iTunes API Integration**: Fetch app icons automatically for forwarded notifications
- **Enhanced Security**: Encrypted message forwarding with custom keys
- **Smart Filtering**: Advanced notification level mapping (Active/Passive)

## Preview
<img src="Preview.png" alt="Preview" />

## Installation
1. Build the project or download the latest `deb` from releases
2. Install the `deb` using your preferred method
3. Configure Bark settings in Preferences to enable notification forwarding

## Configuration
### Bark Forwarding Setup
1. Open Settings → VE Enhanced
2. Enable "Bark Forwarding" 
3. Enter your Bark API Key
4. Optionally set an encryption key for secure forwarding

## Compatibility

- 標準 rootless：支援 iOS/iPadOS 14 或以上，package architecture 為 `iphoneos-arm64`。
- Relaxin／RootHide：自 v2.2 起支援，使用獨立 `roothide` scheme 產生 `iphoneos-arm64e` package，並已完成 Relaxin 真機實驗驗證。
- 標準 rootless 與 Relaxin packages 不可互換；安裝前必須核對 `.deb` 的 architecture。

## Compiling

每次切換 package scheme 前都必須 clean，並保留兩個獨立 release artifacts：

```sh
# 標準 rootless；使用 upstream Theos
make clean package FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=rootless

# Relaxin／RootHide；必須使用 roothide/theos
THEOS=/absolute/path/to/roothide-theos make clean package FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=roothide
```

RootHide build 需要 [roothide/theos](https://github.com/roothide/theos)，不能由只含 `rootless` scheme 的 upstream Theos 產生。兩個 `.deb` 應在 release 名稱中清楚標示 `rootless` 或 `roothide-relaxin`，避免安裝錯誤版本。

詳細技術依據、限制與真機 smoke-test 清單見 [Relaxin jailbreak 相容性研究](docs/relaxin-jailbreak-research.md)。

## Credits
- **Original Project**: [Ve by Alexandra Aurora Göttlicher, 74k1_](https://github.com/rrk567301/Ve)
- **Enhanced by**: Wing CHAN
- **Source Code**: [https://github.com/WingCH/Ve](https://github.com/WingCH/Ve)

## License
[GPL-3.0](https://github.com/WingCH/Ve/blob/main/COPYING)
