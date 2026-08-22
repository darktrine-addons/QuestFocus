-- Localizations/zhCN.lua — Simplified Chinese (zhCN) strings.
-- Overlays Chinese onto ns.L when the client locale is zhCN. enUS.lua
-- remains the source of truth for the full key set; the fallback chain
-- in L returns the English value for any key this file leaves out.
-- Mirrors the key order of enUS.lua for easy diffing.

local addonName, ns = ...
local L = ns.L

if GetLocale() == "zhCN" then

-- ============================================================
-- BINDING_ — 按键绑定名称（Bindings.xml）
-- ============================================================

L.BINDING_HEADER    = "QuestFocus"
L.BINDING_FOCUS     = "当前区域"
L.BINDING_FOCUS_ADD = "当前区域所有任务"
L.BINDING_REVERT    = "恢复"

-- ============================================================
-- STATUS_ — 模块状态词
-- ============================================================

L.STATUS_ENABLED      = "已启用"
L.STATUS_DISABLED     = "已禁用"
L.STATUS_ACTIVE       = "已启用（激活中）"
L.STATUS_PENDING_BOOT = "已启用（等待重载）"
L.STATUS_ON           = "开启"
L.STATUS_OFF          = "关闭"

-- ============================================================
-- CHAT_ — 斜杠命令输出 / 聊天消息
-- ============================================================

L.CHAT_MODULES               = "模块："
L.CHAT_TOGGLE_HINT           = "使用 /qf module enable|disable <名称> 切换；队伍同步会立即生效，区域筛选需要 /reload。"
L.CHAT_UNKNOWN_MODULE        = "未知模块：%s"
L.CHAT_MODULE_SET             = "%s 已设置为%s。"
L.CHAT_MODULE_SET_RELOAD      = "%s 已设置为%s。/reload 后生效。"
L.CHAT_PARTY_DEBUG            = "队伍调试%s"
L.CHAT_PARTY_NOT_LOADED       = "队伍同步模块未加载。"
L.CHAT_BROADCAST_RESERVED     = "广播功能已保留，目前尚未实现。"
L.CHAT_ZF_DISABLED             = "区域筛选模块已禁用。使用 /qf module list 查看模块列表。"
L.CHAT_STATUS                  = "筛选：%s，可恢复：%d"
L.CHAT_COMMANDS                = "命令："
L.CHAT_HELP_BASIC              = "  /qf [筛选] | promote | revert | status"
L.CHAT_HELP_MODES              = "  模式：/qf all | untrack | campaign | daily | weekly | important | ready | inprogress"
L.CHAT_HELP_SETTINGS           = "  /qf settings"
L.CHAT_HELP_MODULES            = "  /qf module list | module enable|disable <名称>"
L.CHAT_HELP_PARTY              = "  /qf party debug | party broadcast on|off"
L.CHAT_NOTHING_TO_PREVIEW      = "没有正在追踪的任务——没有可预览的内容。"
L.CHAT_NO_RELOAD_PENDING       = "没有需要通过界面重载应用的待处理更改。"
L.CHAT_CANNOT_CHANGE_COMBAT    = "战斗中无法更改任务追踪。"
L.CHAT_UNKNOWN_MODE            = "未知模式：%s"
L.CHAT_APPLIED                 = "%s：追踪 %d，取消追踪 %d —— 使用“/qf revert”恢复"
L.CHAT_NO_ZONE                 = "无法确定当前区域。"
L.CHAT_CANNOT_REVERT_COMBAT    = "战斗中无法恢复。"
L.CHAT_NO_SNAPSHOT             = "没有可恢复的状态快照。"
L.CHAT_REVERTED                = "恢复：重新追踪 %d，取消追踪 %d"
L.CHAT_THIS_ZONE               = "当前区域"
L.CHAT_ZONE_CHANGED            = "区域已改变——%s 中有 |cffffffff%d|r 个任务。"
L.CHAT_REFOCUS_LINK            = "[重新聚焦]"
L.CHAT_DOT_HINT                = "队伍状态指示器会实时更新——将鼠标悬停在任务行上可查看每名队员的进度。颜色和形状：/qf settings。"

-- ============================================================
-- CHAT_MODE_ — 聊天环境中的模式显示名称
-- ============================================================

