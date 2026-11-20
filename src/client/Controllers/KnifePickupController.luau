--!strict
-- Observes server-created knife prompts; never sends a pickup request or changes a landed knife's name/parent.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Janitor = require(Shared.Util.Janitor)
local WeaponDefs = require(Shared.Defs.WeaponDefs)
local Hints = require(script.Parent.Parent.Combat.KnifePickupHints)
local WeaponController = require(script.Parent.WeaponController)
local HeldItemController = require(script.Parent.HeldItemController)
local KnifePickupController = {}
local janitor = Janitor.new()
local folderJanitor = Janitor.new()

function KnifePickupController.Init() end

function KnifePickupController.Start()
	local hints = Hints.new()
	janitor:Add(hints)
	janitor:Add(folderJanitor)
	local current: Instance? = nil
	local function update()
		local status = WeaponController.getStatus()
		local def = WeaponDefs.get(status.weaponId)
		hints.setAvailable(
			status.active
				and HeldItemController.canAct()
				and def ~= nil
				and def.Projectile ~= nil
				and def.Projectile.Kind == "Knife"
				and status.mag < def.MagSize
		)
	end
	local function attach(instance: Instance)
		if instance.Name ~= "LandedKnives" or not instance:IsA("Folder") or instance == current then
			return
		end
		folderJanitor:Cleanup()
		current = instance
		update()
		folderJanitor:Add(instance.DescendantAdded:Connect(hints.add))
		folderJanitor:Add(instance.DescendantRemoving:Connect(hints.remove))
		for _, child in instance:GetDescendants() do
			hints.add(child)
		end
		folderJanitor:Add(function()
			hints.Destroy()
			current = nil
		end)
	end
	janitor:Add(workspace.ChildAdded:Connect(attach))
	janitor:Add(workspace.ChildRemoved:Connect(function(instance)
		if instance == current then
			folderJanitor:Cleanup()
		end
	end))
	local existing = workspace:FindFirstChild("LandedKnives")
	if existing then
		attach(existing)
	end
	-- Availability is compared before touching prompts; no world scans occur each frame.
	janitor:Add(RunService.Heartbeat:Connect(update))
	janitor:Add(script.Destroying:Connect(function()
		janitor:Destroy()
	end))
end

return KnifePickupController
