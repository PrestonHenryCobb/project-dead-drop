--!strict
-- Ticket 17-hud: confirmed owner-only slots, charges and held selection. No requests or equip prediction.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.GameConfig)
local GadgetDefs = require(Shared.Defs.GadgetDefs)
local Types = require(Shared.Types)
local HudKit = require(Shared.Util.HudKit)
local HudTheme = require(Shared.Util.HudTheme)
local HudScale = require(Shared.Util.HudScale)
local Janitor = require(Shared.Util.Janitor)
local GadgetCard = require(script.Parent.Parent.Combat.GadgetCard)
local GadgetController = require(script.Parent.GadgetController)
local RemoteController = require(script.Parent.RemoteController)
local GadgetHudController = {}

function GadgetHudController.Init() end

function GadgetHudController.Start()
	local janitor = Janitor.new()
	local theme = HudTheme.get()
	local config = GameConfig.GadgetHud
	local phase: Types.Phase = "Lobby"
	local previousRound: Types.GadgetStateInfo? = nil
	local gui = HudKit.screen("GadgetHud")
	janitor:Add(gui)
	local group = Instance.new("Frame")
	group.Name = "GadgetBar"
	group.BackgroundTransparency = 1
	group.AnchorPoint = Vector2.new(0.5, 1)
	group.Position = UDim2.new(0.5, 0, 1, -theme.CoverBottomPixels - theme.CoverHeightPixels - theme.PaddingPixels)
	group.Size = UDim2.fromOffset(
		GameConfig.Gadgets.Slots * (config.CardWidthPixels + theme.PaddingPixels) - theme.PaddingPixels,
		config.CardHeightPixels
	)
	group.Visible = false
	group.Parent = gui
	HudScale.bind(group)
	local cards = {}
	for index = 1, GameConfig.Gadgets.Slots do
		local panel = HudKit.panel(
			group,
			`GadgetSlot{index}`,
			UDim2.fromOffset((index - 1) * (config.CardWidthPixels + theme.PaddingPixels), 0),
			Vector2.zero,
			UDim2.fromOffset(config.CardWidthPixels, config.CardHeightPixels)
		)
		local root = panel.Parent :: Frame
		local border = Instance.new("UIStroke")
		border.Thickness = theme.StrokePixels
		border.Parent = root
		local name = HudKit.text(
			panel,
			"GadgetName",
			UDim2.fromOffset(theme.PaddingPixels * 2 + theme.IconPixels, theme.PaddingPixels),
			Vector2.zero,
			UDim2.new(1, -theme.PaddingPixels * 3 - theme.IconPixels, 0, theme.CaptionSize)
		)
		name.TextSize = theme.CaptionSize
		name.TextXAlignment = Enum.TextXAlignment.Left
		local status = HudKit.text(
			panel,
			"GadgetCharges",
			UDim2.fromOffset(theme.PaddingPixels, theme.PaddingPixels * 2 + theme.CaptionSize),
			Vector2.zero,
			UDim2.new(1, -theme.PaddingPixels * 2, 0, theme.CaptionSize)
		)
		status.TextSize = theme.CaptionSize
		status.TextXAlignment = Enum.TextXAlignment.Left
		table.insert(cards, {
			root = root,
			panel = panel,
			border = border,
			name = name,
			status = status,
			emblem = nil :: Frame?,
			category = nil :: string?,
		})
	end
	local function update()
		local info = GadgetController.state()
		group.Visible = phase ~= "Lobby"
			and phase ~= "Results"
			and info ~= nil
			and info ~= previousRound
			and #info.Slots > 0
		for index, card in cards do
			local slot = info and info.Slots[index]
			local def = if slot then GadgetDefs.get(slot.Id) else nil
			card.root.Visible = group.Visible and def ~= nil
			if not slot or not def then
				continue
			end
			if card.category ~= def.Category then
				if card.emblem then
					card.emblem:Destroy()
				end
				card.emblem = GadgetCard.emblem(card.panel, def.Category, theme.IconPixels)
				card.emblem.Position = UDim2.fromOffset(theme.PaddingPixels, theme.PaddingPixels)
				card.category = def.Category
			end
			local key = if index == 1 then GameConfig.Controls.Gadget1 else GameConfig.Controls.Gadget2
			local keyText = UserInputService:GetStringForKeyCode(key)
			card.name.Text = `[ {if keyText ~= "" then keyText else key.Name} ] {def.Name}`
			local held = info ~= nil and info.Held == index
			card.status.Text =
				`{slot.Charges} {if slot.Charges == 1 then "CHARGE" else "CHARGES"}{if held then " · HELD" else ""}`
			card.border.Color = if held then GameConfig.GadgetHud.Categories[def.Category].Color else theme.BorderColor
			card.border.Thickness = if held then theme.StrokePixels * 2 else theme.StrokePixels
		end
	end
	janitor:Add(RemoteController.connect("PhaseChanged", function(value: Types.Phase)
		phase = value
		if value == "Lobby" then
			previousRound = GadgetController.state()
		end
		update()
	end))
	janitor:Add(RunService.RenderStepped:Connect(update))
	janitor:Add(script.Destroying:Connect(function()
		janitor:Destroy()
	end))
end

return GadgetHudController