L.CHAT_MODE_ZONE_FILTER = "区域筛选"
L.CHAT_MODE_UNTRACK_ALL = "全部取消追踪"
L.CHAT_MODE_TRACK_ALL   = "全部追踪"
L.CHAT_MODE_CAMPAIGN    = "战役"
L.CHAT_MODE_DAILY       = "日常"
L.CHAT_MODE_WEEKLIES     = "周常"
L.CHAT_MODE_IMPORTANT   = "重要任务"
L.CHAT_MODE_READY       = "可交任务"
L.CHAT_MODE_IN_PROGRESS = "进行中"

-- ============================================================
-- MODE_ — 模式描述（菜单、鼠标提示）
-- ============================================================

L.MODE_ZONE_FILTER = "当前区域"
L.MODE_TRACK_ALL   = "任务日志中的全部任务"
L.MODE_CAMPAIGN    = "战役任务"
L.MODE_DAILY       = "日常任务"
L.MODE_WEEKLIES    = "周常任务"
L.MODE_IMPORTANT   = "重要任务"
L.MODE_READY       = "可交任务"
L.MODE_IN_PROGRESS = "进行中的任务"
L.MODE_UNTRACK_ALL = "全部取消"
L.MODE_ACTIVE      = "激活中"

-- ============================================================
-- SECTION_ — 设置面板分区标题
-- ============================================================

L.SECTION_GLOBAL     = "全局"
L.SECTION_ZONEFILTER = "区域筛选"
L.SECTION_PARTYSYNC  = "队伍同步"

-- ============================================================
-- SETTING_ — 设置面板标签 + 鼠标提示
-- ============================================================

L.SETTING_STYLE_PREVIEW        = "样式预览"
L.SETTING_ZF_ENABLE            = "启用区域筛选"
L.SETTING_ZF_ENABLE_TIP        = "筛选当前区域内的任务，并支持一键恢复。\n开启后会在任务追踪器和世界地图任务日志中添加两个小按钮。\n\n|cffff8c26此选项的更改需要 /reload 才能生效。|r"
L.SETTING_PS_ENABLE            = "启用队伍同步"
L.SETTING_PS_ENABLE_TIP        = "组队时，在每个任务上显示彩色状态指示器。\n同时在任务的鼠标提示中添加“队伍状态：”部分，显示每名队员的任务进度。\n\n|cff44ff44立即生效。|r"
L.SETTING_RELOAD_UI            = "重载界面"
L.SETTING_RELOAD_UI_TIP        = "当带有“需要 /reload”标记的设置发生更改时，点击此项执行 /reload。没有待处理更改时不会执行任何操作。"
L.SETTING_ZF_UNTACK_CLEARS      = "恢复时保留手动取消追踪"
L.SETTING_ZF_UNTACK_CLEARS_TIP = "开启后，激活筛选器期间手动取消追踪的任务，在恢复后不会被重新追踪。按角色保存。\n\n|cffaaaaaa默认关闭：即使你手动取消了其中一些任务了，恢复仍会将任务列表精确恢复到激活筛选器前的状态，|r"
L.SETTING_ZF_ZONE_NUDGE         = "区域变更提醒"
L.SETTING_ZF_ZONE_NUDGE_TIP     = "开启后，激活筛选器期间进入新区域时，筛选按钮（放大镜图标）会闪烁，并在聊天框中显示带有一键[重新聚焦]链接的提示。\n在你点击之前，不会重新追踪任何任务。按角色保存。"

-- ============================================================
-- SIZE_ / SHAPE_ / ANCHOR_ / PALETTE_ / RAID_ — 下拉选项
-- ============================================================

L.SIZE_TINY   = "极小（6像素）"
L.SIZE_SMALL  = "小（8像素）"
L.SIZE_MEDIUM = "中（10像素）"
L.SIZE_LARGE  = "大（12像素）"

L.SHAPE_SQUARE  = "方形"
L.SHAPE_CIRCLE  = "圆形"
L.SHAPE_DIAMOND = "菱形"

L.ANCHOR_TOP_RIGHT      = "右上角"
L.ANCHOR_RIGHT_OF_TITLE = "任务标题右侧"
L.ANCHOR_LEFT_OF_TITLE  = "任务标题左侧"

