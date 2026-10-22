--!strict
-- The city round the Gala (BUILD_ORDER Step 7B), built by Build.luau. The Gala crowns a skyscraper whose shaft drops in
-- setbacks into the void: layers of haze, each darker than the one above, from the city's orange glow down to a solid
-- black floor where anything that falls dies. Round it stand towers in several styles (glass curtain walls, office
-- bands, brick), with crowns, spires, beacons and rooftop plant, in three depth bands: near towers you look down on, a
-- far ring with a few supertalls, and dark silhouettes on the horizon.
--
-- None of it can be reached, so nothing here collides, takes touches or queries, or casts a shadow. It is one
-- persistent model so streaming never drops the skyline.

local Lighting = game:GetService("Lighting")

type Rect = { x1: number, z1: number, x2: number, z2: number }
export type Support = { rect: Rect, top: number } -- a neighbouring tower whose roof carries a deck

local City = {}

-- Facade textures, made by tools/city-textures/make.js: 8 x 8 window cells per tile. The lit overlays line up with
-- any facade, and each face shifts its overlay by whole cells so no two faces light the same way.
local FACADES = {
	"rbxassetid://76021458722767", -- glass curtain wall
	"rbxassetid://89567700592457", -- office bands
	"rbxassetid://74084567347659", -- brick residential
}
local LIT = { "rbxassetid://117649698906085", "rbxassetid://98111879626412" }
local TILE = 32 -- studs per texture tile, so a window cell (one floor) is 4 studs
local CELL = TILE / 8
-- Above 1 on purpose: a Texture's Color3 multiplies its image, so this lifts lit windows to glow against the night.
-- selene: allow(roblox_incorrect_color3_new_bounds)
local LIT_TINT = Color3.new(1.6, 1.35, 1.05)
local FACES = { Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right }

-- The kill floor: solid black, and Workspace.FallenPartsDestroyHeight, so anything that falls past it dies. Every
-- tower stands on it.
local VOID_Y = -560
local BLOCK = 110 -- one tower per city block
local SHAFT_SETBACKS = { { to = -260, grow = 0 }, { to = -400, grow = 16 }, { to = VOID_Y, grow = 32 } }
local NEAR_REACH, MID_REACH = 300, 420 -- how far out the near towers stop and the middle band stops
local CLEAR_X, CLEAR_Z = 200, 230 -- no city block this close to the Gala's centre
local FAR_RING = { count = 140, from = 700, to = 1500 }
local SUPERTALLS = { count = 6, from = 900, to = 1400 }
local HORIZON = { count = 160, from = 1900, to = 2400 }
-- Haze layers down into the void, each darker and more solid than the one above.
local VOID_LAYERS = {
	{ y = -250, transparency = 0.72, color = Color3.fromRGB(215, 150, 135) }, -- lit orange from the city
	{ y = -330, transparency = 0.62, color = Color3.fromRGB(120, 75, 100) },
	{ y = -400, transparency = 0.5, color = Color3.fromRGB(60, 38, 75) },
	{ y = -470, transparency = 0.38, color = Color3.fromRGB(24, 16, 36) },
	{ y = -530, transparency = 0.2, color = Color3.fromRGB(8, 6, 14) },
}
local WORLD = 6000 -- width of the haze layers and the floor
local YIELD_EVERY = 300 -- parts made between yields, so Studio stays responsive

local SHAFT_GREY = Color3.fromRGB(62, 64, 76)
local ROOF_GREY = Color3.fromRGB(70, 72, 80)
local PLANT_GREY = Color3.fromRGB(105, 108, 116)
local BEACON = Color3.fromRGB(255, 30, 30)
local SILHOUETTE = Color3.fromRGB(28, 30, 45)
local CROWN_COLORS = {
	Color3.fromRGB(255, 236, 200),
	Color3.fromRGB(170, 205, 255),
	Color3.fromRGB(255, 150, 210),
	Color3.fromRGB(255, 200, 120),
}

