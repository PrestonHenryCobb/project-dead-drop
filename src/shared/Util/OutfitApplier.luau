--!strict
-- Puts an outfit (spec 25.3) on an R15 character model, and strips Roblox avatar items.
-- Server-side: the server owns what everyone looks like, and players and NPCs go through this same code
-- so they cannot differ (spec 8.2).
--
--   OutfitApplier.strip(model)            removes shirts, pants, accessories, body colors, face and meshes
--   OutfitApplier.apply(model, outfitDef) strips, then dresses the model in the outfit
--
-- The model must be parented in the DataModel (Humanoid:AddAccessory needs it).

local Types = require(script.Parent.Parent.Types)
local GameConfig = require(script.Parent.Parent.GameConfig)
local ArtSurface = require(script.Parent.ArtSurface)
local SculptedOutfit = require(script.Parent.SculptedOutfit)

type OutfitDef = Types.OutfitDef

local OutfitApplier = {}

-- Avatar items that must never survive on a game character.
local AVATAR_CLASSES = { "Accessory", "Hat", "Shirt", "Pants", "ShirtGraphic", "BodyColors", "CharacterMesh" }

local FACE_TEXTURES: { [string]: string } = {
	Default = "rbxasset://textures/face.png",
}

local function setColor(model: Model, partName: string, color: Color3)
	local part = model:FindFirstChild(partName)
	if part and part:IsA("BasePart") then
		part.Color = color
		ArtSurface.apply(part, "Suit", true)
	end
end

