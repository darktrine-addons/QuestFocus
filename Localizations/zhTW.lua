-- Localizations/zhTW.lua -- Traditional Chinese (zhTW) strings.
-- Overlays Traditional Chinese onto ns.L when the client locale is zhTW.
-- enUS.lua remains the source of truth for the full key set; the fallback
-- chain in L returns the English value for any key this file leaves out.
-- Mirrors the key order of enUS.lua for easy diffing.

local addonName, ns = ...
local L = ns.L

if GetLocale() == "zhTW" then

    -- ============================================================
-- BINDING_ — 按鍵綁定名稱（Bindings.xml）
-- ============================================================

L.BINDING_HEADER    = "QuestFocus"
L.BINDING_FOCUS     = "目前區域"
L.BINDING_FOCUS_ADD = "目前區域所有任務"
L.BINDING_REVERT    = "復原"

-- ============================================================
-- STATUS_ — 模組狀態詞
-- ============================================================

L.STATUS_ENABLED      = "已啟用"
L.STATUS_DISABLED     = "已停用"
L.STATUS_ACTIVE       = "已啟用（啟用中）"
L.STATUS_PENDING_BOOT = "已啟用（等待重新載入）"
L.STATUS_ON           = "開啟"
L.STATUS_OFF          = "關閉"

-- ============================================================
-- CHAT_ — 斜線命令輸出 / 聊天訊息
-- ============================================================

L.CHAT_MODULES               = "模組："
L.CHAT_TOGGLE_HINT           = "使用 /qf module enable|disable <名稱> 切換；隊伍同步會立即生效，區域篩選需要 /reload。"
L.CHAT_UNKNOWN_MODULE        = "未知模組：%s"
L.CHAT_MODULE_SET             = "%s 已設定為%s。"
L.CHAT_MODULE_SET_RELOAD      = "%s 已設定為%s。/reload 後生效。"
L.CHAT_PARTY_DEBUG            = "隊伍除錯%s"
L.CHAT_PARTY_NOT_LOADED       = "隊伍同步模組未載入。"
L.CHAT_BROADCAST_RESERVED     = "廣播功能已保留，目前尚未實作。"
L.CHAT_ZF_DISABLED             = "區域篩選模組已停用。使用 /qf module list 查看模組列表。"
L.CHAT_STATUS                  = "篩選：%s，可復原：%d"
L.CHAT_COMMANDS                = "命令："
L.CHAT_HELP_BASIC              = "  /qf [篩選] | promote | revert | status"
L.CHAT_HELP_MODES              = "  模式：/qf all | untrack | campaign | daily | weekly | important | ready | inprogress"
L.CHAT_HELP_SETTINGS           = "  /qf settings"
L.CHAT_HELP_MODULES            = "  /qf module list | module enable|disable <名稱>"
L.CHAT_HELP_PARTY              = "  /qf party debug | party broadcast on|off"
L.CHAT_NOTHING_TO_PREVIEW      = "沒有正在追蹤的任務——沒有可預覽的內容。"
L.CHAT_NO_RELOAD_PENDING       = "沒有需要透過介面重新載入來套用的待處理變更。"
L.CHAT_CANNOT_CHANGE_COMBAT    = "戰鬥中無法變更任務追蹤。"
L.CHAT_UNKNOWN_MODE            = "未知模式：%s"
L.CHAT_APPLIED                 = "%s：追蹤 %d，取消追蹤 %d —— 使用“/qf revert”復原"
L.CHAT_NO_ZONE                 = "無法確定目前區域。"
L.CHAT_CANNOT_REVERT_COMBAT    = "戰鬥中無法復原。"
L.CHAT_NO_SNAPSHOT             = "沒有可復原的狀態快照。"
L.CHAT_REVERTED                = "復原：重新追蹤 %d，取消追蹤 %d"
L.CHAT_THIS_ZONE               = "目前區域"
L.CHAT_ZONE_CHANGED            = "區域已改變——%s 中有 |cffffffff%d|r 個任務。"
L.CHAT_REFOCUS_LINK            = "[重新聚焦]"
L.CHAT_DOT_HINT                = "隊伍狀態指示器會即時更新——將滑鼠懸停在任務行上可查看每名隊員的進度。顏色和形狀：/qf settings。"

-- ============================================================
-- CHAT_MODE_ — 聊天環境中的模式顯示名稱
-- ============================================================