L.PALETTE_DEFAULT      = "默认（绿/黄/蓝/橙）"
L.PALETTE_DEUTERANOPIA = "红绿色盲（红绿友好）"
L.PALETTE_TRITANOPIA   = "蓝黄色盲（蓝黄友好）"

L.RAID_ALWAYS = "始终显示完整列表"
L.RAID_AT_10  = "10名以上成员时汇总"
L.RAID_AT_20  = "20名以上成员时汇总"

-- ============================================================
-- SETTING_PS_ — 队伍同步外观设置标签 + 鼠标提示
-- ============================================================

L.SETTING_PS_SIZE             = "状态指示器大小"
L.SETTING_PS_SIZE_TIP         = "每个追踪任务行上状态指示器的直径。"
L.SETTING_PS_SHAPE             = "状态指示器形状"
L.SETTING_PS_SHAPE_TIP         = "状态指示器的形状。圆形使用圆形透明遮罩覆盖纯色；菱形则将相同纹理旋转45度。"
L.SETTING_PS_ANCHOR            = "状态指示器位置"
L.SETTING_PS_ANCHOR_TIP        = "设置状态指示器在每个任务标题上的位置。【任务标题左侧】选项会向左偏移30像素，以避开任务类型图标。若无任务标题，则强制设置为【右上角】"
L.SETTING_PS_PALETTE            = "颜色方案"
L.SETTING_PS_PALETTE_TIP        = "为色弱用户提供替代颜色方案。默认 = 绿色 / 黄色 / 蓝色 / 橙色。"
L.SETTING_PS_OPACITY            = "状态指示器透明度"
L.SETTING_PS_OPACITY_TIP        = "状态指示器的亮度。40% 会使其融入背景；100% 为完全不透明。"
L.SETTING_PS_RAID_THRESHOLD     = "大型队伍中汇总鼠标提示"
L.SETTING_PS_RAID_THRESHOLD_TIP = "在大型队伍中，逐个显示成员“队伍状态”的鼠标提示列表会过长。当队伍人数达到阈值后，将其替换为一行汇总：有多少成员正在进行该任务、可以交任务或没有该任务。状态指示器仍会正常显示。"
L.SETTING_PREVIEW_TRACKER       = "在任务追踪器中预览（30秒）"
L.SETTING_PREVIEW_TRACKER_TIP   = "临时在任务标题上添加最多4个示例状态指示器，以便查看当前样式在实际环境中的效果。如果追踪任务少于4个，则相应减少；没有追踪任务时不执行任何操作。再次点击可延长30秒计时；关闭设置面板会结束预览。"

-- ============================================================
-- PREVIEW_ — 任务追踪器 / 内联预览标签 + 鼠标提示
-- ============================================================

L.PREVIEW_ALIGNED    = "全部接取"
L.PREVIEW_MIXED      = "部分接取"
L.PREVIEW_READY      = "有人可交"
L.PREVIEW_SHAREABLE  = "可共享"
L.PREVIEW_TIP_ALIGNED   = "队伍中的所有成员都接取了此任务，并且正在推进任务进度。无需协调。"
L.PREVIEW_TIP_MIXED     = "部分队伍成员接取了此任务，部分成员没有。建议确认一下。"
L.PREVIEW_TIP_READY     = "至少有一名队伍成员已完成任务目标且可以交任务。"
L.PREVIEW_TIP_SHAREABLE = "只有你接取了此任务，并且至少有一名队友位于同一区域，可以分享此任务。"

-- ============================================================
-- MENU_ — 任务追踪模式菜单项 + 底部提示
-- ============================================================

L.MENU_API_UNAVAILABLE = "此客户端上的菜单 API 不可用。"
L.MENU_ACTIVE          = "（激活中）"
L.MENU_DRIFTED         = "（已偏离）"
L.MENU_TITLE           = "任务追踪模式"
L.MENU_TRACK_ALL       = "任务日志中的全部任务"
L.MENU_FOCUS           = "当前区域"
L.MENU_FOCUS_ADD       = "当前区域所有任务"
L.MENU_CAMPAIGN        = "战役任务"
L.MENU_DAILY           = "日常任务"
L.MENU_WEEKLIES        = "周常任务"
L.MENU_IMPORTANT       = "重要任务"
L.MENU_READY            = "可交任务"
L.MENU_IN_PROGRESS      = "进行中的任务"
L.MENU_UNTRACK_ALL      = "取消所有任务"
L.MENU_OPEN_SETTINGS    = "打开设置……"
L.MENU_WARN_FOOTER      = "此操作会清空任务列表。"
L.MENU_REVERT_FOOTER    = "/qf revert 可恢复之前的状态。"

