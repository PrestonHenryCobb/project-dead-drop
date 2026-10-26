--!strict
-- Ticket menu-shell: what the menu knows about the player's team and agent select, kept between screens. The server
-- sends TeamRoster and PreDeployStateUpdated whenever they change, possibly before a screen is open, so they are cached
-- here and screens read the latest value and listen for the next.
--
--   LobbyState.start()                         MenuController calls this once
--   LobbyState.roster() -> { Player }          the player's own team, themself included
--   LobbyState.preDeploy() -> PreDeployState?  the latest agent select state (Active false once it has ended)
--   local stop = LobbyState.onChanged(function() ... end)   either changed; call stop() to disconnect

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local RemoteController = require(script.Parent.Parent:WaitForChild("Controllers"):WaitForChild("RemoteController"))

local LobbyState = {}

local roster: { Player } = { Players.LocalPlayer }
local preDeploy: Types.PreDeployState? = nil
local listeners: { [number]: () -> () } = {}
local nextId = 0
local started = false

local function changed()
	for _, listener in listeners do
		task.spawn(listener)
	end
end

function LobbyState.start()
	if started then
		return
	end
	started = true
	RemoteController.connect("TeamRoster", function(info: Types.TeamRosterInfo)
		roster = info.Members
		changed()
	end)
	RemoteController.connect("PreDeployStateUpdated", function(state: Types.PreDeployState)
		preDeploy = state
		changed()
	end)
end

function LobbyState.roster(): { Player }
	return roster
end

function LobbyState.preDeploy(): Types.PreDeployState?
	return preDeploy
end

function LobbyState.onChanged(listener: () -> ()): () -> ()
	nextId += 1
	local id = nextId
	listeners[id] = listener
	return function()
		listeners[id] = nil
	end
end

return LobbyState
