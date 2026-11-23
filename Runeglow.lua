-- Runeglow :: Procs
-- Enchant and trinket procs while they are on you, each with the time it has
-- left: Forever's weapon enchants (Revelation, Insight, Recovery), its Heart
-- of the Mountain trinkets, and Crusader's Holy Strength. Each known proc gets
-- its own movable icon with the countdown inside; unticked procs and any buff
-- names you add share a row of smaller icons instead.
--
-- ## Matching by name
--
-- The spell IDs Forever's enchants are known by (Insight 1248757, Revelation
-- 1248805, Recovery 1248760) are the enchanting casts, not the buffs they
-- proc, so the buffs are looked up by name with GetAuraDataBySpellName, which
-- covers every rank. The names are the English ones; `/runeglow scan` lists
-- the buffs on you by name to find the exact name of a proc.
--
-- ## Secret auras
--
-- Aura data can be secret in combat, which is when procs land. Every read asks
-- C_Secrets first and runs inside RG.GuardedRead, and every comparison on what
-- it returns happens inside the reader, so a secret that slips through fails
-- the read instead of the display. A refused read is UNKNOWN, not absent: a
-- proc already showing keeps its last known timer until it runs out, and
-- everything is read again when combat ends.

local _, RG = ...

-- `icon` is only a fallback, for the preview and for a buff whose own icon
-- cannot be read.
RG.KNOWN = {
	{
		key = "revelation",
		name = "Revelation",
		label = "Revelation (weapon)",
		tooltip = "When a non-periodic spell fails to crit: your next non-periodic spell has 100% more crit chance. Used up by that spell.",
		icon = "Interface\\Icons\\Spell_Holy_SurgeOfLight",
	},
	{
		key = "insight",
		name = "Insight",
		label = "Insight (weapon)",
		tooltip = "A chance on spell cast to raise your Spirit by 100% for 10 seconds.",
		icon = "Interface\\Icons\\Spell_Holy_MindVision",
	},
	{
		key = "recovery",
		name = "Recovery",
		label = "Recovery (weapon)",
		tooltip = "Heals you for 5% of your health when an attack of yours is dodged or parried. If it leaves no buff on you, it never shows: use /runeglow scan right after it heals you to check.",
		icon = "Interface\\Icons\\Spell_Holy_Renew",
	},
	{
		key = "holyStrength",
		name = "Holy Strength",
		label = "Holy Strength (Crusader)",
		tooltip = "Crusader's proc: +100 Strength for 15 seconds.",
		icon = "Interface\\Icons\\Spell_Holy_BlessingOfStrength",
	},
	-- The buff names are assumed to match the item names.
	{
		key = "moltenHeart",
		name = "Molten Heart of the Mountain",
		label = "Molten Heart of the Mountain (trinket)",
		tooltip = "+55 attack power for 15 seconds, doubled in volcanic areas.",
		icon = "Interface\\Icons\\INV_Elemental_Primal_Fire",
	},
	{
		key = "frozenHeart",
		name = "Frozen Heart of the Mountain",
		label = "Frozen Heart of the Mountain (trinket)",
		tooltip = "Up to +29 Frost and Shadow spell damage for 15 seconds, doubled in snowy areas.",
		icon = "Interface\\Icons\\INV_Elemental_Primal_Water",
	},
	{
		key = "dormantHeart",
		name = "Dormant Heart of the Mountain",
		label = "Dormant Heart of the Mountain (trinket)",
		tooltip = "Up to +40 healing and +13 damage for 15 seconds, from casting Greater Heal, Healing Touch, Healing Wave or Holy Light in combat.",
		icon = "Interface\\Icons\\INV_Elemental_Primal_Earth",
	},
}
local KNOWN = RG.KNOWN

