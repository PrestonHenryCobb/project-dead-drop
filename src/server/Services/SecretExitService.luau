--!strict
-- Ticket 7B-secret-exits (SPEC_CHANGES 2026-10-25 "Owner traversal additions"): a small set of prop-triggered secret exits. Each is a
-- wall panel (tag SecretExit, attribute ExitId) between a restricted room and its neighbour, and a lever (tag SecretExitTrigger,
-- same ExitId) inside the restricted room. The map generator builds both (Tools/Gala, 8 exits).
--
--   * Hold Interact (kind "SecretExit", target the ExitId) for SecretExit.HoldSeconds. The server allows it only while the player is
--     in the match and up, inside the restricted room (the lever's side of the wall), within InteractStuds of the lever, facing it
--     within FacingDegrees, with a clear line to it. There is no activation from outside or through a wall.
--   * It is Discreet (CoverService.noteHacking): it breaks Cover only if a witness sees it, like a hack.
--   * Done, the panel opens (no collision, hidden) for OpenSeconds, and anyone can walk through in either direction. It will not close
--     while a body is still in the doorway; it then closes. Opening again waits until it is shut.
--   * Everything is shut again at Lobby and Insertion.
--
-- Nothing is put on a character. The panel and lever are map parts (public, like every door).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enums = require(Shared:WaitForChild("Enums"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local CoverService = require(script.Parent.CoverService)
local DownedService = require(script.Parent.DownedService)
local InteractService = require(script.Parent.InteractService)
local MatchService = require(script.Parent.MatchService)

local SecretExitService = {}

local config = GameConfig.SecretExit

type Exit = {
	id: string,
	panel: BasePart,
	lever: BasePart,
	inside: Vector3, -- unit vector across the wall, pointing into the restricted room
	openUntil: number, -- os.clock(); 0 while shut
	token: number, -- bumps on every open and shut, so a stale timer does nothing
}

local exits: { [string]: Exit } = {}

local sight = RaycastParams.new()
sight.CollisionGroup = GameConfig.Rig.CollisionGroup
sight.RespectCanCollide = true

local function setOpen(exit: Exit, open: boolean)
	exit.panel.CanCollide = not open
	exit.panel.Transparency = if open then 1 else 0
end

local function bodyInDoorway(exit: Exit): boolean
	local size = exit.panel.Size + Vector3.one * config.ClearStuds * 2
	for _, part in workspace:GetPartBoundsInBox(exit.panel.CFrame, size) do
		if part.Name == "HumanoidRootPart" then
			return true
		end
	end
	return false
end

local function shut(exit: Exit, token: number)
	if exit.token ~= token then
		return
	end
	if bodyInDoorway(exit) then
		task.delay(config.ClearCheckSeconds, shut, exit, token) -- wait for whoever is in the opening to walk out
		return
	end
	exit.openUntil = 0
	setOpen(exit, false)
end

local function open(exit: Exit)
	exit.token += 1
	exit.openUntil = os.clock() + config.OpenSeconds
	setOpen(exit, true)
	task.delay(config.OpenSeconds, shut, exit, exit.token)
end

local function resetAll()
	for _, exit in exits do
		exit.token += 1
		exit.openUntil = 0
		setOpen(exit, false)
	end
end

-- Inside the restricted room, near the lever, facing it, with a clear line to it. Used both to offer the hold and to keep it valid.
local function mayPull(exit: Exit, root: BasePart): boolean
	local toLever = exit.lever.Position - root.Position
	if toLever.Magnitude > config.InteractStuds then
		return false
	end
	-- Which side of the wall: the lever's side, which is the restricted room's.
	if (root.Position - exit.panel.Position):Dot(exit.inside) <= 0 then
		return false
	end
	local flat = Vector3.new(toLever.X, 0, toLever.Z)
	local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	if flat.Magnitude > 1e-3 and look.Magnitude > 1e-3 then
		local angle = math.deg(math.acos(math.clamp(look.Unit:Dot(flat.Unit), -1, 1)))
		if angle > config.FacingDegrees then
			return false
		end
	end
	-- The ray ends at the lever's centre, so it meets the lever's own surface first: that is not something in the way.
	local hit = workspace:Raycast(root.Position, toLever, sight)
	return hit == nil or hit.Instance == exit.lever
end

local function begin(player: Player, targetName: string): InteractService.Interaction?
	local exit = exits[targetName]
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if
		not exit
		or not (root and root:IsA("BasePart"))
		or not MatchService.isInMatch()
		or DownedService.isOut(player)
		or exit.openUntil ~= 0
		or not mayPull(exit, root)
	then
		return nil
	end
	CoverService.noteHacking(player) -- Discreet: broken Cover only if witnessed
	return {
		label = "Pull the lever",
		seconds = config.HoldSeconds,
		stillValid = function()
			CoverService.noteHacking(player)
			return not DownedService.isOut(player) and exit.openUntil == 0 and mayPull(exit, root)
		end,
		complete = function()
			if exit.openUntil == 0 then
				open(exit)
			end
		end,
	}
end

function SecretExitService.Init() end

-- Joins a panel and a lever that share an ExitId into one exit. Called for every tagged part, at Start and whenever one arrives later (the
-- map can be built after the services start), so it works in whichever order they appear.
local panels: { [string]: BasePart } = {}
local levers: { [string]: BasePart } = {}

local function tryRegister(id: string)
	local panel, lever = panels[id], levers[id]
	if exits[id] or not (panel and lever) then
		return
	end
	-- The wall panel is thin on one axis: that axis runs across the wall.
	local size = panel.Size
	local across = if size.X <= size.Y and size.X <= size.Z
		then panel.CFrame.RightVector
		elseif size.Z <= size.Y then panel.CFrame.LookVector
		else panel.CFrame.UpVector
	local sign = if (lever.Position - panel.Position):Dot(across) >= 0 then 1 else -1
	exits[id] = {
		id = id,
		panel = panel,
		lever = lever,
		inside = across * sign,
		openUntil = 0,
		token = 0,
	}
end

local function addTagged(instance: Instance, into: { [string]: BasePart })
	local id = instance:GetAttribute("ExitId")
	if instance:IsA("BasePart") and type(id) == "string" then
		into[id] = instance
		tryRegister(id)
	end
end

function SecretExitService.Start()
	for _, instance in CollectionService:GetTagged(Enums.Tag.SecretExitTrigger) do
		addTagged(instance, levers)
	end
	for _, instance in CollectionService:GetTagged(Enums.Tag.SecretExit) do
		addTagged(instance, panels)
	end
	CollectionService:GetInstanceAddedSignal(Enums.Tag.SecretExitTrigger):Connect(function(instance)
		addTagged(instance, levers)
	end)
	CollectionService:GetInstanceAddedSignal(Enums.Tag.SecretExit):Connect(function(instance)
		addTagged(instance, panels)
	end)
	InteractService.register("SecretExit", begin)
	MatchService.onPhaseChanged(function(phase)
		if phase == "Lobby" or phase == "Insertion" then
			resetAll()
		end
	end)
end

return SecretExitService
