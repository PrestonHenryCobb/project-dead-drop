--!strict
-- Ticket gala-art-direction: source-driven finish pass. No geometry, tags or collision are changed.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = script.Parent:FindFirstChild("SharedOverride") or ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local ArtSurface = require(Shared.Util.ArtSurface)
local Sculptures = require(script.Parent.Sculptures)
local Art = {}
local PROP_ROLES = {
	Pillar = "Ivory",
	Table = "Walnut",
	Desk = "Walnut",
	Crate = "Walnut",
	Stage = "Walnut",
	["Reception desk"] = "Walnut",
	["Bar counter"] = "Walnut",
	Railing = "Brass",
	BridgeRail = "Brass",
	GrandStairHandrail = "Brass",
	StairHandrail = "Brass",
	StairRail = "Brass",
}

local function glassPattern(pane: BasePart)
	-- Original two-stroke chevron, drawn once per side. Drawing coordinates, not gameplay distances.
	for _, side in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Name = "DecoChevron"
		gui.Face = side
		gui.LightInfluence = GameConfig.Art.Glass.PatternLightInfluence
		gui.CanvasSize = Vector2.new(256, 256)
		gui.AlwaysOnTop = false
		for _, direction in { -1, 1 } do
			local line = Instance.new("Frame")
			line.AnchorPoint = Vector2.new(0.5, 0.5)
			line.Position = UDim2.fromScale(0.5 + direction * 0.2, 0.5)
			line.Size = UDim2.new(0.5, 0, 0, GameConfig.Art.Glass.PatternStrokePixels)
			line.Rotation = direction * -45
			line.BackgroundColor3 = GameConfig.Art.Materials.Brass.Color
			line.BackgroundTransparency = GameConfig.Art.Glass.PatternTransparency
			line.BorderSizePixel = 0
			line.Parent = gui
		end
		gui.Parent = pane
	end
end

function Art.apply(root: Model)
	-- Keep existing collision/navigation solids; add only cached decorative meshes around them.
	local details = Instance.new("Folder")
	details.Name = "SculptedScenery"
	details.Parent = root
	for _, item in root:GetDescendants() do
		if item:IsA("Part") and item.Name == "Pillar" then
			local frame = item.CFrame
			local size = item.Size
			if item.Shape == Enum.PartType.Cylinder then
				frame *= CFrame.Angles(0, 0, -math.pi / 2)
				size = Vector3.new(size.Y, size.X, size.Z)
			end
			Sculptures.place("Column", frame, size / Sculptures.referenceSize("Column"), details)
			item.Transparency = 1
		elseif item:IsA("BasePart") and item.Name == "CeilingLight" then
			local frame = item.CFrame * CFrame.new(0, -GameConfig.Art.Sculptures.ChandelierDrop, 0)
			Sculptures.place("Chandelier", frame, Vector3.one * GameConfig.Art.Sculptures.ChandelierScale, details)
			item.CFrame = frame
			item.Transparency = 1
		elseif item:IsA("BasePart") and item.Name == "ChandelierRim" then
			item.Transparency = 1
		end
	end
	for _, item in root:GetDescendants() do
		-- The city keeps its separate distant skyline palette and window textures.
		if item:IsA("BasePart") and not item:FindFirstAncestor("Cityscape") and item.Transparency < 1 then
			local material = item.Material
			local role = (PROP_ROLES :: { [string]: string })[item.Name]
			if role then
				ArtSurface.apply(item, role)
			elseif
				item.Color == GameConfig.Art.Materials.Ivory.Color
				or material == Enum.Material.Marble
				or material == Enum.Material.Plaster
			then
				ArtSurface.apply(item, "Ivory")
			elseif material == Enum.Material.Wood or material == Enum.Material.WoodPlanks then
				ArtSurface.apply(item, "Walnut")
			elseif material == Enum.Material.Metal and item.Color == GameConfig.Art.Materials.Brass.Color then
				ArtSurface.apply(item, "Brass")
			elseif material == Enum.Material.Fabric or material == Enum.Material.Carpet then
				ArtSurface.apply(item, "Velvet", true) -- retain role/tier carpets and wing color blocking
			elseif
				material == Enum.Material.Glass
				and item.Name ~= "OneWayGlass"
				and (string.find(item.Name, "Pane") or string.find(item.Name, "Glass"))
			then
				item.Color = GameConfig.Art.Glass.Color
				item.Transparency = GameConfig.Art.Glass.Transparency
				glassPattern(item)
			end
		end
	end
end

return Art
