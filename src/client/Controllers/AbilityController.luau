--!strict
-- Ticket 16: the agent's ability key (spec 15, Q). A press asks the server, which holds the cooldown and decides whether the
-- ability can be used right now. The cooldown the server reports is kept here for the HUD (AbilityController.cooldown).

local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Janitor = require(Shared:WaitForChild("Util"):WaitForChild("Janitor"))
local Types = require(Shared:WaitForChild("Types"))
local RemoteController = require(script.Parent.RemoteController)

local AbilityController = {}

local controls = GameConfig.Controls
local ACTION = "CoverStoryAbility"

local current: Types.AbilityCooldownInfo? = nil

-- The ability's name, full cooldown and when it is ready (server time), or nil before the first match.
function AbilityController.cooldown(): Types.AbilityCooldownInfo?
	return current
end

local function onAbility(_: string, state: Enum.UserInputState): Enum.ContextActionResult
	if state == Enum.UserInputState.Begin and UserInputService:GetFocusedTextBox() == nil then
		RemoteController.fire("RequestAbility")
	end
	return Enum.ContextActionResult.Pass
end

function AbilityController.Init() end

function AbilityController.Start()
	local janitor = Janitor.new()
	ContextActionService:BindAction(ACTION, onAbility, false, controls.Ability, controls.AbilityPad)
	janitor:Add(function()
		ContextActionService:UnbindAction(ACTION)
		current = nil
	end)
	janitor:Add(RemoteController.connect("CooldownUpdate", function(info: Types.AbilityCooldownInfo)
		current = info
	end))
	janitor:Add(script.Destroying:Connect(function()
		janitor:Destroy()
	end))
end

return AbilityController
