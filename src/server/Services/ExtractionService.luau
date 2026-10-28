--!strict
-- Ticket 13a: extraction and the win (spec 12; spec 19 shortens the countdown in Overtime).
--
--   * Each ExtractionSite gets a "Call Extraction" terminal when the Package Heist begins.
--   * The Package carrier, or a teammate of the carrier within Extraction.CallRange of them, holds Interact on a terminal for
--     Extraction.CallSeconds. That starts a countdown (Extraction.Countdown, Overtime.ExtractionCountdown in Overtime) at that
--     site: a tall beacon shows map-wide and rivals are told. One extraction at a time; a new call by another team replaces
--     it only if the Package has changed hands to that team.
--   * At zero the helicopter hovers Extraction.HoverSeconds, then the zone (a Extraction.ZoneSize circle) goes green. The
--     carrier standing in it holds Interact Extraction.ChannelSeconds to win. Damage does not break the channel; being
--     downed, leaving the zone, dropping the Package, or an enemy standing in the zone does (SPEC_CHANGES 11: an enemy in
--     the zone freezes progress; the hold cannot pause, so it restarts).
--   * When a channel fails the zone stays open for Extraction.LingerAfterFailSeconds, then the extraction expires.
--   * A win freezes everyone for Extraction.CinematicSeconds, then MatchService.finish(winning team).
--
-- SPEC-QUESTION: the helicopter and the extraction cinematic are state only (ExtractionState "Hover", "Extracted"); the
-- visuals are client work. Nothing here knows which agent is which beyond the Package's carrier, whom everyone may see.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enums = require(Shared:WaitForChild("Enums"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Types = require(Shared:WaitForChild("Types"))
local CombatService = require(script.Parent.CombatService)
local DisguiseService = require(script.Parent.DisguiseService)
local DownedService = require(script.Parent.DownedService)
local InteractService = require(script.Parent.InteractService)
local MatchService = require(script.Parent.MatchService)
local PackageService = require(script.Parent.PackageService)
local RemoteService = require(script.Parent.RemoteService)
local TeamService = require(script.Parent.TeamService)

type Site = { id: string, marker: BasePart, terminal: BasePart? }
type Extraction = {
	state: "Idle" | "Countdown" | "Hover" | "Open" | "Extracted",
	site: Site?,
	callerTeam: number,
	endsAt: number, -- server clock: Countdown end, Hover end, or the Open window's expiry (0: no expiry yet)
	channeler: Player?,
	beacon: BasePart?,
	disc: BasePart?,
}

local ExtractionService = {}

local config = GameConfig.Extraction
local sites: { [string]: Site } = {}
local folder: Folder? = nil
local current: Extraction = { state = "Idle", site = nil, callerTeam = 0, endsAt = 0, channeler = nil }
local sinceCheck = 0

local function now(): number
	return workspace:GetServerTimeNow()
end

local function inMatch(): boolean
	local phase = MatchService.phase()
	return phase == "PackageHeist" or phase == "Overtime"
end

local function broadcast()
	for _, player in Players:GetPlayers() do
		local info: Types.ExtractionStateInfo = {
			State = current.state,
			SiteId = if current.site then current.site.id else nil,
			Position = if current.site then current.site.marker.Position else nil,
			EndsAt = if current.endsAt ~= 0 then current.endsAt else nil,
			ByYourTeam = current.state ~= "Idle" and TeamService.teamOf(player) == current.callerTeam,
		}
		RemoteService.fireClient("ExtractionState", player, info)
	end
end

local function dropVisuals()
	if current.beacon then
		current.beacon:Destroy()
		current.beacon = nil
	end
	if current.disc then
		current.disc:Destroy()
		current.disc = nil
	end
end

local function setIdle()
	dropVisuals()
	current.state, current.site, current.callerTeam, current.endsAt, current.channeler = "Idle", nil, 0, 0, nil
	broadcast()
end