L.CHAT_MODE_ZONE_FILTER = "區域篩選"
L.CHAT_MODE_UNTRACK_ALL = "全部取消追蹤"
L.CHAT_MODE_TRACK_ALL   = "全部追蹤"
L.CHAT_MODE_CAMPAIGN    = "戰役"
L.CHAT_MODE_DAILY       = "每日"
L.CHAT_MODE_WEEKLIES     = "每週"
L.CHAT_MODE_IMPORTANT   = "重要任務"
L.CHAT_MODE_READY       = "可回報任務"
L.CHAT_MODE_IN_PROGRESS = "進行中"

-- ============================================================
-- MODE_ — 模式描述（選單、滑鼠提示）
-- ============================================================

L.MODE_ZONE_FILTER = "目前區域"
L.MODE_TRACK_ALL   = "任務日誌中的全部任務"
L.MODE_CAMPAIGN    = "戰役任務"
L.MODE_DAILY       = "每日任務"
L.MODE_WEEKLIES    = "每週任務"
L.MODE_IMPORTANT   = "重要任務"
L.MODE_READY       = "可回報任務"
L.MODE_IN_PROGRESS = "進行中的任務"
L.MODE_UNTRACK_ALL = "全部取消"
L.MODE_ACTIVE      = "啟用中"

-- ============================================================
-- SECTION_ — 設定面板分區標題
-- ============================================================

L.SECTION_GLOBAL     = "全域"
L.SECTION_ZONEFILTER = "區域篩選"
L.SECTION_PARTYSYNC  = "隊伍同步"

-- ============================================================
-- SETTING_ — 設定面板標籤 + 滑鼠提示
-- ============================================================

L.SETTING_STYLE_PREVIEW        = "樣式預覽"
L.SETTING_ZF_ENABLE            = "啟用區域篩選"
L.SETTING_ZF_ENABLE_TIP        = "篩選目前區域內的任務，並支援一鍵復原。\n開啟後會在任務追蹤器和世界地圖任務日誌中加入兩個小按鈕。\n\n|cffff8c26此選項的變更需要 /reload 才能生效。|r"
L.SETTING_PS_ENABLE            = "啟用隊伍同步"
L.SETTING_PS_ENABLE_TIP        = "組隊時，在每個任務上顯示彩色狀態指示器。\n同時在任務的滑鼠提示中加入“隊伍狀態：”部分，顯示每名隊員的任務進度。\n\n|cff44ff44立即生效。|r"
L.SETTING_RELOAD_UI            = "重新載入介面"
L.SETTING_RELOAD_UI_TIP        = "當帶有“需要 /reload”標記的設定發生變更時，點擊此項執行 /reload。沒有待處理變更時不會執行任何操作。"
L.SETTING_ZF_UNTACK_CLEARS      = "復原時保留手動取消追蹤"
L.SETTING_ZF_UNTACK_CLEARS_TIP = "開啟後，啟用篩選器期間手動取消追蹤的任務，在復原後不會被重新追蹤。按角色儲存。\n\n|cffaaaaaa預設關閉：即使你手動取消了其中一些任務，復原仍會將任務清單精確恢復到啟用篩選器前的狀態。|r"
L.SETTING_ZF_ZONE_NUDGE         = "區域變更提醒"
L.SETTING_ZF_ZONE_NUDGE_TIP     = "開啟後，啟用篩選器期間進入新區域時，篩選按鈕（放大鏡圖示）會閃爍，並在聊天框中顯示帶有一鍵[重新聚焦]連結的提示。\n在你點擊之前，不會重新追蹤任何任務。按角色儲存。"

-- ============================================================
-- SIZE_ / SHAPE_ / ANCHOR_ / PALETTE_ / RAID_ — 下拉選項
-- ============================================================

L.SIZE_TINY   = "極小（6像素）"
L.SIZE_SMALL  = "小（8像素）"
L.SIZE_MEDIUM = "中（10像素）"
L.SIZE_LARGE  = "大（12像素）"

L.SHAPE_SQUARE  = "方形"
L.SHAPE_CIRCLE  = "圓形"
L.SHAPE_DIAMOND = "菱形"

L.ANCHOR_TOP_RIGHT      = "右上角"
L.ANCHOR_RIGHT_OF_TITLE = "任務標題右側"
L.ANCHOR_LEFT_OF_TITLE  = "任務標題左側"

