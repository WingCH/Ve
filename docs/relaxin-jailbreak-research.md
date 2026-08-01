# Relaxin jailbreak 相容性研究

研究日期：2026-08-02

研究範圍：Relaxin 官方網站與 release artifact、Relaxin 明確採用的 RootHide 官方文件／source，以及 Ve repository 現況。未引用新聞、社群教學或未獲官方背書的同名 GitHub repository。

## 實作與真機驗證更新

2026-08-02：Ve 已完成 native `roothide` package、動態 jbroot path adapter 及 bootstrap-aware installer 的實作。使用者其後確認 Relaxin 真機實驗成功，因此 v2.2 可正式提供獨立的 `iphoneos-arm64e` Relaxin／RootHide package。標準 rootless 與 Relaxin packages 仍不可互換。

此結果確認本次測試裝置上的安裝與主要 runtime flow；由於 Relaxin 仍屬 public beta，而且 Ve 依賴 iOS private API，後續 Relaxin 或 iOS 版本仍須重新執行本文的 smoke-test checklist。

## 結論

**Ve 已加入 Relaxin 支援，並另行產生正式的 RootHide package；現有 rootless `.deb` 不能直接視為相容。**

最明確的阻點在封裝層，而非 hook API：實作前 Ve 只使用 `THEOS_PACKAGE_SCHEME = rootless`，產物是 `iphoneos-arm64` 並以固定 `/var/jb` 佈局封裝；Relaxin 則是使用隨機 jbroot 的 RootHide jailbreak，其官方 Theos scheme 產生 `iphoneos-arm64e` package。RootHide 官方亦明言，自動把 rootless package patch 成 roothide 並非對所有 package 都有效。[RootHide scheme source](https://github.com/roothide/theos/blob/master/vendor/mod/roothide/package/deb.mk)、[RootHidePatcher README](https://github.com/roothide/RootHidePatcher/blob/master/README.md)

Runtime 方面的初步條件較樂觀：Relaxin 內建 ElleKit，而 RootHide 的 ElleKit package `Provides: mobilesubstrate`；RootHide 亦有同名 `preferenceloader` package。因此 Ve 使用的 `MSHookMessageEx` 與現有 dependency 名稱有官方 compatibility surface。[ElleKit package control](https://github.com/roothide/ellekit/blob/master/packaging/control)、[RootHide PreferenceLoader source](https://github.com/roothide/preferenceloader/blob/master/luzconf.py)

實際落地方式是 **native roothide package variant + dual-toolchain path adapter**：標準 rootless variant 繼續使用 upstream Theos；Relaxin variant 明確使用 RootHide Theos；共用 source 在 toolchain 提供 `<roothide.h>` 時使用 `jbroot()`，否則回落至 upstream Theos 的 `<rootless.h>`／`ROOT_PATH_NS_VAR()`。這個方向直接對應 [RootHide developer guide](https://github.com/roothide/Developer/blob/main/README.md) 與 [RootHide Theos scheme source](https://github.com/roothide/theos/blob/master/vendor/mod/roothide/package/deb.mk)，不依賴非保證的 package 自動轉換，同時不會破壞現有 upstream Theos build。

Ve hook 的 `BBServer`、`PSUIPrefsListController` 等均是 iOS private API。官方文件本身不能證明這些 class／selector 在所有 iOS 17.0–17.3.1 build 都完全相同；本次 Relaxin 真機實驗已成功，但未來 Relaxin／iOS 更新仍須回歸驗證。

## 證據等級

- **已確認**：Relaxin 官網、經官方 SHA-256 manifest 驗證的 v0.3.8 IPA、RootHide 官方文件或 source 直接證明。
- **高信心推論**：Relaxin 官網明確表示基於 RootHide，而且官方 IPA 內含 RootHide core、manager、hooks 與 repositories；故採用 RootHide 的 package/runtime contract。
- **真機驗證**：使用者已確認本次 Relaxin 實驗成功；未來版本仍須按相同 checklist 回歸測試。

Relaxin 官網目前沒有連到 Relaxin 自身的公開 source repository。本研究沒有採用搜尋到的第三方「Relaxin Jailbreak」repository。

## Relaxin 技術概況

| 項目 | 已確認結果 | 第一手來源 |
|---|---|---|
| 技術模型 | `roothide semi-untethered jailbreak`，並明示基於 opa334 的 Dopamine 與其 RootHide fork | [Relaxin 官網](https://relaxin.owngoal.dev/)、[官網 application bundle](https://relaxin.owngoal.dev/assets/index-Bo8HzdhC.js) |
| 發佈狀態 | Public beta | [官網 application bundle](https://relaxin.owngoal.dev/assets/index-Bo8HzdhC.js) |
| 公開支援範圍 | A15+、iOS/iPadOS 17.0–17.3.1；app 僅接受 physical iPhone／iPad，並會再按 CPU family、device identifier、OS version/build 選擇 runtime profile | [Relaxin 官網](https://relaxin.owngoal.dev/)、[官方 v0.3.8 IPA manifest](https://relaxin.owngoal.dev/relaxin-release/relaxin-latest.ipa.json) |
| 分發 | `.ipa` 與 `.tipa`；官網只在 `.tipa` 標示「17.0」 | [官網 application bundle](https://relaxin.owngoal.dev/assets/index-Bo8HzdhC.js)、[TIPA manifest](https://relaxin.owngoal.dev/relaxin-release/relaxin-latest.tipa.json) |
| 研究時最新 artifact | v0.3.8；IPA 大小 29,116,444 bytes，SHA-256 `1cbb8daaea6d186bd9bab10a84fb07de4429b0587d9e41b00a9cf3cb47a92544` | [官方 IPA manifest](https://relaxin.owngoal.dev/relaxin-release/relaxin-latest.ipa.json) |
| Bootstrap | RootHide-modified Procursus；APT channel 為 `iphoneos-arm64e/1900`，內含 APT、dpkg、sudo、launchctl、ldid | [官方 v0.3.8 IPA manifest／artifact](https://relaxin.owngoal.dev/relaxin-release/relaxin-latest.ipa.json)、[RootHide Procursus source](https://github.com/roothide/Procursus-roothide) |
| Package manager | Sileo 2.5.1-12（官方 IPA embedded package） | [官方 v0.3.8 IPA manifest／artifact](https://relaxin.owngoal.dev/relaxin-release/relaxin-latest.ipa.json)、[RootHide Sileo source](https://github.com/roothide/Sileo-roothide) |
| Tweak loader／hook engine | ElleKit，提供 `CydiaSubstrate.framework` compatibility；Relaxin app 本身有「Tweak Injection」開關 | [官方 v0.3.8 IPA manifest／artifact](https://relaxin.owngoal.dev/relaxin-release/relaxin-latest.ipa.json)、[RootHide ElleKit source](https://github.com/roothide/ellekit) |
| RootHide 管理 | 內含 RootHide Manager 1.3.9 與 `roothide` core 0.0.9 | [官方 v0.3.8 IPA manifest／artifact](https://relaxin.owngoal.dev/relaxin-release/relaxin-latest.ipa.json)、[RootHide Manager source](https://github.com/roothide/RootHideManagerApp) |

官方 IPA 的 `Info.plist` 指定 minimum iOS 17.0 與 `arm64e` device capability；主 app／engine executable 是 arm64e。IPA 內的 jailbreak runtime dylibs及 ElleKit `CydiaSubstrate` 則同時包含 arm64、arm64e slices。雖然 engine binary 可見 A14/M1 共用 code path，官網公開範圍仍只寫 A15+，故不可據此擴張裝置支援聲明。[Relaxin 官網](https://relaxin.owngoal.dev/)、[官方 v0.3.8 IPA manifest／artifact](https://relaxin.owngoal.dev/relaxin-release/relaxin-latest.ipa.json)

## RootHide 與一般 jailbreak 的關鍵差異

| 特性 | 傳統 rootful | 標準 rootless | Relaxin／RootHide |
|---|---|---|---|
| Jailbreak files | 以 iOS root filesystem 的絕對路徑為主 | 固定 prefix `/var/jb` | 每次 jailbreak 使用隨機命名的 jbroot，不保證存在固定 `/var/jb` |
| Debian architecture | 常見 `iphoneos-arm` | `iphoneos-arm64` | `iphoneos-arm64e` |
| Package scheme | rootful／未指定 | `THEOS_PACKAGE_SCHEME=rootless` | `THEOS_PACKAGE_SCHEME=roothide` |
| Dynamic library path | 絕對路徑／傳統 loader path | `/var/jb` rpath；rootless v2 亦加入 relocated-jbroot rpath | `@loader_path/.jbroot/<absolute-jbroot-path>` |
| Bootstrap 對 `/` 的理解 | iOS rootfs | iOS rootfs，加 `/var/jb` prefix | jbroot 本身；原 iOS rootfs 由 jbroot 的 `/rootfs` symlink 存取 |
| Path API | 原生 path | `rootless.h`／libroot | `roothide.h` 的 `jbroot()`、`rootfs()`、`jbrand()` |

標準 rootless 的 fixed `/var/jb`、package prefix 與 `iphoneos-arm64` 行為見 [Theos 官方 Rootless 文件](https://theos.dev/docs/Rootless.html)。RootHide 官方則明確說明它仍屬 rootless，但會在每次 jailbreak 把 bootstrap 安裝到隨機 jbroot；含 Mach-O 的目錄會有 `.jbroot` symlink，dependency 應使用 `@loader_path/.jbroot/...`。[RootHide 與 rootless 差異](https://github.com/roothide/Developer/blob/main/roothide.md)

RootHide bootstrap 內的 commands 以 jbroot 為預設 filesystem root；需要存取原 iOS rootfs 時使用 `/rootfs/...`，或使用 `jbroot`／`rootfs` API及 command 做 path conversion。[RootHide path 說明](https://github.com/roothide/Developer/blob/main/roothide.md)、[RootHide API](https://github.com/roothide/Developer/blob/main/interface.md)

### Launch daemon、sandbox 與 code signing

經 SHA-256 驗證的 Relaxin v0.3.8 IPA 內有 `jailbreakd`、`launchdhook.dylib`、`roothidehooks.dylib`、`systemhook.dylib`、`opainject`、trustcache handling，以及 `basebin/LaunchDaemons/com.aapl.relaxin.startup.plist`。該 plist 以 root 執行 `@JBROOT@/basebin/jbctl internal startup`；`@JBROOT@` 會在 bootstrap preparation 時替換。這證明 Relaxin 的 launch daemon、process spawn、sandbox extension 與 trust handling 建立在隨機 jbroot contract 上，而不是掃描固定 `/var/jb`。[官方 v0.3.8 IPA manifest／artifact](https://relaxin.owngoal.dev/relaxin-release/relaxin-latest.ipa.json)

官網提供的 v0.3.8 IPA 主 executable 本身未附 code signature，需由安裝途徑簽署；因此不能從下載檔宣稱 Relaxin app 最終獲得了哪些 entitlements。對 jailbreak 內另行建立的 executable/app，RootHide 官方要求 `platform-application`、`com.apple.private.security.no-sandbox`、`com.apple.private.security.storage.AppBundles` 與 `com.apple.private.security.storage.AppDataContainers`。[RootHide entitlement 文件](https://github.com/roothide/Developer/blob/main/entitlements.md)

Ve 現時只有 tweak dylibs 與 PreferenceBundle，沒有獨立 helper executable／daemon；現階段不應無故加入上述 app entitlements。若之後為安裝或資料操作新增 helper，才需要重新評估。

RootHide 建議 app／binary／tweak 的可寫資料置於 jbroot 的 `/var/`；Mach-O 不可放在 jbroot 的 `/var` 或 `/tmp` 載入。[RootHide entitlement 與資料文件](https://github.com/roothide/Developer/blob/main/entitlements.md)

## Ve 現況與相容性判斷

| Ve contract | 現況 | Relaxin 判斷 | 狀態 |
|---|---|---|---|
| Package scheme | `THEOS_PACKAGE_SCHEME = rootless` | 必須另外以 `roothide` scheme clean build | **阻擋正式支援** |
| Debian architecture | `iphoneos-arm64` | RootHide Theos 產物應為 `iphoneos-arm64e` | **阻擋安裝／package resolution** |
| Binary slices | `arm64 arm64e` | Relaxin 的 system-process tweak 需要 arm64e；現有 source 設定已有該 slice | 初步相容，仍需檢查新 ABI artifact |
| Hook API | `#import <substrate.h>`、`MSHookMessageEx` | RootHide ElleKit `Provides: mobilesubstrate (= 99)` 並提供 Substrate API compatibility | 高信心相容 |
| `Depends: mobilesubstrate` | 現有 control dependency | 可由 RootHide ElleKit virtual package 滿足 | 可保留 |
| `Depends: preferenceloader` | 現有 control dependency | RootHide 有同名 package及 `/Library/PreferenceBundles` layout | 高信心相容 |
| Tweak filters | 注入 SpringBoard、Preferences | Relaxin 有 ElleKit injection及 app 內 Tweak Injection toggle | 應可支援，需真機確認 toggle 已啟用 |
| Log／attachment path | `ROOT_PATH_NS(@"/var/mobile/Library/...")` | RootHide `rootless-compat.h` 會轉為 `jbroot(...)`，而且位置屬官方建議的 jbroot `/var` 範圍 | 可工作；應由 dual-toolchain adapter 優先採用 `roothide.h`，並驗證跨 process permissions |
| Settings 內 respring | `ROOT_PATH_NS(@"/usr/bin/killall")` | roothide build 時可由 compatibility header 轉成動態 jbroot path | 初步相容 |
| `install-to-device.sh` | 寫死 `/var/jb/usr/bin/dpkg` 與 `/var/jb/usr/bin/sbreload` | Relaxin 沒有固定 `/var/jb` contract；上傳到 stock `/var/mobile/Documents` 後，bootstrap command 還涉及 `/rootfs` path semantics | **不相容，必須重寫或排除** |
| iOS private API | hook `BBServer`、`PSUIPrefsListController` selectors | Relaxin 規格不保證 iOS 17 private API shape | **必須真機驗證** |

RootHide 官方容許既有 `<rootless.h>` 在 roothide scheme 下經 `rootless-compat.h` 映射到 `jbroot()`，但會主動發出 legacy compatibility warning，並建議改用 `<roothide.h>` 取得完整的 rootful／rootless／roothide compatibility。不過一般 upstream Theos 並不提供 `<roothide.h>`；若同一份 source 仍需由 upstream Theos 建置 rootless variant，project adapter 必須以 `__has_include(<roothide.h>)` 選擇兩套 API，而不能無條件 import RootHide header。[RootHide developer guide](https://github.com/roothide/Developer/blob/main/README.md)、[`rootless-compat.h`](https://github.com/roothide/headers/blob/master/rootless-compat.h)、[`roothide.h`](https://github.com/roothide/headers/blob/master/roothide.h)

## 建議實作方案

### 1. 保留兩種獨立 package 產物

- 現有 jailbreak：以標準 Theos 明確產生 `rootless`／`iphoneos-arm64` `.deb`。
- Relaxin：使用 [roothide/theos](https://github.com/roothide/theos) 明確產生 `roothide`／`iphoneos-arm64e` `.deb`。
- 可保留相同 package identifier；Theos 官方表示 rootful/rootless variants 不必改 package identifier。[Theos Rootless 文件](https://theos.dev/docs/Rootless.html)
- 切換 scheme 時必須 clean；最好讓 CI jobs／object directories 完全分離，避免不同 scheme artifacts 混入。[Theos Rootless 文件](https://theos.dev/docs/Rootless.html)
- Release 名稱應明確標示 `rootless` 與 `roothide-relaxin`，避免使用者裝錯。

不要把 RootHidePatcher 的轉換結果當正式 release 流程；其官方 README 明確表示不支援所有 packages。[RootHidePatcher README](https://github.com/roothide/RootHidePatcher/blob/master/README.md)

### 2. 加入 dual-toolchain path adapter

將目前散落的 `<rootless.h>`／`ROOT_PATH_NS` 收斂到一個 project adapter。當 `__has_include(<roothide.h>)` 成立時，adapter import RootHide header 並呼叫 `jbroot(...)`；否則 import upstream Theos 的 `<rootless.h>` 並呼叫 variable-safe `ROOT_PATH_NS_VAR(...)`。RootHide 的 header 在其 toolchain 的 rootful/rootless build 會提供對應 stub，而 fallback 則保留現有 upstream Theos 支援，因此同一份 source 可涵蓋兩個 toolchain。[RootHide developer guide](https://github.com/roothide/Developer/blob/main/README.md)、[RootHide header source](https://github.com/roothide/headers/blob/master/roothide.h)

`LogManager` 現有 logical path 可先維持 `/var/mobile/Library/codes.wingchan.ve-enhanced/...`，讓 roothide build 將其解析到 jbroot `/var/mobile/...`。這符合 RootHide 建議把 tweak data 放在 jbroot `/var` 的原則；但首次支援仍須驗證 SpringBoard 與 Preferences 都能讀寫同一位置。[RootHide entitlement 與資料文件](https://github.com/roothide/Developer/blob/main/entitlements.md)

### 3. 重寫或停用固定 `/var/jb` 的安裝 script

Relaxin flow 不可再直接呼叫 `/var/jb/usr/bin/dpkg`、`/var/jb/usr/bin/sbreload`。新的 deployment resolver 至少要分辨：

- 標準 rootless：固定 `/var/jb`。
- RootHide：在 remote bootstrap shell 以 `command -v` 解析 `dpkg`／`sbreload`，並由 `dpkg --print-architecture` 確認 `iphoneos-arm64e` package contract。

RootHide 官方說明 bootstrap commands 只接受並輸出 jbroot-based paths。可靠做法不是在 host 端猜測隨機 prefix，而是讓 remote `scp` process 與 `dpkg` 在同一 bootstrap filesystem view 使用 `/tmp/<validated-name>.deb`；官方 v0.3.8 bootstrap 的 `/tmp` 是 mode `1777`，而 jbroot `/var/mobile` 是 mode `0755` 且預設沒有 `Documents` directory。只有當暫存檔確實位於原 iOS rootfs 時，才應使用 `/rootfs/...` conversion。[RootHide path 說明](https://github.com/roothide/Developer/blob/main/roothide.md)、[RootHide path conversion API](https://github.com/roothide/Developer/blob/main/interface.md)、[Relaxin 官方 v0.3.8 IPA manifest／artifact](https://relaxin.owngoal.dev/relaxin-release/relaxin-latest.ipa.json)

即使 host-side resolver 與 staging contract 已落實，仍須在 Relaxin 真機驗證 SSH server 的 `PATH`、SCP view、sudo 與 userspace reload 行為；Sileo 安裝仍是正式 release 的首選 smoke-test 路徑。

### 4. 不要用 package 成功安裝代替 runtime 驗證

Relaxin app 有獨立的「Tweak Injection」開關；測試前必須確認已啟用。官網 changelog亦顯示 public beta 近期仍在修正 helper process、jailbreak folder access、bootstrap permissions 等問題，測試結果應記錄 Relaxin 版本。[Relaxin 官網 application bundle／changelog](https://relaxin.owngoal.dev/assets/index-Bo8HzdhC.js)

## 最小真機驗證清單

以下是 Relaxin release 的回歸測試清單。本次使用者已確認真機實驗成功；後續 Relaxin／iOS 或 Ve 版本更新仍應重新逐項驗證：

1. Relaxin v0.3.8（或測試時最新版本）已 jailbreak，Tweak Injection 已啟用。
2. Sileo 接受 `iphoneos-arm64e` roothide `.deb`，沒有 architecture 或 unresolved dependency error。
3. Installed payload 不含固定 `/var/jb`，Mach-O dependencies／rpaths 使用 `.jbroot` contract。
4. Settings 顯示 VE Enhanced PreferenceBundle。
5. SpringBoard 收到通知後，`VeCore` 成功 hook 並寫入 `logs.json`／attachments。
6. Settings 的 Notifications 頁載入 `VeTarget`，能顯示與閱讀相同 logs。
7. Settings 內 respring 能正常執行；SpringBoard restart、userspace reboot、重新 jailbreak 後資料與設定仍可用。
8. Bark forwarding、app icon lookup、attachment forwarding 在 iOS 17 sandbox/network 環境正常。
9. 停用 Tweak Injection 時 Ve 不應被載入；重新啟用後可恢復。
10. 卸載 package 後，PreferenceBundle、tweak dylibs／filters 均清除，SpringBoard 與 Preferences 無 crash loop。

## 風險與未知項

- Relaxin 是 public beta；release artifact 與 bootstrap 行為仍可能快速變動。官網 v0.3.5 changelog已有 sandbox/filesystem/bootstrap permission 修正。[Relaxin changelog](https://relaxin.owngoal.dev/assets/index-Bo8HzdhC.js)
- 官網未提供 Relaxin 自身公開 source repository。本研究能直接檢查由官網 SHA-256 manifest 驗證的 release artifact，但無法 source-level audit exploit、launchd hook 與 package finalization 的所有分支。
- 官方公開支援文字是 A15+、17.0–17.3.1；不可把 engine 內存在的其他 SoC code path視為公開支援。
- ElleKit 提供 Substrate API 不等於 Ve 的 iOS 17 private hooks 一定有效。最可能的第二階段問題會是 selector/class 變動或 process sandbox，而非 `MSHookMessageEx` symbol 缺失。
- RootHide `rootless-compat.h` 可令現有 path macros 編譯，但官方仍建議遷移至 `roothide.h`；正式 release 應以 dual-toolchain adapter 避免 warning-based compatibility layer，同時保留 upstream Theos fallback。[RootHide compatibility header](https://github.com/roothide/headers/blob/master/rootless-compat.h)

## 最終判斷

技術上屬於**可支援，風險中等**：

- 封裝與 filesystem contract 有清楚、官方提供的修正路徑。
- `mobilesubstrate`／PreferenceLoader dependencies 有 RootHide 官方對應。
- Ve 已包含 arm64e slice，毋須重新設計 hook engine。
- 本次支援已獲使用者在 Relaxin 真機實驗確認；剩餘風險是 iOS private API 與 Relaxin public-beta runtime 在後續版本可能改變，因此仍須持續回歸測試。
