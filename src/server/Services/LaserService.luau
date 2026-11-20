--!strict
-- Ticket 14: laser grids and their fuse boxes (spec 18.2).
--
--   * A laser grid (tag LaserGrid) fills a doorway into a Tier 2 or 3 room. A body inside it is across the beam. Wearing a
--     disguise of the doorway's tier or higher: nothing. Lower clearance, or Exposed (True Form): the alarm rises by
--     AlarmRaise and the agent is Exposed at once.
--   * A fuse box (made beside each grid at match start) cuts its grid for DisabledSeconds: hold Interact (kind "FuseBox")
--     FuseBoxSeconds. It is quiet, Suspicious only if witnessed (noteHacking). A Jammer will do the same (Step 17).
--
-- The grid is a map part: the server hides it while it is off (Transparency 1, attribute LaserOn false).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enums = require(Shared:WaitForChild("Enums"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Placement = require(script.Parent.Parent.Security.Placement)
local AlarmService = require(script.Parent.AlarmService)
local CoverService = require(script.Parent.CoverService)
local DisguiseService = require(script.Parent.DisguiseService)
local DownedService = require(script.Parent.DownedService)
local InteractService = require(script.Parent.InteractService)
local MatchService = require(script.Parent.MatchService)
local ZoneService = require(script.Parent.ZoneService)

type Grid = {
	id: string,
	part: BasePart,
	tier: number, -- the clearance that walks through
	shownTransparency: number,
	offUntil: number, -- os.clock(): the grid is cut until then
	fuseBox: BasePart?,
	lastTriggered: { [Player]: number },
}

local LaserService = {}

local config = GameConfig.Security.LaserGrid
local grids: { Grid } = {}
local byId: { [string]: Grid } = {}

local function isOn(grid: Grid): boolean
	return os.clock() >= grid.offUntil
end

local function show(grid: Grid)
	local on = isOn(grid)
	grid.part.Transparency = if on then grid.shownTransparency else 1
	grid.part:SetAttribute("LaserOn", on)
end

-- The tier of the room the grid guards: the higher of the zones on either side of the doorway.
local function tierOf(part: BasePart): number
	local size = part.Size
	local normal = if size.X <= size.Y and size.X <= size.Z
		then part.CFrame.RightVector
		elseif size.Z <= size.Y then part.CFrame.LookVector
		else part.CFrame.UpVector
	local probe = GameConfig.NPC.Door.SideProbeStuds
	return math.max(
		ZoneService.tierAt(part.Position + normal * probe),
		ZoneService.tierAt(part.Position - normal * probe)
	)
end

-- Inside the doorway and within CrossDepthStuds of the beam plane.
local function across(grid: Grid, position: Vector3): boolean
	local size = grid.part.Size
	local localPoint = grid.part.CFrame:PointToObjectSpace(position)
	local thin = if size.X <= size.Y and size.X <= size.Z then "X" elseif size.Z <= size.Y then "Z" else "Y"
	for _, axis in { "X", "Y", "Z" } do
		local reach = if axis == thin then config.CrossDepthStuds else (size :: any)[axis] / 2
		if math.abs((localPoint :: any)[axis]) > reach then
			return false
		end
	end
	return true
end

-- Is this player standing in a live beam? (Spec 27 #23: a disguise cannot be changed there.)
function LaserService.inBeam(player: Player): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return false
	end
	for _, grid in grids do
		if isOn(grid) and across(grid, root.Position) then
			return true
		end
	end
	return false
end

local function tick()
	if not MatchService.isInMatch() then
		return
	end
	local now = os.clock()
	for _, grid in grids do
		if grid.part:GetAttribute("LaserOn") ~= isOn(grid) then
			show(grid)
		end
		if isOn(grid) then
			for _, player in Players:GetPlayers() do
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if
					root
					and root:IsA("BasePart")
					and not DownedService.isOut(player)
					and across(grid, root.Position)
					and now - (grid.lastTriggered[player] or -math.huge) >= config.RetriggerSeconds
				then
					if CoverService.isExposed(player) or DisguiseService.getClearance(player) < grid.tier then
						grid.lastTriggered[player] = now
						AlarmService.raise(config.AlarmRaise, `Laser grid {grid.id} crossed by {player.Name}`)
						CoverService.expose(player, "LaserGrid")
					end
				end
			end
		end
	end
end

local function beginFuseBox(player: Player, targetName: string): InteractService.Interaction?
	local grid = byId[targetName]
	local box = grid and grid.fuseBox
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if
		not (grid and box and root and root:IsA("BasePart"))
		or not MatchService.isInMatch()
		or DownedService.isOut(player)
	then
		return nil
	end
	local reach = config.FuseBox.InteractStuds
	if not isOn(grid) or (box.Position - root.Position).Magnitude > reach then
		return nil
	end
	CoverService.noteHacking(player)
	return {
		label = "Cut power",
		seconds = config.FuseBoxSeconds,
		stillValid = function()
			CoverService.noteHacking(player)
			return not DownedService.isOut(player) and (box.Position - root.Position).Magnitude <= reach
		end,
		complete = function()
			grid.offUntil = os.clock() + config.DisabledSeconds
			show(grid)
		end,
	}
end

local function makeFuseBox(grid: Grid, folder: Folder)
	local settings = config.FuseBox
	local spot = Placement.clearSpot(grid.part.Position, settings.Size, settings.MinStuds, settings.MaxStuds)
	if not spot then
		warn(`[LaserService] No clear floor near laser grid {grid.id} for a fuse box`)
		return
	end
	local box = Instance.new("Part")
	box.Name = "FuseBox"
	box.Anchored = true
	box.Size = settings.Size
	box.Position = spot
	box.Color = Color3.fromRGB(70, 72, 78)
	box.Material = Enum.Material.Metal
	box:SetAttribute("SecurityId", grid.id)
	CollectionService:AddTag(box, Enums.Tag.FuseBox)
	box.Parent = folder
	grid.fuseBox = box
end

-- Ticket 17c (Jammer): every laser grid within `radius` of `position` is off for `seconds` from now; asked again, it stays off.
function LaserService.jamAt(position: Vector3, radius: number, seconds: number)
	local now = os.clock()
	for _, grid in grids do
		if (grid.part.Position - position).Magnitude <= radius then
			grid.offUntil = math.max(grid.offUntil, now + seconds)
			show(grid)
		end
	end
end

function LaserService.Init() end

function LaserService.Start()
	DisguiseService.setSwapBlocker(LaserService.inBeam)
	local folder = workspace:FindFirstChild("SecurityObjects") or Instance.new("Folder")
	folder.Name = "SecurityObjects"
	folder.Parent = workspace
	for _, instance in CollectionService:GetTagged(Enums.Tag.LaserGrid) do
		if instance:IsA("BasePart") then
			local grid: Grid = {
				id = `L{#grids + 1}`,
				part = instance,
				tier = tierOf(instance),
				shownTransparency = instance.Transparency,
				offUntil = 0,
				fuseBox = nil,
				lastTriggered = {},
			}
			table.insert(grids, grid)
			byId[grid.id] = grid
			show(grid)
			makeFuseBox(grid, folder :: Folder)
		end
	end
	InteractService.register("FuseBox", beginFuseBox)
	MatchService.onPhaseChanged(function(phase)
		if phase == "Lobby" or phase == "Insertion" then
			for _, grid in grids do
				grid.offUntil = 0
				table.clear(grid.lastTriggered)
				show(grid)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		for _, grid in grids do
			grid.lastTriggered[player] = nil
		end
	end)
	local interval = 1 / config.CheckHz
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= interval then
			elapsed = 0
			tick()
		end
	end)
end

return LaserService
