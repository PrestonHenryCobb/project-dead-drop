--!strict
-- Persistent owner-only queue presentation. Searching/Found/Idle come from the server.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.GameConfig)
local Types = require(Shared.Types)
local Janitor = require(Shared.Util.Janitor)
local Remote = require(script.Parent.RemoteController)
local Feedback = require(script.Parent.Parent.Menu.RequestFeedback)
local MatchmakingController = {}
local janitor = Janitor.new()
local current: Types.MatchmakingStateInfo = { State = "Idle" }
local pending = false
local operation: string? = nil
local notice = ""
local listeners: { [number]: () -> () } = {}
local nextListener = 0
local alive = true
local reasons: { [string]: string } = {
	NotAvailable = "Matchmaking is not available in this session.",
	UnknownMode = "Choose an available match mode.",
	AlreadySearching = "A search is already running.",
	NoAgent = "Claim an agent and equip a loadout first.",
	QueueUnavailable = "The queue is unavailable. Try again shortly.",
	NoMatchFound = "No match was found. You can search again.",
	NotSearching = "There is no active search to cancel.",
}
local function changed()
	for _, listener in listeners do
		listener()
	end
end
function MatchmakingController.available(): boolean
	return GameConfig.Matchmaking.Enabled and game.PlaceId == GameConfig.Matchmaking.LobbyPlaceId
end
function MatchmakingController.state(): Types.MatchmakingStateInfo
	return table.clone(current)
end
function MatchmakingController.busy(): boolean
	return pending
end
function MatchmakingController.cancelling(): boolean
	return pending and operation == "RequestCancelFindMatch"
end
function MatchmakingController.notice(): string
	return notice
end
function MatchmakingController.onChanged(listener: () -> ())
	nextListener += 1
	local id = nextListener
	listeners[id] = listener
	return function()
		listeners[id] = nil
	end
end
local function request(name: string, mode: Types.QueueMode?, loadout: Types.LoadoutRequest?)
	if pending or not MatchmakingController.available() then
		return
	end
	pending, notice = true, ""
	operation = name
	changed()
	local thread = task.spawn(function()
		local connected, accepted, reason = pcall(function()
			if loadout then
				local saved, why = Remote.invoke("RequestEquipLoadout", loadout)
				if not saved then
					return false, Feedback.declined(why)
				end
			end
			if mode then
				return Remote.invoke(name, mode)
			end
			return Remote.invoke(name)
		end)
		if not alive then
			return
		end
		pending = false
		operation = nil
		if not connected then
			notice = "Connection unavailable. Check the queue status before trying again."
		elseif not accepted then
			notice = reasons[reason]
				or (if loadout and type(reason) == "string" then reason else "Matchmaking failed. Try again.")
		end
		changed()
	end)
	janitor:Add(function()
		if coroutine.status(thread) ~= "dead" and thread ~= coroutine.running() then
			task.cancel(thread)
		end
	end)
end
function MatchmakingController.find(mode: Types.QueueMode, loadout: Types.LoadoutRequest?)
	if current.State ~= "Searching" and current.State ~= "Found" then
		request("RequestFindMatch", mode, loadout)
	end
end
function MatchmakingController.cancel()
	if current.State == "Searching" then
		request("RequestCancelFindMatch", nil)
	end
end
function MatchmakingController.Init() end
function MatchmakingController.Start()
	janitor:Add(Remote.connect("MatchmakingState", function(info: Types.MatchmakingStateInfo)
		current = table.clone(info)
		notice = if info.State == "Failed" then reasons[info.Reason or ""] or "Matchmaking failed. Try again." else ""
		changed()
	end))
	janitor:Add(script.Destroying:Connect(function()
		alive = false
		table.clear(listeners)
		janitor:Destroy()
	end))
end
return MatchmakingController
