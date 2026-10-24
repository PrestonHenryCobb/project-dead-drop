--!strict
-- What a bullet does where it lands on the map (STEP8): a puff of dust and a thud. Pooled, client only. Hits on people
-- have no effect here; the shooter's hitmarker comes from the server (spec 8.4).
--
--   ShotFx.impact(position, normal)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local SoundPlayer = require(script.Parent.SoundPlayer)

local ShotFx = {}

local feedback = GameConfig.Combat.Feedback
local POOL_SIZE = 16
local DUST_COLOR = Color3.fromRGB(170, 165, 155)
local MIN_SOUND_GAP = 0.08 -- seconds between impact thuds, so a stream of bullets is not a roar
local DUST_SPEED = NumberRange.new(6, 12)
local DUST_SIZE = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0) })
local DUST_SPREAD_DEGREES = 40

local pool: { { part: Part, dust: ParticleEmitter } } = {}
local index = 0
local lastSoundAt = 0

local function build()
	local folder = Instance.new("Folder")
	folder.Name = "CombatImpacts"
	folder.Parent = workspace.CurrentCamera
	for _ = 1, POOL_SIZE do
		local part = Instance.new("Part")
		part.Name = "Impact"
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Transparency = 1
		part.Size = Vector3.one * 0.2
		part.Parent = folder
		local dust = Instance.new("ParticleEmitter")
		dust.Enabled = false
		dust.Rate = 0
		dust.Lifetime = NumberRange.new(feedback.ImpactSeconds * 0.5, feedback.ImpactSeconds)
		dust.Speed = DUST_SPEED
		dust.SpreadAngle = Vector2.new(DUST_SPREAD_DEGREES, DUST_SPREAD_DEGREES)
		dust.EmissionDirection = Enum.NormalId.Front
		dust.Size = DUST_SIZE
		dust.Color = ColorSequence.new(DUST_COLOR)
		dust.Transparency = NumberSequence.new(0.2, 1)
		dust.Parent = part
		table.insert(pool, { part = part, dust = dust })
	end
end

function ShotFx.impact(position: Vector3, normal: Vector3)
	if #pool == 0 then
		build()
	end
	index = index % POOL_SIZE + 1
	local slot = pool[index]
	slot.part.CFrame = CFrame.lookAt(position, position + normal)
	slot.dust:Emit(feedback.ImpactParticles)
	local now = os.clock()
	if now - lastSoundAt >= MIN_SOUND_GAP then
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
