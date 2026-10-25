--!strict
-- Ticket gala-sculptures: bake original CSG once in EDIT mode. Never do CSG per NPC or per frame.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = script.Parent:FindFirstChild("SharedOverride") or ReplicatedStorage:WaitForChild("Shared")
local Definitions = require(Shared.Defs.SculptureDefs)
local GameConfig = require(Shared.GameConfig)
local ArtSurface = require(Shared.Util.ArtSurface)
local Sculptures = {}

type Shape = { size: { number }, at: { number }, rotation: { number }, kind: string }
type Component = { name: string, role: string, add: { Shape }, cut: { Shape }? }
type Definition = { reference: { number }, parts: { Component } }

local function vector(v: { number }): Vector3
	return Vector3.new(v[1], v[2], v[3])
end

function Sculptures.referenceSize(name: string): Vector3
	local definition = (Definitions :: any)[name]
	assert(definition, `Unknown sculpture {name}`)
	return vector(definition.reference)
end

local function primitive(shape: Shape, parent: Instance): BasePart
	local part = if shape.kind == "Wedge" then Instance.new("WedgePart") else Instance.new("Part")
	part.Size = vector(shape.size)
	local r = vector(shape.rotation)
	part.CFrame = CFrame.new(vector(shape.at)) * CFrame.Angles(math.rad(r.X), math.rad(r.Y), math.rad(r.Z))
	if part:IsA("Part") and shape.kind == "Cylinder" then
		part.Shape = Enum.PartType.Cylinder
	end
	part.Anchored = true
	part.CanCollide, part.CanQuery, part.CanTouch = false, false, false
	part.Parent = parent
	return part
end

function Sculptures.bake(): Folder
	assert(not RunService:IsRunning(), "Bake sculptures in Edit mode")
	local temporary = Instance.new("Folder")
	temporary.Name = "GalaSculptureBake"
	temporary.Parent = workspace
	local result = Instance.new("Folder")
	result.Name = GameConfig.Art.Sculptures.AssetFolder
	local ok, problem = pcall(function()
		for name, definition in Definitions :: { [string]: Definition } do
			local model = Instance.new("Model")
			model.Name = name
			model.Parent = result
			for _, component in definition.parts do
				local inputs: { BasePart } = {}
				for _, shape in component.add do
					table.insert(inputs, primitive(shape, temporary))
				end
				local base = table.remove(inputs, 1) :: BasePart
				local baked: BasePart = base
				if #inputs > 0 then
					baked =
						base:UnionAsync(inputs, Enum.CollisionFidelity.Box, Enum.RenderFidelity.Automatic) :: BasePart
					baked.Parent = temporary
				end
				if component.cut and #component.cut > 0 then
					local cuts: { BasePart } = {}
					for _, shape in component.cut do
						table.insert(cuts, primitive(shape, temporary))
					end
					baked =
						baked:SubtractAsync(cuts, Enum.CollisionFidelity.Box, Enum.RenderFidelity.Automatic) :: BasePart
				end
				baked.Name = component.name
				baked.Anchored = true
				baked.CanCollide, baked.CanQuery, baked.CanTouch = false, false, false
				baked.Massless = true
				if baked:IsA("PartOperation") then
					baked.UsePartColor = true
				end
				if (GameConfig.Art.Materials :: any)[component.role] then
					ArtSurface.apply(baked, component.role)
				else
					baked.Material = Enum.Material.SmoothPlastic
					baked.Color = Color3.new(1, 1, 1)
				end
				baked.Parent = model
			end
		end
	end)
	temporary:Destroy()
	if not ok then
		result:Destroy()
		error(problem)
	end
	local old = ReplicatedStorage:FindFirstChild(result.Name)
	if old then
		old:Destroy()
	end
	result.Parent = ReplicatedStorage
	return result
end

-- Clone baked parts with asset-space scaling. Templates are not changed and no original colliders are replaced.
function Sculptures.place(name: string, frame: CFrame, scale: Vector3, parent: Instance, velvet: Color3?): Model
	local assets = ReplicatedStorage:FindFirstChild(GameConfig.Art.Sculptures.AssetFolder)
	assert(assets, "Bake Gala sculptures before placing them")
	local template = assets:FindFirstChild(name)
	assert(template and template:IsA("Model"), `Missing sculpture {name}`)
	local model = template:Clone()
	for _, part in model:GetChildren() do
		if part:IsA("BasePart") then
			local offset = part.CFrame
			part.Size *= scale
			part.CFrame = frame * CFrame.new(offset.Position * scale) * offset.Rotation
			if name == "Settee" and part.Name ~= "Frame" and velvet then
				part.Color = velvet
			end
			if name == "Settee" then
				part.CanCollide, part.CanQuery = true, true
			end
			if part.Name == "Diffuser" then
				part.Color = GameConfig.Art.Lighting.Key
				part.Material = Enum.Material.Neon
			end
		end
	end
	model.Parent = parent
	return model
end

return Sculptures
