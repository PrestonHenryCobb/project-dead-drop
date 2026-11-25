--!strict
-- Loading screens for the moves between places (owner 2026-11-25): a themed screen from the moment a match is found until the new place takes over, and
-- another from the end of a match's results until the player is back in the lobby place. The screen at game start is src/first/BootLoading.
-- A teleport that fails, or one that never comes, closes the screen so the player is never stuck behind it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Janitor = require(Shared:WaitForChild("Util"):WaitForChild("Janitor"))
local LoadingScreen = require(Shared:WaitForChild("Util"):WaitForChild("LoadingScreen"))
local Types = require(Shared:WaitForChild("Types"))
local RemoteController = require(script.Parent.RemoteController)

local LoadingController = {}

local janitor = Janitor.new()
local current: LoadingScreen.LoadingScreen? = nil
local generation = 0

local function hide()
	generation += 1
	if current then
		current.close()
		current = nil
	end
end

local function show(sceneId: string)
	hide()
	local screen = LoadingScreen.show(sceneId)
	current = screen
	-- Roblox shows its own screen once a teleport starts unless it is given one; this carries ours across.
	pcall(function()
		TeleportService:SetTeleportGui(screen.gui)
	end)
	local mine = generation
	task.delay(GameConfig.Loading.TransitionTimeoutSeconds, function()
		if generation == mine then
			hide()
		end
	end)
end

function LoadingController.Init() end

function LoadingController.Start()
	local matchmaking = GameConfig.Matchmaking
	if not matchmaking.Enabled then
		return
	end
	janitor:Add(RemoteController.connect("MatchmakingState", function(info: Types.MatchmakingStateInfo)
		if info.State == "Found" then
			show("ToMatch")
		elseif info.State == "Failed" or info.State == "ReturnFailed" or info.State == "Idle" then
			hide()
		end
	end))
	if game.PlaceId == matchmaking.MatchPlaceId then
		-- The server sends everyone to the lobby place when the results screen ends, which is the match's next Lobby phase after Results.
		local sawResults = false
		janitor:Add(RemoteController.connect("PhaseChanged", function(phase: string)
			if phase == "Results" then
				sawResults = true
			elseif phase == "Lobby" and sawResults then
				show("ToLobby")
			end
		end))
	end
	janitor:Add(TeleportService.TeleportInitFailed:Connect(hide))
	janitor:Add(script.Destroying:Connect(function()
		janitor:Destroy()
	end))
end

return LoadingController
