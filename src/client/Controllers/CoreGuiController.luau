--!strict
-- Hides the default Roblox UI that would reveal who is a player (spec 8.2, CLAUDE.md rule 4):
-- the player list (usernames) and the health bar. Nametags and chat bubbles are turned off on the server.

local StarterGui = game:GetService("StarterGui")

local CoreGuiController = {}

function CoreGuiController.Init() end

function CoreGuiController.Start()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
end

return CoreGuiController
