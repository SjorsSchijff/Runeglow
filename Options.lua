-- Runeglow :: Options
-- A page in the game's Options > AddOns panel, and /runeglow.

local _, RG = ...

local category
local layout

--------------------------------------------------------------------------------
-- Options panel
--------------------------------------------------------------------------------

local function NotifySetting(variable)
	if category and Settings and Settings.NotifyUpdate then
		Settings.NotifyUpdate("RUNEGLOW_" .. variable)
	end
end

-- A proxy setting reads and writes RG.db through get/set and re-applies.
local function Proxy(variable, varType, name, default, get, set)
	return Settings.RegisterProxySetting(category, "RUNEGLOW_" .. variable, varType, name, default, get,
		function(value)
			set(value)
			RG.Apply()
		end)
end

local function Checkbox(variable, name, tooltip, default, get, set)
	local setting = Proxy(variable, Settings.VarType.Boolean, name, default, get, set)
	Settings.CreateCheckbox(category, setting, tooltip)
end

local function Slider(variable, name, tooltip, default, minimum, maximum, step, format, get, set)
	local setting = Proxy(variable, Settings.VarType.Number, name, default, get, set)
	local options = Settings.CreateSliderOptions(minimum, maximum, step)
	options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(value)
		return format:format(value)
	end)
	Settings.CreateSlider(category, setting, options, tooltip)
end

local function Header(text, tooltip)
	layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(text, tooltip))
end

local function Button(name, buttonText, tooltip, onClick)
	if CreateSettingsButtonInitializer then
		layout:AddInitializer(CreateSettingsButtonInitializer(name, buttonText, onClick, tooltip, true))
	end
end

local function BuildPanel()
	if not (Settings and Settings.RegisterVerticalLayoutCategory and Settings.RegisterProxySetting) then
		return
	end
	local defaults = RG.DEFAULTS
	category, layout = Settings.RegisterVerticalLayoutCategory("Runeglow")

	Checkbox("ENABLED", "Enable Runeglow", "Show your enchant and trinket procs.", defaults.enabled,
		function() return RG.db.enabled end,
		function(v) RG.db.enabled = v end)

	Checkbox("LOCKED", "Lock positions", "Stop the icons and the row from being dragged.", defaults.locked,
		function() return RG.db.locked end,
		function(v) RG.db.locked = v end)

	Checkbox("PREVIEW", "Preview icons", "Show every icon with a looping countdown so you can drag and scale them.", false,
		function() return RG.IsPreview() end,
		function(v) RG.SetPreview(v) end)

	Button("Reset positions", "Reset", "Put every icon and the row back at their default positions.", function()
		RG.ResetPositions()
		RG.Print("Icon positions reset.")
	end)

	Header("Procs", "Buffs are matched by their English name. Add any other buff with /runeglow add <name>.")
	for _, known in ipairs(RG.KNOWN) do
		Checkbox("TRACK_" .. known.key, known.label, known.tooltip, not known.off,
			function() return RG.db.tracked[known.key] end,
			function(v) RG.db.tracked[known.key] = v end)
	end

	Header("Own icons", "A ticked proc gets its own icon with the countdown inside, that you can drag anywhere. An unticked one goes in the row.")
	for _, known in ipairs(RG.KNOWN) do
		Checkbox("OWN_" .. known.key, "Own icon: " .. known.name, nil, true,
			function() return RG.db.alerts[known.key].separate end,
			function(v) RG.db.alerts[known.key].separate = v end)
	end
	Checkbox("SHOW_NAMES", "Show proc names", "Show the proc's name above its own icon.", defaults.showNames,
		function() return RG.db.showNames end,
		function(v) RG.db.showNames = v end)
	Slider("ALERT_SIZE", "Own icon size", nil, defaults.alertSize, 32, 96, 4, "%d",
		function() return RG.db.alertSize end,
		function(v) RG.db.alertSize = v end)

	Header("Row", "Unticked procs and the names you add with /runeglow add.")
	Slider("ICON_SIZE", "Row icon size", nil, defaults.iconSize, 20, 64, 2, "%d",
		function() return RG.db.iconSize end,
		function(v) RG.db.iconSize = v end)
	Slider("FONT_SIZE", "Row timer size", nil, defaults.fontSize, 8, 24, 1, "%d",
		function() return RG.db.fontSize end,
		function(v) RG.db.fontSize = v end)

	Header("Everything")
	Slider("SCALE", "Scale", "Scales the row and every own icon.", defaults.scale, 0.5, 2, 0.1, "%.1f",
		function() return RG.db.scale end,
		function(v) RG.db.scale = v end)

	Settings.RegisterAddOnCategory(category)
end

RG.OnLogin(function()
	local ok, err = pcall(BuildPanel)
	if not ok then
		category, layout = nil, nil
		RG.ReportError("Options panel", err)
	end
end)

function RG.OpenOptions()
	if not category then
		RG.Print("The options panel is not available on this client. |cffffffff/runeglow help|r lists the commands.")
		return
	end
	if InCombatLockdown and InCombatLockdown() then
		RG.Print("Cannot open options during combat. Try again when combat ends.")
		return
	end
	Settings.OpenToCategory(category:GetID())
