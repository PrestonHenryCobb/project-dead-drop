--!strict
-- Ticket auto-recover: the Auto re-cover option on the client. H turns it on or off (until the settings menu has it); the server
-- says whether it is on and when a re-cover ring runs. AutoRecoverController.state() gives the last message for the HUD: a ring
-- (Active, Seconds from when it was received) before the disguise goes back on by itself.
--
--   AutoRecoverController.state() -> Types.AutoRecoverInfo?, number    the last message, and when it arrived (os.clock())

local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Janitor = require(Shared:WaitForChild("Util"):WaitForChild("Janitor"))
local Types = require(Shared:WaitForChild("Types"))
local RemoteController = require(script.Parent.RemoteController)

local AutoRecoverController = {}

local ACTION = "CoverStoryToggleAutoRecover"

local current: Types.AutoRecoverInfo? = nil
local receivedAt = 0

function AutoRecoverController.state(): (Types.AutoRecoverInfo?, number)
	return current, receivedAt
end

local function onToggle(_: string, state: Enum.UserInputState): Enum.ContextActionResult
	if state == Enum.UserInputState.Begin and UserInputService:GetFocusedTextBox() == nil then
		local info = current
		RemoteController.fire("RequestAutoRecover", not (info == nil or info.Enabled))
	end
	return Enum.ContextActionResult.Pass
end

function AutoRecoverController.Init() end

function AutoRecoverController.Start()
	local janitor = Janitor.new()
	ContextActionService:BindAction(ACTION, onToggle, false, GameConfig.Controls.ToggleAutoRecover)
	janitor:Add(function()
		ContextActionService:UnbindAction(ACTION)
		current = nil
	end)
	janitor:Add(RemoteController.connect("AutoRecoverState", function(info: Types.AutoRecoverInfo)
		current = info
		receivedAt = os.clock()
	end))
	janitor:Add(script.Destroying:Connect(function()
		janitor:Destroy()
	end))
end

return AutoRecoverController
