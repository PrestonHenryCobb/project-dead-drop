--!strict
-- Original sculpted Deco lobby set dressing. Only MenuStage's client-only folder is edited.
-- The authored forms are static geometry; lamps reuse the stage's non-shadowed light budget.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local config = require(ReplicatedStorage.Shared.GameConfig).Menu.Stage
local Gala = {}
function Gala.build(folder: Instance, origin: CFrame)
	local function part(name: string, size: Vector3, position: CFrame, color: Color3, material: Enum.Material?): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = origin * position
		p.Color = color
		p.Material = material or Enum.Material.Metal
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = folder
		return p
	end
	local function rod(name: string, a: Vector3, b: Vector3, width: number, color: Color3)
		local p = part(name, Vector3.new(width, width, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), color)
		return p
	end
	local back = config.RoomSize.Z / 2 - 1.65
	-- Three monumental luminous window bays, with stepped architectural mullions and radiating fans.
	for _, x in { -12, 0, 12 } do
		part("IvoryWindowSurround", Vector3.new(9.8, 15, 0.28), CFrame.new(x, 11, back + 0.2), config.Brass)
		local glass = part(
			"CoolFrostedGlass",
			Vector3.new(9.3, 14.5, 0.22),
			CFrame.new(x, 11, back),
			config.Art.Glass,
			Enum.Material.Glass
		)
		glass.Reflectance = config.Art.GlassReflectance
		for _, side in { -1, 1 } do
			part("WindowEdge", Vector3.new(0.1, 14.5, 0.2), CFrame.new(x + side * 4.25, 11, back - 0.18), config.Brass)
			for i = 1, 3 do
				local px = x + side * (3.8 - i * 0.72)
				local top = 17.6 - i * 0.65
				rod("SteppedFan", Vector3.new(x, 6.2, back - 0.2), Vector3.new(px, top, back - 0.2), 0.1, config.Brass)
				rod(
					"WindowCrown",
					Vector3.new(px, top, back - 0.2),
					Vector3.new(px, 18.1, back - 0.2),
					0.1,
					config.Brass
				)
			end
		end
		part("WindowTransom", Vector3.new(9.2, 0.16, 0.2), CFrame.new(x, 7.2, back - 0.2), config.Brass)
		part("WindowSpine", Vector3.new(0.14, 14.2, 0.2), CFrame.new(x, 11, back - 0.2), config.Brass)
	end
	-- Fluted ivory columns, broad stepped capitals and brass neck rings.
	for _, x in { -18, -6, 6, 18 } do
		local y = 10.5
		part(
			"ColumnShaft",
			Vector3.new(1.2, 20, 1.35),
			CFrame.new(x, y, back - 0.7),
			config.Floor,
			Enum.Material.Marble
		)
		for _, step in { 0, 1, 2 } do
			part(
				"ColumnCapital",
				Vector3.new(1.4 + step * 0.4, 0.35, 1.5 + step * 0.35),
				CFrame.new(x, 20 + step * 0.35, back - 0.7),
				config.Brass
			)
			part(
				"ColumnFoot",
				Vector3.new(1.4 + step * 0.3, 0.25, 1.5 + step * 0.3),
				CFrame.new(x, 0.3 + step * 0.25, back - 0.7),
				config.Brass
			)
		end
		for _, dx in { -0.38, 0, 0.38 } do
			part("ColumnFlute", Vector3.new(0.055, 18.7, 0.07), CFrame.new(x + dx, 10.4, back - 1.41), config.Brass)
		end
	end
	-- A second balcony silhouette and geometric metal screens instead of a bare wooden wall.
	for _, y in { 4.2, 4.5 } do
		part("GalleryStringCourse", Vector3.new(42, 0.12, 0.25), CFrame.new(0, y, back - 0.6), config.Brass)
	end
	for x = -20, 20, 4 do
		rod(
			"GalleryChevron",
			Vector3.new(x - 1.7, 0.5, back - 2.55),
			Vector3.new(x, 3.1, back - 2.55),
			0.09,
			config.Brass
		)
		rod(
			"GalleryChevron",
			Vector3.new(x, 3.1, back - 2.55),
			Vector3.new(x + 1.7, 0.5, back - 2.55),
			0.09,
			config.Brass
		)
	end
	-- Marble parquet and restrained cyan perimeter inlay, matching the references without gameplay tier signals.
	for _, side in { -1, 1 } do
		for i = 0, 5 do
			part(
				"MarbleParquet",
				Vector3.new(3.8, 0.03, 6.8),
				CFrame.new(side * (7 + i * 2.1), 0.025, -4 + i * 2.4) * CFrame.Angles(0, math.rad(side * 35), 0),
				if i % 2 == 0 then config.Art.MarbleDark else config.Floor,
				Enum.Material.Marble
			)
		end
		part(
			"CyanFloorInlay",
			Vector3.new(0.08, 0.04, 24),
			CFrame.new(side * 17, 0.06, 0),
			config.RimColor,
			Enum.Material.Neon
		)
		part("BrassCarpetBorder", Vector3.new(0.08, 0.04, 11), CFrame.new(side * 5.25, 0.12, 0), config.Brass)
	end
	-- Velvet settees frame the stage, without obstructing the operative silhouette.
	for _, side in { -1, 1 } do
		local x = side * 12
		part("VelvetSeat", Vector3.new(6.8, 0.9, 2.7), CFrame.new(x, 1.2, 5), config.Carpet, Enum.Material.Fabric)
		part("VelvetBack", Vector3.new(6.8, 2.1, 0.65), CFrame.new(x, 2.3, 6.05), config.Carpet, Enum.Material.Fabric)
		for _, endSide in { -1, 1 } do
			part(
				"SetteeArm",
				Vector3.new(0.7, 1.8, 2.7),
				CFrame.new(x + endSide * 3.25, 1.9, 5),
				config.Carpet,
				Enum.Material.Fabric
			)
			part("SetteeFoot", Vector3.new(0.16, 0.8, 2.1), CFrame.new(x + endSide * 2.8, 0.45, 5), config.Brass)
		end
		for dx = -2, 2, 1 do
			part("UpholsteryStud", Vector3.new(0.08, 0.08, 0.08), CFrame.new(x + dx, 2.5, 5.7), config.Brass)
		end
	end
	-- Sculpted tiered chandelier: faceted illuminated glass rods in a stepped octagonal crown.
	local center = Vector3.new(0, config.Art.ChandelierHeight, 7)
	local chainHeight = config.RoomSize.Y - center.Y
	part(
		"ChandelierStem",
		Vector3.new(0.12, chainHeight, 0.12),
		CFrame.new(center + Vector3.new(0, chainHeight / 2, 0)),
		config.Brass
	)
	part(
		"CofferedCeiling",
		Vector3.new(config.RoomSize.X, 0.25, config.RoomSize.Z),
		CFrame.new(0, config.RoomSize.Y, 0),
		config.Walnut,
		Enum.Material.Wood
	)
	for tier = 1, 3 do
		local radius = 4.3 - tier * 0.8
		local height = 2.4 + (0.4 * tier)
		for i = 0, 15 do
			local angle = i * math.pi / 8
			local pos = center + Vector3.new(math.cos(angle) * radius, -tier * 1.1, math.sin(angle) * radius)
			local fin = part(
				"ChandelierGlass",
				Vector3.new(0.36, height, 0.36),
				CFrame.new(pos) * CFrame.Angles(0, -angle, 0),
				config.LampColor,
				Enum.Material.Glass
			)
			fin.Reflectance = config.Art.GlassReflectance
			part(
				"ChandelierBrassCap",
				Vector3.new(0.5, 0.16, 0.5),
				CFrame.new(pos + Vector3.new(0, height / 2, 0)),
				config.Brass
			)
		end
	end
	-- No new lights, Humanoids, shadows, textures, uploads or per-frame animations.
end
return Gala
