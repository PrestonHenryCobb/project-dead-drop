--!strict
-- Owner-only confirmed Asset slots; no draft data or predicted safe unlocks.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.GameConfig)
local AssetDefs = require(Shared.Defs.AssetDefs)
local Types = require(Shared.Types)
local Janitor = require(Shared.Util.Janitor)
local HudKit = require(Shared.Util.HudKit)
local HudTheme = require(Shared.Util.HudTheme)
local HudScale = require(Shared.Util.HudScale)
local Style = require(script.Parent.Parent.Combat.AssetStyle)
local RemoteController = require(script.Parent.RemoteController)
local AssetHudController = {}
function AssetHudController.Init() end
function AssetHudController.Start()
	local janitor = Janitor.new()
	local theme, config = HudTheme.get(), GameConfig.AssetHud
	local phase: Types.Phase = "Lobby"
	local state: Types.AssetStateInfo? = nil
	local gui = HudKit.screen("AssetHud")
	janitor:Add(gui)
	local strip = Instance.new("Frame")
	strip.Name = "AssetStrip"
	strip.AnchorPoint = Vector2.new(1, 0)
	strip.Position = UDim2.new(1, -theme.MarginPixels, 0, config.TopPixels)
	strip.Size = UDim2.fromOffset(
		config.SlotWidthPixels,
		#AssetDefs.rarities * (config.SlotHeightPixels + theme.PaddingPixels) - theme.PaddingPixels
	)
	strip.BackgroundTransparency = 1
	strip.Visible = false
	strip.Parent = gui
	HudScale.bind(strip)
	local slots = {}
	for index, rarity in AssetDefs.rarities do
		local panel = HudKit.panel(
			strip,
			rarity,
			UDim2.fromOffset(0, (index - 1) * (config.SlotHeightPixels + theme.PaddingPixels)),
			Vector2.zero,
			UDim2.fromOffset(config.SlotWidthPixels, config.SlotHeightPixels)
		)
		local title = HudKit.text(
			panel,
			"AssetRarity",
			UDim2.fromOffset(theme.PaddingPixels, theme.PaddingPixels / 2),
			Vector2.zero,
			UDim2.new(1, -theme.PaddingPixels * 2, 0, theme.CaptionSize)
		)
		title.TextSize = theme.CaptionSize
		local name = HudKit.text(
			panel,
			"AssetName",
			UDim2.fromOffset(theme.PaddingPixels, theme.PaddingPixels + theme.CaptionSize),
			Vector2.zero,
			UDim2.new(1, -theme.PaddingPixels * 2, 0, theme.CaptionSize)
		)
		name.TextSize = theme.CaptionSize
		name.TextXAlignment = Enum.TextXAlignment.Left
		slots[rarity] = { title = title, name = name }
	end
	local function refresh()
		strip.Visible = state ~= nil and phase ~= "Lobby" and phase ~= "Results"
		if not state then
			return
		end
		local byRarity = {}
		for _, slot in state.Slots do
			byRarity[slot.Rarity] = slot
		end
		for _, rarity in AssetDefs.rarities do
			local ui, slot = slots[rarity], byRarity[rarity]
			local def = slot and AssetDefs.get(slot.AssetId)
			local found = slot ~= nil and slot.Found
			ui.title.Text =
				`{Style.name(rarity)} · {if not slot then "—" elseif found then "FOUND" else "NOT FOUND"}`
			ui.title.TextColor3 = if found then (Style.color(rarity) or theme.AccentColor) else theme.DimTextColor
			ui.name.Text = if def and slot then `{def.Name} {Style.value(slot.AssetId, rarity)}` else "—"
			ui.name.TextColor3 = if found then theme.TextColor else theme.DimTextColor
		end
	end
	janitor:Add(RemoteController.connect("AssetState", function(info: Types.AssetStateInfo)
		state = info
		refresh()
	end))
	janitor:Add(RemoteController.connect("PhaseChanged", function(value: Types.Phase)
		phase = value
		if value == "Lobby" then
			state = nil
		end
		refresh()
	end))
	janitor:Add(script.Destroying:Connect(function()
		janitor:Destroy()
	end))
end
return AssetHudController