L.PALETTE_DEFAULT      = "預設（綠/黃/藍/橙）"
L.PALETTE_DEUTERANOPIA = "紅綠色盲（紅綠友善）"
L.PALETTE_TRITANOPIA   = "藍黃色盲（藍黃友善）"

L.RAID_ALWAYS = "始終顯示完整清單"
L.RAID_AT_10  = "10名以上成員時彙總"
L.RAID_AT_20  = "20名以上成員時彙總"

-- ============================================================
-- SETTING_PS_ — 隊伍同步外觀設定標籤 + 滑鼠提示
-- ============================================================

L.SETTING_PS_SIZE             = "狀態指示器大小"
L.SETTING_PS_SIZE_TIP         = "每個追蹤任務行上狀態指示器的直徑。"
L.SETTING_PS_SHAPE             = "狀態指示器形狀"
L.SETTING_PS_SHAPE_TIP         = "狀態指示器的形狀。圓形使用圓形透明遮罩覆蓋純色；菱形則將相同紋理旋轉45度。"
L.SETTING_PS_ANCHOR            = "狀態指示器位置"
L.SETTING_PS_ANCHOR_TIP        = "設定狀態指示器在每個任務標題上的位置。【任務標題左側】選項會向左偏移30像素，以避開任務類型圖示。若無任務標題，則強制設定為【右上角】"
L.SETTING_PS_PALETTE            = "顏色方案"
L.SETTING_PS_PALETTE_TIP        = "為色弱使用者提供替代顏色方案。預設 = 綠色 / 黃色 / 藍色 / 橙色。"
L.SETTING_PS_OPACITY            = "狀態指示器透明度"
L.SETTING_PS_OPACITY_TIP        = "狀態指示器的亮度。40% 會使其融入背景；100% 為完全不透明。"
L.SETTING_PS_RAID_THRESHOLD     = "大型隊伍中彙總滑鼠提示"
L.SETTING_PS_RAID_THRESHOLD_TIP = "在大型隊伍中，逐個顯示成員“隊伍狀態”的滑鼠提示清單會過長。當隊伍人數達到閾值後，將其替換為一行彙總：有多少成員正在進行該任務、可以回報任務或沒有該任務。狀態指示器仍會正常顯示。"
L.SETTING_PREVIEW_TRACKER       = "在任務追蹤器中預覽（30秒）"
L.SETTING_PREVIEW_TRACKER_TIP   = "臨時在任務標題上加入最多4個範例狀態指示器，以便查看目前樣式在實際環境中的效果。如果追蹤任務少於4個，則相應減少；沒有追蹤任務時不執行任何操作。再次點擊可延長30秒計時；關閉設定面板會結束預覽。"

-- ============================================================
-- PREVIEW_ — 任務追蹤器 / 內聯預覽標籤 + 滑鼠提示
-- ============================================================

L.PREVIEW_ALIGNED    = "全部接取"
L.PREVIEW_MIXED      = "部分接取"
L.PREVIEW_READY      = "有人可回報"
L.PREVIEW_SHAREABLE  = "可分享"
L.PREVIEW_TIP_ALIGNED   = "隊伍中的所有成員都接取了此任務，並且正在推進任務進度。無需協調。"
L.PREVIEW_TIP_MIXED     = "部分隊伍成員接取了此任務，部分成員沒有。建議確認一下。"
L.PREVIEW_TIP_READY     = "至少有一名隊伍成員已完成任務目標且可以回報任務。"
L.PREVIEW_TIP_SHAREABLE = "只有你接取了此任務，並且至少有一名隊友位於同一區域，可以分享此任務。"

-- ============================================================
-- MENU_ — 任務追蹤模式選單項 + 底部提示
-- ============================================================

L.MENU_API_UNAVAILABLE = "此客戶端上的選單 API 不可用。"
L.MENU_ACTIVE          = "（啟用中）"
L.MENU_DRIFTED         = "（已偏離）"
L.MENU_TITLE           = "任務追蹤模式"
L.MENU_TRACK_ALL       = "任務日誌中的全部任務"
L.MENU_FOCUS           = "目前區域"
L.MENU_FOCUS_ADD       = "目前區域所有任務"
L.MENU_CAMPAIGN        = "戰役任務"
L.MENU_DAILY           = "每日任務"
L.MENU_WEEKLIES        = "每週任務"
L.MENU_IMPORTANT       = "重要任務"
L.MENU_READY            = "可回報任務"
L.MENU_IN_PROGRESS      = "進行中的任務"
L.MENU_UNTRACK_ALL      = "取消所有任務"
L.MENU_OPEN_SETTINGS    = "開啟設定……"
L.MENU_WARN_FOOTER      = "此操作會清空任務清單。"
L.MENU_REVERT_FOOTER    = "/qf revert 可復原之前的狀態。"

