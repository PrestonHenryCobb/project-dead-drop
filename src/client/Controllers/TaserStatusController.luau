--!strict
-- Ticket 8.5c-client: owner-only presentation of confirmed taser hits. Movement and action refusals remain server-owned.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local WeaponDefs = require(Shared.Defs.WeaponDefs)
local Janitor = require(Shared.Util.Janitor)
local RemoteController = require(script.Parent.RemoteController)
local TaserStatusController = {}
local lockedUntil = 0
local slowedUntil = 0

function TaserStatusController.remaining(): number
	return math.max(0, lockedUntil - os.clock())
end

function TaserStatusController.slowed(): boolean
	return os.clock() < slowedUntil
end

local function clear()
	lockedUntil, slowedUntil = 0, 0
end

function TaserStatusController.Init() end

function TaserStatusController.Start()
	local janitor = Janitor.new()
	janitor:Add(RemoteController.connect("CombatStatus", function(info: Types.CombatStatusInfo)
		if info.Kind ~= "Taser" then
			return
		end
		local def = WeaponDefs.get("LatticeTaser")
		local taser = def and def.Taser
		if not taser then
			return
		end
		local now = os.clock()
		-- The event carries the slow time; lock duration comes from the same registered definition as the server.
		lockedUntil = math.max(lockedUntil, now + taser.LockoutSeconds)
		slowedUntil = math.max(slowedUntil, now + info.Seconds)
	end))
	janitor:Add(RemoteController.connect("PhaseChanged", function(phase: Types.Phase)
		if phase == "Lobby" or phase == "Insertion" or phase == "Results" then
			clear()
		end
	end))
	janitor:Add(RemoteController.connect("Eliminated", clear))
	janitor:Add(Players.LocalPlayer.CharacterAdded:Connect(clear))
	janitor:Add(Players.LocalPlayer.CharacterRemoving:Connect(clear))
	janitor:Add(clear)
	janitor:Add(script.Destroying:Connect(function()
		janitor:Destroy()
	end))
end

return TaserStatusController
