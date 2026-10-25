--!strict
-- Step 8B.4: a single fire/aim binding for whichever item is held. Only the weapon exists today; future gadgets
-- supply the same handlers when equipped. Switching cancels held inputs, so a held trigger never leaks to a new item.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Janitor = require(Shared:WaitForChild("Util"):WaitForChild("Janitor"))

export type Item = {
	fire: (Enum.UserInputState) -> (),
	aim: (Enum.UserInputState) -> (),
	setHeld: (boolean) -> (),
}

local HeldItemController = {}
local janitor = Janitor.new()
local active: Item? = nil
local weapon: Item? = nil

local function cancelInputs()
	local item = active
	if item then
		item.fire(Enum.UserInputState.Cancel)
		item.aim(Enum.UserInputState.Cancel)
	end
end

function HeldItemController.equip(item: Item)
	if active == item then
		return
	end
	cancelInputs()
	if active then
		active.setHeld(false)
	end
	active = item
	item.setHeld(true)
end

function HeldItemController.registerWeapon(item: Item)
	assert(weapon == nil, "Weapon input registered twice")
	weapon = item
	HeldItemController.equip(item)
end

function HeldItemController.equipWeapon()
	local item = weapon
	if item then
		HeldItemController.equip(item)
	end
end

local function onFire(_: string, state: Enum.UserInputState): Enum.ContextActionResult
	if state == Enum.UserInputState.Begin and UserInputService:GetFocusedTextBox() then
		return Enum.ContextActionResult.Pass
	end
	if active and state ~= Enum.UserInputState.Change then
		active.fire(state)
	end
	return Enum.ContextActionResult.Sink
end

local function onAim(_: string, state: Enum.UserInputState): Enum.ContextActionResult
	if state == Enum.UserInputState.Begin and UserInputService:GetFocusedTextBox() then
		return Enum.ContextActionResult.Pass
	end
	if active and state ~= Enum.UserInputState.Change then
		active.aim(state)
	end
	return Enum.ContextActionResult.Sink
end

function HeldItemController.Init() end

function HeldItemController.Start()
	local controls = GameConfig.Controls
	local priority = GameConfig.Combat.InputPriority
	ContextActionService:BindActionAtPriority("HeldItemFire", onFire, false, priority, controls.Fire, controls.FirePad)
	ContextActionService:BindActionAtPriority("HeldItemAim", onAim, false, priority, controls.Aim, controls.AimPad)
	janitor:Add(function()
		cancelInputs()
		ContextActionService:UnbindAction("HeldItemFire")
		ContextActionService:UnbindAction("HeldItemAim")
	end)
	janitor:Add(UserInputService.WindowFocusReleased:Connect(cancelInputs))
	janitor:Add(UserInputService.TextBoxFocused:Connect(cancelInputs))
	janitor:Add(Players.LocalPlayer.CharacterRemoving:Connect(cancelInputs))
	janitor:Add(Players.LocalPlayer.CharacterAdded:Connect(HeldItemController.equipWeapon))
	janitor:Add(script.Destroying:Connect(function()
		janitor:Destroy()
	end))
end

return HeldItemController
