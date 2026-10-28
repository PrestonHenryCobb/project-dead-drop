--!strict
-- North-up public room footprints and server-supplied polylines. No character/NPC enumeration.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.GameConfig)
local Types = require(Shared.Types)
local Janitor = require(Shared.Util.Janitor)
local HudTheme = require(Shared.Util.HudTheme)
local config = GameConfig.RouteHud
local RouteMap = {}

function RouteMap.new(parent: Frame)
	local content = Janitor.new()
	local tracked = Janitor.new()
	local projectMark: ((Vector3) -> Vector2)? = nil
	local markFloor: string? = nil
	local markFloorAt: ((number) -> string?)? = nil
	local theme = HudTheme.get()
	local function frame(name: string, position: UDim2, size: UDim2, color: Color3): Frame
		local item = Instance.new("Frame")
		item.Name = name
		item.BorderSizePixel = 0
		item.Position = position
		item.Size = size
		item.BackgroundColor3 = color
		item.Parent = parent
		content:Add(item)
		return item
	end
	local function caption(name: string, text: string, at: Vector2, color: Color3, tracking: boolean?): TextLabel
		local label = Instance.new("TextLabel")
		label.Name = name
		label.Text = text
		label.RichText = false
		label.Font = theme.Font
		label.TextSize = theme.CaptionSize
		label.TextColor3 = color
		label.BackgroundColor3 = theme.PanelColor
		label.BackgroundTransparency = theme.PanelTransparency
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		label.Position = UDim2.fromOffset(at.X, at.Y)
		label.Size = UDim2.fromOffset(config.FlagPixels, config.FlagPixels)
		label.Parent = parent
		if tracking then
			tracked:Add(label)
		else
			content:Add(label)
		end
		return label
	end
	return {
		draw = function(
			zones: { BasePart },
			floor: string?,
			floorAt: (number) -> string?,
			result: Types.RouteResult?,
			mode: string,
			origin: Vector3
		)
			content:Cleanup()
			tracked:Cleanup()
			projectMark = nil
			markFloor, markFloorAt = floor, floorAt
			local lowX, lowZ, highX, highZ = math.huge, math.huge, -math.huge, -math.huge
			for _, zone in zones do
				-- Bounds include all public floors, keeping scale stable when browsing floors.
				for _, x in { -1, 1 } do
					for _, z in { -1, 1 } do
						local p =
							zone.CFrame:PointToWorldSpace(Vector3.new(zone.Size.X * x / 2, 0, zone.Size.Z * z / 2))
						lowX, highX = math.min(lowX, p.X), math.max(highX, p.X)
						lowZ, highZ = math.min(lowZ, p.Z), math.max(highZ, p.Z)
					end
				end
			end
			if lowX == math.huge or not floor then
				return
			end
			local extent = math.max(highX - lowX, highZ - lowZ) + config.MapMarginStuds * 2
			local scale = config.MapPixels / extent
			local center = Vector2.new((lowX + highX) / 2, (lowZ + highZ) / 2)
			local function project(p: Vector3): Vector2
				return Vector2.new(
					config.MapPixels / 2 + (p.X - center.X) * scale,
					config.MapPixels / 2 + (p.Z - center.Y) * scale
				)
			end
			projectMark = project
			for _, zone in zones do
				if floorAt(zone.Position.Y) == floor then
					local p = project(zone.Position)
					local tier = zone:GetAttribute("Tier")
					local color = if type(tier) == "number" then GameConfig.Zones.TierColors[tier] else nil
					local room = frame(
						"Room",
						UDim2.fromOffset(p.X, p.Y),
						UDim2.fromOffset(zone.Size.X * scale, zone.Size.Z * scale),
						color or theme.DimTextColor
					)
					room.AnchorPoint = Vector2.new(0.5, 0.5)
					local _, angle = zone.CFrame:ToOrientation()
					room.Rotation = -math.deg(angle)
					room.BackgroundTransparency = config.ZoneTransparency
				end
			end
			local function line(route: Types.RouteInfo?, name: string)
				if not route then
					return
				end
				local selected = name == mode
				local color = if name == "Clean" then config.CleanColor else config.FastColor
				for index = 1, #route.Points - 1 do
					local a, b = route.Points[index], route.Points[index + 1]
					if floorAt(a.Y) == floor and floorAt(b.Y) == floor then
						local from, to = project(a), project(b)
						local delta = to - from
						local item = frame(
							name .. "Route",
							UDim2.fromOffset((from.X + to.X) / 2, (from.Y + to.Y) / 2),
							UDim2.fromOffset(
								delta.Magnitude,
								if selected then config.SelectedLinePixels else config.LinePixels
							),
							color
						)
						item.AnchorPoint = Vector2.new(0.5, 0.5)
						item.Rotation = math.deg(math.atan2(delta.Y, delta.X))
						item.BackgroundTransparency = if selected then 0 else config.AlternateTransparency
					end
				end
				-- Flags and summary use matching step numbers for the selected route.
				if selected then
					for index, step in route.Steps do
						local point = route.Points[step.Index]
						if point and floorAt(point.Y) == floor then
							caption(
								"StepFlag",
								tostring(index),
								project(point),
								if step.CoverBreak or step.Kind == "Hack" then GameConfig.UI.WarningColor else color
							)
						end
					end
				end
				local goal = route.Points[#route.Points]
				if goal and floorAt(goal.Y) == floor and selected then
					caption("Destination", "◎", project(goal), color)
				end
			end
			if result then
				-- The selected line stays on top when both share a corridor.
				line(if mode == "Clean" then result.Fast else result.Clean, if mode == "Clean" then "Fast" else "Clean")
				line(if mode == "Clean" then result.Clean else result.Fast, mode)
			end
			if floorAt(origin.Y) == floor then
				caption("You", "▲", project(origin), theme.TextColor)
			end
		end,
		marks = function(points: { Vector3 })
			tracked:Cleanup()
			local project, floorAt = projectMark, markFloorAt
			if not project or not floorAt or not markFloor then
				return
			end
			for _, point in points do
				if floorAt(point.Y) == markFloor then
					caption("TrackedMark", "●", project(point), GameConfig.CarrierTrackHud.MarkColor, true)
				end
			end
		end,
		Destroy = function()
			tracked:Destroy()
			content:Destroy()
		end,
	}
end

return RouteMap
