-- Runeglow :: Core
-- Saved settings, events, chat output, dragging, and reads that stay safe
-- around the client's secret values.
--
-- Client note: written for World of Warcraft: Forever (Interface 16001), which
-- ships the Retail 12 API: C_UnitAuras and C_Spell, no UnitBuff or
-- GetSpellInfo, and aura data that can be secret in combat.

local ADDON, RG = ...
_G.Runeglow = RG

RG.ADDON = ADDON
RG.VERSION = C_AddOns.GetAddOnMetadata(ADDON, "Version") or "?"

-- Runeglow's colour: the border and the name on every icon.
RG.COLOR = { 0.62, 0.45, 1 }
RG.FONT = GameFontNormal:GetFont()

--------------------------------------------------------------------------------
-- Chat
--------------------------------------------------------------------------------

function RG.Print(...)
	local parts = { "|cff9e73ffRuneglow:|r" }
	for i = 1, select("#", ...) do
		parts[#parts + 1] = tostring((select(i, ...)))
	end
	DEFAULT_CHAT_FRAME:AddMessage(table.concat(parts, " "))
end

--------------------------------------------------------------------------------
-- Secret values
--------------------------------------------------------------------------------

-- A secret refuses comparison; a plain value compares false with a new table.
local function Compare(value)
	return value == {}
end

-- True when value is secret. Errs on the side of "secret".
function RG.IsSecret(value)
	if type(issecretvalue) == "function" then
		local ok, result = pcall(issecretvalue, value)
		if ok then
			return result and true or false
		end
	end
	return not pcall(Compare, value) or not pcall(tostring, value)
end

-- Unexpected failures, by context, each printed once per session.
RG.errors = {}

function RG.ReportError(context, err)
	local message = RG.IsSecret(err) and "<secret error message>" or tostring(err)
	local entry = RG.errors[context]
	if entry then
		entry.count = entry.count + 1
		return
	end
	RG.errors[context] = { message = message, count = 1 }
	RG.Print(("|cffff5555%s failed:|r %s"):format(context, message:match("^[^\n]*")))
end

-- Asks a C_Secrets predicate: true, false, or nil when the client has no answer.
local function AskPredicate(name, quiet, ...)
	if not C_Secrets then
		return false
	end
	local predicate = C_Secrets[name]
	if not predicate then
		return nil
	end
	local ok, secret = pcall(predicate, ...)
	if not ok then
		if not quiet then
			RG.ReportError("C_Secrets." .. name, secret)
		end
		return nil
	end
	return secret and true or false
end

-- Whether reading the player's aura for this spell name would give secrets.
function RG.AuraSecret(spell)
	if AskPredicate("HasSecretRestrictions", false) == false then
		return false
	end
	local secret
	if spell then
		-- Buff names not in the player's spellbook may not resolve as a
		-- SpellIdentifier; stay quiet and fall back to the general predicate.
		secret = AskPredicate("ShouldSpellAuraBeSecret", true, spell)
	end
	if secret == nil then
		secret = AskPredicate("ShouldAurasBeSecret", false)
	end
	return secret
end

local function GuardedReadResult(context, secret, ok, ...)
	if ok then
		return true, ...
	end
	-- The client said readable, so this is a real failure; otherwise it is the
	-- refusal it announced, which stays quiet.
	if secret == false then
		RG.ReportError(context, (...))
	end
	return nil
end

-- Runs reader(...) under pcall unless the client already said it is secret.
-- Returns true and reader's results, or nil when the answer is UNKNOWN.
function RG.GuardedRead(context, secret, reader, ...)
	if secret == true then
		return nil
	end
	return GuardedReadResult(context, secret, pcall(reader, ...))
end

--------------------------------------------------------------------------------
-- Events
--------------------------------------------------------------------------------

local handlers = {}
local dispatcher = CreateFrame("Frame")

-- An event this client does not know is skipped rather than fatal.
function RG.RegisterEvent(event, handler, unit)
	if not handlers[event] then
		local ok = pcall(function()
			if unit then
				dispatcher:RegisterUnitEvent(event, unit)
			else
				dispatcher:RegisterEvent(event)
			end
		end)
		if not ok then
			return false
		end
		handlers[event] = {}
	end
	table.insert(handlers[event], handler)
	return true
end

dispatcher:SetScript("OnEvent", function(_, event, ...)
	for _, handler in ipairs(handlers[event] or {}) do
		local ok, err = pcall(handler, ...)
		if not ok then
			RG.ReportError("Event " .. event, err)
		end
	end
end)

--------------------------------------------------------------------------------
-- Saved settings
--------------------------------------------------------------------------------

-- Fills in missing keys of dst from src, recursing into tables.
local function CopyDefaults(src, dst)
	if type(dst) ~= "table" then
		dst = {}
	end
	for k, v in pairs(src) do
		if type(v) == "table" then
			dst[k] = CopyDefaults(v, rawget(dst, k))
		elseif dst[k] == nil then
			dst[k] = v
		end
	end
	return dst
end

-- Set by Runeglow.lua before PLAYER_LOGIN.
RG.DEFAULTS = nil

local onLogin = {}
function RG.OnLogin(fn)
	onLogin[#onLogin + 1] = fn
end

RG.RegisterEvent("PLAYER_LOGIN", function()
	RuneglowDB = CopyDefaults(RG.DEFAULTS, RuneglowDB)
	RG.db = RuneglowDB
	for _, fn in ipairs(onLogin) do
		local ok, err = pcall(fn)
		if not ok then
			RG.ReportError("Login", err)
		end
	end
end)

--------------------------------------------------------------------------------
-- Dragging
--------------------------------------------------------------------------------

-- Positions stored relative to CENTER are in UIParent pixels so changing scale
-- keeps every icon anchored at the exact same spot on screen.
function RG.RestorePoint(frame, store)
	frame:ClearAllPoints()
	local x, y = store.x, store.y
	if store.point == "CENTER" and store.relPoint == "CENTER" then
		local scale = frame:GetScale()
		if scale and scale > 0 then
			x, y = x / scale, y / scale
		end
	end
	frame:SetPoint(store.point, UIParent, store.relPoint, x, y)
end

local function SavePoint(frame, store)
	local fx, fy = frame:GetCenter()
	local ux, uy = UIParent:GetCenter()
	if fx and fy and ux and uy then
		local scale = frame:GetScale() or 1
		store.point, store.relPoint = "CENTER", "CENTER"
		store.x = math.floor(fx * scale - ux + 0.5)
		store.y = math.floor(fy * scale - uy + 0.5)
		RG.RestorePoint(frame, store)
		return
	end
	local point, _, relPoint, x, y = frame:GetPoint(1)
	if point then
		store.point, store.relPoint = point, relPoint
		store.x, store.y = math.floor(x + 0.5), math.floor(y + 0.5)
	end
end

-- getConfig returns a table with `point`; dragging follows RG.db.locked.
function RG.MakeMovable(frame, getConfig)
	frame:SetMovable(true)
	frame:SetClampedToScreen(true)
	frame:EnableMouse(false)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", function(self)
		if not RG.db.locked then
			self:StartMoving()
		end
	end)
	frame:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		SavePoint(self, getConfig().point)
	end)
end
