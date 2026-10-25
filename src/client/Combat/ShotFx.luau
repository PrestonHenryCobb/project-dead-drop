--!strict
-- What a bullet does where it lands on the map: brief geometric sparks and a thud. Pooled, client only. Hits on people
-- have no effect here; the shooter's hitmarker comes from the server (spec 8.4).
--
--   ShotFx.impact(position, normal)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local SoundPlayer = require(script.Parent.SoundPlayer)
local RunService = game:GetService("RunService")
local Janitor = require(ReplicatedStorage.Shared.Util.Janitor)

local ShotFx = {}

local feedback = GameConfig.Combat.Feedback
local art = GameConfig.Art
local janitor = Janitor.new()

local pool: { { rays: { Part }, frame: CFrame, born: number } } = {}
local index = 0
local lastSoundAt = 0

local function build()
	local folder = Instance.new("Folder")
	folder.Name = "CombatImpacts"
	folder.Parent = workspace.CurrentCamera
	janitor:Add(folder)
	for _ = 1, art.ImpactPoolSize do
		local rays: { Part } = {}
		for _ = 1, art.ImpactSpokes do
			local part = Instance.new("Part")
			part.Name = "GeometricSpark"
			part.Anchored = true
			part.CanCollide, part.CanQuery, part.CanTouch, part.CastShadow = false, false, false, false
			part.Transparency = 1
			part.Material = Enum.Material.Neon
			part.Color = art.Materials.Brass.Color
			part.Size = Vector3.new(art.ImpactWidth, art.ImpactLength, art.ImpactWidth)
			part.Parent = folder
			table.insert(rays, part)
		end
		table.insert(pool, { rays = rays, frame = CFrame.identity, born = -math.huge })
	end
	janitor:Add(RunService.RenderStepped:Connect(function()
		local now = os.clock()
		for _, slot in pool do
			local age = (now - slot.born) / feedback.ImpactSeconds
			for ray, part in slot.rays do
				part.Transparency = math.clamp(age, 0, 1)
				if age < 1 then
					part.CFrame = slot.frame
						* CFrame.Angles(0, 0, ray * math.pi * 2 / art.ImpactSpokes)
						* CFrame.new(0, art.ImpactLength * (1 + age), 0)
				end
			end
		end
	end))
	janitor:Add(script.Destroying:Connect(function()
		janitor:Destroy()
	end))
end

function ShotFx.impact(position: Vector3, normal: Vector3)
	if #pool == 0 then
		build()
	end
	index = index % art.ImpactPoolSize + 1
	local slot = pool[index]
	slot.frame = CFrame.lookAt(position + normal * art.ImpactWidth, position + normal)
	slot.born = os.clock()
	local now = os.clock()
	if now - lastSoundAt >= art.ImpactSoundGap then
		lastSoundAt = now
		SoundPlayer.playAt(feedback.ImpactSound, position, feedback.ShotVolume, feedback.ShotRollOff * 4)
	end
end

-- The map point and surface a ray from `origin` along `direction` hits, for the local player's own shots (nothing if it
-- reaches no wall). Characters are skipped, as the server's shot is.
local mapParams = RaycastParams.new()
mapParams.CollisionGroup = GameConfig.Rig.CollisionGroup
mapParams.RespectCanCollide = true

function ShotFx.mapHit(origin: Vector3, direction: Vector3): (Vector3?, Vector3?)
	local result = workspace:Raycast(origin, direction * GameConfig.Combat.MaxShotStuds, mapParams)
	if result then
		return result.Position, result.Normal
	end
	return nil, nil
end

return ShotFx
