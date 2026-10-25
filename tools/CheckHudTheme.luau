--!strict
-- Run in Studio's Command Bar (Client or Server). Exercise the real resolver and require the HUD controllers.
local shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local config = require(shared:WaitForChild("GameConfig"))
local theme = require(shared:WaitForChild("Util"):WaitForChild("HudTheme"))
local gala = theme.get("Gala")
assert(gala.AccentColor == config.UI.HudThemes.Gala.AccentColor, "Gala skin did not resolve")
assert(gala.PanelColor == config.UI.HudThemes.Gala.PanelColor, "Gala panel override lost")
assert(gala.VitalsWidthPixels == config.UI.GraphicHud.VitalsWidthPixels, "Skin changed base layout")
assert(table.isfrozen(gala), "Resolved theme must be immutable")
assert(theme.get("Gala") == gala, "Theme was not cached")
assert(theme.get("UnregisteredTestMap").PanelColor == config.UI.GraphicHud.PanelColor, "Neutral fallback failed")
local hud = require(shared.Util.HudKit)
assert(type(hud.panel) == "function", "HudKit dependency failed")
local player = game:GetService("Players").LocalPlayer
if player then
	local controllers = player:WaitForChild("PlayerScripts"):WaitForChild("Client"):WaitForChild("Controllers")
	for _, name in
		{
			"CombatHudController",
			"CoverController",
			"DisguiseController",
			"DownedHudController",
			"TakedownHintController",
		}
	do
		local controller = require(controllers:WaitForChild(name))
		assert(type(controller.Init) == "function" and type(controller.Start) == "function", `Failed controller {name}`)
	end
end
print("HUD theme and require checks passed")