-- ============================================================
-- KEY_ / TIP_KEY_ — 鼠标按键标签（菜单与鼠标提示大小写）
-- ============================================================

L.KEY_LEFT_CLICK           = "左键"
L.KEY_SHIFT_LEFT_CLICK     = "Shift+左键"
L.TIP_KEY_LEFT_CLICK       = "左键"
L.TIP_KEY_SHIFT_LEFT_CLICK = "Shift+左键"

-- ============================================================
-- TIP_ — 任务追踪按钮鼠标提示
-- ============================================================

L.TIP_NO_FILTER            = "无筛选"
L.TIP_FILTER_DRIFT         = "筛选：%s（%s）"
L.TIP_FILTER_CLEAN         = "筛选：%s"
L.TIP_DRIFT_BOTH           = "新增 %d，移除 %d"
L.TIP_DRIFT_ADDED          = "新增 %d"
L.TIP_DRIFT_REMOVED        = "移除 %d"
L.TIP_NARROW_DESC          = "将任务列表缩小为当前区域内有目标的任务。"
L.TIP_NO_CHANGES           = "（无变化）"
L.TIP_MAP_UNKNOWN           = "当前区域未知——请打开一次世界地图。"
L.TIP_FOCUS_LINE            = "%s：当前区域 %s |cffaaaaaa（追踪 %d）|r%s"
L.TIP_FOCUS_ADD_LINE        = "%s：当前区域所有任务 %s |cffaaaaaa（追踪 %d）|r%s"
L.TIP_REAPPLY_HINT          = "|cff44ff44绿色按钮|r|cffaaaaaa 会重新应用当前模式。|r"
L.TIP_WARN_LEGEND           = "= 任务追踪器将隐藏"
L.TIP_HOTKEYS               = "右键：模式菜单  |  Shift+右键：设置"
L.TIP_RESTORE_TITLE          = "恢复"
L.TIP_NOTHING_TO_RESTORE     = "没有可恢复的内容。"
L.TIP_RESTORES_N             = "恢复筛选器应用前的 %d 个任务|4任务:任务|。"
L.TIP_KEEPS_N                = "保留你之后添加的 %d 个任务|4任务:任务|。"
L.TIP_CLEARS_FILTER          = "清除筛选状态——不会更改任务追踪。"
L.TIP_REAPPLY_TITLE          = "重新应用任务追踪模式"
L.TIP_CURRENT_MODE           = "当前模式：%s"
L.TIP_REAPPLY_DESC           = "清除偏离状态并重新应用所选模式。"
L.TIP_NO_MODE_ACTIVE         = "没有活动模式。"

-- ============================================================
-- PARTY_ — 队伍进度鼠标提示 + 状态指示器
-- ============================================================

L.PARTY_READY_TO_TURN_IN  = "可以交任务"
L.PARTY_NOT_ON_QUEST      = "未接此任务"
L.PARTY_IN_PROGRESS_COUNT = "进行中（%d/%d）"
L.PARTY_IN_PROGRESS       = "进行中"
L.PARTY_SUMMARY           = "队伍：|cffffffff%d|r 人进行中 · |cff66ff66%d|r 人可交 · |cff888888%d|r 人未接"
L.PARTY_STATE             = "队伍状态："
L.PARTY_YOU               = "你"
L.PARTY_DOT_LEGEND        = "状态指示器：  %s   %s   %s   %s"
L.PARTY_DOT_READY         = "有人可交"
L.PARTY_DOT_SHARE         = "可共享"
L.PARTY_DOT_MIXED         = "部分接取"
L.PARTY_DOT_ALIGNED       = "全部接取"
L.PARTY_VISIBILITY_FOOTER = "隐藏 / 未接任务的成员行取决于战网可见性。"

end