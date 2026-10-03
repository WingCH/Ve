---
status: accepted
date: 2026-10-03
---

# 沿用現有通知範圍，並在 AI 不確定或失敗時照常轉發

AI 判斷沿用 Ve 現有通知入口條件與 App 封鎖清單。對符合原有處理條件且未封鎖的 App 通知，將來源 App 識別資訊、標題及正文送到所選 provider 的 endpoint；不另加每個 App 的 AI 允許清單。使用者希望保持現有範圍，由內容判斷減少不需要的 Bark 轉發。

預設判斷規則只篩選明確促銷或廣告。私人訊息、交易、驗證碼與安全提醒先保留。AI 不確定、逾時或 API 失敗時照常轉發，優先避免漏收。這是使用者於 2026-10-03 在設計訪談 Q1–Q3 確認的預設。

使用者在 Q9 確認最新 prompt 優先於舊修正例子。修正例子供參考，保留原有人工標籤供覆核。此優先次序需要在判斷指令中明確表達，實際模型遵循程度仍待驗證。

AI 的作用範圍是 Bark 轉發。現有來源通知發布呼叫先執行，原文：「orig_BBServer_publishBulletin_destinations(self, _cmd, bulletin, destinations);」— [VeCore.m:26](../../Tweak/Core/VeCore.m#L26)，核對版本 `f1ce706ccd15411319fb63f3acb9f07fc8b5b710`。依據關係：程式碼直接顯示執行順序；保留這個順序是本方案的範圍約束。

2026-10-04 補充：使用者確認 AI 可選，未設定 token 或關閉時直接略過 AI。Provider／endpoint 可切換，原有通知範圍與失敗照傳原則繼續適用。
