--!strict
-- Ticket 17-hud: confirmed owner-only slots, charges and held selection. No requests or equip prediction.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.GameConfig)
local InputHints = require(Shared.Util.InputHints)
local GadgetDefs = require(Shared.Defs.GadgetDefs)
local Types = require(Shared.Types)
local HudKit = require(Shared.Util.HudKit)
local HudTheme = require(Shared.Util.HudTheme)
local HudScale = require(Shared.Util.HudScale)
local Janitor = require(Shared.Util.Janitor)
local HudIcons = require(script.Parent.Parent.Combat.HudIcons)
local GadgetController = require(script.Parent.GadgetController)
local RemoteController = require(script.Parent.RemoteController)
local TaserStatusController = require(script.Parent.TaserStatusController)
local GadgetHudController = {}

function GadgetHudController.Init() end

function GadgetHudController.Start()
	local janitor = Janitor.new()
	local theme = HudTheme.get()
	local floating = GameConfig.UI.FloatingHud
	local size = floating.GadgetSizePixels
	local hintUntil = 0
	local lastHeld: number? = nil
	local wasVisible = false
	local phase: Types.Phase = "Lobby"
	local previousRound: Types.GadgetStateInfo? = nil
	local gui = HudKit.screen("GadgetHud")
	janitor:Add(gui)
	local group = Instance.new("Frame")
	group.Name = "GadgetBar"
	group.BackgroundTransparency = 1
	group.AnchorPoint = Vector2.new(0, 1)
	group.Position = UDim2.new(
		0,
		theme.MarginPixels + floating.DisguiseWidthPixels + floating.BracketGapPixels * 2 + theme.PaddingPixels,
		1,
		-theme.MarginPixels
	)
	group.Size = UDim2.fromOffset(GameConfig.Gadgets.Slots * (size + theme.PaddingPixels) - theme.PaddingPixels, size)
	group.Visible = false
	group.Parent = gui
	HudScale.bind(group)
	local cards = {}
	for index = 1, GameConfig.Gadgets.Slots do
		local panel = HudKit.panel(
			group,
			`GadgetSlot{index}`,
			UDim2.fromOffset((index - 1) * (size + theme.PaddingPixels), 0),
			Vector2.zero,
			UDim2.fromOffset(size, size)
		)
		local root = panel.Parent :: Frame
		local border = Instance.new("UIStroke")
		border.Thickness = theme.StrokePixels
		border.Parent = root
		local name = HudKit.text(
			panel,
			"GadgetName",
			UDim2.fromOffset(0, -theme.PaddingPixels - theme.CaptionSize * (index + 1)),
			Vector2.zero,
			UDim2.fromOffset(theme.AmmoWidthPixels, theme.CaptionSize)
		)
		name.TextSize = theme.CaptionSize
		name.TextXAlignment = Enum.TextXAlignment.Left
		local status = HudKit.text(
			panel,
			"GadgetCharges",
			UDim2.new(1, 0, 1, 0),
			Vector2.new(1, 1),
			UDim2.fromOffset(theme.CaptionSize * 2, theme.CaptionSize)
		)
		status.TextSize = theme.CaptionSize
		local bind = HudKit.text(
			panel,
			"GadgetBind",
			UDim2.new(0.5, 0, 1, theme.PaddingPixels / 2),
			Vector2.new(0.5, 0),
			UDim2.fromOffset(size, theme.CaptionSize)
		)
		bind.TextSize = theme.CaptionSize

		table.insert(cards, {
			root = root,
			panel = panel,
			border = border,
			name = name,
			status = status,
			bind = bind,
			emblem = nil :: Frame?,
			id = nil :: string?,
			charges = nil :: number?,
		})
	end
	local function update()
		local info = GadgetController.state()
		group.Visible = phase ~= "Lobby"
			and phase ~= "Results"
			and info ~= nil
			and info ~= previousRound
			and #info.Slots > 0
		if (group.Visible and not wasVisible) or (info and info.Held ~= lastHeld) then
			hintUntil = os.clock() + floating.HintSeconds
		end
		wasVisible = group.Visible
		lastHeld = if info then info.Held else nil
		for index, card in cards do
			local slot = info and info.Slots[index]
			local def = if slot then GadgetDefs.get(slot.Id) else nil
			card.root.Visible = group.Visible and def ~= nil
			if not slot or not def then
				continue
			end
			if card.id ~= slot.Id then
				if card.emblem then
					card.emblem:Destroy()
				end
				card.emblem = HudIcons.draw(
					card.panel,
					slot.Id,
					UDim2.fromOffset((size - floating.GadgetIconPixels) / 2, 0),
					floating.GadgetIconPixels,
					theme.TextColor
				)
				card.id = slot.Id
				hintUntil = os.clock() + floating.HintSeconds
			end
			local key = if index == 1 then GameConfig.Controls.Gadget1 else GameConfig.Controls.Gadget2
			card.bind.Text = InputHints.bracket(key, GameConfig.Controls.GadgetNextPad, "")
			card.name.Text = def.Name
			local held = info ~= nil and info.Held == index
			if card.charges ~= slot.Charges then
				hintUntil = os.clock() + floating.HintSeconds
			end
			card.charges = slot.Charges
			card.name.Visible = os.clock() < hintUntil
			card.status.Text = tostring(slot.Charges)
			local locked = TaserStatusController.remaining()
			card.panel.BackgroundTransparency = if locked > 0 then floating.WarningTransparency else 1
			if locked > 0 then
				card.name.Visible = true
				card.name.Text = "TASED " .. tostring(math.ceil(locked))
			end
			if card.emblem then
				for _, line in card.emblem:GetChildren() do
					if line:IsA("Frame") then
						line.BackgroundTransparency = if slot.Charges == 0 or locked > 0
							then floating.InactiveTransparency
							else 0
					end
				end
			end

			card.status.TextColor3 = if locked > 0 then GameConfig.UI.WarningColor else theme.TextColor
			card.border.Color = theme.TextColor
			card.border.Transparency = if held then 0.4 else 1
			card.border.Thickness = if held then theme.StrokePixels * 2 else theme.StrokePixels
		end
	end
	janitor:Add(InputHints.onChange(function()
		hintUntil = os.clock() + floating.HintSeconds
	end))
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
