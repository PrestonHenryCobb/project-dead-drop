--!strict
-- Attribute-driven map safe colours only. No lights, labels, metadata or changes on a character/NPC.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.GameConfig)
local Enums = require(Shared.Enums)
local Janitor = require(Shared.Util.Janitor)
local Style = require(script.Parent.Parent.Combat.AssetStyle)
local AssetSafeController = {}
function AssetSafeController.Init() end
function AssetSafeController.Start()
	local janitor = Janitor.new()
	local tracked: { [BasePart]: Janitor.Janitor } = {}
	local function remove(instance: Instance)
		local owner = tracked[instance :: BasePart]
		if owner then
			tracked[instance :: BasePart] = nil
			owner:Destroy()
		end
	end
	local function track(instance: Instance)
		if not instance:IsA("BasePart") or tracked[instance] then
			return
		end
		local ancestor = instance.Parent
		while ancestor and ancestor ~= workspace do
			if ancestor:IsA("Model") and ancestor:FindFirstChildOfClass("Humanoid") then
				return
			end
			ancestor = ancestor.Parent
		end
		local owner = Janitor.new()
		tracked[instance] = owner
		local original = instance.Color
		local function refresh()
			local rarity = instance:GetAttribute("Rarity")
			local color = if type(rarity) == "string" then Style.color(rarity) else nil
			instance.Color = if color
				then (if instance:GetAttribute("Opened") == true
					then color:Lerp(Color3.new(0, 0, 0), GameConfig.AssetHud.SafeDimFraction)
					else color)
				else original
		end
		owner:Add(function()
			if instance.Parent then
				instance.Color = original
			end
		end)
		owner:Add(instance:GetAttributeChangedSignal("Rarity"):Connect(refresh))
		owner:Add(instance:GetAttributeChangedSignal("Opened"):Connect(refresh))
		owner:Add(instance.Destroying:Connect(function()
			remove(instance)
		end))
		refresh()
	end
	janitor:Add(CollectionService:GetInstanceAddedSignal(Enums.Tag.AssetSafe):Connect(track))
	janitor:Add(CollectionService:GetInstanceRemovedSignal(Enums.Tag.AssetSafe):Connect(remove))
	for _, instance in CollectionService:GetTagged(Enums.Tag.AssetSafe) do
		track(instance)
	end
	janitor:Add(function()
		for instance in tracked do
			remove(instance)
		end
	end)
	janitor:Add(script.Destroying:Connect(function()
		janitor:Destroy()
	end))
end
return AssetSafeController