-- Builds the city into `parent` and returns how many parts it made. `footprint` is the Gala's ground floor outline and
-- `shaftTop` the underside of its lowest floor.
function City.build(parent: Instance, footprint: Rect, shaftTop: number, supports: { Support }): number
	local model = Instance.new("Model")
	model.Name = "Cityscape"
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	model.Parent = parent
	local rng = Random.new(23)
	local count = 0

	local function block(name: string, size: Vector3, cframe: CFrame, color: Color3): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = cframe
		p.Color = color
		p.Material = Enum.Material.SmoothPlastic
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = model
		count += 1
		if count % YIELD_EVERY == 0 then
			task.wait()
		end
		return p
	end
	local function glow(name: string, size: Vector3, cframe: CFrame, color: Color3): Part
		local p = block(name, size, cframe, color)
		p.Material = Enum.Material.Neon
		return p
	end
	-- A facade on all four sides, with a lit-window overlay shifted by whole cells on each face.
	local function windows(p: BasePart, facade: string, lit: string)
		for _, face in FACES do
			local base = Instance.new("Texture")
			base.Texture = facade
			base.Face = face
			base.StudsPerTileU, base.StudsPerTileV = TILE, TILE
			base.Parent = p
			local glowing = Instance.new("Texture")
			glowing.Name = "LitWindows"
			glowing.Texture = lit
			glowing.Face = face
			glowing.StudsPerTileU, glowing.StudsPerTileV = TILE, TILE
			glowing.OffsetStudsU = CELL * rng:NextInteger(0, 7)
			glowing.OffsetStudsV = CELL * rng:NextInteger(0, 7)
			glowing.Color3 = LIT_TINT
			glowing.ZIndex = 2
			glowing.Parent = p
		end
	end
	local function beacon(x: number, y: number, z: number)
		local b = glow("Beacon", Vector3.new(2, 2, 2), CFrame.new(x, y, z), BEACON)
		b.Shape = Enum.PartType.Ball
	end
	-- A ring of light round the top edge of a block.
	local function crown(cx: number, y: number, cz: number, w: number, d: number, color: Color3)
		glow("Crown", Vector3.new(w + 0.4, 0.8, 0.4), CFrame.new(cx, y, cz - d / 2 - 0.2), color)
		glow("Crown", Vector3.new(w + 0.4, 0.8, 0.4), CFrame.new(cx, y, cz + d / 2 + 0.2), color)
		glow("Crown", Vector3.new(0.4, 0.8, d + 0.4), CFrame.new(cx - w / 2 - 0.2, y, cz), color)
		glow("Crown", Vector3.new(0.4, 0.8, d + 0.4), CFrame.new(cx + w / 2 + 0.2, y, cz), color)
	end
	-- Plant on a roof: cooling units, sometimes a water tank, sometimes a mast with a beacon.
	local function roofPlant(cx: number, top: number, cz: number, w: number, d: number)
		for _ = 1, rng:NextInteger(2, 4) do
			local sx, sz = rng:NextNumber(4, math.max(5, w * 0.3)), rng:NextNumber(4, math.max(5, d * 0.3))
			local sy = rng:NextNumber(2, 5)
			block(
				"Roof plant",
				Vector3.new(sx, sy, sz),
				CFrame.new(
					cx + rng:NextNumber(-w / 2 + sx / 2, w / 2 - sx / 2),
					top + sy / 2,
					cz + rng:NextNumber(-d / 2 + sz / 2, d / 2 - sz / 2)
				),
				PLANT_GREY
			)
		end
		if rng:NextNumber() < 0.35 then
			local tank = block(
				"Water tank",
				Vector3.new(8, 7, 7),
				CFrame.new(cx + w * 0.25, top + 4, cz - d * 0.25) * CFrame.Angles(0, 0, math.rad(90)),
				Color3.fromRGB(110, 85, 70)
			)
			tank.Shape = Enum.PartType.Cylinder
		end
		if rng:NextNumber() < 0.4 then
			local mast = rng:NextNumber(12, 30)
			block("Mast", Vector3.new(0.8, mast, 0.8), CFrame.new(cx, top + mast / 2, cz), PLANT_GREY)
			beacon(cx, top + mast + 1, cz)
		end
	end
	-- A tower standing on the street: one to three tiers stepping in, a facade on each, and (when `detailed`) a crown,
	-- roof plant or a spire.
	local function tower(cx: number, cz: number, w: number, d: number, top: number, detailed: boolean)
		local facade, lit = FACADES[rng:NextInteger(1, #FACADES)], LIT[rng:NextInteger(1, #LIT)]
		local shape = rng:NextNumber()
		local splits = if shape < 0.45 then { 1 } elseif shape < 0.8 then { 0.72, 1 } else { 0.55, 0.8, 1 }
		local bottom, tw, td = VOID_Y, w, d
		local crownColor = CROWN_COLORS[rng:NextInteger(1, #CROWN_COLORS)]
		for index, split in splits do
			local tierTop = VOID_Y + (top - VOID_Y) * split
			local tier = block(
				"Tower",
				Vector3.new(tw, tierTop - bottom, td),
				CFrame.new(cx, (bottom + tierTop) / 2, cz),
				ROOF_GREY
			)
			windows(tier, facade, lit)
			if index < #splits then
				if detailed then
					crown(cx, tierTop - 0.4, cz, tw, td, crownColor)
				end
				bottom, tw, td = tierTop, tw * 0.72, td * 0.72
			end
		end
		if not detailed then
			return
		end
		if rng:NextNumber() < 0.5 then
			crown(cx, top - 0.4, cz, tw, td, crownColor)
		end
		if rng:NextNumber() < 0.2 then
			local height = rng:NextNumber(20, 70)
			local spire = block(
				"Spire",
				Vector3.new(height, 3, 3),
				CFrame.new(cx, top + height / 2, cz) * CFrame.Angles(0, 0, math.rad(90)),
				PLANT_GREY
			)
			spire.Shape = Enum.PartType.Cylinder
			beacon(cx, top + height + 1, cz)
		else
			roofPlant(cx, top, cz, tw, td)
		end
	end

	-- The Gala's own skyscraper: glass all the way down in three setbacks, a crown of light under the Gala and lit bands
	-- at each setback, fading into the void.
	local cx, cz = (footprint.x1 + footprint.x2) / 2, (footprint.z1 + footprint.z2) / 2
	local fw, fd = footprint.x2 - footprint.x1, footprint.z2 - footprint.z1
	local from = shaftTop
	for index, setback in SHAFT_SETBACKS do
		local w, d = fw + setback.grow * 2, fd + setback.grow * 2
		local shaft = block(
			"Skyscraper shaft",
			Vector3.new(w, from - setback.to, d),
			CFrame.new(cx, (from + setback.to) / 2, cz),
			SHAFT_GREY
		)
		windows(shaft, FACADES[1], LIT[1])
		if index > 1 then
			crown(cx, from - 0.4, cz, w, d, CROWN_COLORS[1])
		end
		from = setback.to
	end
	crown(cx, shaftTop - 1.5, cz, fw, fd, CROWN_COLORS[4])

	-- Neighbouring towers that carry decks: office facades, lit, with a crown under the deck's rim.
	for _, support in supports do
		local r = support.rect
		local w, d = r.x2 - r.x1, r.z2 - r.z1
		local scx, scz = (r.x1 + r.x2) / 2, (r.z1 + r.z2) / 2
		local body = block(
			"Neighbour tower",
			Vector3.new(w, support.top - VOID_Y, d),
			CFrame.new(scx, (support.top + VOID_Y) / 2, scz),
			ROOF_GREY
		)
		windows(body, FACADES[2], LIT[1])
		crown(scx, support.top - 1, scz, w, d, CROWN_COLORS[1])
	end

	-- Near and middle band: one tower per block, low and close so you look down on them, rising with distance.
	for gx = -5, 5 do
		for gz = -5, 5 do
			local dx, dz = gx * BLOCK + rng:NextNumber(-12, 12), gz * BLOCK + rng:NextNumber(-12, 12)
			if math.abs(dx) < CLEAR_X and math.abs(dz) < CLEAR_Z then
				continue
			end
			local w, d = rng:NextNumber(40, 74), rng:NextNumber(40, 74)
			local spot: Rect =
				{ x1 = cx + dx - w / 2, z1 = cz + dz - d / 2, x2 = cx + dx + w / 2, z2 = cz + dz + d / 2 }
			local blocked = false
			for _, support in supports do
				local r = support.rect
				if spot.x1 < r.x2 + 20 and r.x1 - 20 < spot.x2 and spot.z1 < r.z2 + 20 and r.z1 - 20 < spot.z2 then
					blocked = true
					break
				end
			end
			if blocked then
				continue
			end
			local far = math.max(math.abs(dx), math.abs(dz))
			local top = if far < NEAR_REACH
				then rng:NextNumber(-320, -60)
				elseif far < MID_REACH then rng:NextNumber(-260, -20)
				else rng:NextNumber(-200, 60)
			tower(cx + dx, cz + dz, w, d, top, true)
		end
	end

	-- Far band: a scattered ring of plainer towers, and a few supertalls that rise above the Gala.
	for _ = 1, FAR_RING.count do
		local angle, r = rng:NextNumber(0, math.pi * 2), rng:NextNumber(FAR_RING.from, FAR_RING.to)
		tower(
			cx + math.cos(angle) * r,
			cz + math.sin(angle) * r,
			rng:NextNumber(50, 110),
			rng:NextNumber(50, 110),
			rng:NextNumber(-300, 110),
			false
		)
	end
	for i = 1, SUPERTALLS.count do
		local angle = (i / SUPERTALLS.count + rng:NextNumber(-0.05, 0.05)) * math.pi * 2
		local r = rng:NextNumber(SUPERTALLS.from, SUPERTALLS.to)
		tower(
			cx + math.cos(angle) * r,
			cz + math.sin(angle) * r,
			rng:NextNumber(70, 100),
			rng:NextNumber(70, 100),
			rng:NextNumber(320, 460),
			true
		)
	end

	-- The horizon: dark silhouettes that the haze swallows.
	for i = 1, HORIZON.count do
		local angle = (i / HORIZON.count) * math.pi * 2 + rng:NextNumber(-0.01, 0.01)
		local r = rng:NextNumber(HORIZON.from, HORIZON.to)
		local w, top = rng:NextNumber(80, 200), rng:NextNumber(-300, 150)
		block(
			"Silhouette",
			Vector3.new(w, top - VOID_Y, w * 0.6),
			CFrame.new(cx + math.cos(angle) * r, (top + VOID_Y) / 2, cz + math.sin(angle) * r)
				* CFrame.Angles(0, -angle, 0),
			SILHOUETTE
		)
	end

	-- The void: the haze layers, then the black floor, which is also where falling kills.
	for _, layer in VOID_LAYERS do
		local haze = block("Void haze", Vector3.new(WORLD, 2, WORLD), CFrame.new(cx, layer.y, cz), layer.color)
		haze.Transparency = layer.transparency
	end
	block("Void floor", Vector3.new(WORLD, 2, WORLD), CFrame.new(cx, VOID_Y - 1, cz), Color3.new(0, 0, 0))
	workspace.FallenPartsDestroyHeight = VOID_Y - 2

	-- The night sky: plenty of stars and a bright moon over the city glow.
	local sky = Lighting:FindFirstChild("GalaSky") :: Sky?
	if not sky then
		local made = Instance.new("Sky")
		made.Name = "GalaSky"
		made.Parent = Lighting
		sky = made
	end
	local nightSky = sky :: Sky
	nightSky.StarCount = 4000
	nightSky.MoonAngularSize = 14
	nightSky.CelestialBodiesShown = true

	return count
end

return City
