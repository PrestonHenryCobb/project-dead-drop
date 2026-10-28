--!strict
-- Bounded client-only copies of streamed visual parts. Never clone scripts, rig metadata or identity labels.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.GameConfig)
local config = GameConfig.SecurityHud
local SecurityFeeds = {}

local function working(part: BasePart): boolean
	local state = part:GetAttribute("CameraState")
	return part.Parent ~= nil and (state == "Sweep" or state == "Locked")
end

function SecurityFeeds.cameras(instances: { Instance }): { BasePart }
	local result = {}
	for _, instance in instances do
		if instance:IsA("BasePart") and working(instance) then
			table.insert(result, instance)
		end
	end
	table.sort(result, function(a, b)
		return tostring(a:GetAttribute("SecurityId")) < tostring(b:GetAttribute("SecurityId"))
	end)
	return result
end

local function clean(instance: Instance)
	for name in instance:GetAttributes() do
		instance:SetAttribute(name, nil)
	end
	for _, tag in CollectionService:GetTags(instance) do
		CollectionService:RemoveTag(instance, tag)
	end
end

local function copy(part: BasePart): BasePart?
	local ok, result = pcall(function()
		return part:Clone()
	end)
	if not ok or not result then
		return nil
	end
	local cloned = result :: BasePart
	cloned.Name = "FeedSurface"
	clean(cloned)
	for _, child in cloned:GetChildren() do
		if child:IsA("DataModelMesh") or child:IsA("Decal") or child:IsA("SurfaceAppearance") then
			clean(child)
			child:ClearAllChildren()
		else
			child:Destroy()
		end
	end
	cloned.Anchored = true
	cloned.CanCollide = false
	cloned.CanTouch = false
	cloned.CanQuery = false
	return cloned
end

function SecurityFeeds.new(viewport: ViewportFrame)
	local world = Instance.new("WorldModel")
	world.Parent = viewport
	local eye = Instance.new("Camera")
	eye.FieldOfView = GameConfig.Security.Camera.ConeDegrees
	eye.Parent = viewport
	viewport.CurrentCamera = eye
	viewport.Ambient = config.Ambient
	viewport.LightColor = config.LightColor
	local copies: { [BasePart]: BasePart } = {}
	local source: BasePart? = nil
	local elapsed = config.SceneSeconds
	local params = OverlapParams.new()
	params.MaxParts = config.MaxPartsPerFeed
	local sight = RaycastParams.new()
	sight.CollisionGroup = GameConfig.Rig.CollisionGroup
	sight.RespectCanCollide = true

	local function clear()
		for _, cloned in copies do
			cloned:Destroy()
		end
		table.clear(copies)
	end

	local function sample(camera: BasePart)
		local candidates: { [BasePart]: boolean } = {}
		for _, part in workspace:GetPartBoundsInRadius(camera.Position, config.SceneRadius, params) do
			candidates[part] = true
		end
		-- Rig surfaces can be non-queryable. Include nearby models identically, without asking who owns them.
		for _, model in workspace:GetChildren() do
			if model:IsA("Model") and (model:GetPivot().Position - camera.Position).Magnitude <= config.SceneRadius then
				for _, part in model:GetDescendants() do
					if part:IsA("BasePart") then
						candidates[part] = true
					end
				end
			end
		end
		local ordered = {}
		for part in candidates do
			if
				part ~= camera
				and part.Transparency < 1
				and (not workspace.CurrentCamera or not part:IsDescendantOf(workspace.CurrentCamera))
			then
				table.insert(ordered, part)
			end
		end
		table.sort(ordered, function(a, b)
			return (a.Position - camera.Position).Magnitude < (b.Position - camera.Position).Magnitude
		end)
		local keep: { [BasePart]: boolean } = {}
		for index = 1, math.min(#ordered, config.MaxPartsPerFeed) do
			local part = ordered[index]
			keep[part] = true
			if not copies[part] then
				local cloned = copy(part)
				if cloned then
					cloned.Parent = world
					copies[part] = cloned
				end
			end
		end
		for part, cloned in copies do
			if not keep[part] then
				cloned:Destroy()
				copies[part] = nil
			end
		end
	end

	return {
		update = function(camera: BasePart?, dt: number)
			if camera ~= source then
				clear()
				source = camera
				elapsed = config.SceneSeconds
			end
			if not camera or not working(camera) then
				clear()
				return
			end
			eye.CFrame = camera.CFrame * CFrame.new(0, 0, -config.FeedNearOffset)
			sight.FilterDescendantsInstances = { camera }
			elapsed += dt
			if elapsed >= config.SceneSeconds then
				elapsed = 0
				sample(camera)
			end
			for part, cloned in copies do
				if part.Parent then
					cloned.CFrame = part.CFrame
					cloned.Size = part.Size
					cloned.Color = part.Color
					cloned.Material = part.Material
					-- Missing/budgeted viewport occluders must never make a hidden actor visible through a wall.
					local hit = workspace:Raycast(eye.CFrame.Position, part.Position - eye.CFrame.Position, sight)
					cloned.Transparency = if not hit or hit.Instance == part then part.Transparency else 1
				else
					cloned:Destroy()
					copies[part] = nil
				end
			end
		end,
		Destroy = function()
			clear()
			viewport.CurrentCamera = nil
			world:Destroy()
			eye:Destroy()
		end,
	}
end

return SecurityFeeds
