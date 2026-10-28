--!strict
-- GPS carrier tracking (docs/GPS_DESIGN.md, owner answers 2026-10-28). Only the Package carrier can see rivals on the GPS, paid
-- for in the team's intel.
--
--   * The client sends RequestCarrierTrack(true) when the tracking key goes down and (false) when it comes up. The server tells
--     a tap from a hold: a press that ends within CarrierTrack.TapSeconds is a tap, a press still down after it is a hold.
--   * Tap: the nearest rival within CarrierTrack.Radius studs (through walls) is shown for PingSeconds; it costs TapCost intel,
--     and nothing when nobody is in range.
--   * Hold: every rival in range is sent live, SendHz times a second, for HoldCostPerSecond intel at the start and each second
--     after. It ends when the key goes up, the team cannot pay, or the carrier stops being the carrier (drops it, goes down, the
--     match ends).
--   * Rivals are the players of other teams and the bots, on their feet. The carrier is sent positions only, never who they are.
--   * A tracked player rival gets TrackedCue (no payload; the client draws a vignette and plays a whisper), again only after
--     CueRepeatSeconds. Tracking does not break the carrier's Cover.
--
-- Not shown: a crowd NPC (only the rivals above) and a downed or eliminated agent.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Types = require(Shared:WaitForChild("Types"))
local BotRegistry = require(script.Parent.Parent.Bots.BotRegistry)
local DownedService = require(script.Parent.DownedService)
local IntelService = require(script.Parent.IntelService)
local MatchService = require(script.Parent.MatchService)
local PackageService = require(script.Parent.PackageService)
local RemoteService = require(script.Parent.RemoteService)
local TeamService = require(script.Parent.TeamService)

type Rival = { position: Vector3, player: Player? }

type Press = {
	downAt: number,
	live: boolean,
	nextCharge: number,
	blocked: boolean, -- could not pay for the hold: nothing more until the key is released
	lastSent: number,
}

local CarrierTrackService = {}

local config = GameConfig.CarrierTrack
local presses: { [Player]: Press } = {}
local cuedAt: { [Player]: number } = {} -- when each rival was last sent the cue

local function rootOf(player: Player): BasePart?
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- Can this player track now: they carry the Package, in a match, on their feet.
local function canTrack(player: Player): boolean
	return PackageService.isCarrier(player) and MatchService.isInMatch() and not DownedService.isOut(player)
end

-- The rivals of the carrier's team within the radius of the carrier, nearest first.
local function rivalsNear(carrier: Player, teamId: number): { Rival }
	local root = rootOf(carrier)
	local found: { { rival: Rival, distance: number } } = {}
	if not root then
		return {}
	end
	local function consider(position: Vector3, player: Player?)
		local distance = (position - root.Position).Magnitude
		if distance <= config.Radius then
			table.insert(found, { rival = { position = position, player = player }, distance = distance })
		end
	end
	for _, other in Players:GetPlayers() do
		local otherRoot = rootOf(other)
		local otherTeam = TeamService.teamOf(other)
		if other ~= carrier and otherRoot and otherTeam ~= teamId and not DownedService.isOut(other) then
			consider(otherRoot.Position, other)
		end
	end
	for _, bot in BotRegistry.list() do
		if bot.teamId ~= teamId and BotRegistry.alive(bot) then
			consider(bot.npc.ground, nil)
		end
	end
	table.sort(found, function(a, b)
		return a.distance < b.distance
	end)
	local list: { Rival } = {}
	for _, entry in found do
		table.insert(list, entry.rival)
	end
	return list
end

local function marksOf(rivals: { Rival }): { Vector3 }
	local marks: { Vector3 } = {}
	for _, rival in rivals do
		table.insert(marks, rival.position)
	end
	return marks
end

local function cue(rivals: { Rival }, now: number)
	for _, rival in rivals do
		local player = rival.player
		if player and now - (cuedAt[player] or -math.huge) >= config.CueRepeatSeconds then
			cuedAt[player] = now
			RemoteService.fireClient("TrackedCue", player)
		end
	end
end

local function send(player: Player, mode: "Ping" | "Live" | "End", marks: { Vector3 }, teamId: number)
	local info: Types.CarrierTrackInfo = {
		Mode = mode,
		Marks = marks,
		Seconds = if mode == "Ping" then config.PingSeconds else nil,
		Intel = IntelService.balance(teamId),
	}
	RemoteService.fireClient("CarrierTrackState", player, info)
end

local function endLive(player: Player, press: Press)
	if press.live then
		press.live = false
		local teamId = TeamService.teamOf(player)
		if teamId then
			send(player, "End", {}, teamId)
		end
	end
end

local function tap(player: Player, teamId: number)
	local rivals = rivalsNear(player, teamId)
	local nearest = rivals[1]
	if not nearest then
		RemoteService.fireClient("Notification", player, "No rival in range")
		return
	end
	if not IntelService.spend(teamId, config.TapCost) then
		RemoteService.fireClient("Notification", player, `Needs {config.TapCost} intel`)
		return
	end
	send(player, "Ping", { nearest.position }, teamId)
	cue({ nearest }, os.clock())
end

local function onRequest(player: Player, down: unknown)
	if type(down) ~= "boolean" then
		return
	end
	local press = presses[player]
	if down then
		if not press and canTrack(player) then
			presses[player] = { downAt = os.clock(), live = false, nextCharge = 0, blocked = false, lastSent = 0 }
		end
		return
	end
	if not press then
		return
	end
	presses[player] = nil
	local teamId = TeamService.teamOf(player)
	if press.live then
		endLive(player, press)
	elseif not press.blocked and teamId and canTrack(player) and os.clock() - press.downAt < config.TapSeconds then
		tap(player, teamId)
	end
end

local function step()
	local now = os.clock()
	for player, press in presses do
		local teamId = TeamService.teamOf(player)
		if not (teamId and canTrack(player)) then
			endLive(player, press)
			presses[player] = nil
		elseif press.blocked then
			continue
		elseif not press.live and now - press.downAt >= config.TapSeconds then
			-- Still down after the tap window: a hold begins, paid for its first second now.
			if IntelService.spend(teamId, config.HoldCostPerSecond) then
				press.live = true
				press.nextCharge = now + 1
			else
				press.blocked = true
				RemoteService.fireClient("Notification", player, `Needs {config.HoldCostPerSecond} intel`)
			end
		elseif press.live then
			if now >= press.nextCharge then
				if IntelService.spend(teamId, config.HoldCostPerSecond) then
					press.nextCharge += 1
				else
					press.blocked = true
					endLive(player, press)
					RemoteService.fireClient("Notification", player, "Out of intel")
					continue
				end
			end
			if now - press.lastSent >= 1 / config.SendHz then
				press.lastSent = now
				local rivals = rivalsNear(player, teamId)
				send(player, "Live", marksOf(rivals), teamId)
				cue(rivals, now)
			end
		end
	end
end

function CarrierTrackService.Init() end

function CarrierTrackService.Start()
	RemoteService.onRequest("RequestCarrierTrack", onRequest)
	RunService.Heartbeat:Connect(step)
	MatchService.onPhaseChanged(function(phase)
		if phase == "Lobby" or phase == "Insertion" then
			table.clear(presses)
			table.clear(cuedAt)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		presses[player] = nil
		cuedAt[player] = nil
	end)
end

return CarrierTrackService
