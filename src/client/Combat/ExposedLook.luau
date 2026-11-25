--!strict
-- Recognises a character that is Exposed (wearing a True Form) from its body colours alone: the plain True Form or any agent's own (Defs/AgentLooks). No
-- roster, attribute, tag or server message is used, so the client learns nothing it could not see (identity secrecy).
--
--   ExposedLook.matches(model) -> boolean       true for another player's character in a True Form look

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AgentLooks = require(Shared:WaitForChild("Defs"):WaitForChild("AgentLooks"))
local OutfitDefs = require(Shared:WaitForChild("Defs"):WaitForChild("OutfitDefs"))
local Types = require(Shared:WaitForChild("Types"))

local ExposedLook = {}

local function bodyColors(look: Types.OutfitDef): { [string]: Color3 }
	return {
		Head = look.BodyColors.Skin,
		UpperTorso = look.Shirt.Color,
		LowerTorso = look.Pants.Color,
		RightUpperArm = look.Shirt.Color,
		LeftUpperArm = look.Shirt.Color,
		RightLowerArm = if look.Shirt.LongSleeves then look.Shirt.Color else look.BodyColors.Skin,
		LeftLowerArm = if look.Shirt.LongSleeves then look.Shirt.Color else look.BodyColors.Skin,
		RightHand = look.BodyColors.Skin,
		LeftHand = look.BodyColors.Skin,
		RightUpperLeg = look.Pants.Color,
		LeftUpperLeg = look.Pants.Color,
		RightFoot = look.BodyColors.Shoes,
		LeftFoot = look.BodyColors.Shoes,
	}
end

local lookColors: { { [string]: Color3 } } = { bodyColors(OutfitDefs.trueForm) }
for _, look in AgentLooks.all() do
	table.insert(lookColors, bodyColors(look))
end

function ExposedLook.matches(model: Model): boolean
	if model == Players.LocalPlayer.Character then
		return false
	end
	for _, colors in lookColors do
		local all = true
		for name, color in colors do
			local part = model:FindFirstChild(name)
			if not (part and part:IsA("BasePart") and part.Color == color) then
				all = false
				break
			end
		end
		if all then
			return true
		end
	end
	return false
end

return ExposedLook
