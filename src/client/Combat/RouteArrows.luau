--!strict
-- The former chevron renderer now draws one pooled, continuous floor ribbon on authored route geometry.
-- It begins at the room's route anchor, never at the player's root, and never identifies actors.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.GameConfig)
local Types = require(Shared.Types)
local config = GameConfig.RouteHud
local RouteArrows = {}

-- Keep a contiguous prefix on the current floor. A distance budget trims only the tail;
-- per-point radius tests and floor probes used to create arbitrary holes between chevrons.
function RouteArrows.segments(route: Types.RouteInfo?, floor: string?, floorAt: (number) -> string?): { { Vector3 } }
	local out: { { Vector3 } } = {}
	if not route or not floor then
		return out
	end
	local remaining = config.PathRangeStuds
	local began = false
	local traversalAt: { [number]: boolean } = {}
	for _, step in route.Steps do
		if step.CoverBreak then
			traversalAt[step.Index] = true
		end
	end
	for index = 1, #route.Points - 1 do
		-- A vent/zipline/gondola is a traversal, not a walkable floor segment through walls or open air.
		-- End at its entrance; the next server route resumes on arrival.
		if traversalAt[index] then
			break
		end
		local a, b = route.Points[index], route.Points[index + 1]
		if floorAt(a.Y) ~= floor or floorAt(b.Y) ~= floor then
			if began then
				break
			end
			continue
		end
		local length = (b - a).Magnitude
		if length <= GameConfig.UI.GraphicHud.DirectionEpsilonStuds then
			continue
		end
		began = true
		local shown = math.min(length, remaining)
		table.insert(out, { a, a:Lerp(b, shown / length) })
		remaining -= shown
		if remaining <= 0 or #out >= config.PathMaxSegments then
			break
		end
	end
	return out
end

function RouteArrows.new()
	local folder = Instance.new("Folder")
	folder.Name = "LocalRouteLine"
	folder.Parent = workspace
	local lines: { BasePart } = {}
	local joints: { BasePart } = {}
	local function part(name: string): Part
		local item = Instance.new("Part")
		item.Name = name
		item.Anchored = true
		item.CanCollide, item.CanTouch, item.CanQuery = false, false, false
		item.CastShadow = false
		item.Material = Enum.Material.SmoothPlastic
		item.Color = config.PathColor
		item.Transparency = 1
		item.Parent = folder
		return item
	end
	for _ = 1, config.PathMaxSegments do
		table.insert(lines, part("RouteLine"))
		local joint = part("RouteJoin")
		joint.Shape = Enum.PartType.Ball
		joint.Size = Vector3.one * config.PathWidthStuds
		table.insert(joints, joint)
	end
	local function hide()
		for _, list in { lines, joints } do
			for _, item in list do
				item.Transparency = 1
			end
		end
	end
	return {
		hide = hide,
		update = function(route: Types.RouteInfo?, floor: string?, floorAt: (number) -> string?)
			hide()
			local lift = Vector3.yAxis * config.PathLiftStuds
			for index, segment in RouteArrows.segments(route, floor, floorAt) do
				local a, b = segment[1] + lift, segment[2] + lift
				local line, joint = lines[index], joints[index]
				line.Size = Vector3.new(config.PathWidthStuds, config.PathWidthStuds, (b - a).Magnitude)
				line.CFrame = CFrame.lookAt((a + b) / 2, b)
				line.Transparency = config.PathTransparency
				joint.Position = a
				joint.Transparency = config.PathTransparency
			end
		end,
		Destroy = function()
			folder:Destroy()
		end,
	}
end

return RouteArrows
