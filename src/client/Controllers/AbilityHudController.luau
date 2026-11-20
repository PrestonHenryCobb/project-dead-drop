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
local AbilityController = require(script.Parent.AbilityController)
local RemoteController = require(script.Parent.RemoteController)
local TaserStatusController = require(script.Parent.TaserStatusController)
local AbilityHudController = {}

function AbilityHudController.Init() end

function AbilityHudController.Start()
	local janitor = Janitor.new()
	local theme = HudTheme.get()
	local phase: Types.Phase = "Lobby"
	local previousRound: Types.AbilityCooldownInfo? = nil
	local gui = HudKit.screen("AbilityHud")
	janitor:Add(gui)
	local panel = HudKit.panel(
		gui,
		"Ability",
		UDim2.new(1, -theme.MarginPixels, 1, -theme.MarginPixels - theme.AmmoHeightPixels - theme.PaddingPixels),
		Vector2.new(1, 1),
		UDim2.fromOffset(theme.AmmoWidthPixels, theme.AmmoHeightPixels)
	)
	local root = panel.Parent :: Frame
	root.Visible = false
	local name = HudKit.text(
		panel,
		"AbilityName",
		UDim2.fromOffset(theme.PaddingPixels, theme.PaddingPixels),
		Vector2.zero,
		UDim2.new(1, -theme.PaddingPixels * 2, 0, theme.CaptionSize)
	)
	name.TextSize = theme.CaptionSize
	name.TextXAlignment = Enum.TextXAlignment.Left
	local status = HudKit.text(
		panel,
		"AbilityCooldown",
		UDim2.new(0, theme.PaddingPixels, 1, -theme.PaddingPixels),
		Vector2.new(0, 1),
		UDim2.new(1, -theme.PaddingPixels * 2, 0, theme.NumberSize)
	)
	status.TextSize = theme.NumberSize
	status.TextXAlignment = Enum.TextXAlignment.Left
	local function update()
		local info = AbilityController.cooldown()
		local inMatch = phase ~= "Lobby" and phase ~= "Results"
		root.Visible = inMatch and info ~= nil and info ~= previousRound
		if not root.Visible or not info then
			return
		end
		name.Text = InputHints.bracket(GameConfig.Controls.Ability, GameConfig.Controls.AbilityPad, info.Name)
		local remaining = math.max(0, info.ReadyAt - workspace:GetServerTimeNow())
		local locked = TaserStatusController.remaining()
		status.Text = if locked > 0
			then `LOCKED {math.ceil(locked)}s`
			elseif remaining == 0 then "READY"
			else `{math.ceil(remaining)}s`
		status.TextColor3 = if locked > 0
			then GameConfig.UI.WarningColor
			elseif remaining == 0 then theme.AccentColor
			else theme.TextColor
		if locked > 0 and TaserStatusController.slowed() then
			name.Text = "TASED · MOVEMENT SLOWED"
		end
	end
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