end

--------------------------------------------------------------------------------
-- Slash commands
--------------------------------------------------------------------------------

local COMMANDS = {
	{ "", "open the options" },
	{ "preview", "show every icon with a made-up timer, for dragging into place" },
	{ "lock", "stop the icons from being dragged" },
	{ "unlock", "let the icons be dragged" },
	{ "scale <0.5-2.0>", "set the scale of every icon and the row" },
	{ "reset", "put every icon back at its default position" },
	{ "add <buff name>", "track another buff, in the row" },
	{ "remove <buff name>", "stop tracking a buff" },
	{ "list", "the buffs being tracked" },
	{ "scan", "list the buffs on you by name, to find a proc's exact name" },
	{ "status", "what each tracked buff was last read as" },
}

local function PrintHelp()
	RG.Print(("version %s, commands:"):format(RG.VERSION))
	for _, command in ipairs(COMMANDS) do
		local cmd = command[1] == "" and "/runeglow" or "/runeglow " .. command[1]
		RG.Print(("|cffffffff%s|r - %s"):format(cmd, command[2]))
	end
end

local function PrintScan()
	local list, hidden = RG.Scan()
	if not list then
		RG.Print("Your buffs cannot be read right now (hidden in combat?). Try again out of combat.")
	elseif #list == 0 and hidden == 0 then
		RG.Print("You have no buffs.")
	else
		local note = hidden > 0 and (" (%d hidden)"):format(hidden) or ""
		RG.Print(("%d buff(s) on you%s. Track one with |cffffffff/runeglow add <name>|r:"):format(#list, note))
		for _, buff in ipairs(list) do
			RG.Print(("|cffffffff%s|r (spell %s%s)"):format(buff.name, tostring(buff.spellId),
				buff.duration and (", " .. math.floor(buff.duration + 0.5) .. "s") or ""))
		end
	end
end

local function PrintList()
	local names = {}
	for _, known in ipairs(RG.KNOWN) do
		if RG.db.tracked[known.key] then
			names[#names + 1] = known.name .. (RG.db.alerts[known.key].separate and "" or " (row)")
		end
	end
	for _, name in ipairs(RG.db.extra) do
		names[#names + 1] = name .. " (row)"
	end
	RG.Print("Tracking: " .. (#names > 0 and table.concat(names, ", ") or "nothing"))
end

function RG.HandleSlash(input)
	local command, rest = (input or ""):match("^%s*(%S*)%s*(.-)%s*$")
	command = command:lower()

	if command == "" or command == "options" or command == "config" then
		RG.OpenOptions()
	elseif command == "help" then
		PrintHelp()
	elseif command == "preview" or command == "test" then
		RG.SetPreview(not RG.IsPreview())
		NotifySetting("PREVIEW")
		RG.Print("Preview " .. (RG.IsPreview() and "on: drag the icons into place." or "off."))
	elseif command == "lock" or command == "unlock" then
		RG.db.locked = command == "lock"
		RG.Apply()
		NotifySetting("LOCKED")
		RG.Print(RG.db.locked and "Icons locked." or "Icons unlocked: drag them into place.")
	elseif command == "scale" then
		if rest == "" then
			RG.Print(("Current scale: |cffffffff%.1f|r (range 0.5 to 2.0)."):format(RG.db.scale))
			return
		end
		local value = tonumber(rest)
		if not value or value < 0.5 or value > 2 then
			RG.Print("Scale must be a number between |cffffffff0.5|r and |cffffffff2.0|r.")
			return
		end
		RG.db.scale = math.floor(value * 10 + 0.5) / 10
		RG.Apply()
		NotifySetting("SCALE")
		RG.Print(("Scale set to |cffffffff%.1f|r."):format(RG.db.scale))
	elseif command == "reset" then
		RG.ResetPositions()
		RG.Print("Icon positions reset.")
	elseif command == "add" or command == "remove" then
		local ok, detail = (command == "add" and RG.AddExtra or RG.RemoveExtra)(rest)
		if ok then
			RG.Apply()
			if detail then
				NotifySetting("TRACK_" .. detail)
			end
			RG.Print(("%s |cffffffff%s|r."):format(command == "add" and "Tracking" or "No longer tracking", rest))
		else
			RG.Print(("Could not %s |cffffffff%s|r: %s."):format(command, rest, detail))
		end
	elseif command == "list" then
		PrintList()
	elseif command == "scan" then
		PrintScan()
	elseif command == "status" then
		RG.Print(RG.StatusLine())
		for context, entry in pairs(RG.errors) do
			RG.Print(("|cffff5555%s|r x%d: %s"):format(context, entry.count, entry.message:match("^[^\n]*")))
		end
	else
		RG.Print(("Unknown command '%s'. |cffffffff/runeglow help|r lists them."):format(command))
	end
end

SLASH_RUNEGLOW1 = "/runeglow"
SLASH_RUNEGLOW2 = "/rglow"
SlashCmdList.RUNEGLOW = function(input)
	local ok, err = pcall(RG.HandleSlash, input)
	if not ok then
		RG.ReportError("Command", err)
	end
end
