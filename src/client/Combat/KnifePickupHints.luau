--!strict
-- Local prompt visibility only. The server still validates every pickup and changes the inventory.
local KnifePickupHints = {}

export type Hints = {
	add: (Instance) -> (),
	remove: (Instance) -> (),
	setAvailable: (boolean) -> (),
	Destroy: () -> (),
}

function KnifePickupHints.new(): Hints
	local prompts: { [ProximityPrompt]: boolean } = {}
	local available = false
	local function add(instance: Instance)
		if not instance:IsA("ProximityPrompt") or prompts[instance] ~= nil then
			return
		end
		local parent = instance.Parent
		if not parent or parent.Name ~= "LandedKnife" or not parent:IsA("BasePart") then
			return
		end
		prompts[instance] = instance.Enabled
		instance.Enabled = instance.Enabled and available
	end
	local function remove(instance: Instance)
		if instance:IsA("ProximityPrompt") then
			local original = prompts[instance]
			if original ~= nil then
				instance.Enabled = original
				prompts[instance] = nil
			end
		end
	end
	return {
		add = add,
		remove = remove,
		setAvailable = function(value: boolean)
			if available == value then
				return
			end
			available = value
			for prompt, original in prompts do
				prompt.Enabled = original and available
			end
		end,
		Destroy = function()
			for prompt in prompts do
				remove(prompt)
			end
		end,
	}
end

return KnifePickupHints
