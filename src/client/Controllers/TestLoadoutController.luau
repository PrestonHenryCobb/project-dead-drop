--!strict
-- Ticket studio-test-loadout: owner-only test requests; no progression, rig metadata or public kit markers.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.GameConfig)
local Janitor = require(Shared.Util.Janitor)
local RemoteController = require(script.Parent.RemoteController)
local TestLoadoutController = {}
local janitor = Janitor.new()

function TestLoadoutController.Init() end

function TestLoadoutController.cycle(action: string): boolean
	if not RunService:IsStudio() or UserInputService:GetFocusedTextBox() then
		return false
	end
	if action ~= "Agent" and action ~= "Weapon" and action ~= "All" then
		return false
	end
	RemoteController.fire("RequestTestLoadout", action)
	return true
end

function TestLoadoutController.Start()
	if not RunService:IsStudio() then
		return
	end
	local config = GameConfig.Debug.TestLoadout
	local function bind(name: string, action: string, key: Enum.KeyCode)
		ContextActionService:BindActionAtPriority(name, function(_: string, state: Enum.UserInputState)
			if UserInputService:GetFocusedTextBox() then
				return Enum.ContextActionResult.Pass
			end
			if state == Enum.UserInputState.Begin then
				TestLoadoutController.cycle(action)
			end
			return Enum.ContextActionResult.Sink
		end, false, GameConfig.Combat.InputPriority, key)
		janitor:Add(function()
			ContextActionService:UnbindAction(name)
		end)
	end
	bind("StudioCycleAgent", "All", config.AgentKey)
	bind("StudioCycleWeapon", "Weapon", config.WeaponKey)
	local function sync()
		RemoteController.fire("RequestTestLoadout", "Sync")
	end
	janitor:Add(Players.LocalPlayer.CharacterAdded:Connect(sync))
	sync()
	janitor:Add(script.Destroying:Connect(function()
		janitor:Destroy()
	end))
end

return TestLoadoutController
