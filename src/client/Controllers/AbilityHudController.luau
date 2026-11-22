--!strict
-- Ticket 16-hud: owner's confirmed ability cooldown. Static feedback respects Reduce Motion; no easing or flashes.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.GameConfig)
local InputHints = require(Shared:WaitForChild("Util"):WaitForChild("InputHints"))
local Types = require(Shared.Types)
local HudKit = require(Shared.Util.HudKit)
local HudTheme = require(Shared.Util.HudTheme)
local Janitor = require(Shared.Util.Janitor)
local HudIcons = require(script.Parent.Parent.Combat.HudIcons)
local AbilityController = require(script.Parent.AbilityController)
local RemoteController = require(script.Parent.RemoteController)
local TaserStatusController = require(script.Parent.TaserStatusController)
local AbilityHudController = {}

function AbilityHudController.Init() end

function AbilityHudController.Start()
	local janitor = Janitor.new()
	local theme = HudTheme.get()
	local floating = GameConfig.UI.FloatingHud
	local hintUntil = 0
	local lastInfo: Types.AbilityCooldownInfo? = nil
	local emblem: Frame? = nil
	local phase: Types.Phase = "Lobby"
	local previousRound: Types.AbilityCooldownInfo? = nil
	local gui = HudKit.screen("AbilityHud")
	janitor:Add(gui)
	local panel = HudKit.panel(
		gui,
		"Ability",
		UDim2.new(1, -theme.MarginPixels - theme.AmmoWidthPixels - theme.PaddingPixels, 1, -theme.MarginPixels),
		Vector2.new(1, 1),
		UDim2.fromOffset(floating.AbilitySizePixels, floating.AbilitySizePixels)
	)
	local ring = HudKit.ring(panel, "CooldownTick", floating.AbilitySizePixels)
	local root = panel.Parent :: Frame
	root.Visible = false
	local name = HudKit.text(
		panel,
		"AbilityName",
		UDim2.new(1, 0, 0, -theme.CaptionSize - theme.PaddingPixels),
		Vector2.new(1, 0),
		UDim2.fromOffset(theme.AmmoWidthPixels, theme.CaptionSize)
	)
	name.TextSize = theme.CaptionSize
	name.TextXAlignment = Enum.TextXAlignment.Right
	local status = HudKit.text(
		panel,
		"AbilityCooldown",
		UDim2.new(0.5, 0, 1, theme.CaptionSize),
		Vector2.new(0.5, 1),
		UDim2.fromOffset(floating.AbilitySizePixels, theme.CaptionSize)
	)
	status.TextSize = theme.CaptionSize
	status.TextXAlignment = Enum.TextXAlignment.Center
	local function update()
		local info = AbilityController.cooldown()
		local inMatch = phase ~= "Lobby" and phase ~= "Results"
		root.Visible = inMatch and info ~= nil and info ~= previousRound
		if not root.Visible or not info then
			return
		end
		if info ~= lastInfo then
			hintUntil = os.clock() + floating.HintSeconds
			if not lastInfo or info.Name ~= lastInfo.Name then
				if emblem then
					emblem:Destroy()
				end
				local pixels = floating.GadgetIconPixels
				emblem = HudIcons.draw(
					panel,
					HudIcons.talentId(info.Name),
					UDim2.fromOffset(
						(floating.AbilitySizePixels - pixels) / 2,
						(floating.AbilitySizePixels - pixels) / 2
					),
					pixels,
					theme.TextColor
				)
			end
			lastInfo = info
		end
		name.Visible = os.clock() < hintUntil
		name.Text = InputHints.bracket(GameConfig.Controls.Ability, GameConfig.Controls.AbilityPad, info.Name)
		local remaining = math.max(0, info.ReadyAt - workspace:GetServerTimeNow())
		local locked = TaserStatusController.remaining()
		status.Text = if locked > 0
			then tostring(math.ceil(locked))
			elseif remaining > 0 then tostring(math.ceil(remaining))
			else ""
		ring(
			if locked > 0 then 0 else 1 - remaining / math.max(info.Seconds, 0.001),
			if locked > 0 then GameConfig.UI.WarningColor else theme.TextColor
		)
		status.TextColor3 = if locked > 0
			then GameConfig.UI.WarningColor
			elseif remaining == 0 then theme.AccentColor
			else theme.TextColor
		panel.BackgroundTransparency = if locked > 0 then floating.WarningTransparency else 1
		if locked > 0 then
			name.Visible = true
			name.Text = if TaserStatusController.slowed() then "TASED · MOVEMENT SLOWED" else "TASED"
		end
	end
	janitor:Add(InputHints.onChange(function()
		hintUntil = os.clock() + floating.HintSeconds
	end))
	janitor:Add(RemoteController.connect("PhaseChanged", function(nextPhase: Types.Phase)
		phase = nextPhase
		if nextPhase == "Lobby" then
			-- AbilityController retains its last packet. Await a fresh record before showing a new round's cooldown.
			previousRound = AbilityController.cooldown()
		end
		update()
	end))
	janitor:Add(RunService.RenderStepped:Connect(update))
	janitor:Add(script.Destroying:Connect(function()
		janitor:Destroy()
	end))
end

return AbilityHudController
