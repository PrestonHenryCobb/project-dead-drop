--!strict
-- Spectating (SPEC_CHANGES 14.4, ticket 9c). An eliminated player watches the match until it ends:
--   * Living teammates first (Teammate mode), cycling with Next and Previous.
--   * Once the whole team is out, any living player (Player mode), or a drone camera (Drone mode) bounded by the
--     map's zone volumes, so it can pass through walls but never leave the buildings, terraces and streets.
--   * A spectator chat that only eliminated players receive; the living never hear it.
--
-- The server owns who may be watched and where the drone may be. The client draws the camera and sends the drone's
-- wanted position; the server limits its speed, clamps it into the volumes and streams the map around it. Spectators
-- are already out of play, so telling them which characters are players leaks nothing to anyone still in the match
-- (CLAUDE.md rule 3 is about the living).
--
--   SpectateService.isSpectating(player) -> boolean
--   SpectateService.stopAll()                   everyone goes back to the lobby (the match ended)
--   SpectateService.watchMatch(player)          someone who joined while a match runs watches it (spec 27 #5)

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enums = require(Shared:WaitForChild("Enums"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Types = require(Shared:WaitForChild("Types"))
local Validate = require(Shared:WaitForChild("Util"):WaitForChild("Validate"))
local DownedService = require(script.Parent.DownedService)
local RemoteService = require(script.Parent.RemoteService)
local TeamService = require(script.Parent.TeamService)

local SpectateService = {}

type Spectator = {
	mode: string, -- "Teammate", "Player", "Drone" or "None"
	target: Player?,
	canDrone: boolean,
	dronePos: Vector3,
	droneAt: number, -- os.clock() of the last accepted drone position
	streamAt: number,
	lastPos: Vector3?, -- where the last watched character was, for the drone to start from
}

local config = GameConfig.Spectate
local spectators: { [Player]: Spectator } = {}
local volumes: { BasePart } = {}
local checkElapsed = 0

local function addVolume(instance: Instance)
	if instance:IsA("BasePart") and not table.find(volumes, instance) then
		table.insert(volumes, instance)
	end
end

local function removeVolume(instance: Instance)
	local index = table.find(volumes, instance :: BasePart)
	if index then
		table.remove(volumes, index)
	end
end

-- The nearest point to `position` that lies inside (or within the margin of) any zone volume.
local function clampToVolumes(position: Vector3): Vector3
	local best = position
	local bestDistance = math.huge
	for _, part in volumes do
		local cf = part.CFrame
		local local3 = cf:PointToObjectSpace(position)
		local half = part.Size / 2 + Vector3.one * config.DroneMarginStuds
		local clamped = Vector3.new(
			math.clamp(local3.X, -half.X, half.X),
			math.clamp(local3.Y, -half.Y, half.Y),
			math.clamp(local3.Z, -half.Z, half.Z)
		)
		local distance = (clamped - local3).Magnitude
		if distance == 0 then
			return position
		end
		if distance < bestDistance then
			bestDistance = distance
			best = cf:PointToWorldSpace(clamped)
		end
	end
	return best
end

-- Downed teammates are still alive: they can be revived, so they can be watched.
local function living(player: Player): boolean
	return DownedService.isDowned(player) or not DownedService.isOut(player)
end

local function byUserId(a: Player, b: Player): boolean
	return a.UserId < b.UserId
end

-- Who this spectator may watch, and whether any of their own team is still alive.
local function candidates(spectator: Player): ({ Player }, boolean)
	local list = {}
	local teamId = TeamService.teamOf(spectator)
	if teamId then
		for _, member in TeamService.members(teamId) do
			if member ~= spectator and living(member) then
				table.insert(list, member)
			end
		end
	end
	if #list > 0 then
		table.sort(list, byUserId)
		return list, true
	end
	for _, other in Players:GetPlayers() do
		if other ~= spectator and living(other) then
			table.insert(list, other)
		end
	end
	table.sort(list, byUserId)
	return list, false
end

local function sendState(player: Player, state: Spectator, dronePosition: Vector3?)
	local info: Types.SpectateStateInfo = {
		Mode = state.mode,
		TargetUserId = if state.target then state.target.UserId else nil,
		CanDrone = state.canDrone,
		DronePosition = dronePosition,
	}
	RemoteService.fireClient("SpectateState", player, info)
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function startDrone(player: Player, state: Spectator)
	local from = state.lastPos
	if not from then
		local root = rootOf(player)
		from = if root then root.Position else Vector3.zero
	end
	state.mode = "Drone"
	state.target = nil
	state.dronePos = clampToVolumes((from :: Vector3) + Vector3.new(0, config.DroneStartHeight, 0))
	state.droneAt = os.clock()
	sendState(player, state, state.dronePos)
end

local function follow(player: Player, state: Spectator, target: Player, teamAlive: boolean)
	state.mode = if teamAlive then "Teammate" else "Player"
	state.target = target
	sendState(player, state, nil)
end

-- Keeps one spectator's view legal: the watched player must still be living, a drone only once the team is out.
local function refresh(player: Player, state: Spectator)
	local list, teamAlive = candidates(player)
	state.canDrone = not teamAlive and #volumes > 0
	if state.mode == "Drone" then
		if state.canDrone then
			return
		end
		state.target = nil -- a teammate lives again (revived), or there are no volumes: leave the drone
	end
	local target = state.target
	if target and table.find(list, target) then
		local label = if teamAlive then "Teammate" else "Player"
		if state.mode ~= label then
			state.mode = label
			sendState(player, state, nil)
		end
		return
	end
	if #list > 0 then
		follow(player, state, list[1], teamAlive)
	elseif state.canDrone then
		startDrone(player, state)
	elseif state.mode ~= "None" or target ~= nil then
		state.mode, state.target = "None", nil
		sendState(player, state, nil)
	end
end

local function begin(player: Player)
	if spectators[player] then
		return
	end
	local root = rootOf(player)
	local state: Spectator = {
		mode = "None",
		target = nil,
		canDrone = false,
		dronePos = root and root.Position or Vector3.zero,
		droneAt = os.clock(),
		streamAt = 0,
		lastPos = root and root.Position or nil,
	}
	spectators[player] = state
	sendState(player, state, nil)
	refresh(player, state)
end

local function finish(player: Player)
	if not spectators[player] then
		return
	end
	spectators[player] = nil
	if player.Parent then
		RemoteService.fireClient(
			"SpectateState",
			player,
			{ Mode = "None", CanDrone = false } :: Types.SpectateStateInfo
		)
	end
end

local function cycle(player: Player, state: Spectator, step: number)
	local list, teamAlive = candidates(player)
	if #list == 0 then
		return
	end
	local index = if state.target then table.find(list, state.target) else nil
	local nextIndex = if index then (index - 1 + step) % #list + 1 else 1
	follow(player, state, list[nextIndex], teamAlive)
end

local function onRequest(player: Player, action: unknown)
	local state = spectators[player]
	if not state or type(action) ~= "string" then
		return
	end
	if action == "Next" then
		cycle(player, state, 1)
	elseif action == "Previous" then
		cycle(player, state, -1)
	elseif action == "Drone" then
		if state.mode == "Drone" then
			cycle(player, state, 1)
		else
			refresh(player, state) -- recompute canDrone before judging it
			if state.canDrone then
				startDrone(player, state)
			end
		end
	end
end

local function onDronePosition(player: Player, wanted: unknown)
	local state = spectators[player]
	local target = Validate.vector3(wanted)
	if not state or state.mode ~= "Drone" or not target then
		return
	end
	local now = os.clock()
	local elapsed = math.clamp(now - state.droneAt, 0, 1)
	state.droneAt = now
	local offset = target - state.dronePos
	local maxStep = config.DroneSpeed * config.DroneBoost * config.DroneStepSlack * elapsed + 1
	if offset.Magnitude > maxStep then
		offset = offset.Unit * maxStep
	end
	local accepted = clampToVolumes(state.dronePos + offset)
	state.dronePos = accepted
	if (accepted - target).Magnitude > config.DroneSnapStuds then
		sendState(player, state, accepted) -- the client was too fast or went outside: put its camera back
	end
end

local function onChat(player: Player, text: unknown)
	if not spectators[player] or type(text) ~= "string" then
		return
	end
	local line = string.sub(text, 1, config.ChatMaxLength)
	if string.match(line, "^%s*$") then
		return
	end
	local ok, result = pcall(TextService.FilterStringAsync, TextService, line, player.UserId)
	if not ok then
		return
	end
	local filtered = result :: TextFilterResult
	for recipient in spectators do
		local readOk, message = pcall(filtered.GetChatForUserAsync, filtered, recipient.UserId)
		if readOk and recipient.Parent then
			local info: Types.SpectatorChatInfo = { Sender = player.DisplayName, Text = message :: string }
			RemoteService.fireClient("SpectatorChat", recipient, info)
		end
	end
end

-- Ticket 10a: the match is over, so every spectator goes back to the lobby.
function SpectateService.stopAll()
	for player in spectators do
		finish(player)
	end
end

-- Spec 27 #5: a player who joins (or rejoins) while a match is running cannot take part in it. They spectate until it ends,
-- exactly as an eliminated player does; stopAll sends them back to the lobby then.
function SpectateService.watchMatch(player: Player)
	begin(player)
end

function SpectateService.isSpectating(player: Player): boolean
	return spectators[player] ~= nil
end

function SpectateService.Init()
	for _, instance in CollectionService:GetTagged(Enums.Tag.ZoneVolume) do
		addVolume(instance)
	end
end

function SpectateService.Start()
	CollectionService:GetInstanceAddedSignal(Enums.Tag.ZoneVolume):Connect(addVolume)
	CollectionService:GetInstanceRemovedSignal(Enums.Tag.ZoneVolume):Connect(removeVolume)
	DownedService.onEliminated(function(player)
		begin(player)
		-- Whoever they were watching, or whose team just ran out, may need a new view.
		for other, state in spectators do
			if other ~= player then
				refresh(other, state)
			end
		end
	end)
	local function watch(player: Player)
		player.CharacterAdded:Connect(function()
			task.defer(function()
				if spectators[player] and not DownedService.isOut(player) then
					finish(player) -- a new life
				end
			end)
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		spectators[player] = nil
		for other, state in spectators do
			refresh(other, state)
		end
	end)
	RemoteService.onRequest("RequestSpectate", onRequest)
	RemoteService.onRequest("RequestDronePosition", onDronePosition)
	RemoteService.onRequest("RequestSpectatorChat", onChat)
	RunService.Heartbeat:Connect(function(dt)
		checkElapsed += dt
		local recheck = checkElapsed >= config.TargetCheckSeconds
		if recheck then
			checkElapsed = 0
		end
		local now = os.clock()
		for player, state in spectators do
			if recheck then
				refresh(player, state)
			end
			if now - state.streamAt >= config.StreamSeconds then
				state.streamAt = now
				local watched = state.target and rootOf(state.target)
				if watched then
					state.lastPos = watched.Position
					player:RequestStreamAround(watched.Position)
				elseif state.mode == "Drone" then
					player:RequestStreamAround(state.dronePos)
				end
			end
		end
	end)
end

return SpectateService
