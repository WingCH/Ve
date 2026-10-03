# VE Enhanced 2.2.1

正式發佈：[GitHub Release 2.2.1](https://github.com/WingCH/Ve/releases/tag/2.2.1)。

# English

## What's New

- Fixed duplicate Bark forwarding after reboot or respring for unchanged notifications already present in saved history.
- Preserved forwarding for notification updates and distinct notifications that share a timestamp.
- Improved notification matching using the app, timestamp, content, and available bulletin identifiers.
- Added a notification-replay regression test that reloads saved history in a separate process.

## Downloads

- `codes.wingchan.ve-enhanced_2.2.1_iphoneos-arm64.deb` — For standard rootless jailbreaks.
- `codes.wingchan.ve-enhanced_2.2.1_iphoneos-arm64e.deb` — For Relaxin and RootHide.

> These packages are not interchangeable. Choose the package that matches your device's package architecture.

## Verification

- Both release packages passed clean-build, metadata, payload, Mach-O architecture, code-signature hash, and checksum verification.
- The resolver, support-contract, mocked-installer, and notification-replay tests all passed. The replay test passed 15 assertions after reloading history in a separate process.
- Real-device reboot, Bark forwarding, and SpringBoard/Preferences loading have not been tested for this version. The Linux builds use allemande for arm64e ABI conversion; runtime compatibility still needs device verification.
- Replay detection depends on retained notification history. Notifications removed by clearing history or the log limit can no longer be matched.

## SHA-256

`cba49b4de6888bbbecd6c46504d5012a927f4c593f3bb4c8be98ba2e776f7acc`  
`codes.wingchan.ve-enhanced_2.2.1_iphoneos-arm64.deb`

`e9c39377cac8f05ad11eb42dd513ffeba49e0c92aace06fe2bf5e3a667ea1f65`  
`codes.wingchan.ve-enhanced_2.2.1_iphoneos-arm64e.deb`

See the [Relaxin jailbreak compatibility research](https://github.com/WingCH/Ve/blob/2.2.1/docs/relaxin-jailbreak-research.md) for technical details and the regression checklist.

---

# 中文

## 更新內容

- 修正重新開機／respring 後，已儲存於歷史記錄的相同通知被重複轉發至 Bark 的問題。
- 保留通知更新及同一時間不同通知的正常轉發。
- 改善通知比對，使用 app、時間、內容及可用的 bulletin identifiers 辨識相同通知。
- 新增通知重播回歸測試，由另一個 process 重新讀取已儲存的歷史記錄。

## 下載

- `codes.wingchan.ve-enhanced_2.2.1_iphoneos-arm64.deb` — 適用於標準 rootless jailbreak。
- `codes.wingchan.ve-enhanced_2.2.1_iphoneos-arm64e.deb` — 適用於 Relaxin／RootHide。

> 兩個 packages 不可互換，請按裝置上的 package architecture 選擇。

## 驗證

- 兩個 release packages 均已完成 clean build、metadata、payload、Mach-O architecture、code-signature hash 與 checksum 驗證。
- Resolver、support contract、mocked installer 及通知重播測試全部通過；重播測試在另一個 process 重新讀取歷史記錄後，15 個 assertions 通過。
- 此版本尚未測試真機重新開機、Bark 實際轉發及 SpringBoard／Preferences 載入。Linux 建置使用 allemande 轉換 arm64e ABI，runtime 相容性仍需真機驗證。
- 重播辨識依賴保留的通知歷史；被清除或因記錄上限而移除的通知不再有可比對的紀錄。

## SHA-256

`cba49b4de6888bbbecd6c46504d5012a927f4c593f3bb4c8be98ba2e776f7acc`  
`codes.wingchan.ve-enhanced_2.2.1_iphoneos-arm64.deb`

`e9c39377cac8f05ad11eb42dd513ffeba49e0c92aace06fe2bf5e3a667ea1f65`  
`codes.wingchan.ve-enhanced_2.2.1_iphoneos-arm64e.deb`

詳細限制與回歸測試清單見 [Relaxin jailbreak 相容性研究](https://github.com/WingCH/Ve/blob/2.2.1/docs/relaxin-jailbreak-research.md)。
