--!strict
-- Owner-only confirmed Asset slots; no draft data or predicted safe unlocks.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.GameConfig)
local AssetDefs = require(Shared.Defs.AssetDefs)
local Types = require(Shared.Types)
local Janitor = require(Shared.Util.Janitor)
local HudKit = require(Shared.Util.HudKit)
local HudTheme = require(Shared.Util.HudTheme)
local HudScale = require(Shared.Util.HudScale)
local HudIcons = require(script.Parent.Parent.Combat.HudIcons)
local Style = require(script.Parent.Parent.Combat.AssetStyle)
local RemoteController = require(script.Parent.RemoteController)
local AssetHudController = {}
function AssetHudController.Init() end
function AssetHudController.Start()
	local janitor = Janitor.new()
	local theme, config = HudTheme.get(), GameConfig.AssetHud
	local floating = GameConfig.UI.FloatingHud
	local hintUntil = 0
	local previous = ""
	local phase: Types.Phase = "Lobby"
	local state: Types.AssetStateInfo? = nil
	local gui = HudKit.screen("AssetHud")
	janitor:Add(gui)
	local strip = Instance.new("Frame")
	strip.Name = "AssetStrip"
	strip.AnchorPoint = Vector2.zero
	strip.Position = UDim2.new(0, theme.MarginPixels, 0, config.TopPixels)
	strip.Size = UDim2.fromOffset(
		floating.GadgetSizePixels,
		#AssetDefs.rarities * (floating.GadgetSizePixels + theme.PaddingPixels) - theme.PaddingPixels
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
			UDim2.fromOffset(0, (index - 1) * (floating.GadgetSizePixels + theme.PaddingPixels)),
			Vector2.zero,
			UDim2.fromOffset(floating.GadgetSizePixels, floating.GadgetSizePixels)
		)
		local title = HudKit.text(
			panel,
			"AssetValue",
			UDim2.new(0.5, 0, 1, 0),
			Vector2.new(0.5, 1),
			UDim2.fromOffset(floating.GadgetSizePixels, theme.CaptionSize)
		)
		title.TextSize = theme.CaptionSize
		local name = HudKit.text(
			panel,
			"AssetName",
			UDim2.new(1, theme.PaddingPixels, 0.5, 0),
			Vector2.new(0, 0.5),
			UDim2.fromOffset(theme.AmmoWidthPixels, theme.CaptionSize * 2)
		)
		name.TextSize = theme.CaptionSize
		name.TextWrapped = true
		name.TextXAlignment = Enum.TextXAlignment.Left
		slots[rarity] = { title = title, name = name, panel = panel, emblem = nil :: Frame?, id = nil :: string? }
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
			local id = if slot then slot.AssetId else ""
			if ui.id ~= id then
				if ui.emblem then
					ui.emblem:Destroy()
				end
				ui.emblem = if def
					then HudIcons.draw(
						ui.panel,
						id,
						UDim2.fromOffset((floating.GadgetSizePixels - floating.GadgetIconPixels) / 2, 0),
						floating.GadgetIconPixels,
						theme.TextColor
					)
					else nil
				ui.id = id
			end
			if ui.emblem then
				for _, line in ui.emblem:GetChildren() do
					if line:IsA("Frame") then
						line.BackgroundColor3 = if found
							then (Style.color(rarity) or theme.TextColor)
							else theme.DimTextColor
						line.BackgroundTransparency = if found then 0 else floating.InactiveTransparency
					end
				end
			end
			ui.title.Text = if found and slot then Style.value(slot.AssetId, rarity) else "—"
			ui.title.TextColor3 = if found then theme.TextColor else theme.DimTextColor
			ui.name.Text = if def
				then def.Name .. " · " .. Style.name(rarity) .. (if found then "" else " · NOT FOUND")
				else ""
			ui.name.TextColor3 = if found then theme.TextColor else theme.DimTextColor
		end
	end
	janitor:Add(RemoteController.connect("AssetState", function(info: Types.AssetStateInfo)
		local parts = {}
		for _, slot in info.Slots do
			table.insert(parts, slot.Rarity .. slot.AssetId .. tostring(slot.Found))
		end
		local key = table.concat(parts, ":")
		if key ~= previous then
			hintUntil = os.clock() + floating.HintSeconds
		end
		previous = key
		state = info
		refresh()
	end))
	janitor:Add(RemoteController.connect("PhaseChanged", function(value: Types.Phase)
		phase = value
		if value == "Lobby" then
			state = nil
			previous = ""
			hintUntil = 0
		end
		refresh()
	end))
	janitor:Add(RunService.RenderStepped:Connect(function()
		for _, slot in slots do
			slot.name.Visible = os.clock() < hintUntil
		end
	end))
	janitor:Add(script.Destroying:Connect(function()
		janitor:Destroy()
	end))
end
return AssetHudController
