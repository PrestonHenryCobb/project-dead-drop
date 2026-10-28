--!strict
-- Ticket 17: sub-gadgets on the client (docs/GADGETS_DRAFT.md). Keys 1, 2 and 3 ask the server to equip the weapon or a gadget
-- (the gamepad's d-pad right cycles them); the server answers with GadgetState, and only then does the held item change, so a
-- refused request never leaves the client holding something the server does not think it holds. While a gadget is held the
-- fire button deploys it and the aim button is its alternate use, through the same HeldItemController the weapon uses.
--
--   GadgetController.state() -> Types.GadgetStateInfo?    the gadgets, charges and what is held, for the HUD

local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Janitor = require(Shared:WaitForChild("Util"):WaitForChild("Janitor"))
local Types = require(Shared:WaitForChild("Types"))
local HeldItemController = require(script.Parent.HeldItemController)
local RemoteController = require(script.Parent.RemoteController)

local GadgetController = {}

local controls = GameConfig.Controls
local ACTION = "CoverStoryGadgetKeys"

local current: Types.GadgetStateInfo? = nil

function GadgetController.state(): Types.GadgetStateInfo?
	return current
end

-- What the fire and aim buttons do while a gadget is held.
local item: HeldItemController.Item = {
	fire = function(state: Enum.UserInputState)
		if state == Enum.UserInputState.Begin then
			local camera = workspace.CurrentCamera
			RemoteController.fire("RequestGadget", "Deploy", nil, if camera then camera.CFrame.LookVector else nil)
		end
	end,
	aim = function(state: Enum.UserInputState)
		if state == Enum.UserInputState.Begin then
			RemoteController.fire("RequestGadget", "Alternate")
		end
	end,
	setHeld = function() end,
}

local function onKey(_: string, state: Enum.UserInputState, input: InputObject): Enum.ContextActionResult
	if state ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	local info = current
	local slot: number
	if input.KeyCode == controls.Weapon then
		slot = 0
	elseif input.KeyCode == controls.Gadget1 then
		slot = 1
	elseif input.KeyCode == controls.Gadget2 then
		slot = 2
	elseif info then
		slot = (info.Held + 1) % (#info.Slots + 1) -- the pad cycles weapon, gadget 1, gadget 2
	else
		return Enum.ContextActionResult.Pass
	end
	RemoteController.fire("RequestGadget", "Equip", slot)
	return Enum.ContextActionResult.Pass
end

function GadgetController.Init() end

function GadgetController.Start()
	local janitor = Janitor.new()
	ContextActionService:BindActionAtPriority(
		ACTION,
		onKey,
		false,
		GameConfig.Combat.InputPriority,
		controls.Weapon,
		controls.Gadget1,
		controls.Gadget2,
		controls.GadgetNextPad
	)
	janitor:Add(function()
		ContextActionService:UnbindAction(ACTION)
		current = nil
	end)
	janitor:Add(RemoteController.connect("GadgetState", function(info: Types.GadgetStateInfo)
		current = info
		if info.Held ~= 0 then
			HeldItemController.equip(item)
		else
			HeldItemController.equipWeapon()
		end
	end))
	janitor:Add(script.Destroying:Connect(function()
		janitor:Destroy()
	end))
end

return GadgetController