-- ============================================================
-- KEY_ / TIP_KEY_ — 滑鼠按鍵標籤（選單與滑鼠提示大小寫）
-- ============================================================

L.KEY_LEFT_CLICK           = "左鍵"
L.KEY_SHIFT_LEFT_CLICK     = "Shift+左鍵"
L.TIP_KEY_LEFT_CLICK       = "左鍵"
L.TIP_KEY_SHIFT_LEFT_CLICK = "Shift+左鍵"

-- ============================================================
-- TIP_ — 任務追蹤按鈕滑鼠提示
-- ============================================================

L.TIP_NO_FILTER            = "無篩選"
L.TIP_FILTER_DRIFT         = "篩選：%s（%s）"
L.TIP_FILTER_CLEAN         = "篩選：%s"
L.TIP_DRIFT_BOTH           = "新增 %d，移除 %d"
L.TIP_DRIFT_ADDED          = "新增 %d"
L.TIP_DRIFT_REMOVED        = "移除 %d"
L.TIP_NARROW_DESC          = "將任務清單縮小為目前區域內有目標的任務。"
L.TIP_NO_CHANGES           = "（無變化）"
L.TIP_MAP_UNKNOWN           = "目前區域未知——請開啟一次世界地圖。"
L.TIP_FOCUS_LINE            = "%s：目前區域 %s |cffaaaaaa（追蹤 %d）|r%s"
L.TIP_FOCUS_ADD_LINE        = "%s：目前區域所有任務 %s |cffaaaaaa（追蹤 %d）|r%s"
L.TIP_REAPPLY_HINT          = "|cff44ff44綠色按鈕|r|cffaaaaaa 會重新套用目前模式。|r"
L.TIP_WARN_LEGEND           = "= 任務追蹤器將隱藏"
L.TIP_HOTKEYS               = "右鍵：模式選單  |  Shift+右鍵：設定"
L.TIP_RESTORE_TITLE          = "復原"
L.TIP_NOTHING_TO_RESTORE     = "沒有可復原的內容。"
L.TIP_RESTORES_N             = "復原篩選器套用前的 %d 個任務|4任務:任務|。"
L.TIP_KEEPS_N                = "保留你之後加入的 %d 個任務|4任務:任務|。"
L.TIP_CLEARS_FILTER          = "清除篩選狀態——不會變更任務追蹤。"
L.TIP_REAPPLY_TITLE          = "重新套用任務追蹤模式"
L.TIP_CURRENT_MODE           = "目前模式：%s"
L.TIP_REAPPLY_DESC           = "清除偏離狀態並重新套用所選模式。"
L.TIP_NO_MODE_ACTIVE         = "沒有活動模式。"

-- ============================================================
-- PARTY_ — 隊伍進度滑鼠提示 + 狀態指示器
-- ============================================================

L.PARTY_READY_TO_TURN_IN  = "可以回報任務"
L.PARTY_NOT_ON_QUEST      = "未接此任務"
L.PARTY_IN_PROGRESS_COUNT = "進行中（%d/%d）"
L.PARTY_IN_PROGRESS       = "進行中"
L.PARTY_SUMMARY           = "隊伍：|cffffffff%d|r 人進行中 · |cff66ff66%d|r 人可回報 · |cff888888%d|r 人未接"
L.PARTY_STATE             = "隊伍狀態："
L.PARTY_YOU               = "你"
L.PARTY_DOT_LEGEND        = "狀態指示器：  %s   %s   %s   %s"
L.PARTY_DOT_READY         = "有人可回報"
L.PARTY_DOT_SHARE         = "可分享"
L.PARTY_DOT_MIXED         = "部分接取"
L.PARTY_DOT_ALIGNED       = "全部接取"
L.PARTY_VISIBILITY_FOOTER = "隱藏 / 未接任務的成員行取決於 Battle.net 可見性。"

end