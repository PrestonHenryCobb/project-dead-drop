--!strict
-- Ticket gala-sculptures: exactly the same baked face/tailoring on player disguises and NPC outfits.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(script.Parent.Parent.GameConfig)
local Definitions = require(script.Parent.Parent.Defs.SculptureDefs)
local ArtSurface = require(script.Parent.ArtSurface)
local Types = require(script.Parent.Parent.Types)
local Janitor = require(script.Parent.Janitor)
local SculptedOutfit = {}

function SculptedOutfit.available(): boolean
	local assets = ReplicatedStorage:FindFirstChild(GameConfig.Art.Sculptures.AssetFolder)
	return assets ~= nil and assets:FindFirstChild("Head") ~= nil and assets:FindFirstChild("Suit") ~= nil
end

function SculptedOutfit.strip(model: Model)
	for _, name in { "Head", "Suit", "Lapels", "BowTie" } do
		local visual = model:FindFirstChild("Sculpted" .. name)
		if visual then
			visual:Destroy()
		end
	end
end

local function attach(model: Model, name: string, target: BasePart, ratio: Vector3, colors: { [string]: Color3 })
	local assets = ReplicatedStorage:FindFirstChild(GameConfig.Art.Sculptures.AssetFolder) :: Folder
	local template = assets:FindFirstChild(name) :: Model
	local definition = (Definitions :: any)[name]
	local reference = definition.reference
	local scale = target.Size / Vector3.new(reference[1], reference[2], reference[3]) * ratio
	-- An Accessory would be auto-scaled again by player Humanoids, unlike Humanoid-free NPCs.
	local accessory = Instance.new("Model")
	accessory.Name = "Sculpted" .. name
	local fitted: { { part: BasePart, original: BasePart, weld: Weld } } = {}
	local janitor = Janitor.new()
	for _, component in definition.parts do
		local original = template:FindFirstChild(component.name) :: BasePart
		local part = original:Clone()
		part.Name = if component == definition.parts[1] then "Handle" else component.name
		local offset = CFrame.new(original.Position * scale) * original.CFrame.Rotation
		part.Size *= scale
		part.Anchored = false
		part.Massless = true
		part.CanCollide, part.CanQuery, part.CanTouch = false, false, false
		part.CFrame = target.CFrame * offset
		ArtSurface.apply(part, "Suit", true)
		part.Color = colors[component.role] or GameConfig.Art.Materials.Ivory.Color
		local weld = Instance.new("Weld")
		weld.Name = "AccessoryWeld"
		weld.Part0, weld.Part1, weld.C0 = target, part, offset
		weld.Parent = part
		part.Parent = accessory
		table.insert(fitted, { part = part, original = original, weld = weld })
	end
	-- Humanoid scaling may settle after an outfit swap. Refit on size changes, never on a frame loop.
	janitor:Add(target:GetPropertyChangedSignal("Size"):Connect(function()
		local resized = target.Size / Vector3.new(reference[1], reference[2], reference[3]) * ratio
		for _, entry in fitted do
			entry.part.Size = entry.original.Size * resized
			entry.weld.C0 = CFrame.new(entry.original.Position * resized) * entry.original.CFrame.Rotation
		end
	end))
	janitor:Add(accessory.Destroying:Connect(function()
		janitor:Destroy()
	end))
	accessory.Parent = model
end

function SculptedOutfit.apply(model: Model, outfit: Types.OutfitDef)
	if not SculptedOutfit.available() then
		return
	end -- Native shared rig remains usable in an unbuilt source-only place.
	local head, torso = model:FindFirstChild("Head"), model:FindFirstChild("UpperTorso")
	if not (head and head:IsA("BasePart") and torso and torso:IsA("BasePart")) then
		return
	end
	local colors = {
		Skin = outfit.BodyColors.Skin,
		Ink = GameConfig.Art.Sculptures.FaceInk,
		Cloth = outfit.Shirt.Color,
		Ivory = GameConfig.Art.Materials.Ivory.Color,
	}
	attach(model, "Head", head, GameConfig.Art.Sculptures.HeadRatio, colors)
	attach(model, "Suit", torso, Vector3.one, colors)
	for _, detail in outfit.Accessories do
		if detail.Kind == "Lapels" or detail.Kind == "BowTie" then
			attach(model, detail.Kind, torso, Vector3.one, { Accent = detail.Color })
		end
	end
	head.Transparency, torso.Transparency = 1, 1
	for _, item in head:GetChildren() do
		if item:IsA("Decal") then
			item.Transparency = 1
		end
	end
end

return SculptedOutfit
