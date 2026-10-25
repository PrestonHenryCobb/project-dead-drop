--!strict
-- Hold-to-interact (spec 24: Interact is held). A client sends RequestInteract(kind, target) when the key goes down and
-- RequestInteractCancel when it comes up; the server times the hold, re-checks that it is still allowed at
-- GameConfig.Interact.CheckHz, and only then does the thing. Each system registers the kinds it handles: Step 9 the
-- downed bodies ("Body"), later intel, doors and caches.
--
-- The holder is told when a hold begins and ends (InteractState) for the HUD. Nothing else is told.
--
--   InteractService.register(kind, begin)   begin(player, target) -> Interaction?   nil refuses the request
--   InteractService.cancel(player)          ends any hold the player has going (going down, for example)
--   InteractService.isBusy(player) -> boolean

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Types = require(Shared:WaitForChild("Types"))
local RemoteService = require(script.Parent.RemoteService)

export type Interaction = {
	label: string, -- what it does, for the HUD ("Revive", "Execute")
	seconds: number,
	stillValid: () -> boolean, -- checked while the hold runs; false cancels it
	complete: () -> (),
}

type Hold = { interaction: Interaction, endsAt: number }

local InteractService = {}

local config = GameConfig.Interact
local handlers: { [string]: (Player, string) -> Interaction? } = {}
local holds: { [Player]: Hold } = {}

function InteractService.register(kind: string, begin: (Player, string) -> Interaction?)
	assert(not handlers[kind], `Interaction kind {kind} is registered twice`)
	handlers[kind] = begin
end

function InteractService.isBusy(player: Player): boolean
	return holds[player] ~= nil
end

local function tell(player: Player, interaction: Interaction, active: boolean)
	local info: Types.InteractStateInfo = { Kind = interaction.label, Seconds = interaction.seconds, Active = active }
	RemoteService.fireClient("InteractState", player, info)
end

function InteractService.cancel(player: Player)
	local hold = holds[player]
	if hold then
		holds[player] = nil
		tell(player, hold.interaction, false)
	end
end

local function onRequest(player: Player, kind: unknown, target: unknown)
	if type(kind) ~= "string" or type(target) ~= "string" or #target > config.MaxTargetLength then
		return
	end
	local begin = handlers[kind]
	if not begin or holds[player] then
		return
	end
	local interaction = begin(player, target)
	if not interaction then
		return
	end
	holds[player] = { interaction = interaction, endsAt = os.clock() + interaction.seconds }
	tell(player, interaction, true)
end

local function check()
	local now = os.clock()
	for player, hold in holds do
		if not hold.interaction.stillValid() then
			InteractService.cancel(player)
		elseif now >= hold.endsAt then
			holds[player] = nil
			tell(player, hold.interaction, false)
			hold.interaction.complete()
		end
	end
end

function InteractService.Init() end

function InteractService.Start()
	RemoteService.onRequest("RequestInteract", onRequest)
	RemoteService.onRequest("RequestInteractCancel", function(player: Player)
		InteractService.cancel(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		holds[player] = nil
	end)
	local interval = 1 / config.CheckHz
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= interval then
			elapsed = 0
			check()
		end
	end)
end

return InteractService
