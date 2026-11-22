--!strict
-- Client-only gala balcony: open skyline behind the operative, warm doorways at the edges, no world Lighting edits.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local config = require(ReplicatedStorage.Shared.GameConfig).Menu.Stage
local Gala = {}

function Gala.build(folder: Instance, origin: CFrame)
	local scene = config.Balcony
	local function part(name: string, size: Vector3, position: CFrame, color: Color3, material: Enum.Material?): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = origin * position
		p.Color = color
		p.Material = material or Enum.Material.Metal
		p.Anchored = true
		p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
		p.CastShadow = false
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.Parent = folder
		return p
	end
	-- Composition coordinates are authored geometry, not gameplay distances or map edits.
	local railZ = scene.RailZ
	part("NightSky", Vector3.new(420, 220, 1), CFrame.new(0, 70, 220), scene.SkyColor, Enum.Material.Neon)
	part("DistantCityBase", Vector3.new(360, 80, 1), CFrame.new(0, -42, 180), scene.TowerColor)
	local random = Random.new(211126)
	for index = 1, scene.TowerCount do
		local x = (index - (scene.TowerCount + 1) / 2) * scene.TowerSpacingStuds
		local height = random:NextNumber(14, 42)
		local width = random:NextNumber(5, 8)
		local z = scene.TowerDistanceStuds + random:NextNumber(0, 28)
		local base = -8
		part("SkylineTower", Vector3.new(width, height, 7), CFrame.new(x, base + height / 2, z), scene.TowerColor)
		part("TowerCrown", Vector3.new(width * 0.65, 1.2, 7.2), CFrame.new(x, base + height, z), config.Walnut)
		for row = 1, scene.WindowRows do
			local y = base + height * row / (scene.WindowRows + 1)
			local color = if (index + row) % 3 == 0 then scene.WindowColor else scene.CoolWindowColor
			part(
				"DistantWindowBand",
				Vector3.new(width * 0.72, 0.14, 0.06),
				CFrame.new(x, y, z - 3.55),
				color,
				Enum.Material.Neon
			)
		end
		if index % 3 == 0 then
			part("TowerSpire", Vector3.new(0.16, 5, 0.16), CFrame.new(x, base + height + 2.5, z), config.Brass)
		end
	end
	for _ = 1, scene.StarCount do
		local star = part(
			"DistantStar",
			Vector3.new(0.13, 0.13, 0.13),
			CFrame.new(random:NextNumber(-140, 140), random:NextNumber(40, 100), 210),
			scene.CoolWindowColor,
			Enum.Material.Neon
		)
		star.Shape = Enum.PartType.Ball
	end
	-- A clear waist-high balustrade leaves the city visible instead of enclosing the operative in a room.
	part("BalconyHandrail", Vector3.new(config.RoomSize.X, 0.15, 0.22), CFrame.new(0, 3.1, railZ), config.Brass)
	part("BalconyFootrail", Vector3.new(config.RoomSize.X, 0.1, 0.18), CFrame.new(0, 0.35, railZ), config.Brass)
	for x = -20, 20, 2.5 do
		part("BalconyPost", Vector3.new(0.08, 2.75, 0.08), CFrame.new(x, 1.7, railZ), config.Brass)
	end
	-- Dark stone, restrained brass inlay and a velvet runner ground the agent without a bright platform.
	part("VelvetRunner", Vector3.new(6, 0.05, 14), CFrame.new(0, 0.04, -1), config.Carpet, Enum.Material.Fabric)
	for _, side in { -1, 1 } do
		part("RunnerInlay", Vector3.new(0.045, 0.06, 14), CFrame.new(side * 3.1, 0.06, -1), config.Brass)
		local x = side * 19
		part("GalaWing", Vector3.new(7, 17, 9), CFrame.new(x, 8.5, 12), config.Walnut, Enum.Material.Wood)
		part("DoorwayGlow", Vector3.new(3.8, 11, 0.08), CFrame.new(x, 5.6, 7.45), config.LampColor, Enum.Material.Neon)
		for _, edge in { -1, 1 } do
			part("DoorwayFrame", Vector3.new(0.2, 12, 0.2), CFrame.new(x + edge * 2.1, 6, 7.2), config.Brass)
		end
		part("DoorwayCrown", Vector3.new(4.4, 0.25, 0.4), CFrame.new(x, 12, 7.2), config.Brass)
		part(
			"StonePlanter",
			Vector3.new(2.4, 1.6, 2.4),
			CFrame.new(side * 13, 0.8, 5.5),
			config.Floor,
			Enum.Material.Marble
		)
		for branch = 1, 5 do
			local angle = branch * math.pi * 2 / 5
			local leaf = part(
				"Topiary",
				Vector3.new(0.8, 3, 0.8),
				CFrame.new(side * 13 + math.cos(angle) * 0.5, 2.5, 5.5 + math.sin(angle) * 0.5),
				Color3.fromHex("253A33"),
				Enum.Material.SmoothPlastic
			)
			leaf.Shape = Enum.PartType.Ball
		end
	end
end
return Gala
