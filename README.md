# VE Enhanced
Enhanced notification logger with notification forwarding capabilities.

## About
This is a fork of [Ve](https://github.com/rrk567301/Ve) with added notification forwarding features. The original Ve is a natively integrated notification logger for jailbroken iOS devices.

## New Features in VE Enhanced
- **Bark Integration**: Forward notifications to Bark server with encryption support
- **iTunes API Integration**: Fetch app icons automatically for forwarded notifications
- **Enhanced Security**: Encrypted message forwarding with custom keys
- **Smart Filtering**: Advanced notification level mapping (Active/Passive)
- **可選 AI 篩選**：支援 Clef／Jev 的 System One 協定、自訂 provider endpoint／prompt、逐條人工修正與後續 context。

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

### AI 判斷與人工修正（2.3.0）

在 Settings → Notifications → **VE Enhanced Settings** 開啟 AI 區域；同頁 **Notification Logs** 可查看判斷及修正。既有 PreferenceLoader 入口仍保留。

AI 是可選功能。未設定 token 或關閉 AI 時，直接沿用 Bark。啟用後預設先觀察；你可切換至攔截模式，調整等待秒數與略過門檻。Cloudflare 可選 Clef／Clef-flash，Jev／System One 可設定模型名稱、完整 endpoint URL 與各自 token。

全域 prompt 可編輯及還原。每次判斷帶同一 App 最近 10 條人工修正，最新版 prompt 優先。紀錄保存 AI 原判斷、轉發動作及人工標籤；修正不自動補發。刪除通知仍保留修正例子，可另外清除；Reset All Data 會清除它們。

本輪 vphone 測到的是實際通知／HTTP／UI，模型回覆使用本機 fixture。真實 Clef／Jev 的判斷準確率與 rootless 實機仍待驗證。[設計及驗證界線](docs/clef-notification-filter-design.md)。

### AI 設定介面修正（2.3.1）

新增設定及編輯頁統一使用英文。模型、token 及連線欄位按 provider 顯示；Jev 不顯示 Cloudflare 模型或 Account ID。Cloudflare 標準 endpoint 保留所需 Account ID，完整自訂 URL 不使用 `{account_id}` 時隱藏該欄位。原有 token、模型、URL 與自訂 prompt 保留。

### Notification Logs 英文介面（2.3.2）

通知列表、AI 狀態、詳細頁、修正及補發介面統一使用英文。通知內容及使用者填寫的修正原因保留原文。詳細頁顯示當次的 Skip score 與 Skip threshold。

Skip threshold 是略過通知的分數門檻。Filter 模式在分數大於或等於門檻時略過轉發，其他分數照常轉發。預設 0.9 表示略過分數至少 0.9 才攔截，並不代表實際準確率達 90%。Observe 模式仍照常轉發。

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

## Regression Tests

```sh
bash tests/resolve-bootstrap-command-test.sh
bash tests/install-to-device-test.sh
bash tests/relaxin-support-contract-test.sh
bash tests/notification-replay-test.sh
bash tests/ai-filter-test.sh
python3 tests/ai-settings-contract-test.py
```

通知重播測試會先儲存通知，再由另一個 process 讀取，驗證重啟後的重播、通知更新及同一時間的不同通知。此測試需要 macOS Foundation，或 Linux 的 Clang、GNUstep Foundation 及 Objective-C development headers；非標準安裝可用 `GNUSTEP_PREFIX` 和 `OBJC_INCLUDE_DIR` 指定路徑。

2.2.3 改用穩定的 publisher ID 比對 respring 重播，並保留新內容、新日期及不同通知的正常轉發。指定 vphone 的實際通知／HTTP 驗證已通過；詳見 [重播修正及驗證](docs/respring-notification-replay.md)。

## Credits
- **Original Project**: [Ve by Alexandra Aurora Göttlicher, 74k1_](https://github.com/rrk567301/Ve)
- **Enhanced by**: Wing CHAN
- **Source Code**: [https://github.com/WingCH/Ve](https://github.com/WingCH/Ve)

## License
[GPL-3.0](https://github.com/WingCH/Ve/blob/main/COPYING)
