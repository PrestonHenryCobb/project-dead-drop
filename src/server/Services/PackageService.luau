--!strict
-- Ticket 13a: the Package (spec 11, spec 19 overtime rules).
--
--   * It appears on the Sanctum's pedestal when the Package Heist begins (all active vault terminals hacked).
--   * Hold Interact within Package.PickupRange for Package.PickupSeconds to take it; the first hold to finish wins.
--   * The carrier is Exposed for as long as they hold it and cannot disguise or re-cover (CoverService, DisguiseService),
--     walks at Package.CarrierSpeedMult, and cannot ride ziplines. Vents cannot be blocked: SPEC-QUESTION, a physical duct
--     cannot refuse a body, so the carrier is Exposed in it anyway (they already are).
--   * The carrier can pass it to the nearest living teammate within Package.PassRange (hold Interact Package.PassSeconds)
--     and drop it (RequestDropPackage, key X). Downed, eliminated or leaving drops it where they stood.
--   * A dropped Package falls with physics. Untouched for Package.ReturnSeconds, or out of the map (below Package.MinY),
--     it goes back to the pedestal and everyone is told. In Overtime a drop starts Overtime.DroppedGraceSeconds, after
--     which the match ends with no winner (MatchService.finish).
--   * Everyone is told where a resting Package is. Rivals of the carrier are told where it is for Package.PingPulseSeconds
--     every Package.PingInterval (PackageState); the carrier's own team is only told it has it.
--
--   PackageService.isCarrier(player) -> boolean
--   PackageService.carrier() -> Player?
--   PackageService.isHeld() -> boolean

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enums = require(Shared:WaitForChild("Enums"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Types = require(Shared:WaitForChild("Types"))
local CoverService = require(script.Parent.CoverService)
local DisguiseService = require(script.Parent.DisguiseService)
local DownedService = require(script.Parent.DownedService)
local InteractService = require(script.Parent.InteractService)
local MatchService = require(script.Parent.MatchService)
local RemoteService = require(script.Parent.RemoteService)
local TeamService = require(script.Parent.TeamService)

type Status = "Hidden" | "Pedestal" | "Carried" | "Dropped"

local PackageService = {}

local config = GameConfig.Package

local status: Status = "Hidden"
local carrier: Player? = nil
local part: Part? = nil
local weld: WeldConstraint? = nil
local lastCarrierPosition = Vector3.zero
local pedestalPosition = Vector3.zero
local returnsAt = 0 -- server clock: a dropped Package goes back then
local graceEndsAt: number? = nil -- server clock: Overtime ends then unless someone has it
local nextPulseAt = 0
local pulseUntil = 0
local sinceCheck = 0

local function now(): number
	return workspace:GetServerTimeNow()
end

function PackageService.isCarrier(player: Player): boolean
	return carrier == player
end

function PackageService.carrier(): Player?
	return carrier
end

function PackageService.isHeld(): boolean
	return status == "Carried"
end

local function inMatch(): boolean
	local phase = MatchService.phase()
	return phase == "PackageHeist" or phase == "Overtime"
end

-- Each player's own view: everyone sees where a resting Package is; rivals see a carried one only during a pulse.
local function send()
	local clock = now()
	local pulsing = status == "Carried" and clock < pulseUntil
	for _, player in Players:GetPlayers() do
		local teamId = TeamService.teamOf(player)
		local carrierTeam = carrier and TeamService.teamOf(carrier)
		local mine = carrier ~= nil and carrierTeam ~= nil and carrierTeam == teamId
		local position: Vector3? = nil
		if status == "Pedestal" or status == "Dropped" then
			position = part and part.Position
		elseif pulsing and not mine then
			position = lastCarrierPosition
		end
		local info: Types.PackageStateInfo = {
			State = status,
			Position = position,
			YouCarry = carrier == player,
			TeamCarries = mine,
			PulseUntil = if pulsing then pulseUntil else nil,
			ReturnsAt = if status == "Dropped" then returnsAt else nil,
		}
		RemoteService.fireClient("PackageState", player, info)
	end
end

local function clearWeld()
	if weld then
		weld:Destroy()
		weld = nil
	end
end

local function setFree(player: Player)
	CoverService.setPackageCarrier(player, false)
	DisguiseService.setCarrier(player, false)
end

local function returnToPedestal()
	local package = part
	if not package then
		return
	end
	clearWeld()
	if carrier then
		setFree(carrier)
		carrier = nil
	end
	package.Anchored = true
	package.CanCollide = false
	package.AssemblyLinearVelocity = Vector3.zero
	package.CFrame = CFrame.new(pedestalPosition)
	status = "Pedestal"
	graceEndsAt = nil
	RemoteService.fireAllClients("Notification", "The Package has returned to the Sanctum.")
	send()
end

-- Puts the Package down at a position, falling with physics.
local function drop(at: Vector3)
	local package = part
	if not package then
		return
	end
	clearWeld()
	if carrier then
		setFree(carrier)
		carrier = nil
	end
	package.Anchored = false
	package.CanCollide = true
	package.Massless = false
	package.CFrame = CFrame.new(at)
	package.AssemblyLinearVelocity = Vector3.zero
	package:SetNetworkOwner(nil)
	status = "Dropped"
	returnsAt = now() + config.ReturnSeconds
	if MatchService.phase() == "Overtime" then
		graceEndsAt = now() + GameConfig.Overtime.DroppedGraceSeconds
	end
	send()
end

local function grant(player: Player)
	local package = part
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (package and root and root:IsA("BasePart")) then
		return
	end
	clearWeld()
	if carrier and carrier ~= player then
		setFree(carrier)
	end
	carrier = player
	status = "Carried"
	graceEndsAt = nil
	package.Anchored = false
	package.CanCollide = false
	package.Massless = true
	package.CFrame = root.CFrame * config.CarryOffset
	local joint = Instance.new("WeldConstraint")
	joint.Part0 = root
	joint.Part1 = package
	joint.Parent = package
	weld = joint
	lastCarrierPosition = root.Position
	CoverService.setPackageCarrier(player, true)
	DisguiseService.setCarrier(player, true)
	nextPulseAt = now() + config.PingInterval
	pulseUntil = 0
	send()
end

local function beginPickup(player: Player, _: string): InteractService.Interaction?
	local package = part
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if
		not (package and root and root:IsA("BasePart"))
		or not inMatch()
		or (status ~= "Pedestal" and status ~= "Dropped")
		or DownedService.isOut(player)
		or carrier ~= nil
	then
		return nil
	end
	local function inReach(slack: number): boolean
		return (package.Position - root.Position).Magnitude <= config.PickupRange + slack
	end
	if not inReach(0) then
		return nil
	end
	return {
		label = "Take the Package",
		seconds = config.PickupSeconds,
		stillValid = function()
			return (status == "Pedestal" or status == "Dropped")
				and not DownedService.isOut(player)
				and inReach(config.PickupSlackStuds)
		end,
		complete = function()
			-- Two holds finishing together: the first to complete wins, the second finds it taken.
			if status == "Pedestal" or status == "Dropped" then
				grant(player)
			end
		end,
	}
end

local function nearestTeammate(from: Player): Player?
	local character = from.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return nil
	end
	local best: Player? = nil
	local bestDistance = config.PassRange
	for _, other in Players:GetPlayers() do
		local otherCharacter = other.Character
		local otherRoot = otherCharacter and otherCharacter:FindFirstChild("HumanoidRootPart")
		if
			TeamService.areTeammates(from, other)
			and otherRoot
			and otherRoot:IsA("BasePart")
			and not DownedService.isOut(other)
		then
			local distance = (otherRoot.Position - root.Position).Magnitude
			if distance <= bestDistance then
				best, bestDistance = other, distance
			end
		end
	end
	return best
end

local function beginPass(player: Player, _: string): InteractService.Interaction?
	if carrier ~= player or status ~= "Carried" or DownedService.isOut(player) then
		return nil
	end
	local receiver = nearestTeammate(player)
	if not receiver then
		return nil
	end
	return {
		label = "Pass the Package",
		seconds = config.PassSeconds,
		stillValid = function()
			return carrier == player and not DownedService.isOut(player) and nearestTeammate(player) ~= nil
		end,
		complete = function()
			local target = nearestTeammate(player)
			if carrier == player and target then
				grant(target)
			end
		end,
	}
end

local function onDrop(player: Player)
	if carrier ~= player or status ~= "Carried" then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		local forward = root.CFrame.LookVector * config.DropForwardStuds
		drop(root.Position + forward + Vector3.new(0, config.DropLiftStuds, 0))
	else
		drop(lastCarrierPosition)
	end
end

local function create()
	local package = Instance.new("Part")
	package.Name = "Package"
	package.Size = config.Size
	package.Color = config.Color
	package.Material = Enum.Material.Neon
	package.Anchored = true
	package.CanCollide = false
	package.CFrame = CFrame.new(pedestalPosition)
	local light = Instance.new("PointLight")
	light.Color = config.Color
	light.Range = config.LightRange
	light.Parent = package
	package.Parent = workspace
	CollectionService:AddTag(package, Enums.Tag.PackageItem)
	part = package
end

local function reset()
	clearWeld()
	if carrier then
		setFree(carrier)
	end
	carrier, graceEndsAt = nil, nil
	if part then
		part:Destroy()
		part = nil
	end
	status = "Hidden"
end

local function findPedestal(): Vector3?
	local fallback: BasePart? = nil
	for _, instance in CollectionService:GetTagged(Enums.Tag.PackagePedestal) do
		if instance:IsA("BasePart") then
			if instance:GetAttribute("VaultId") == "Sanctum" then
				return instance.Position + Vector3.new(0, instance.Size.Y / 2 + config.LiftStuds, 0)
			end
			fallback = fallback or instance
		end
	end
	return fallback and fallback.Position + Vector3.new(0, fallback.Size.Y / 2 + config.LiftStuds, 0)
end

local function check()
	local clock = now()
	if status == "Carried" then
		local who = carrier
		local character = who and who.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not who or DownedService.isOut(who) or not (root and root:IsA("BasePart")) then
			drop(lastCarrierPosition + Vector3.new(0, config.DropLiftStuds, 0)) -- where they went down
		else
			lastCarrierPosition = root.Position
			if clock >= nextPulseAt then
				nextPulseAt = clock + config.PingInterval
				pulseUntil = clock + config.PingPulseSeconds
				send()
			elseif pulseUntil ~= 0 and clock >= pulseUntil then
				pulseUntil = 0
				send()
			end
		end
	elseif status == "Dropped" then
		local package = part
		if package and (clock >= returnsAt or package.Position.Y < config.MinY) then
			returnToPedestal()
		end
	end
	if graceEndsAt and clock >= graceEndsAt and MatchService.phase() == "Overtime" and status ~= "Carried" then
		graceEndsAt = nil
		MatchService.finish(nil) -- nobody picked it up in time (spec 19)
	end
end

function PackageService.Init() end

function PackageService.Start()
	MatchService.setPackageCheck(PackageService.isHeld)
	InteractService.register("Package", beginPickup)
	InteractService.register("PackagePass", beginPass)
	RemoteService.onRequest("RequestDropPackage", onDrop)
	MatchService.onPhaseChanged(function(phase)
		if phase == "PackageHeist" then
			local position = findPedestal()
			if position then
				pedestalPosition = position
				create()
				status = "Pedestal"
				send()
			end
		elseif phase == "Insertion" or phase == "Lobby" or phase == "Results" then
			reset()
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		if carrier == player then
			drop(lastCarrierPosition)
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

return PackageService
