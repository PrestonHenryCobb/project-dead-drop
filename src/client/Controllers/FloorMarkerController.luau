--!strict
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enums = require(Shared.Enums)
local Janitor = require(Shared.Util.Janitor)
local FloorBands = require(script.Parent.Parent.Combat.FloorBands)
local FloorMarkerController = {}
local janitor = Janitor.new()
local bands = FloorBands.new()

function FloorMarkerController.hint(target: Vector3): string
	local camera = workspace.CurrentCamera
	return if camera then bands.hint(camera.CFrame.Position.Y, target.Y) else ""
end

function FloorMarkerController.Init() end

function FloorMarkerController.Start()
	janitor:Add(CollectionService:GetInstanceAddedSignal(Enums.Tag.ZoneVolume):Connect(bands.add))
	janitor:Add(CollectionService:GetInstanceRemovedSignal(Enums.Tag.ZoneVolume):Connect(bands.remove))
	for _, instance in CollectionService:GetTagged(Enums.Tag.ZoneVolume) do
		bands.add(instance)
	end
	janitor:Add(bands.clear)
	janitor:Add(script.Destroying:Connect(function()
		janitor:Destroy()
	end))
end

return FloorMarkerController
