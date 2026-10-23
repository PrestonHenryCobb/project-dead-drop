--!strict
-- One-way windows (MAP_BRIEF_REPLAN stage 2). Panes tagged OneWayGlass are built as mirrors, which is how everyone
-- outside sees them. Each frame this client checks which side of each pane its camera is on, and draws the panes it is
-- inside of as clear glass. Only the look changes, and only for this player: the pane still blocks movement, shots and
-- every sight check both ways, so seeing out never lets anyone shoot or spot through it.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enums = require(Shared:WaitForChild("Enums"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))

local OneWayGlassController = {}

local config = GameConfig.Map.OneWayGlass

type Pane = { part: BasePart, inside: Vector3, clear: boolean? }
local panes: { [BasePart]: Pane } = {}

local function setClear(pane: Pane, clear: boolean)
	if pane.clear == clear then
		return
	end
	pane.clear = clear
	local part = pane.part
	part.Material = if clear then Enum.Material.Glass else Enum.Material.SmoothPlastic
	part.Transparency = if clear then config.InsideTransparency else 0
	part.Reflectance = if clear then 0 else config.OutsideReflectance
end

local function add(instance: Instance)
	local inside = instance:GetAttribute("Inside")
	if instance:IsA("BasePart") and typeof(inside) == "Vector3" then
		panes[instance] = { part = instance, inside = inside }
	end
end

function OneWayGlassController.Init() end

function OneWayGlassController.Start()
	-- Panes stream in and out with StreamingEnabled.
	for _, instance in CollectionService:GetTagged(Enums.Tag.OneWayGlass) do
		add(instance)
	end
	CollectionService:GetInstanceAddedSignal(Enums.Tag.OneWayGlass):Connect(add)
	CollectionService:GetInstanceRemovedSignal(Enums.Tag.OneWayGlass):Connect(function(instance)
		if instance:IsA("BasePart") then
			panes[instance] = nil
		end
	end)

	RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local eye = camera.CFrame.Position
		for _, pane in panes do
			setClear(pane, (eye - pane.part.Position):Dot(pane.inside) > 0)
		end
	end)
end

return OneWayGlassController
