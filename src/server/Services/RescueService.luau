--!strict
-- Ticket 18d: Agent Tags and Rescue (spec 14.1, 14.2; the price is intel, Downed.Rescue.Cost).
--
--   * An eliminated agent drops an Agent Tag, a small glowing badge, where they fell; it stays AgentTagSeconds. (Solos: none,
--     there is no rescue.) Nothing on the badge says whose it is.
--   * A living teammate holds Interact on it (kind "AgentTag", TagPickupSeconds, quiet) to carry it. If its carrier is eliminated
--     the tags they carried drop where they fell.
--   * At a Supply Cache the carrier buys "Rescue teammate" (SupplyService; it takes CacheSeconds and breaks Cover). The
--     rescued agent comes back at the Insertion Point nearest the cache as a random Guest, with 100 HP, the usual starting
--     plates and their ability on AbilityCooldownMult of its cooldown. Each agent can be rescued MaxPerPlayer times a match.
--     Rescue is off during Overtime.
--
--   RescueService.canRescue(player) -> (boolean, string?)    can this carrier rescue someone now; if not, why
--   RescueService.rescue(player, near)                       brings back the first eligible agent whose tag they carry

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enums = require(Shared:WaitForChild("Enums"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local AbilityService = require(script.Parent.AbilityService)
local DownedService = require(script.Parent.DownedService)
local InteractService = require(script.Parent.InteractService)
local MatchService = require(script.Parent.MatchService)
local TeamService = require(script.Parent.TeamService)

type Tag = { id: string, part: Part, owner: Player }

local RescueService = {}

local config = GameConfig.Downed.Rescue
local tags: { [string]: Tag } = {}
local carrying: { [Player]: { Player } } = {} -- the agents whose tags a player carries
local rescued: { [Player]: number } = {} -- times each agent has been rescued this match
local nextTagId = 0

local floorParams = RaycastParams.new()
floorParams.CollisionGroup = GameConfig.Rig.CollisionGroup
floorParams.RespectCanCollide = true

local function removeTag(tag: Tag)
	tags[tag.id] = nil
	tag.part:Destroy()
end

local function dropTag(owner: Player, position: Vector3)
	nextTagId += 1
	local id = `T{nextTagId}`
	local floor = workspace:Raycast(position + Vector3.new(0, 2, 0), Vector3.new(0, -12, 0), floorParams)
	local part = Instance.new("Part")
	part.Name = "AgentTag"
	part.Size = config.TagSize
	part.Color = config.TagColor
	part.Material = Enum.Material.Neon
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CastShadow = false
	part.Position = (if floor then floor.Position else position) + Vector3.new(0, config.TagLiftStuds, 0)
	part:SetAttribute("TagId", id)
	CollectionService:AddTag(part, Enums.Tag.AgentTag)
	part.Parent = workspace
	local tag: Tag = { id = id, part = part, owner = owner }
	tags[id] = tag
	task.delay(GameConfig.Downed.AgentTagSeconds, function()
		if tags[id] == tag then
			removeTag(tag)
		end
	end)
end

local function onEliminated(player: Player)
	if TeamService.isSolos() or not MatchService.isInMatch() then
		return
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return
	end
	dropTag(player, root.Position)
	-- What they carried falls with them.
	for _, owner in carrying[player] or {} do
		dropTag(owner, root.Position)
	end
	carrying[player] = nil
end

local function beginPickup(player: Player, tagId: string): InteractService.Interaction?
	local tag = tags[tagId]
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if
		not (tag and root and root:IsA("BasePart"))
		or DownedService.isOut(player)
		or tag.owner == player
		or not TeamService.areTeammates(player, tag.owner)
	then
		return nil
	end
	local function inReach(): boolean
		return (tag.part.Position - root.Position).Magnitude <= GameConfig.Downed.InteractStuds
	end
	if not inReach() then
		return nil
	end
	return {
		label = "Take Agent Tag",
		seconds = config.TagPickupSeconds,
		stillValid = function()
			return not DownedService.isOut(player)
				and inReach()
				and tags[tagId] == tag
				and (player.Character :: Model?) == root.Parent
		end,
		complete = function()
			if tags[tagId] ~= tag then
				return
			end
			removeTag(tag)
			carrying[player] = carrying[player] or {}
			table.insert(carrying[player], tag.owner)
		end,
	}
end

-- The first agent whose tag the carrier has and who can still be rescued.
local function nextOwner(carrier: Player): (Player?, number?)
	for index, owner in carrying[carrier] or {} do
		if owner.Parent and DownedService.isOut(owner) and (rescued[owner] or 0) < config.MaxPerPlayer then
			return owner, index
		end
	end
	return nil, nil
end

function RescueService.canRescue(player: Player): (boolean, string?)
	if TeamService.isSolos() then
		return false, "No rescue in Solos"
	elseif MatchService.phase() == "Overtime" then
		return false, "Rescue is off during Overtime"
	elseif #(carrying[player] or {}) == 0 then
		return false, "Carry an Agent Tag"
	elseif not nextOwner(player) then
		return false, "Nobody left to rescue"
	end
	return true, nil
end

-- Puts the agent back in the match at the Insertion Point nearest `near`.
local function revive(owner: Player, near: Vector3)
	MatchService.reinstate(owner)
	rescued[owner] = (rescued[owner] or 0) + 1
	owner:LoadCharacter() -- a new life: DisguiseService gives a random Guest look, CombatService full health and ammo
	local character = owner.Character
	local root = character and character:WaitForChild("HumanoidRootPart", 5)
	if not (character and root) then
		return
	end
	local best: BasePart? = nil
	local bestDistance = math.huge
	for _, point in CollectionService:GetTagged(Enums.Tag.InsertionPoint) do
		if point:IsA("BasePart") and (point.Position - near).Magnitude < bestDistance then
			best, bestDistance = point, (point.Position - near).Magnitude
		end
	end
	if best then
		character:PivotTo(CFrame.new(best.Position + Vector3.new(0, config.SpawnLiftStuds, 0)))
	end
	AbilityService.setCooldownFraction(owner, config.AbilityCooldownMult)
end

function RescueService.rescue(player: Player, near: Vector3)
	local owner, index = nextOwner(player)
	if not (owner and index) then
		return
	end
	table.remove(carrying[player], index)
	task.spawn(revive, owner, near)
end

function RescueService.Init() end

function RescueService.Start()
	InteractService.register("AgentTag", beginPickup)
	DownedService.onEliminated(onEliminated)
	DownedService.onLeftDowned(onEliminated) -- spec 27 #4: a downed player who leaves drops their tag too
	MatchService.onPhaseChanged(function(phase)
		if phase == "Insertion" then
			for _, tag in tags do
				removeTag(tag)
			end
			table.clear(carrying)
			table.clear(rescued)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		carrying[player] = nil
		rescued[player] = nil
	end)
end

return RescueService
