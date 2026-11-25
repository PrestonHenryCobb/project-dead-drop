--!strict
-- A small frames-per-second readout in the top-left corner, off by default (owner 2026-11-25, Settings > Performance).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local HudKit = require(Shared:WaitForChild("Util"):WaitForChild("HudKit"))
local Janitor = require(Shared:WaitForChild("Util"):WaitForChild("Janitor"))
local SettingsController = require(script.Parent.SettingsController)

local FpsCounterController = {}

local config = GameConfig.FpsCounter
local janitor = Janitor.new()

function FpsCounterController.Init() end

function FpsCounterController.Start()
	local gui = HudKit.screen("FpsCounter")
	gui.DisplayOrder = GameConfig.MatchHud.DisplayOrder + 1
	gui.Enabled = false
	janitor:Add(gui)
	local label = HudKit.text(
		gui,
		"Fps",
		UDim2.fromOffset(config.MarginPixels, config.MarginPixels),
		Vector2.new(0, 0),
		UDim2.fromOffset(config.TextSize * 8, config.TextSize + 4)
	)
	label.TextSize = config.TextSize
	label.TextXAlignment = Enum.TextXAlignment.Left
	local frames, elapsed = 0, 0
	janitor:Add(RunService.RenderStepped:Connect(function(dt: number)
		local on = SettingsController.get().ShowFps
		if gui.Enabled ~= on then
			gui.Enabled = on
			frames, elapsed = 0, 0
		end
		if not on then
			return
		end
		frames += 1
		elapsed += dt
		if elapsed >= config.UpdateSeconds then
			label.Text = string.format("%d FPS", math.floor(frames / elapsed + 0.5))
			frames, elapsed = 0, 0
		end
	end))
	janitor:Add(script.Destroying:Connect(function()
		janitor:Destroy()
	end))
end

return FpsCounterController
