--!strict
-- Ticket 14: the global alarm (spec 18.4), shared by every team.
--
--   * Level 0 Calm, 1 Alert, 2 Heightened, 3 Lockdown. Anything that notices a crime calls raise().
--   * The level falls by one every DecayIntervalSeconds with no new raise. Lockdown ends after LockdownSeconds and drops to
--     Level 2 (then decays like any level). A raise during Lockdown changes nothing.
--   * The alarm only runs while a match does: SecurityService arms it with the match phase and clears it between matches.
--
-- What each level does is done by the systems it touches, which ask here: Security witnesses see further from Alert
-- (CoverService, detectionMult), cameras sweep faster and keycard doors seal in Lockdown (CameraService, DoorService).
-- Extra guards at Heightened, Security walking at 14 and shooting Exposed agents in Lockdown are the guards' (GuardService).
--
--   AlarmService.level() -> number
--   AlarmService.raise(amount, reason)
--   AlarmService.detectionMult() -> number      Security's sight range multiplier
--   AlarmService.sweepMult() -> number          how much faster cameras sweep
--   AlarmService.onChange(listener)             listener(level, previous)
--   AlarmService.setArmed(armed)                raises count only while armed
--   AlarmService.reset()                        back to Calm

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enums = require(Shared:WaitForChild("Enums"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local RemoteService = require(script.Parent.RemoteService)

local AlarmService = {}

local config = GameConfig.Security.Alarm
local currentLevel = 0
local armed = false
local lastRaiseAt = 0 -- os.clock() of the last raise or decay step
local lockdownEndsAt = 0
local listeners: { (number, number) -> () } = {}

function AlarmService.level(): number
	return currentLevel
end

function AlarmService.detectionMult(): number
	return if currentLevel >= Enums.AlarmLevel.Alert then config.AlertDetectionMult else 1
end

function AlarmService.sweepMult(): number
	return if currentLevel >= Enums.AlarmLevel.Lockdown then config.LockdownCameraSweepMult else 1
end

function AlarmService.onChange(listener: (number, number) -> ())
	table.insert(listeners, listener)
end

local function set(level: number)
	local previous = currentLevel
	if level == previous then
		return
	end
	currentLevel = level
	lastRaiseAt = os.clock()
	lockdownEndsAt = if level >= Enums.AlarmLevel.Lockdown then lastRaiseAt + config.LockdownSeconds else 0
	RemoteService.fireAllClients("AlarmLevel", level)
	if GameConfig.Debug.PrintEvents then
		print(`[Alarm] level {previous} -> {level}`)
	end
	for _, listener in listeners do
		listener(level, previous)
	end
end

function AlarmService.raise(amount: number, reason: string)
	if amount <= 0 or not armed then
		return
	end
	if GameConfig.Debug.PrintEvents then
		print(`[Alarm] raised by {amount}: {reason}`)
	end
	if currentLevel >= config.MaxLevel then
		return
	end
	set(math.min(currentLevel + amount, config.MaxLevel))
end

function AlarmService.setArmed(value: boolean)
	armed = value
end

function AlarmService.reset()
	set(0)
end

local function step()
	if currentLevel == 0 then
		return
	end
	local now = os.clock()
	if currentLevel >= config.MaxLevel then
		if now >= lockdownEndsAt then
			set(config.MaxLevel - 1)
		end
	elseif now - lastRaiseAt >= config.DecayIntervalSeconds then
		set(currentLevel - 1)
	end
end

function AlarmService.Init() end

function AlarmService.Start()
	Players.PlayerAdded:Connect(function(player)
		RemoteService.fireClient("AlarmLevel", player, currentLevel)
	end)
	local interval = 1 / config.TickHz
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= interval then
			elapsed = 0
			step()
		end
	end)
end

return AlarmService
