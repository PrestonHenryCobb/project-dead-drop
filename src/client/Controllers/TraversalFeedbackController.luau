--!strict
-- Ticket 19-traversal-warnings: public traversal affordances only, never character metadata.
-- The badge does not activate traversal, predict Cover changes, or add a confirmation press.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enums = require(Shared.Enums)
local GameConfig = require(Shared.GameConfig)
local HudKit = require(Shared.Util.HudKit)
local HudTheme = require(Shared.Util.HudTheme)
local Janitor = require(Shared.Util.Janitor)
local RemoteController = require(script.Parent.RemoteController)

local TraversalFeedbackController = {}
local janitor = Janitor.new()
local player = Players.LocalPlayer
local config = GameConfig.UI.TraversalWarnings
local graphics = HudTheme.get()
local vents: { [BasePart]: boolean } = {}
local shown: { [ProximityPrompt]: string } = {}
local ray = RaycastParams.new()
ray.FilterType = Enum.RaycastFilterType.Exclude
local enabled = true

local function promptLabel(prompt: ProximityPrompt): string?
	local ancestor: Instance? = prompt.Parent
	while ancestor and ancestor ~= workspace do
		if CollectionService:HasTag(ancestor, Enums.Tag.ZiplineAnchor) then
			return "ZIPLINE · BREAKS COVER"
		elseif CollectionService:HasTag(ancestor, Enums.Tag.GondolaCall) then
			return "GONDOLA · RIDING BREAKS COVER"
		end
		ancestor = ancestor.Parent
	end
	return nil
end

local function addVent(instance: Instance)
	if instance:IsA("BasePart") then
		vents[instance] = true
	end
end

local function nearVent(): boolean
	local body = player.Character
	local root = body and body:FindFirstChild("HumanoidRootPart")
	local camera = workspace.CurrentCamera
	if not (root and root:IsA("BasePart") and camera) then
		return false
	end
	for vent in vents do
		if vent:IsDescendantOf(workspace) and (vent.Position - root.Position).Magnitude <= config.VentDistanceStuds then
			local offset = vent.Position - camera.CFrame.Position
			local distance = offset.Magnitude
			if distance > 0 and camera.CFrame.LookVector:Dot(offset / distance) >= config.VentFacingDot then
				local hit = workspace:Raycast(camera.CFrame.Position, offset, ray)
				if not hit or hit.Instance == vent then
					return true
				end
			end
		end
	end
	return false
end

function TraversalFeedbackController.Init() end

function TraversalFeedbackController.Start()
	local screen = HudKit.screen("TraversalHud")
	janitor:Add(screen)
	local panel = HudKit.panel(
		screen,
		"Warning",
		UDim2.new(0.5, 0, 1, -(graphics.CoverBottomPixels + graphics.CoverHeightPixels + graphics.PaddingPixels)),
		Vector2.new(0.5, 1),
		UDim2.fromOffset(graphics.ActionWidthPixels, config.HeightPixels)
	)
	local container = panel.Parent :: Frame
	container.Visible = false
	local icon = HudKit.icon(
		panel,
		"Eye",
		UDim2.fromOffset(graphics.PaddingPixels, graphics.PaddingPixels),
		graphics.IconPixels,
		graphics.TextColor
	)
	-- Normalized drawing coordinates, matching HudKit's code-drawn icons.
	local slash = Instance.new("Frame")
	slash.Name = "CoverBreakSlash"
	slash.AnchorPoint = Vector2.new(0.5, 0.5)
	slash.Position = UDim2.fromScale(0.5, 0.5)
	slash.Size = UDim2.fromOffset(graphics.IconPixels, graphics.IconPixels * graphics.IconStrokeFraction)
	slash.Rotation = -45
	slash.BorderSizePixel = 0
	slash.BackgroundColor3 = graphics.TextColor
	slash.Parent = icon
	local inset = graphics.PaddingPixels * 2 + graphics.IconPixels
	local label = HudKit.text(
		panel,
		"Risk",
		UDim2.fromOffset(inset, 0),
		Vector2.zero,
		UDim2.new(1, -inset - graphics.PaddingPixels, 1, 0)
	)
	label.TextSize = graphics.CaptionSize
	label.TextXAlignment = Enum.TextXAlignment.Left

	local function characterAdded(body: Model)
		ray.FilterDescendantsInstances = { body }
		enabled = true
	end
	if player.Character then
		characterAdded(player.Character)
	end
	janitor:Add(player.CharacterAdded:Connect(characterAdded))
	for _, vent in CollectionService:GetTagged(Enums.Tag.Vent) do
		addVent(vent)
	end
	janitor:Add(CollectionService:GetInstanceAddedSignal(Enums.Tag.Vent):Connect(addVent))
	janitor:Add(CollectionService:GetInstanceRemovedSignal(Enums.Tag.Vent):Connect(function(instance: Instance)
		if instance:IsA("BasePart") then
			vents[instance] = nil
		end
	end))
	janitor:Add(ProximityPromptService.PromptShown:Connect(function(prompt: ProximityPrompt)
		shown[prompt] = promptLabel(prompt)
	end))
	janitor:Add(ProximityPromptService.PromptHidden:Connect(function(prompt: ProximityPrompt)
		shown[prompt] = nil
	end))
	for _, event in { "Downed", "Eliminated" } do
		janitor:Add(RemoteController.connect(event, function()
			enabled = false
		end))
	end
	janitor:Add(RemoteController.connect("Revived", function()
		enabled = true
	end))
	local elapsed = 0
	janitor:Add(RunService.Heartbeat:Connect(function(dt: number)
		elapsed += dt
		if elapsed < config.CheckSeconds then
			return
		end
		elapsed = 0
		local text: string? = nil
		local body = player.Character
		local humanoid = body and body:FindFirstChildOfClass("Humanoid")
		if enabled and humanoid and humanoid.Health > 0 then
			for prompt, value in shown do
				if prompt.Enabled and prompt:IsDescendantOf(workspace) then
					text = value
					break
				else
					shown[prompt] = nil
				end
			end
			if not text and nearVent() then
				text = "VENT · BREAKS COVER"
			end
		end
		label.Text = text or ""
		container.Visible = text ~= nil
	end))
	janitor:Add(script.Destroying:Connect(function()
		janitor:Destroy()
	end))
end

return TraversalFeedbackController
