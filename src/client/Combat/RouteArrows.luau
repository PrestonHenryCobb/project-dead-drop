--!strict
-- Bounded, pooled client-only floor chevrons. Never parent an effect to a rig.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.GameConfig)
local Types = require(Shared.Types)
local config = GameConfig.RouteHud
local RouteArrows = {}

-- Sample only the nearby portion of same-floor segments; work is bounded even on long routes.
function RouteArrows.samples(
	route: Types.RouteInfo?,
	origin: Vector3,
	floor: string?,
	floorAt: (number) -> string?
): { { Point: Vector3, Direction: Vector3 } }
	local out = {}
	if not route or not floor then
		return out
	end
	for index = 1, #route.Points - 1 do
		local a, b = route.Points[index], route.Points[index + 1]
		if floorAt(a.Y) ~= floor or floorAt(b.Y) ~= floor then
			continue
		end
		local delta = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
		local length = delta.Magnitude
		if length <= GameConfig.UI.GraphicHud.DirectionEpsilonStuds then
			continue
		end
		local direction = delta / length
		local projection = (origin - a):Dot(direction)
		local low = math.max(0, projection - config.ArrowRangeStuds)
		local high = math.min(length, projection + config.ArrowRangeStuds)
		for distance = math.ceil(low / config.ArrowSpacingStuds) * config.ArrowSpacingStuds, high, config.ArrowSpacingStuds do
			local point = a:Lerp(b, distance / length)
			if (point - origin).Magnitude <= config.ArrowRangeStuds then
				table.insert(out, { Point = point, Direction = direction })
				if #out >= config.ArrowMax then
					return out
				end
			end
		end
	end
	return out
end

function RouteArrows.new()
	local folder = Instance.new("Folder")
	folder.Name = "LocalRouteArrows"
	folder.Parent = workspace
	local pool: { BasePart } = {}
	for _ = 1, config.ArrowMax * 2 do
		local part = Instance.new("Part")
		part.Name = "RouteChevron"
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.CastShadow = false
		part.Material = Enum.Material.Neon
		part.Transparency = 1
		part.Parent = folder
		table.insert(pool, part)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { folder }
	local function hide()
		for _, part in pool do
			part.Transparency = 1
		end
	end
	return {
		hide = hide,
		update = function(
			route: Types.RouteInfo?,
			origin: Vector3,
			floor: string?,
			floorAt: (number) -> string?,
			color: Color3
		)
			hide()
			for index, sample in RouteArrows.samples(route, origin, floor, floorAt) do
				local hit = workspace:Raycast(
					sample.Point + Vector3.yAxis * config.ArrowProbeUpStuds,
					-Vector3.yAxis * (config.ArrowProbeUpStuds + config.ArrowProbeDownStuds),
					params
				)
				if not hit then
					continue
				end
				local actor = false
				local parent: Instance? = hit.Instance
				while parent and parent ~= workspace do
					if parent:IsA("Model") and parent:FindFirstChildOfClass("Humanoid") then
						actor = true
						break
					end
					parent = parent.Parent
				end
				if actor then
					continue
				end
				local tip = hit.Position + Vector3.yAxis * config.ArrowLiftStuds
				local side = sample.Direction:Cross(Vector3.yAxis)
				for arm, sign in { -1, 1 } do
					local tail = tip
						- sample.Direction * config.ArrowLengthStuds
						+ side * sign * config.ArrowLengthStuds / 2
					local part = pool[(index - 1) * 2 + arm]
					part.Size = Vector3.new(config.ArrowWidthStuds, config.ArrowWidthStuds, (tail - tip).Magnitude)
					part.CFrame = CFrame.lookAt((tail + tip) / 2, tip)
					part.Color = color
					part.Transparency = 0
				end
			end
		end,
		Destroy = function()
			folder:Destroy()
		end,
	}
end

return RouteArrows
