# Clef 通知篩選設計

設計日期：2026-10-03。實作更新：2026-10-04。狀態：**2.3.4 雙 scheme 正式產物已通過 ABI／簽署／dSYM 檢查，並發布至 GitHub。指定 vphone 的合成通知／HTTP、完整 raw body 及原文複製驗證通過。原有設定及 logs 已還原。真實 Clef／Jev 判斷準確率尚未驗證。**

上一版本：2.3.3 雙 scheme 正式產物已通過 ABI／簽署／dSYM 檢查。正式 RootHide 包已安裝到指定 vphone，binary identity 及介面 smoke 通過；實機卡頓覆核待完成。

最新交付：[2.3.4 prerelease](https://github.com/WingCH/Ve/releases/tag/2.3.4)。Rootless／RootHide 安裝包及建置、runtime、SHA256SUMS 紀錄共 5 個 assets 已下載核對，與本機及 GitHub digest 相符。原文：「"all_verified": true」— [發布讀回紀錄](/Users/wingchan/Project/Ve/packages/native-release-2.3.4/published-assets-verified.json)。真實模型準確率待驗證。

## 已確認的需求

通知處理範圍與 AI 失敗時的轉發行為見 [ADR 0001](adr/0001-ai-forwarding-boundary.md)。人工修正的保留、同 App 最近 10 條例子及獨立補發行為見 [ADR 0002](adr/0002-correction-examples-lifecycle.md)。領域用語見 [CONTEXT.md](../CONTEXT.md)。

- 設定提供一份全域判斷規則（prompt），可編輯並可「還原預設」。這由使用者在 Q4 確認。
- 紀錄顯示每條通知的 AI 原始判斷，讓使用者看見 AI 建議轉發或略過。
- 使用者可以在紀錄為單條通知指定「應轉發／不應轉發」，並可選填修正原因。
- 保存人工修正時，保留 AI 原始判斷，以便覆核兩者差異。
- 提供觀察模式與攔截模式。預設使用觀察模式，由使用者決定何時切換。這由使用者在 Q8 確認。
- 觀察模式照常進行原有 Bark 轉發，AI 判斷只供查看。攔截模式才會根據判斷略過轉發。
- 最新 prompt 優先於舊修正例子，原有人工標籤仍保留。這由使用者在 Q9 確認。
- 預設使用 `@cf/cloudflare/clef`，設定可切換至 `@cf/cloudflare/clef-flash`。這由使用者在 Q10 確認。
- Ve 直接呼叫 Cloudflare Workers AI REST API，由使用者在裝置設定 Account ID 與 API token。這由使用者在 Q11 確認。
- AI 等待上限可在設定調整，預設 2 秒。逾時照常轉發，遲到的 AI 回覆只更新紀錄。這由使用者在 Q12 補充問題確認。

## API 可行性與驗證界線

Clef 的 `state` 接受通知與例子這類結構化資料。官方原文：「a string, or structured data (object/array)」— [Clef 模型頁，Parameters / state](https://developers.cloudflare.com/workers-ai/models/clef/#parameters)。依據關係：來源直接允許結構化輸入；將目前通知與同 App 的修正例子一併放入 `state` 是本方案的使用方式，效果待驗證。

判斷規則可配合 typed question 的 `instructions`。官方範例原文：「instructions: "Is this support request urgent?"」— [Clef 模型頁，Usage](https://developers.cloudflare.com/workers-ai/models/clef/#usage)。依據關係：來源直接展示如何指定判斷問題；本方案會提供固定的通知判斷問題與使用者規則。

REST API 需要 Account ID 與 API token。官方原文：「You need your API token and Account ID to use the REST API.」— [Workers AI REST API，Get API token and Account ID](https://developers.cloudflare.com/workers-ai/get-started/rest-api/)。依據關係：來源直接列出所需設定。沿用該頁的 Workers AI token 建立流程，不使用 Global API Key。

修正例子會隨後續判斷請求送出。沒有證據表示一次人工修正能保證後續判斷正確。需用已標註通知驗證改善幅度、誤擋、模糊判斷與繁中／廣東話內容。

Context7 未提供 Clef 專屬文件，因此模型 schema 以已讀取的官方模型頁為依據。REST API 認證流程另經 Context7 查詢及目前官方 REST API 頁核對；現行頁面引導使用 Workers AI token 建立流程。

## 接駁方案

Ve 使用背景網路請求呼叫 `/client/v4/accounts/{account_id}/ai/run/{model_name}`，Bark 仍由 Ve 進行原有轉發。AI 呼叫只判斷是否應略過 Bark 轉發，不接收 Bark key 或加密 key。原有 Bark payload 與加密流程沿用。

請求 `state` 包含目前通知、最新版判斷規則與同一 App 最近 10 條有效修正例子。修正例子以最近修改時間排序，同一通知再次修正時更新既有標籤，撤銷修正後不再選取該例子。使用者確認完整方案後，已按此選取方式實作。

判斷使用固定的 `noul` 問題 `skip_bark`。使用者編輯的是判斷規則，程式固定問題與回傳格式。模型回傳「應略過」的概率後，由 Ve 的模式、門檻與失敗處理規則決定實際動作。

## 設定與紀錄

除已確認的全域 prompt、模型與等待時間外，設定提供 AI 啟用開關、觀察／攔截模式、Account ID、遮蔽顯示的 API token、攔截門檻及「清除修正例子」。憑證未設定或 AI 關閉時，沿用原有 Bark 轉發。

攔截門檻預設為「應略過」概率至少 0.90，並可在設定調整。低於門檻、不確定或回覆不合法時照常轉發。0.90 是初始操作門檻，不表示真實準確率達 90%；需先以觀察模式與人工標註覆核。

列表顯示精簡的 AI 判斷狀態。詳細頁分開顯示 AI 原始判斷／概率、當次採取的轉發動作、人工修正及可選原因，並提供修改／撤銷修正與獨立的「補發到 Bark」。Bark API 接受請求與接收裝置實際顯示通知屬於不同證據，不將前者標為已送達裝置。

「還原預設 prompt」只還原文字規則，保留修正例子。「Reset Preferences」還原設定，保留修正例子。「Reset All Data」清除通知、附件與修正例子。重新封鎖 App 後，該 App 的舊修正可以保留，但不送給 AI。以上細節已隨完整方案確認，並納入實作。

## 需要處理的本機資料流程

AI 建議、實際採取的轉發動作與人工修正需要分開保存。觀察模式可以同時出現「AI 建議略過」與「按觀察模式照常轉發」。AI 失敗也可能按既定 fallback 照常轉發，因此不能只用一個布林值代表整個流程。此資料區分已實作，並經指定 guest 的觀察模式與人工修正回歸核對。

現有通知新增方法會先存入本機紀錄，再進入 Bark 轉發。原文：「if (![[LogManager sharedInstance] addLogForBulletin:bulletin])」— [VeCore.m:46](../Tweak/Core/VeCore.m#L46)，核對版本 `f1ce706ccd15411319fb63f3acb9f07fc8b5b710`。依據關係：程式碼直接顯示順序；非同步 AI 回覆需要更新既有紀錄，並處理紀錄已被刪除的情況。

修改前基準 `f1ce706ccd15411319fb63f3acb9f07fc8b5b710` 的 LogManager 使用 atomic file replacement，原文：「[jsonData writeToFile:[LogManager logsPath] atomically:YES];」— [LogManager.m:310](../Manager/LogManager.m#L310)。Settings 中的人工修正與 SpringBoard 中的 AI 回覆可能同時寫入；不能把 atomic replacement 當作跨 process 的 read-modify-write transaction。此為根據現有寫入方式推論的實作風險，需要以單一寫入擁有者或明確的跨 process 同步處理。

通知新增、AI 回覆、人工修正、刪除及重設須共用跨 process 的寫入同步。每次紀錄更新檢查通知與判斷請求識別，避免遲到回覆覆寫較新結果或重新建立已刪除紀錄。AI 回覆、逾時與手動補發分開處理，正常自動轉發分支只可觸發一次。此可靠性設計已實作；本機跨 process 寫入測試已通過。

## 整體確認與驗收

使用者已確認完整方案並授權實作、雙 scheme 建置及 GitHub commit／push。後續補充確認 AI 可略過，以及可設定 provider／endpoint。

實作驗收需包括：既有紀錄相容、觀察模式不因 AI 判斷略過轉發、攔截模式的正確分支、失敗及逾時照常轉發、同 App 最近期修正選取、刪通知後修正仍保留、人工修正不自動補發、以及 Settings 與 AI 回覆同時更新時不遺失資料。Static checks 不能代替模型判斷效果、原版 runtime 或裝置轉發證據。

## Provider 與可選功能補充

AI 預設關閉。未設定所選 provider 的 token，或關閉 AI 時，不建立 AI 請求或等待計時器，直接沿用 Bark。Cloudflare 預設 endpoint 需要 Account ID；完整自訂 endpoint 若沒有 `{account_id}` 變數則不需要它。這反映使用者後續確認的可選功能範圍。

Provider 提供 Cloudflare Workers AI 與 Jev／System One。每個 provider 分開保存 token 和 endpoint，切換 provider 不會將另一服務的 token 送出去。Cloudflare 模型選擇 Clef／Clef-flash，System One 可輸入模型名稱，預設 `jev-latest`。Endpoint 可自訂完整 URL，Cloudflare URL 支援 `{account_id}` 與 `{model}` 變數。API token 編輯頁遮蔽顯示內容。

兩種 provider 共用 typed decision request。Cloudflare 公告原文：「Clef follows the System One API」— [模型相容性章節](https://developers.cloudflare.com/changelog/post/2026-10-01-clef-workers-ai/)。依據關係：官方直接陳述協定相容；Cloudflare 回覆另有 `success/result` 外層，所以程式分開解包。

Jev 的 endpoint 與模型別名已核對。原文：「POST https://api.typesafe.ai/v1/systemone」及「"model": "jev-latest"」— [TypeSafe API，Evaluation endpoint / Request body](https://docs.typesafe.ai/api)。依據關係：來源直接提供連線與模型名稱；自訂 URL 僅支援這個 System One 協定，沒有宣稱支援 Chat Completions。

## 本輪驗證與限制

本機 AI 測試共 303 assertions，涵蓋兩種回覆 adapter、缺少 token、失敗與逾時、只轉發一次、修正選取／保留、紀錄淘汰後仍沿用已捕捉的通知進行轉發，以及跨 process 寫入。Preferences schema 與版本同步檢查、既有四項 regression commands 亦通過；通知重播為 20 assertions。

指定 guest `~/.vphone/machines/iOS-26.6.2` 已由 `dpkg` 安裝 RootHide candidate。實際通知、SpringBoard hook、本機 HTTP、Bark request 與 UI 操作均已讀回。原文：「"passed": true」— [runtime 矩陣](/Users/wingchan/Project/Ve/packages/native-release-2.3.0/guest/runtime-matrix.json)。依據關係：此矩陣記錄實際 guest 通知及 HTTP 次數，但模型回覆來自 deterministic fixture，不能證明真實模型的準確率。

人工修正保留 AI 原判斷且不補發、獨立補發一次、下一次帶最新 prompt 與修正 context、刪通知後例子仍保留、入口返回不重複，以及 prompt／provider／endpoint 儲存讀回均已驗證。原文：「"passed": true」— [後續 context](/Users/wingchan/Project/Ve/packages/native-release-2.3.0/guest/feedback-context-verification.json) 與 [修正保留](/Users/wingchan/Project/Ve/packages/native-release-2.3.0/guest/correction-retention-verification.json)。依據關係：這些是 guest 的真實 HTTP payload 與檔案讀回；其中的模型分數仍屬 fixture。

原有 Notifications 入口依賴 legacy `lazyLoadBundle:` 時機，在指定 guest 未顯示。改為在已載入的 `PSListController` 出現時辨識 `BulletinBoardController`，加入單一 Logs 與設定捷徑。設定 bundle 保持獨立；沒有把全部 Preferences controllers 重編進 Target。

測試曾發現新增 plist 的 `keyboard` 使用 NSNumber，導致 `keyboardTypeForString:` 收到錯誤型別。已改為字串，補 schema regression，並成功載入及操作設定頁。此為本輪發現並修正的實作錯誤；不把該次 crash 當成舊 Safe Mode 根因。

Rootless／RootHide candidate 的 arm64／arm64e ABI、簽署及保存 dSYM UUID 已通過。標準 rootless 實機、正式服務認證及真實模型辨識品質仍未測，不沿用舊版本 runtime 成功旗標。

正式 package 來源 commit：`d8c6105344fa2863872bb73596b9b8ea2a41b2bf`。Rootless SHA-256：`101c4e9ad44a0fc64e4f8a236a4d6d131930b7d2d1ed2a13f1299689a0e72d7c`；RootHide SHA-256：`67b61fcd0210fa25a5040ee7975cac43c040535b1375d82ff5f0c1458550ffa2`。最終讀回原文：「"matches_prior": true」— [guest 設定還原](/Users/wingchan/Project/Ve/packages/native-release-2.3.0/guest/preferences-restored.json)。此結果確認測試前設定已還原；新版 Ve 保留在指定 guest，臨時通知 App 已移除。

## 2026-10-04 設定介面修正

狀態：已處理，指定 vphone 介面驗證通過。新增的設定標籤、說明、選單、驗證錯誤及 prompt／token／endpoint 編輯頁改用英文，配合既有 Settings 介面。預設 prompt 改用相同意思的英文規則，識別為 `default-v2`；已儲存的自訂 prompt 保持原值。

連線設定按 provider 顯示。Jev 只顯示 Jev 模型與 token；Cloudflare 只顯示 Clef 模型與 Cloudflare token。兩者分別保存原有 token、URL 及模型值。切換 provider、返回 endpoint 編輯頁後，重新計算可見欄位。

Cloudflare Account ID 僅在選取 Cloudflare 且 endpoint 包含 `{account_id}` 時顯示。標準 REST API 仍需要它。官方原文：「You need your API token and Account ID to use the REST API.」— [Workers AI REST API，第 1 節](https://developers.cloudflare.com/workers-ai/get-started/rest-api/#1-get-api-token-and-account-id)，2026-10-04 核對。依據關係：官方直接列出標準 endpoint 的需要；自訂完整 URL 不使用該變數時，程式已有的替換規則不需要額外 Account ID，介面因此隱藏該欄位。

本機 AI 測試 303 assertions、Preferences schema／英文 UI 契約及通知重播 20 assertions 通過。RootHide arm64／arm64e package 已建置，ABI 檢查通過並安裝到指定 guest。此修正仍為本機變更，沒有更新已發佈的 2.3.0 assets。

指定 guest 已驗證 provider 切換、自訂完整 URL 隱藏 Account ID、Restore Default 恢復欄位，以及英文 prompt／token／endpoint 編輯頁與修正清除對話框。原文：「"passed": true」— [介面驗證](/Users/wingchan/Project/Ve/packages/provider-settings-20261004/ui-verification.json)。依據關係：結果來自實際 UI tree、儲存後設定讀回與安裝 binary SHA-256 比對。兩個臨時修改的設定已還原，來源 log 與修正例子沒有清除。此輪只驗證設定介面及儲存，沒有呼叫真實模型。

## 2.3.1 build

狀態：已處理，正式 build 與指定 vphone 設定介面驗證通過。使用者要求將上述設定介面修正產生新 build，版本同步為 2.3.1。沿用兩個獨立 package scheme、來源 commit、ABI／簽署／dSYM UUID 驗證、指定 vphone 安裝讀回及 GitHub prerelease 流程。原有 2.3.0 assets 保留。

2.3.1 來源 commit：`f15c6353e6f90ed6146808845c0a727184432f69`。兩款 package 都由此 commit 的乾淨 tracked source 原生建置。Rootless SHA-256：`08d0f3aae6d787b06c7cf77a9bd0a72c5c02869a1a68281dc627cbe824bfb1c6`；RootHide SHA-256：`b8d50399eaaaaad05a3a3561bd908c595aa5837e0b85d58568598d55342fa904`。

正式 RootHide package 已安裝，`dpkg-query` 讀回 2.3.1，三個 installed binary SHA-256 與正式 artifact 相符。Respring 後設定介面、provider 欄位、自訂 URL 儲存、Restore Default、英文編輯頁及清除修正對話框均通過。原文：「"passed": true」及「"matches_prior": true」— [2.3.1 runtime 驗證](/Users/wingchan/Project/Ve/packages/native-release-2.3.1/RUNTIME-VERIFICATION-2.3.1.json)。依據關係：此檔記錄指定 guest 的 UI／設定及 installed identity；本次沒有重跑通知／HTTP 矩陣，也沒有呼叫真實模型或測試 rootless 實機。

## 2.3.2 Notification Logs 英文介面

狀態：已處理，正式 build 及指定 vphone 驗證通過。使用者要求 Notification Logs 也改用英文，並詢問 0.9 Skip threshold 的意思。列表 AI 狀態、詳細頁、Bark 狀態、修正／補發及錯誤訊息改用英文，通知內容與修正原因保留原文。詳細頁增加當次儲存的 Skip threshold，與 Skip score 一起顯示。

0.9 是略過通知的操作門檻，並不表示實際準確率。原文：「if (probability.doubleValue >= threshold) return @"skip";」— [VEAIPolicy.m:108](/Users/wingchan/Project/Ve/Manager/VEAIPolicy.m:108)，2.3.2 修改時核對。依據關係：程式直接以大於或等於門檻分類為 skip；只有 Filter 模式按分類攔截，Observe 仍照常轉發。本次沒有改動判斷或轉發規則。

使用者追加 API raw data。按 AI API 範圍實作：每條新 AI 請求保存遮蔽後的 URL／headers／request body、HTTP status／response body、transport error 及耗時。詳細頁新增可即時更新、捲動及複製 JSON 的 AI API Raw Data 頁。各 body 以 16 KiB 為上限，超出時保留原始 byte count 並標示 truncated。舊紀錄沒有原始請求／回覆時直接標示未有記錄，不重建或補發。

Raw data 與原有 AI metadata 共用 request ID 及 store lock，遲到回覆只更新同一紀錄，已刪除或過期 request 不會重新建立紀錄。關閉 AI 或未設定憑證時記錄 not_requested，仍不建立 AI 請求或等待計時器。新 raw data 測試合共 312 assertions，涵蓋 request／response 保存、憑證遮蔽、16 KiB 限制、HTTP failure／transport error 與逾時回覆。

使用者明確選擇 AI 和 Bark request／response，因此 raw data 頁合併顯示 AI、自動 Bark 轉發及最新一次手動補發的獨立資料。Bark 的 API key（包括 URL 路徑）與加密 key 遮蔽；加密傳送時保存實際送出的 ciphertext，不改動原有加密或 payload。手動補發另有 request ID，舊回覆不能覆寫較新的補發紀錄。最終本機測試共 316 assertions 通過。

2.3.2 正式來源 commit：`e4590760a722ad4409d06d4221b75398ba265bfe`。Rootless SHA-256：`df1ea370e5853e4d5c648a6c25b7502736aafd6a136590ac31d0c450f2c86ba7`；RootHide SHA-256：`37fd6ab4346b7964c1d5b01ee1576f11d39697bdef98e81d344fb84011a3c565`。兩個 scheme 的 ABI、簽署及保存 dSYM UUID 通過，installed 三個 binary hash 與正式 RootHide artifact 相符。

指定 guest 的六項通知／HTTP 矩陣、英文 Notification Logs、當次分數／門檻、修正及補發對話框、AI／Bark／手動補發 raw data 與 Copy JSON 已通過。原文：「"passed": true」及「"matches_prior": true」— [2.3.2 runtime 驗證](/Users/wingchan/Project/Ve/packages/native-release-2.3.2/RUNTIME-VERIFICATION-2.3.2.json)。依據關係：實際 HTTP request body 與所存 raw body 相符，憑證遮蔽且逾時／遲到回覆未增加轉發次數；模型分數仍為 fixture，不表示真實模型準確率。測試前設定已還原。

## 2026-10-04 API raw data 按服務分頁

狀態：已處理，候選及正式 RootHide 產物的指定 vphone 介面驗證通過；以 2.3.3 交付，2.3.2 既有 assets 保留。使用者指出合併 JSON 容易把 AI 判斷回覆與 Bark 傳送回覆看成同一份。介面改為 AI API Raw Data、Bark API Raw Data 兩個入口。依使用者補充，Bark 自動轉發及手動補發放在同一頁，各自保留 request／response。儲存及轉發邏輯沿用。

已讀回兩個入口及各自的 Copy JSON：AI 只包含 AI trace，Bark 只包含 automatic／manual traces。原文：「"passed": true」— [分頁介面驗證](/Users/wingchan/Project/Ve/packages/api-raw-separate-view/ui-verification.json)。依據關係：指定 guest 的 UI 及複製後資料實測；因新版 vphone clipboard RPC 不容許跨 process 讀取，Bark 的複製內容改由同一 App 的未儲存文字編輯頁讀回，離開時沒有儲存或修改 prompt。此驗證只使用既有合成紀錄，沒有送出新 API 請求。

## 2026-10-04 Notification Logs 開頁停頓

狀態：已實作，vphone 受控慢讀檔及功能回歸通過，實機覆核待完成。使用者報告約 100 條紀錄，每次進入列表都會停頓一兩秒；要求先轉場，再載入。正常 vphone 的 100 條／5 日合成資料同步載入約 26 ms，未重現同樣實機時長。受控 1.5 秒讀檔延遲在實際 getJson／列表載入路徑重現約 1,552 ms 主線程阻塞。

改為 viewDidAppear 後在背景 queue 準備列表，主線程只使用快照。合併刷新請求，搜尋／排序不同時拒絕舊結果；同一查詢的資料更新可先顯示已有快照，避免持續新通知令載入畫面一直等待。返回頁面保留目前內容。自訂 cell 刷新及 stable record ID 已修正，避免排序／搜尋後顯示舊 cell 文字。

相同慢讀檔測試的主線程資料準備由約 1,552 ms 降至約 0.002 ms，列表稍後正確更新。這不代表整個轉場耗時 0.002 ms，也不能代替實機結果。原文：「"max_main_thread_ms": 1551.6953750000084」及「"max_main_thread_ms": 0.001791666818462545」— [修正前](/Users/wingchan/Project/Ve/packages/list-latency/slow-before.json)／[修正後](/Users/wingchan/Project/Ve/packages/list-latency/slow-after.json)。

日期／App 排序、搜尋、取消及再次進入回歸均通過。原文：「"passed": true」— [功能驗證](/Users/wingchan/Project/Ve/packages/list-latency/functional-verification.json)。臨時延遲及 DEBUG instrumentation 已移出 product source，另留在 ignored debug artifacts 方便重現。原有 guest logs 已還原，原文：「"byte_identical": true」— [紀錄還原](/Users/wingchan/Project/Ve/packages/list-latency/logs-restored.json)。本次沒有真實 API 請求或實機操作，剩餘驗收為使用者安裝 2.3.3 後覆核實機停頓。

## 2026-10-04 2.3.3 正式產物與 main 整合

使用者要求建置並發布至 GitHub，以及 commit／push 至 main。main 可 fast-forward，保留既有功能分支提交。正式建置來源：`05d498e423f7f2077e11e0970bab80774d2cfac9`，tracked source 在兩次建置時均乾淨。原文：「"source_clean_for_build": true」— [2.3.3 建置紀錄](/Users/wingchan/Project/Ve/packages/native-release-2.3.3/BUILD-INFO-2.3.3.json)。Rootless SHA-256：`4f0bdd9a9b6f79b6e2eb79ade810ee0afdbf7b54a8f309c50d63733d16d31b7f`；RootHide SHA-256：`08ac0a33f07aa1acf3362c1ad47fa7e2fb4923900e84a173a2c1fc533864a495`。兩個 scheme 均通過 ABI、簽署及保存 dSYM UUID 核對。

316 項 AI assertions、20 項跨 process 重播 assertions、5 項通知授權測試，以及 settings／bootstrap／installer／Relaxin contracts 通過。指定 `iOS-26.6.2` 已安裝正式 RootHide 包，三個 installed binary hash 相符。原文：「"package_version_verified": true」及「"passed": true」— [2.3.3 runtime 驗證](/Users/wingchan/Project/Ve/packages/native-release-2.3.3/RUNTIME-VERIFICATION-2.3.3.json)。依據關係：正式包的版本、binary identity、列表進入／再次進入及 AI／Bark reader 實測通過；受控慢讀檔及完整搜尋／排序回歸則明確列為提交前候選測試。這些結果不代替實機卡頓或真實模型準確率驗證。

## 2026-10-04 完整 raw data、官方 context 核對及詐騙規則

狀態：已處理，2.3.4 正式產物的本機及指定 vphone 驗證通過，GitHub prerelease 已交付；真實 Jev／Clef 的判斷效果仍待驗證。使用者要求完整 request／response，撤回原有 capture 的整理方式。新 capture 保存完整 body bytes、原始 UTF-8 text、URL、可取得的 headers、status 及錯誤，不再以 JSON 解析結果取代 body，不再遮蔽或截斷。Base64 是可還原完整 bytes 的儲存表示。頁面直接呈現 body 原文，Copy 可選 Full Trace、JSON Archive 或各次 request／response body；Bark 自動與手動呼叫仍在同一頁。舊資料已失去的內容無法補回，介面標示 legacy capture。

官方文件容許政策及例子放 state，並未要求全部搬入 instructions。官方原文：「examples」— [TypeSafe State](https://docs.typesafe.ai/concepts/state#state-can-be-a-simple-string-or-a-structured-json-value)，來源直接允許這個輸入。官方 SDK 及公開 Clef encoder 的交叉核對見[研究筆記](jev-instructions-and-raw-trace-review.md)。實作保留 state，instructions 改用 backtick 明確引用 `notification`、`current_policy.rules`、`corrected_examples`，完整定義兩種 should_forward 標籤與 skip 答案的相反方向，並補上 Noul true／false criteria。人工修正是後續 inference 的 context，沒有訓練模型權重，也沒有證據保證改成某個欄位名稱就提高準確率。

預設政策與判斷問題加入明確 scam／fraud／phishing 企圖，同時保留真正的防詐騙警報、交易及驗證碼。最新自訂 prompt 優先，人工例子不能覆蓋現行規則；舊預設 prompt 採用 default-v3，自訂文字保留。Observe／Filter、0.9 門檻及失敗／逾時的轉發邊界沿用。

331 項 assertions 與英文 settings contract 通過。兩個 package 的 ABI、簽署及保存 dSYM UUID 核對通過，正式 RootHide 包已安裝至 `iOS-26.6.2`，三個 installed binary hash 相符。合成 HTTP 測試核對 AI、自動 Bark 及手動 Bark 的完整 body；每個 response 超過原有 16 KiB 限制，仍與發送端 bytes 相符。原文：「"passed": true」— [2.3.4 正式 runtime 驗證](https://github.com/WingCH/Ve/releases/download/2.3.4/RUNTIME-VERIFICATION-2.3.4.json)。依據關係：正式包的受控 receiver／sender 和 App 所存 bytes 實測，分類分數由 fixture 提供，不能據此聲稱模型可識別真實詐騙。

Request Body 的原文複製另在同一 Settings process 的未儲存 prompt editor 讀回，原文：「"passed": true」— [原文複製驗證](/Users/wingchan/Project/Ve/packages/raw-trace-2.3.4/copy-verification.json)。離開時沒有 Save；vphone 原有設定與 logs 已還原。Capture 的範圍是 App 交給 NSURLSession 及 callback 收到的資料，headers 以系統可取得的值為準。此證據不代表 TLS 封包逐 byte capture。

## 2026-10-04 2.3.4 GitHub 正式交付

正式建置及 release tag 的來源 commit：`c71140e99930692c3b71f58b4717759f9813de0c`。兩次建置時 tracked source 均乾淨，原文：「"source_clean_for_build": true」— [BUILD-INFO-2.3.4.json](https://github.com/WingCH/Ve/releases/download/2.3.4/BUILD-INFO-2.3.4.json)。Rootless SHA-256：`287bdb3e447a702c3ab2f2d0e603500b9d19deb9be171955b6657fbf5500766e`；RootHide SHA-256：`8125c97dfec6d6bda83c2fc9ea969a427b46ee920579f0844c4228efba703e9d`。

正式包重新完成通知／HTTP／原文複製驗證，沒有沿用 binary hash 不同的候選結果。20 項跨 process 重播 assertions、5 項通知授權測試及 bootstrap／installer／Relaxin contracts 亦通過。GitHub 的 5 個 assets 已全部下載核對 bytes、SHA-256 與 API digest。發布後的此文件提交只補交付紀錄，沒有改動正式包的程式碼。
