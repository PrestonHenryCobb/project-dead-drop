--!strict
-- Paste into Studio's SERVER Command Bar during a playtest. Requires the real server and client cadence modules.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local WeaponDefs = require(ReplicatedStorage.Shared.Defs.WeaponDefs)
local Server = require(ServerScriptService.Server.Combat.FireRate)
local Client = require(StarterPlayer.StarterPlayerScripts.Client.Combat.WeaponCadence)

local base = WeaponDefs.get("GuiseSMG")
assert(base, "GuiseSMG must exist for cadence fixtures")
local burst = table.clone(base)
burst.RPM = 600
burst.Burst = { Count = 3, DelaySeconds = 0.35 }
local spin = table.clone(base)
spin.RPM = 750
spin.SpinUp = { StartRPM = 500, Seconds = 1 }
local akimbo = table.clone(base)
akimbo.RPM, akimbo.AimedRPM = 1100, 550

local checks = 0
local epsilon = 1e-9
for _, def in { base, burst, spin, akimbo } do
	local serverStreak, clientStreak = Server.newStreak(), Client.newStreak()
	local now = 0
	for index = 1, 150 do
		local aiming = index % 8 >= 4
		local a = Server.gapAfterShot(def, serverStreak, now, aiming)
		local b = Client.gapAfterShot(def, clientStreak, now, aiming)
		assert(math.abs(a - b) < epsilon, `Cadence differs at shot {index}`)
		assert(serverStreak.burstShots == clientStreak.burstShots, "Burst counter differs")
		assert(serverStreak.startedAt == clientStreak.startedAt, "Spin start differs")
		checks += 3
		now += if index % 25 == 0 then 2 else a
	end
end

local streak = Client.newStreak()
local burstStreak = Client.newStreak()
assert(math.abs(Client.gapAfterShot(burst, burstStreak, 0, false) - 0.1) < epsilon, "First burst shot gap wrong")
assert(math.abs(Client.gapAfterShot(burst, burstStreak, 0.1, false) - 0.1) < epsilon, "Second burst shot gap wrong")
assert(math.abs(Client.gapAfterShot(burst, burstStreak, 0.2, false) - 0.35) < epsilon, "Burst end pause missing")
assert(math.abs(Client.gapAfterShot(burst, burstStreak, 1.2, false) - 0.1) < epsilon, "Pause did not reset burst")
assert(math.abs(Client.gapAfterShot(spin, streak, 0, false) - 60 / 500) < epsilon, "Spin should start at 500 RPM")
for index = 1, 10 do
	local gap = Client.gapAfterShot(spin, streak, index / 10, false)
	if index == 10 then
		assert(math.abs(gap - 60 / 750) < epsilon, "Spin should reach 750 RPM after one second")
	end
end
assert(math.abs(Client.gapAfterShot(spin, streak, 3, false) - 60 / 500) < epsilon, "A pause should restart spin-up")
assert(math.abs(Client.gapAfterShot(akimbo, Client.newStreak(), 0, true) - 60 / 550) < epsilon, "Aimed RPM ignored")
print(
	`Cadence parity passed: {checks} comparisons plus spin-up/restart/aimed-rate assertions. Test trigger/input behavior separately.`
)
