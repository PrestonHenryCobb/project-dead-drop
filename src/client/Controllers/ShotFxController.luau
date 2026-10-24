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
local SoundPlayer = require(Combat:WaitForChild("SoundPlayer"))
local RemoteController = require(script.Parent.RemoteController)

local ShotFxController = {}

local feedback = GameConfig.Combat.Feedback

local function onShotHeard(info: Types.ShotInfo)
	local def = WeaponDefs.get(info.WeaponId)
	if not def then
		return
	end
	local range = if def.Quiet then GameConfig.Audio.SuppressedWeaponRadius else GameConfig.Audio.DefaultWeaponRadius
	SoundPlayer.playAt(def.Sounds.Fire, info.Origin, feedback.ShotVolume, range)
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
	SoundPlayer.preload({ feedback.ImpactSound })
	RemoteController.connect("ShotHeard", onShotHeard)
end

return ShotFxController
