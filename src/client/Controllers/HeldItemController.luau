--!strict
-- Step 8B.4: a single fire/aim binding for whichever item is held. Only the weapon exists today; future gadgets
-- supply the same handlers when equipped. Switching cancels held inputs, so a held trigger never leaks to a new item.

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Janitor = require(Shared:WaitForChild("Util"):WaitForChild("Janitor"))
local Types = require(Shared.Types)
local RemoteController = require(script.Parent.RemoteController)

export type Item = {
	fire: (Enum.UserInputState) -> (),
	aim: (Enum.UserInputState) -> (),
	setHeld: (boolean) -> (),
}

local HeldItemController = {}
local janitor = Janitor.new()
local active: Item? = nil
local weapon: Item? = nil
local interfaces: { [Instance]: boolean } = {}
local interfaceOrder: { [Instance]: number } = {}
local behindInterfaces: { [Instance]: boolean } = {}
local nextInterfaceOrder = 0
local focused = true
local incapacitated = false
local extractionFrozen = false
local phase: Types.Phase? = nil

local function displayOrder(owner: Instance): number
	local screen = if owner:IsA("ScreenGui") then owner else owner:FindFirstAncestorOfClass("ScreenGui")
	return if screen then (screen :: ScreenGui).DisplayOrder else 0
end

function HeldItemController.isInputBlocked(except: Instance?): boolean
	local order = if except then interfaceOrder[except] else nil
	local background = except ~= nil and behindInterfaces[except] == true
	local display = if except then displayOrder(except) else 0
	for owner in interfaces do
		-- Match visual stacking first, then opening order within the same display layer.
		local ownerBackground = behindInterfaces[owner] == true
		local ownerDisplay = displayOrder(owner)
		if
			owner ~= except
			and (
				not order
				or (background and not ownerBackground)
				or (
					ownerBackground == background
					and (ownerDisplay > display or (ownerDisplay == display and interfaceOrder[owner] > order))
				)
			)
		then
			return true
		end
	end
	return not focused or GuiService.MenuIsOpen or UserInputService:GetFocusedTextBox() ~= nil
end

-- This is only an input gate; the server still validates every action. Unknown phase permits Studio direct-spawn mode.
function HeldItemController.canAct(except: Instance?): boolean
	if HeldItemController.isInputBlocked(except) or incapacitated or extractionFrozen then
		return false
	end
	if phase == "Lobby" or phase == "Insertion" or phase == "Results" then
		return false
	end
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return humanoid ~= nil
		and humanoid.Health > 0
		and root ~= nil
		and root:IsA("BasePart")
		and workspace.CurrentCamera ~= nil
end

local function cancelInputs()
	local item = active
	if item then
		item.fire(Enum.UserInputState.Cancel)
		item.aim(Enum.UserInputState.Cancel)
	end
end

-- Client UI owns its blocker and releases it on close/teardown. Remote views register behind dialogs even if their
-- delayed server acknowledgement arrives later. Cancelling never changes the server-confirmed item.
function HeldItemController.setInterfaceBlocked(owner: Instance, blocked: boolean, background: boolean?)
	if blocked and not interfaces[owner] then
		nextInterfaceOrder += 1
		interfaceOrder[owner] = nextInterfaceOrder
	elseif not blocked then
		interfaceOrder[owner] = nil
	end
	behindInterfaces[owner] = if blocked and background then true else nil
	interfaces[owner] = if blocked then true else nil
	if blocked then
		cancelInputs()
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

function HeldItemController.isWeaponHeld(): boolean
	return weapon ~= nil and active == weapon
end

function HeldItemController.unregisterWeapon(item: Item)
	if weapon ~= item then
		return
	end
	if active == item then
		cancelInputs()
		item.setHeld(false)
		active = nil
	end
	weapon = nil
end

local function onFire(_: string, state: Enum.UserInputState): Enum.ContextActionResult
	if not HeldItemController.canAct() then
		cancelInputs()
		return Enum.ContextActionResult.Pass
	end
	if active and state ~= Enum.UserInputState.Change then
		active.fire(state)
	end
	return Enum.ContextActionResult.Sink
end

local function onAim(_: string, state: Enum.UserInputState): Enum.ContextActionResult
	if not HeldItemController.canAct() then
		cancelInputs()
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
		table.clear(interfaces)
		table.clear(interfaceOrder)
		table.clear(behindInterfaces)
		nextInterfaceOrder = 0
		ContextActionService:UnbindAction("HeldItemFire")
		ContextActionService:UnbindAction("HeldItemAim")
	end)
	janitor:Add(UserInputService.WindowFocusReleased:Connect(function()
		focused = false
		cancelInputs()
	end))
	janitor:Add(UserInputService.WindowFocused:Connect(function()
		focused = true
	end))
	janitor:Add(GuiService.MenuOpened:Connect(cancelInputs))
	janitor:Add(UserInputService.TextBoxFocused:Connect(cancelInputs))
	janitor:Add(Players.LocalPlayer.CharacterRemoving:Connect(cancelInputs))
	janitor:Add(Players.LocalPlayer.CharacterAdded:Connect(function()
		incapacitated = false
		HeldItemController.equipWeapon()
	end))
	janitor:Add(RemoteController.connect("Downed", function()
		incapacitated = true
		cancelInputs()
	end))
	janitor:Add(RemoteController.connect("Eliminated", function()
		incapacitated = true
		cancelInputs()
	end))
	janitor:Add(RemoteController.connect("Revived", function()
		incapacitated = false
	end))
	janitor:Add(RemoteController.connect("PhaseChanged", function(value: Types.Phase)
		phase = value
		if value == "Lobby" or value == "Insertion" or value == "Results" then
			extractionFrozen = false
			cancelInputs()
		end
	end))
	janitor:Add(RemoteController.connect("ExtractionState", function(info: Types.ExtractionStateInfo)
		extractionFrozen = info.State == "Extracted"
		if extractionFrozen then
			cancelInputs()
		end
	end))
	janitor:Add(script.Destroying:Connect(function()
		janitor:Destroy()
	end))
end

return HeldItemController
