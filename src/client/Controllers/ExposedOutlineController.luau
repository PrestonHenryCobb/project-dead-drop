--!strict
-- Outlines every other player who is Exposed (owner 2026-11-25), in the colour the local player chose in Settings. The Exposed look is recognised from body
-- colours alone (Combat/ExposedLook), so no roster or tag is involved. The outline is occluded by walls: it shows what line of sight already shows.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Janitor = require(Shared:WaitForChild("Util"):WaitForChild("Janitor"))
local ExposedLook = require(script.Parent.Parent:WaitForChild("Combat"):WaitForChild("ExposedLook"))
local SettingsController = require(script.Parent.SettingsController)

local ExposedOutlineController = {}

local config = GameConfig.ExposedOutline
local janitor = Janitor.new()
local outlines: { [Model]: Highlight } = {}
local elapsed = 0

local function remove(model: Model)
	local outline = outlines[model]
	if outline then
		outline:Destroy()
		outlines[model] = nil
	end
end

local function sweep()
	local preferences = SettingsController.get()
	if not preferences.ExposedOutline then
		for model in outlines do
			remove(model)
		end
		return
	end
	for model in outlines do
		if model.Parent ~= workspace or not ExposedLook.matches(model) then
			remove(model)
		end
	end
	local count = 0
	for _ in outlines do
		count += 1
	end
	for _, child in workspace:GetChildren() do
		if child:IsA("Model") and not outlines[child] and count < config.MaxOutlines and ExposedLook.matches(child) then
			local outline = Instance.new("Highlight")
			outline.Name = "Outline"
			outline.Adornee = child
			outline.DepthMode = Enum.HighlightDepthMode.Occluded
			outline.FillTransparency = config.FillTransparency
			outline.OutlineTransparency = config.OutlineTransparency
			outline.Parent = child
			outlines[child] = outline
			count += 1
		end
	end
	for _, outline in outlines do
		outline.OutlineColor = preferences.ExposedOutlineColor
	end
end

function ExposedOutlineController.Init() end

function ExposedOutlineController.Start()
	janitor:Add(game:GetService("RunService").Heartbeat:Connect(function(dt: number)
		elapsed += dt
		if elapsed >= config.SweepSeconds then
			elapsed = 0
			sweep()
		end
	end))
	janitor:Add(function()
		for model in outlines do
			remove(model)
		end
	end)
	janitor:Add(script.Destroying:Connect(function()
		janitor:Destroy()
	end))
end

return ExposedOutlineController