local function neonPart(name: string, size: Vector3, cframe: CFrame, color: Color3): Part
	local created = Instance.new("Part")
	created.Name = name
	created.Anchored = true
	created.CanCollide = false
	created.CanQuery = false
	created.Material = Enum.Material.Neon
	created.Color = color
	created.Size = size
	created.CFrame = cframe
	created.Transparency = 0.4
	created.Parent = folder
	return created
end

local function flatDistance(a: Vector3, b: Vector3): number
	local offset = a - b
	return Vector3.new(offset.X, 0, offset.Z).Magnitude
end

-- Is this position on the pad (the zone), and level with it?
local function inZone(position: Vector3, site: Site): boolean
	return flatDistance(position, site.marker.Position) <= config.ZoneSize / 2
		and math.abs(position.Y - site.marker.Position.Y) <= config.ZoneHeightStuds
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function teamOfCarrier(): number?
	local carrier = PackageService.carrier()
	return carrier and TeamService.teamOf(carrier)
end

-- An agent of another team than the carrier's standing in the zone.
local function enemyInZone(site: Site, teamId: number): boolean
	for _, player in Players:GetPlayers() do
		local root = rootOf(player)
		local otherTeam = TeamService.teamOf(player)
		if
			root
			and otherTeam
			and otherTeam ~= teamId
			and not DownedService.isOut(player)
			and inZone(root.Position, site)
		then
			return true
		end
	end
	return false
end

local function beginCall(player: Player, siteId: string): InteractService.Interaction?
	local site = sites[siteId]
	local carrier = PackageService.carrier()
	local teamId = TeamService.teamOf(player)
	local root = rootOf(player)
	local carrierRoot = carrier and rootOf(carrier)
	if not (site and carrier and teamId and root and carrierRoot and site.terminal) or not inMatch() then
		return nil
	end
	if DownedService.isOut(player) or teamOfCarrier() ~= teamId then
		return nil
	end
	-- The carrier, or a teammate close to them (spec 12.1).
	if player ~= carrier and (carrierRoot.Position - root.Position).Magnitude > config.CallRange then
		return nil
	end
	-- A running extraction is replaced only when the Package has changed hands to the new caller's team.
	if current.state ~= "Idle" and (current.callerTeam == teamId or current.state == "Extracted") then
		return nil
	end
	local terminal = site.terminal
	local function near(slack: number): boolean
		return (terminal.Position - root.Position).Magnitude <= config.CallReachStuds + slack
	end
	if not near(0) then
		return nil
	end
	return {
		label = "Call extraction",
		seconds = config.CallSeconds,
		stillValid = function()
			return not DownedService.isOut(player) and PackageService.carrier() == carrier and near(config.SlackStuds)
		end,
		complete = function()
			if current.state == "Extracted" or PackageService.carrier() ~= carrier or teamOfCarrier() ~= teamId then
				return
			end
			dropVisuals()
			local seconds = if MatchService.phase() == "Overtime"
				then GameConfig.Overtime.ExtractionCountdown
				else config.Countdown
			current.state, current.site, current.callerTeam = "Countdown", site, teamId
			current.endsAt, current.channeler = now() + seconds, nil
			local up = site.marker.Position
			current.beacon = neonPart(
				"ExtractionBeacon",
				config.BeaconSize,
				CFrame.new(up + Vector3.new(0, config.BeaconSize.Y / 2, 0)),
				config.BeaconColor
			)
			RemoteService.fireAllClients("Notification", "EXTRACTION CALLED")
			broadcast()
		end,
	}
end

