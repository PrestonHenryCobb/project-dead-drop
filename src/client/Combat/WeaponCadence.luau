--!strict
-- Ticket 8.5-client-rules: prediction counterpart of server/Combat/FireRate. Keep formulas identical.
-- tools/CheckWeaponCadence.luau compares both real modules in Studio's Server Command Bar.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Types = require(Shared:WaitForChild("Types"))

export type Streak = { startedAt: number, lastShotAt: number, burstShots: number }
local WeaponCadence = {}

function WeaponCadence.newStreak(): Streak
	return { startedAt = -math.huge, lastShotAt = -math.huge, burstShots = 0 }
end

local function rpmAt(def: Types.WeaponDef, streak: Streak, now: number, aiming: boolean): number
	local rpm = if aiming and def.AimedRPM then def.AimedRPM else def.RPM
	local spin = def.SpinUp
	if spin then
		local slowestGap = 60 / spin.StartRPM
		if now - streak.lastShotAt > slowestGap * GameConfig.Combat.SpinUpGapMult then
			streak.startedAt = now
		end
		local along = math.clamp((now - streak.startedAt) / spin.Seconds, 0, 1)
		rpm = spin.StartRPM + (rpm - spin.StartRPM) * along
	end
	return rpm
end

function WeaponCadence.gapAfterShot(def: Types.WeaponDef, streak: Streak, now: number, aiming: boolean): number
	local gap = 60 / rpmAt(def, streak, now, aiming)
	local burst = def.Burst
	if burst then
		if now - streak.lastShotAt > math.max(gap, burst.DelaySeconds) then
			streak.burstShots = 0
		end
		streak.burstShots += 1
		if streak.burstShots >= burst.Count then
			streak.burstShots = 0
			gap = math.max(gap, burst.DelaySeconds)
		end
	end
	streak.lastShotAt = now
	return gap
end

return WeaponCadence
