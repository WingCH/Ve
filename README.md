# VE Enhanced 2.2.1

修正重新開機／respring 後，已記錄的相同通知被重複轉發至 Bark。通知內容、標題、副標題或版本有更新時仍然會處理；同一時間來自不同 app 或不同通知 ID 的訊息亦不會被當成相同通知。

Source tag: [2.2.1](https://github.com/WingCH/Ve/tree/2.2.1)
Source commit: [4b1a6be8872f18375d149c7c203caba099931329](https://github.com/WingCH/Ve/commit/4b1a6be8872f18375d149c7c203caba099931329)

## Downloads

| 環境 | Package architecture | 套件 |
| --- | --- | --- |
| 標準 rootless | `iphoneos-arm64` | [下載 rootless .deb](https://github.com/WingCH/Ve/raw/refs/heads/release-artifacts/2.2.1/codes.wingchan.ve-enhanced_2.2.1_rootless_iphoneos-arm64.deb) |
| RootHide／Relaxin | `iphoneos-arm64e` | [下載 RootHide／Relaxin .deb](https://github.com/WingCH/Ve/raw/refs/heads/release-artifacts/2.2.1/codes.wingchan.ve-enhanced_2.2.1_roothide-relaxin_iphoneos-arm64e.deb) |

兩個套件不可互換。安裝前請核對 jailbreak 類型及 package architecture。SHA-256 校驗碼見 [SHA256SUMS](SHA256SUMS)。

## Validation and limits

- 通知重播測試：在獨立 process 重新讀取 JSON 歷史，直接執行 production 通知比對 helper，15 個 assertions 通過。
- Bootstrap command resolver、installer integration 及 Relaxin support contract 三組現有測試通過；installer 使用 mocked SSH。
- Rootless 和 RootHide 均由此 source commit clean build；每個套件的三個 Mach-O binaries 均含 arm64／arm64e，六個 slice 的簽章 hash、套件 layout、ownership、permissions 及 plists 檢查通過。
- 此版本未在真機測試 SpringBoard／Preferences 載入、Bark 實際轉發或重新開機。重播辨識依賴保留的通知歷史；被清除或因記錄上限而移除的通知不再有可比對的紀錄。
- 套件由 Linux 建置，arm64e 使用 Theos 文件建議的 allemande ABI 轉換；轉換及套件檢查並不保證真機 runtime 相容性。

## Build provenance

- iPhoneOS SDK: 16.5; deployment target: iOS 14.0; Clang: 13.0.0 (Swift 5.8 Linux toolchain).
- Upstream Theos: `dd5c14bb9d91311e221d51b5bfb8c9e5948156db`.
- RootHide Theos: `88506b2c22e9e07dd4ed055f23c9e398a117a2c7`.
- Allemande: `43b2ca59ad3f6a55735b1f7b5cba8c34b55bd8f9`.
- `FINALPACKAGE=1`; independent `rootless` and `roothide` package schemes; generated staging permissions normalized before packaging.
- License: GPL-3.0; see [COPYING](COPYING) and the source tag above.

此分支保存下載套件。雲端環境目前限制 `api.github.com`／`uploads.github.com`，所以尚未建立 GitHub Release 頁面；可直接使用上述下載連結。