local function beginChannel(player: Player, siteId: string): InteractService.Interaction?
	local site = current.site
	local root = rootOf(player)
	if
		current.state ~= "Open"
		or not site
		or site.id ~= siteId
		or PackageService.carrier() ~= player
		or not root
		or DownedService.isOut(player)
		or not inZone(root.Position, site)
	then
		return nil
	end
	current.channeler = player
	current.endsAt = 0 -- a fresh try; the expiry returns only if this one fails
	broadcast()
	local teamId = TeamService.teamOf(player) or 0
	return {
		label = "Extract",
		seconds = config.ChannelSeconds,
		stillValid = function()
			local here = rootOf(player)
			return current.state == "Open"
				and PackageService.carrier() == player
				and here ~= nil
				and not DownedService.isOut(player)
				and inZone(here.Position, site)
				and not enemyInZone(site, teamId)
		end,
		complete = function()
			if current.state ~= "Open" or PackageService.carrier() ~= player then
				return
			end
			current.state, current.channeler = "Extracted", nil
			broadcast()
			-- Spec 12.3: everything stops for the cinematic, then the match ends with this team the winner.
			for _, member in Players:GetPlayers() do
				if member.Character then
					CombatService.setFrozen(member, true)
					DisguiseService.setFrozen(member, true)
				end
			end
			task.delay(config.CinematicSeconds, function()
				MatchService.finish(teamId)
			end)
		end,
	}
end

local function open()
	local site = current.site
	if not site then
		return
	end
	current.state, current.endsAt = "Open", 0
	local size = config.ZoneSize
	local disc = neonPart(
		"ExtractionZone",
		Vector3.new(0.3, size, size),
		CFrame.new(site.marker.Position + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		config.ZoneColor
	)
	disc.Shape = Enum.PartType.Cylinder
	current.disc = disc
	broadcast()
end

local function check()
	local clock = now()
	if current.state == "Idle" or current.state == "Extracted" then
		return
	end
	if not inMatch() then
		setIdle()
		return
	end
	if current.state == "Countdown" then
		if clock >= current.endsAt then
			current.state, current.endsAt = "Hover", clock + config.HoverSeconds
			broadcast()
		end
	elseif current.state == "Hover" then
		if clock >= current.endsAt then
			open()
		end
	elseif current.state == "Open" then
		local channeler = current.channeler
		if channeler and not InteractService.isBusy(channeler) then
			-- The hold ended without winning: the zone stays open for a while, then the call expires.
			current.channeler = nil
			current.endsAt = clock + config.LingerAfterFailSeconds
			broadcast()
		elseif not channeler and current.endsAt ~= 0 and clock >= current.endsAt then
			setIdle()
		end
	end
end

local function createTerminals()
	local holder = Instance.new("Folder")
	holder.Name = "ExtractionObjects"
	holder.Parent = workspace
	folder = holder
	for _, site in sites do
		local base = site.marker.Position
		local terminal = Instance.new("Part")
		terminal.Name = "ExtractionTerminal"
		terminal.Anchored = true
		terminal.Size = config.TerminalSize
		terminal.Material = Enum.Material.Neon
		terminal.Color = config.TerminalColor
		terminal.CFrame = CFrame.new(base + Vector3.new(0, config.TerminalSize.Y / 2, 0))
		terminal:SetAttribute("SiteId", site.id)
		terminal.Parent = holder
		CollectionService:AddTag(terminal, Enums.Tag.ExtractionTerminal)
		site.terminal = terminal
	end
end

local function clear()
	dropVisuals()
	if folder then
		folder:Destroy()
		folder = nil
	end
	for _, site in sites do
		site.terminal = nil
	end
	current.state, current.site, current.callerTeam, current.endsAt, current.channeler = "Idle", nil, 0, 0, nil
end

function ExtractionService.Init() end

function ExtractionService.Start()
	for _, instance in CollectionService:GetTagged(Enums.Tag.ExtractionSite) do
		local id = instance:GetAttribute("Site")
		if instance:IsA("BasePart") and type(id) == "string" then
			sites[id] = { id = id, marker = instance, terminal = nil }
		end
	end
	InteractService.register("ExtractionCall", beginCall)
	InteractService.register("ExtractionChannel", beginChannel)
	MatchService.onPhaseChanged(function(phase)
		if phase == "PackageHeist" then
			createTerminals()
		elseif phase == "Insertion" or phase == "Lobby" then
			clear()
			broadcast()
		end
	end)
	RunService.Heartbeat:Connect(function(dt)
		sinceCheck += dt
		if sinceCheck >= 1 / config.CheckHz then
			sinceCheck = 0
			check()
		end
	end)
end

return ExtractionService
