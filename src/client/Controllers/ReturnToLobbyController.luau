--!strict
-- When a match ends the server sends everyone back to the lobby place. If that teleport keeps failing it says so (MatchmakingState with
-- State "ReturnFailed") and this shows a Return to lobby button that asks the server to try again (RequestReturnToLobby).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Janitor = require(Shared:WaitForChild("Util"):WaitForChild("Janitor"))
local HudKit = require(Shared:WaitForChild("Util"):WaitForChild("HudKit"))
local HudTheme = require(Shared:WaitForChild("Util"):WaitForChild("HudTheme"))
local Types = require(Shared:WaitForChild("Types"))
local RemoteController = require(script.Parent.RemoteController)

local ReturnToLobbyController = {}

local janitor = Janitor.new()
local theme = HudTheme.get()

function ReturnToLobbyController.Init() end

function ReturnToLobbyController.Start()
	local gui = HudKit.screen("ReturnToLobby")
	gui.Enabled = false
	janitor:Add(gui)
	local button = Instance.new("TextButton")
	button.Name = "Return"
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	button.Position = UDim2.fromScale(0.5, 0.8)
	button.Size = UDim2.fromOffset(theme.ActionWidthPixels, theme.CaptionSize * 3)
	button.BackgroundColor3 = theme.PanelColor
	button.TextColor3 = theme.TextColor
	button.TextSize = theme.CaptionSize
	button.Font = Enum.Font.GothamBold
	button.Text = "COULD NOT RETURN TO LOBBY · CLICK TO TRY AGAIN"
	button.BorderSizePixel = 0
	button.Parent = gui
	janitor:Add(button.Activated:Connect(function()
		RemoteController.fire("RequestReturnToLobby")
	end))
	janitor:Add(RemoteController.connect("MatchmakingState", function(info: Types.MatchmakingStateInfo)
		gui.Enabled = info.State == "ReturnFailed"
	end))
	janitor:Add(script.Destroying:Connect(function()
		janitor:Destroy()
	end))
end

return ReturnToLobbyController