local DEFAULTS = {
	enabled = true,
	locked = false,
	scale = 1,
	-- Each proc's own icon.
	alertSize = 48,
	-- The row's icons, and the timer under them.
	iconSize = 32,
	fontSize = 13,
	-- Keyed by KNOWN[i].key; filled in below.
	tracked = {},
	-- Extra buff names, shown in the row.
	extra = {},
	point = { point = "CENTER", relPoint = "CENTER", x = 0, y = -160 },
	-- Per KNOWN key: whether it gets its own icon, and where.
	alerts = {},
}

-- Side by side above the row, so none starts on top of another.
local ALERT_SPACING = 76
for index, known in ipairs(KNOWN) do
	DEFAULTS.tracked[known.key] = true
	DEFAULTS.alerts[known.key] = {
		separate = true,
		point = { point = "CENTER", relPoint = "CENTER", x = (index - (#KNOWN + 1) / 2) * ALERT_SPACING, y = -90 },
	}
end
RG.DEFAULTS = DEFAULTS

local GAP = 4
local BORDER = 1
local ALERT_INSET = 3
-- How often the timers redraw, and an expired proc is re-read.
local TICK = 0.1
local EXTRA_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local PREVIEW_TIMES = { 8, 4.5, 0, 12 }

local row
local alerts = {}
local testMode = false

-- One per tracked buff, in display order:
--   { name, key (nil for extra names), fallbackIcon,
--     state = "active" | "absent" | "unknown", icon, expiration, applications, readable }
local entries = {}

--------------------------------------------------------------------------------
-- Configuration
--------------------------------------------------------------------------------

local function Trim(text)
	return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Whether name is one of KNOWN (any case).
local function KnownByName(name)
	for _, known in ipairs(KNOWN) do
		if known.name:lower() == name:lower() then
			return known
		end
	end
end

-- Adds an extra buff name. Returns true (and known key if built-in), or false and a reason.
function RG.AddExtra(name)
	name = Trim(name or "")
	if name == "" then
		return false, "no name given"
	end
	local known = KnownByName(name)
	if known then
		RG.db.tracked[known.key] = true
		return true, known.key
	end
	for _, existing in ipairs(RG.db.extra) do
		if existing:lower() == name:lower() then
			return false, "already tracked"
		end
	end
	table.insert(RG.db.extra, name)
	return true
end

function RG.RemoveExtra(name)
	name = Trim(name or "")
	local known = KnownByName(name)
	if known then
		RG.db.tracked[known.key] = false
		return true, known.key
	end
	for index, existing in ipairs(RG.db.extra) do
		if existing:lower() == name:lower() then
			table.remove(RG.db.extra, index)
			return true
		end
	end
	return false, "not tracked"
end

-- Rebuilt on every Apply, carrying over what each name was last read as.
local function BuildEntries()
	local cfg = RG.db
	local previous = {}
	for _, entry in ipairs(entries) do
		previous[entry.name] = entry
	end

	entries = {}
	local function add(name, icon, key)
		local entry = previous[name] or { name = name, state = "unknown" }
		entry.fallbackIcon, entry.key = icon, key
		entries[#entries + 1] = entry
	end
	for _, known in ipairs(KNOWN) do
		if cfg.tracked[known.key] then
			add(known.name, known.icon, known.key)
		end
	end
	for _, name in ipairs(cfg.extra) do
		add(name, EXTRA_ICON)
	end
end

-- Whether this entry shows in its own icon rather than in the row.
local function InAlert(entry)
	return entry.key ~= nil and RG.db.alerts[entry.key].separate
end

--------------------------------------------------------------------------------
-- Reading
--------------------------------------------------------------------------------

local function IsAvailable()
	return C_UnitAuras ~= nil and C_UnitAuras.GetAuraDataBySpellName ~= nil
end

-- Runs inside RG.GuardedRead. Returns present, icon, expiration, applications,
-- all plain values: each test that could meet a secret happens here.
local function ReadBuff(name)
	local data = C_UnitAuras.GetAuraDataBySpellName("player", name, "HELPFUL")
	if not data then
		return false
	end
	local expiration = data.expirationTime
	if not (expiration and expiration > 0) then
		expiration = nil
	end
	local applications = data.applications
	if not (applications and applications > 1) then
		applications = nil
	end
	local icon = data.icon
	if icon ~= nil and RG.IsSecret(icon) then
		icon = nil
	end
	return true, icon, expiration, applications
end

local function ReadEntry(entry, now)
	local ok, present, icon, expiration, applications = RG.GuardedRead("Reading " .. entry.name,
		RG.AuraSecret(entry.name), ReadBuff, entry.name)
	entry.readable = ok == true
	if not ok then
		-- Unknown: a proc on display runs out on its last known timer.
		if entry.state == "active" and entry.expiration and entry.expiration <= now then
			entry.state = "absent"
		elseif entry.state ~= "active" then
			entry.state = "unknown"
		end
		return
	end
	if present then
		entry.state, entry.icon, entry.expiration, entry.applications = "active", icon, expiration, applications
	else
		entry.state, entry.icon, entry.expiration, entry.applications = "absent", nil, nil, nil
	end
end

--------------------------------------------------------------------------------
-- Shared drawing
--------------------------------------------------------------------------------

local function FormatRemaining(seconds)
	if seconds >= 60 then
		return ("%dm"):format(math.ceil(seconds / 60))
	elseif seconds >= 10 then
		return ("%d"):format(math.floor(seconds))
	end
	return ("%.1f"):format(seconds)
end

local function SetTimer(frame, expiration, now)
	if expiration and expiration > now then
		frame.timer:SetText(FormatRemaining(expiration - now))
	else
		frame.timer:SetText("")
	end
end

--------------------------------------------------------------------------------
-- The row: small icons with the timer on the icon
--------------------------------------------------------------------------------

local function CreateRowIcon()
	local icon = CreateFrame("Frame", nil, row)

	icon.border = icon:CreateTexture(nil, "BACKGROUND")
	icon.border:SetAllPoints(icon)

	icon.texture = icon:CreateTexture(nil, "ARTWORK")
	icon.texture:SetPoint("TOPLEFT", icon, "TOPLEFT", BORDER, -BORDER)
	icon.texture:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -BORDER, BORDER)
	icon.texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)

	icon.count = icon:CreateFontString(nil, "OVERLAY")
	icon.count:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -2, 2)
	icon.count:SetTextColor(1, 1, 1)

	icon.timer = icon:CreateFontString(nil, "OVERLAY")
	icon.timer:SetPoint("CENTER", icon, "CENTER", 0, 0)
	icon.timer:SetTextColor(1, 1, 1)
	return icon
end

-- Icon frames are reused; WoW cannot free frames.
local function GetRowIcon(index)
	local icon = row.icons[index]
	if not icon then
		icon = CreateRowIcon()
		row.icons[index] = icon
	end
	return icon
end

local function LayoutRow(shown)
	local cfg = RG.db
	local now = GetTime()
	local r, g, b = RG.COLOR[1], RG.COLOR[2], RG.COLOR[3]
	local countFontSize = math.max(8, cfg.fontSize - 3)
	for index, entry in ipairs(shown) do
		local icon = GetRowIcon(index)
		icon:SetSize(cfg.iconSize, cfg.iconSize)
		icon.border:SetColorTexture(r, g, b, 0.9)
		icon.count:SetFont(RG.FONT, countFontSize, "OUTLINE")
		icon.timer:SetFont(RG.FONT, cfg.fontSize, "OUTLINE")
		icon:ClearAllPoints()
		icon:SetPoint("TOPLEFT", row, "TOPLEFT", (index - 1) * (cfg.iconSize + GAP), 0)
		icon.texture:SetTexture(entry.icon or entry.fallbackIcon)
		icon.count:SetText(entry.applications and tostring(entry.applications) or "")
		icon.entry = entry
		SetTimer(icon, entry.expiration, now)
		icon:Show()
	end
	for index = #shown + 1, #row.icons do
		row.icons[index].entry = nil
		row.icons[index]:Hide()
	end

	-- At least one slot wide, so there is always something to drag in preview.
	local slots = math.max(#shown, 1)
	row:SetSize(slots * cfg.iconSize + (slots - 1) * GAP, cfg.iconSize)
	-- Only catch mouse clicks when unlocked AND actually visible (preview or active icons).
	row:EnableMouse(not cfg.locked and (testMode or #shown > 0))
end

--------------------------------------------------------------------------------
-- Own icons: a dark frame with a 1px border and the name in capitals above,
-- pulsing while shown, with the countdown in the middle of the icon.
--------------------------------------------------------------------------------

local EDGES = {
	{ "TOPLEFT", "TOPRIGHT", false },
	{ "BOTTOMLEFT", "BOTTOMRIGHT", false },
	{ "TOPLEFT", "BOTTOMLEFT", true },
	{ "TOPRIGHT", "BOTTOMRIGHT", true },
}

local function CreatePulse(frame, lowAlpha, duration)
	local pulse = frame:CreateAnimationGroup()
	pulse:SetLooping("REPEAT")
	local fadeOut = pulse:CreateAnimation("Alpha")
	fadeOut:SetFromAlpha(1)
	fadeOut:SetToAlpha(lowAlpha)
	fadeOut:SetDuration(duration)
	fadeOut:SetOrder(1)
	local fadeIn = pulse:CreateAnimation("Alpha")
	fadeIn:SetFromAlpha(lowAlpha)
	fadeIn:SetToAlpha(1)
	fadeIn:SetDuration(duration)
	fadeIn:SetOrder(2)
	return pulse
end

-- Named Runeglow_<Key> ("Runeglow_Revelation").
local function BuildAlert(key)
	local frame = CreateFrame("Frame", "Runeglow_" .. key:gsub("^%l", string.upper), UIParent)
	frame:SetFrameStrata("HIGH")
	frame:Hide()
	RG.MakeMovable(frame, function()
		return RG.db.alerts[key]
	end)

	local background = frame:CreateTexture(nil, "BACKGROUND")
	background:SetAllPoints(frame)
	background:SetColorTexture(0, 0, 0, 0.55)

	for _, edge in ipairs(EDGES) do
		local line = frame:CreateTexture(nil, "BORDER")
		line:SetColorTexture(RG.COLOR[1], RG.COLOR[2], RG.COLOR[3], 0.9)
		line:SetPoint(edge[1], frame, edge[1], 0, 0)
		line:SetPoint(edge[2], frame, edge[2], 0, 0)
		if edge[3] then
			line:SetWidth(1)
		else
			line:SetHeight(1)
		end
	end

	frame.icon = frame:CreateTexture(nil, "ARTWORK")
	frame.icon:SetPoint("TOPLEFT", frame, "TOPLEFT", ALERT_INSET, -ALERT_INSET)
	frame.icon:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -ALERT_INSET, ALERT_INSET)
	frame.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

	frame.timer = frame:CreateFontString(nil, "OVERLAY")
	frame.timer:SetPoint("CENTER", frame, "CENTER", 0, 0)
	frame.timer:SetTextColor(1, 1, 1)

	frame.count = frame:CreateFontString(nil, "OVERLAY")
	frame.count:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -3, 3)
	frame.count:SetTextColor(1, 1, 1)

	frame.title = frame:CreateFontString(nil, "OVERLAY")
	frame.title:SetPoint("BOTTOM", frame, "TOP", 0, 4)
	frame.title:SetTextColor(RG.COLOR[1], RG.COLOR[2], RG.COLOR[3])

	frame.pulse = CreatePulse(frame, 0.6, 0.5)
	return frame
end

local function ApplyAlert(alert, key)
	local cfg = RG.db
	alert:SetSize(cfg.alertSize, cfg.alertSize)
	alert:SetScale(cfg.scale)
	RG.RestorePoint(alert, cfg.alerts[key].point)
	alert:EnableMouse(not cfg.locked)
	alert.title:SetFont(RG.FONT, 12, "OUTLINE")
	-- The countdown fills most of the icon, as on a cooldown.
	alert.timer:SetFont(RG.FONT, math.max(10, math.floor(cfg.alertSize * 0.4)), "OUTLINE")
	alert.count:SetFont(RG.FONT, math.max(10, math.floor(cfg.alertSize * 0.25)), "OUTLINE")
end

-- entry is nil to hide the alert.
local function ShowAlert(alert, entry)
	if not entry then
		alert.entry = nil
		alert.pulse:Stop()
		alert:Hide()
		return
	end
	alert.entry = entry
	alert.icon:SetTexture(entry.icon or entry.fallbackIcon)
	alert.title:SetText(entry.name:upper())
	alert.count:SetText(entry.applications and tostring(entry.applications) or "")
	SetTimer(alert, entry.expiration, GetTime())
	if not alert:IsShown() then
		alert:Show()
		alert.pulse:Play()
	end
end

local function ShowAlerts(byKey)
	for key, alert in pairs(alerts) do
		ShowAlert(alert, byKey[key])
	end
end

--------------------------------------------------------------------------------
-- Update
--------------------------------------------------------------------------------

-- The row's entries and the alerts' entries by key, with made-up timers.
local function PreviewEntries()
	local shown, byKey, now = {}, {}, GetTime()
	for index, entry in ipairs(entries) do
		local seconds = PREVIEW_TIMES[(index - 1) % #PREVIEW_TIMES + 1]
		local duration = seconds > 0 and seconds or 8
		local preview = {
			name = entry.name,
			fallbackIcon = entry.fallbackIcon,
			expiration = now + duration,
			previewDuration = duration,
		}
		if InAlert(entry) then
			byKey[entry.key] = preview
		else
			if seconds <= 0 then
				preview.expiration = nil
				preview.previewDuration = nil
			end
			shown[#shown + 1] = preview
		end
	end
	return shown, byKey
end

local function Redraw()
	if not row or not RG.db then
		return
	end
	if not RG.db.enabled or not IsAvailable() then
		row:Hide()
		ShowAlerts({})
		return
	end
	row:Show()

	if testMode then
		row.backdrop:Show()
		local shown, byKey = PreviewEntries()
		LayoutRow(shown)
		ShowAlerts(byKey)
		return
	end
	row.backdrop:Hide()

	local shown, byKey = {}, {}
	for _, entry in ipairs(entries) do
		if entry.state == "active" then
			if InAlert(entry) then
				byKey[entry.key] = entry
			else
				shown[#shown + 1] = entry
			end
		end
	end
	LayoutRow(shown)
	ShowAlerts(byKey)
end

function RG.Update()
	if not row or not RG.db then
		return
	end
	if RG.db.enabled then
		local now = GetTime()
		for _, entry in ipairs(entries) do
			ReadEntry(entry, now)
		end
	end
	Redraw()
end

-- Re-applies every setting; called after any change.
function RG.Apply()
	if not row then
		return
	end
	local cfg = RG.db
	row:SetScale(cfg.scale)
	RG.RestorePoint(row, cfg.point)
	for key, alert in pairs(alerts) do
		ApplyAlert(alert, key)
	end
	BuildEntries()
	RG.Update()
end

-- Redraws the timers, and re-reads once one runs out so an expired proc goes.
local sinceTick = 0
local function OnUpdate(_, elapsed)
	sinceTick = sinceTick + elapsed
	if sinceTick < TICK then
		return
	end
	sinceTick = 0

	local now, expired = GetTime(), false
	local function tick(frame)
		local entry = frame.entry
		if entry and frame:IsShown() then
			if testMode and entry.previewDuration and entry.expiration and entry.expiration <= now then
				entry.expiration = now + entry.previewDuration
			end
			SetTimer(frame, entry.expiration, now)
			if not testMode and entry.expiration and entry.expiration <= now then
				expired = true
			end
		end
	end
	for _, icon in ipairs(row.icons) do
		tick(icon)
	end
	for _, alert in pairs(alerts) do
		tick(alert)
	end
	if expired then
		RG.Update()
	end
end

--------------------------------------------------------------------------------
-- Construction
--------------------------------------------------------------------------------

local function BuildRow()
	local frame = CreateFrame("Frame", "Runeglow_Row", UIParent)
	frame:SetFrameStrata("MEDIUM")
	RG.MakeMovable(frame, function()
		return RG.db
	end)

	-- Only in preview, so there is something to grab while positioning.
	frame.backdrop = frame:CreateTexture(nil, "BACKGROUND")
	frame.backdrop:SetAllPoints(frame)
	frame.backdrop:SetColorTexture(0, 0, 0, 0.45)
	frame.backdrop:Hide()

	frame.icons = {}
	frame:SetScript("OnUpdate", OnUpdate)
	return frame
end

RG.OnLogin(function()
	row = BuildRow()
	for _, known in ipairs(KNOWN) do
		alerts[known.key] = BuildAlert(known.key)
	end
	RG.RegisterEvent("UNIT_AURA", RG.Update, "player")
	RG.RegisterEvent("PLAYER_ENTERING_WORLD", RG.Update)
	-- Reads refused in combat get their answer once it ends.
	RG.RegisterEvent("PLAYER_REGEN_ENABLED", RG.Update)
	RG.Apply()
end)

--------------------------------------------------------------------------------
-- Preview, positions, scan, status
--------------------------------------------------------------------------------

function RG.SetPreview(enabled)
	testMode = enabled
	Redraw()
end

function RG.IsPreview()
	return testMode
end

function RG.ResetPositions()
	local point = RG.db.point
	for field, value in pairs(DEFAULTS.point) do
		point[field] = value
	end
	for key, defaultAlert in pairs(DEFAULTS.alerts) do
		local alert = RG.db.alerts[key]
		if type(alert) ~= "table" then
			alert = { separate = defaultAlert.separate, point = {} }
			RG.db.alerts[key] = alert
		end
		if type(alert.point) ~= "table" then
			alert.point = {}
		end
		for field, value in pairs(defaultAlert.point) do
			alert.point[field] = value
		end
	end
	RG.Apply()
end

function RG.GetEntries()
	return entries
end

-- Extracts plain fields from one aura; fails safely if any field is secret.
local function ReadBuffFields(data)
	local duration = data.duration
	return {
		name = data.name .. "",
		spellId = data.spellId and (data.spellId + 0),
		duration = (duration and duration > 0) and duration or nil,
	}
end

-- Runs inside RG.GuardedRead: individual buffs may be secret without aborting the scan.
local function ReadAllBuffs()
	local list, hidden = {}, 0
	for index = 1, 40 do
		local data = C_UnitAuras.GetAuraDataByIndex("player", index, "HELPFUL")
		if not data then
			break
		end
		local ok, item = pcall(ReadBuffFields, data)
		if ok then
			list[#list + 1] = item
		else
			hidden = hidden + 1
		end
	end
	return list, hidden
end

-- Every buff on you by name (plus count of hidden secret buffs), or nil when auras are secret right now.
function RG.Scan()
	if not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then
		return nil
	end
	local ok, list, hidden = RG.GuardedRead("Scan", RG.AuraSecret(), ReadAllBuffs)
	if not ok then
		return nil
	end
	return list, hidden or 0
end

function RG.StatusLine()
	if not IsAvailable() then
		return "C_UnitAuras.GetAuraDataBySpellName is missing on this client."
	end
	local parts = {}
	for _, entry in ipairs(entries) do
		parts[#parts + 1] = ("%s %s%s"):format(entry.name, entry.state, entry.readable and "" or " (unreadable)")
	end
	return #parts > 0 and table.concat(parts, ", ") or "nothing tracked"
end