local function newPart(name: string, size: Vector3, color: Color3, shape: Enum.PartType?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	ArtSurface.apply(part, "Suit", true)
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		part.Shape = shape
	end
	return part
end

-- An accessory whose Handle sits `offset` away from the character's attachment point.
local function newAccessory(name: string, attachmentName: string, handle: Part, offset: CFrame): Accessory
	local accessory = Instance.new("Accessory")
	accessory.Name = name
	handle.Name = "Handle"
	handle.Parent = accessory
	local attachment = Instance.new("Attachment")
	attachment.Name = attachmentName
	attachment.CFrame = offset:Inverse()
	attachment.Parent = handle
	return accessory
end

-- Welds an extra part onto an accessory's handle, `offset` away from it.
local function addExtra(accessory: Accessory, part: Part, offset: CFrame)
	local handle = accessory:FindFirstChild("Handle") :: Part
	local weld = Instance.new("Weld")
	weld.Part0 = handle
	weld.Part1 = part
	weld.C0 = offset
	weld.Parent = part
	part.Parent = accessory
end

local function buildAccessory(kind: Types.AccessoryKind, color: Color3): Accessory
	if kind == "Tie" then
		return newAccessory(
			"Tie",
			"BodyFrontAttachment",
			newPart("Handle", Vector3.new(0.35, 1.5, 0.15), color),
			CFrame.new(0, 0.1, -0.05)
		)
	elseif kind == "BowTie" then
		return newAccessory(
			"BowTie",
			"BodyFrontAttachment",
			newPart("Handle", Vector3.new(0.9, 0.35, 0.15), color),
			CFrame.new(0, 0.65, -0.05)
		)
	elseif kind == "Lapels" then
		-- Two slim strips down the front of a jacket, one each side of the tie, in the trim colour.
		local accessory = newAccessory(
			"Lapels",
			"BodyFrontAttachment",
			newPart("Handle", Vector3.new(GameConfig.Art.LapelWidth, 1.5, 0.12), color),
			CFrame.new(-0.55, 0.05, -0.08) * CFrame.Angles(0, 0, math.rad(-GameConfig.Art.LapelAngleDegrees))
		)
		addExtra(
			accessory,
			newPart("LapelRight", Vector3.new(GameConfig.Art.LapelWidth, 1.5, 0.12), color),
			CFrame.new(1.1, 0, 0) * CFrame.Angles(0, 0, math.rad(GameConfig.Art.LapelAngleDegrees * 2))
		)
		return accessory
	elseif kind == "PocketSquare" then
		return newAccessory(
			"PocketSquare",
			"BodyFrontAttachment",
			newPart("Handle", Vector3.new(0.35, 0.3, 0.12), color),
			CFrame.new(-0.75, 0.45, -0.1)
		)
	elseif kind == "LapelPin" then
		return newAccessory(
			"LapelPin",
			"BodyFrontAttachment",
			newPart("Handle", Vector3.new(0.3, 0.3, 0.3), color, Enum.PartType.Ball),
			CFrame.new(0.65, 0.45, -0.1)
		)
	elseif kind == "Fedora" then
		-- A brim and a crown. Hats mean "employee": Guests never wear one.
		local accessory = newAccessory(
			"Fedora",
			"HatAttachment",
			newPart("Handle", Vector3.new(2.9, 0.15, 2.9), color),
			CFrame.new(0, 0.02, 0)
		)
		addExtra(accessory, newPart("Crown", Vector3.new(1.6, 0.8, 1.6), color), CFrame.new(0, 0.5, 0))
		return accessory
	end
	-- Sunglasses
	return newAccessory(
		"Sunglasses",
		"FaceFrontAttachment",
		newPart("Handle", Vector3.new(1.3, 0.3, 0.12), color),
		CFrame.new(0, 0.1, -0.05)
	)
end

local function buildHair(style: Types.HairStyle, color: Color3): Accessory?
	if style == "Bald" then
		return nil
	end
	local height = if style == "Crop" then 0.3 else 0.5
	local cap = newPart("Handle", Vector3.new(1.3, height, 1.3), color)
	local accessory = newAccessory("Hair", "HairAttachment", cap, CFrame.new(0, -0.15, 0))
	if style == "Long" then
		addExtra(accessory, newPart("HairBack", Vector3.new(1.3, 1.6, 0.35), color), CFrame.new(0, -0.9, 0.5))
	elseif style == "Bun" then
		addExtra(
			accessory,
			newPart("HairBun", Vector3.new(0.7, 0.7, 0.7), color, Enum.PartType.Ball),
			CFrame.new(0, 0.4, 0.35)
		)
	end
	return accessory
end

function OutfitApplier.strip(model: Model)
	SculptedOutfit.strip(model)
	-- Restore native visual parts before fitting the next shared sculpture models.
	for _, name in { "Head", "UpperTorso" } do
		local body = model:FindFirstChild(name)
		if body and body:IsA("BasePart") then
			body.Transparency = 0
		end
	end
	for _, child in model:GetDescendants() do
		for _, className in AVATAR_CLASSES do
			if child:IsA(className) then
				child:Destroy()
				break
			end
		end
	end
	local head = model:FindFirstChild("Head")
	if head then
		for _, child in head:GetChildren() do
			-- FaceControls lets animations change the expression. Players run animations and NPCs don't yet,
			-- so a live face would make the two look different; every rig gets the same static face instead.
			if child:IsA("Decal") or child:IsA("FaceControls") then
				child:Destroy()
			end
		end
	end
end

function OutfitApplier.apply(model: Model, outfit: OutfitDef, deferSculpture: boolean?)
	OutfitApplier.strip(model)

	local skin, shoes = outfit.BodyColors.Skin, outfit.BodyColors.Shoes
	local shirt, pants = outfit.Shirt.Color, outfit.Pants.Color
	local sleeves = if outfit.Shirt.LongSleeves then shirt else skin

	setColor(model, "Head", skin)
	setColor(model, "UpperTorso", shirt)
	setColor(model, "LowerTorso", pants)
	for _, side in { "Left", "Right" } do
		setColor(model, side .. "UpperArm", shirt)
		setColor(model, side .. "LowerArm", sleeves)
		setColor(model, side .. "Hand", skin)
		setColor(model, side .. "UpperLeg", pants)
		setColor(model, side .. "LowerLeg", pants)
		setColor(model, side .. "Foot", shoes)
	end

	local head = model:FindFirstChild("Head")
	if head then
		local face = Instance.new("Decal")
		face.Name = "face"
		face.Texture = FACE_TEXTURES[outfit.Face]
		face.Face = Enum.NormalId.Front
		face.Parent = head
	end

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	assert(humanoid, "OutfitApplier needs a Humanoid")

	local scaleValues = {
		BodyHeightScale = outfit.Scale.Height,
		BodyWidthScale = outfit.Scale.Width,
		BodyDepthScale = outfit.Scale.Depth,
		HeadScale = outfit.Scale.Head,
	}
	for name, value in scaleValues do
		local scale = humanoid:FindFirstChild(name)
		if scale and scale:IsA("NumberValue") then
			scale.Value = value
		end
	end

	-- Identical clearance accent for both player disguises and NPC outfits; no identity metadata.
	local badge = newAccessory(
		"ClearanceAccent",
		"BodyFrontAttachment",
		newPart("Handle", GameConfig.Art.BadgeSize, GameConfig.Art.ClearanceCyan),
		GameConfig.Art.BadgeOffset
	)
	humanoid:AddAccessory(badge)

	local hair = buildHair(outfit.Hair.Style, outfit.Hair.Color)
	if hair then
		humanoid:AddAccessory(hair)
	end
	for _, def in outfit.Accessories do
		if not (SculptedOutfit.available() and (def.Kind == "Lapels" or def.Kind == "BowTie")) then
			humanoid:AddAccessory(buildAccessory(def.Kind, def.Color))
		end
	end
	if not deferSculpture then
		SculptedOutfit.apply(model, outfit)
	end
end

return OutfitApplier
