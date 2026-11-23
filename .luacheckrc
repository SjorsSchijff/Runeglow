-- The WoW API is too large to list, so reading globals is not checked (113);
-- writing one is, since a leaked global is shared with every other addon.
std = "lua51"
max_line_length = false
exclude_files = { "tests/**" }
ignore = {
	"113", -- accessing an undefined global: the WoW API
	"212", -- unused argument: event and hook signatures are fixed
}
globals = {
	"Runeglow",
	"RuneglowDB",
	"SlashCmdList",
	"SLASH_RUNEGLOW1",
	"SLASH_RUNEGLOW2",
}
