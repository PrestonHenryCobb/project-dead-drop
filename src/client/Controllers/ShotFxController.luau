--!strict
-- Other people's shots, as far as you can hear them (spec 23): the sound at the muzzle and the puff where a bullet hit the
-- map. The server sends ShotHeard only to players within earshot, 25 studs for a suppressed weapon and 120 otherwise.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Types = require(Shared:WaitForChild("Types"))
local WeaponDefs = require(Shared:WaitForChild("Defs"):WaitForChild("WeaponDefs"))
local Combat = script.Parent.Parent:WaitForChild("Combat")
local ShotFx = require(Combat:WaitForChild("ShotFx"))
local ShotVisuals = require(Combat:WaitForChild("ShotVisuals"))
local SoundPlayer = require(Combat:WaitForChild("SoundPlayer"))
local RemoteController = require(script.Parent.RemoteController)

local ShotFxController = {}

local feedback = GameConfig.Combat.Feedback
type HeardShot = { weaponId: string, origin: Vector3, at: number }
local heardShots: { HeardShot } = {}
local heardIndex = 0

local function firstPellet(def: Types.WeaponDef, origin: Vector3): boolean
	if not def.Pellets then
		return true
	end
	local now = os.clock()
	local fastest = math.max(def.RPM, def.AimedRPM or def.RPM)
	local window =
		math.max(GameConfig.Combat.FireRateToleranceSeconds, 60 / fastest - GameConfig.Combat.FireRateToleranceSeconds)
	for _, shot in heardShots do
		if shot.weaponId == def.Id and shot.origin == origin and now - shot.at < window then
			return false
		end
	end
	heardIndex = heardIndex % #heardShots + 1
	local shot = heardShots[heardIndex]
	shot.weaponId, shot.origin, shot.at = def.Id, origin, now
	return true
end

local function onShotHeard(info: Types.ShotInfo)
	local def = WeaponDefs.get(info.WeaponId)
	if not def then
		return
	end
	local range = def.HearStuds
		or (if def.Quiet then GameConfig.Audio.SuppressedWeaponRadius else GameConfig.Audio.DefaultWeaponRadius)
	local first = firstPellet(def, info.Origin)
	if first then
		SoundPlayer.playAt(def.Sounds.Fire, info.Origin, feedback.ShotVolume, range)
	end
	-- SPEC-QUESTION: should tracers be visible farther away than shots are heard? ShotHeard currently limits both.
	ShotVisuals.fire(def, ShotVisuals.remoteMuzzle(info.Origin, info.Hit), info.Hit, first)
	if not info.Struck then
		local direction = info.Hit - info.Origin
		if direction.Magnitude > 0 then
			-- The surface faces back toward the shooter, which is as good as its true normal for a puff of dust.
			ShotFx.impact(info.Hit, -direction.Unit)
		end
	end
end

function ShotFxController.Init() end

function ShotFxController.Start()
	-- ShotHeard currently sends each pellet separately. A bounded slot per possible shooter coalesces their sound/flash.
	for _ = 1, GameConfig.Match.MaxPlayers do
		table.insert(heardShots, { weaponId = "", origin = Vector3.zero, at = -math.huge })
	end
	ShotVisuals.start()
	SoundPlayer.preload({ feedback.ImpactSound })
	RemoteController.connect("ShotHeard", onShotHeard)
end

return ShotFxController
