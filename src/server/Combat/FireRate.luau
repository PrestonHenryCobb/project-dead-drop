--!strict
-- How soon a weapon may fire again (spec 13, ticket 8.5). Besides the plain RPM, a weapon can fire in bursts (Count
-- shots at RPM, then a pause), spin up (held fire climbs from StartRPM to RPM), or slow down while aimed (AimedRPM).
-- CombatService keeps one Streak per player and asks for the gap after each shot; the client follows the same rules.
--
--   FireRate.newStreak() -> Streak
--   FireRate.gapAfterShot(def, streak, now, aiming) -> number   seconds until the next shot; call once per shot fired

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Types = require(Shared:WaitForChild("Types"))

export type Streak = {
	startedAt: number, -- when the current run of held fire began
	lastShotAt: number,
	burstShots: number, -- shots fired in the current burst
}

local FireRate = {}

local config = GameConfig.Combat

function FireRate.newStreak(): Streak
	return { startedAt = -math.huge, lastShotAt = -math.huge, burstShots = 0 }
end

-- The rate this shot was fired at: aimed rate if aiming, and for a spin-up weapon, how far it has spun up.
local function rpmAt(def: Types.WeaponDef, streak: Streak, now: number, aiming: boolean): number
	local rpm = if aiming and def.AimedRPM then def.AimedRPM else def.RPM
	local spin = def.SpinUp
	if spin then
		local slowestGap = 60 / spin.StartRPM
		if now - streak.lastShotAt > slowestGap * config.SpinUpGapMult then
			streak.startedAt = now -- the trigger was let go: start spinning up again
		end
		local along = math.clamp((now - streak.startedAt) / spin.Seconds, 0, 1)
		rpm = spin.StartRPM + (rpm - spin.StartRPM) * along
	end
	return rpm
end

function FireRate.gapAfterShot(def: Types.WeaponDef, streak: Streak, now: number, aiming: boolean): number
	local gap = 60 / rpmAt(def, streak, now, aiming)
	local burst = def.Burst
	if burst then
		if now - streak.lastShotAt > math.max(gap, burst.DelaySeconds) then
			streak.burstShots = 0 -- a fresh burst
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

return FireRate
