--!strict
-- Ticket 18c: the Supply Cache shop (spec 17.3, priced in intel because Funds are gone).
--
--   * Interact with a cache (tag SupplyCache, hold kind "SupplyCache", Shop.OpenSeconds, quiet) opens the shop for that agent:
--     they are sent ShopState with the items, this cache's prices and why any cannot be bought. One agent at a time per cache.
--   * RequestShopBuy(itemId) starts a purchase: it needs the team's intel, an item that has a use now, and takes PurchaseSeconds
--     near the cache. Buying breaks Cover (spec 17.3), from the moment it begins. The price is taken when it finishes.
--   * The shop closes when the agent asks (RequestShopClose), goes further than InteractStuds + SlackStuds from the cache, is
--     downed, or the match ends.
--   * A cache in a zone of HigherTierMinTier or more is HigherTierDiscount cheaper (spec 17.3).
--   * Items: an armour plate, a full ammo refill, healing to full, a gadget charge, an ability cooldown reset, and a Security
--     Keycard of SecurityKeycardUses uses. Each use of a keycard opens a keycard door in KeycardSeconds without breaking Cover
--     (SecurityService asks keycardUses and useKeycard). Rescuing a teammate is Step 18d.
-- The shop's screen is the client's (ShopState); nothing here draws anything.
--
--   SupplyService.keycardUses(player) -> number
--   SupplyService.useKeycard(player) -> boolean     spends one use

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enums = require(Shared:WaitForChild("Enums"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Types = require(Shared:WaitForChild("Types"))
local AbilityService = require(script.Parent.AbilityService)
local CombatService = require(script.Parent.CombatService)
local CoverService = require(script.Parent.CoverService)
local DownedService = require(script.Parent.DownedService)
local GadgetService = require(script.Parent.GadgetService)
local IntelService = require(script.Parent.IntelService)
local InteractService = require(script.Parent.InteractService)
local MatchService = require(script.Parent.MatchService)
local RemoteService = require(script.Parent.RemoteService)
local TeamService = require(script.Parent.TeamService)
local ZoneService = require(script.Parent.ZoneService)

type Cache = { part: BasePart, id: string, tier: number?, user: Player? }
type Session = { cache: Cache, buying: string?, buyId: number }

local SupplyService = {}

local config = GameConfig.Economy.Shop
local caches: { [string]: Cache } = {}
local sessions: { [Player]: Session } = {}
local keycards: { [Player]: number } = {}

function SupplyService.keycardUses(player: Player): number
	return keycards[player] or 0
end

function SupplyService.useKeycard(player: Player): boolean
	local uses = keycards[player] or 0
	if uses <= 0 then
		return false
	end
	keycards[player] = if uses > 1 then uses - 1 else nil
	return true
end

local function priceOf(cache: Cache, base: number): number
	if cache.tier == nil then
		cache.tier = ZoneService.tierAt(cache.part.Position) -- read when first needed: the zones are made at boot
	end
	if (cache.tier :: number) < config.HigherTierMinTier then
		return base
	end
	return math.max(1, math.floor(base * (1 - config.HigherTierDiscount) + 0.5))
end

-- Why an item has no use for this player now, or nil if it does.
local function unavailable(player: Player, itemId: string): string?
	if itemId == "ArmorPlate" then
		return if CombatService.canTakePlate(player) then nil else "Armour is full"
	elseif itemId == "AmmoRefill" then
		return if CombatService.canRefillAmmo(player) then nil else "Ammo is full"
	elseif itemId == "HealToFull" then
		return if CombatService.isHurt(player) then nil else "Already at full health"
	elseif itemId == "GadgetCharge" then
		return if GadgetService.canAddCharge(player) then nil else "Gadget charges are full"
	elseif itemId == "AbilityCooldownReset" then
		return if AbilityService.onCooldown(player) then nil else "Ability is ready"
	elseif itemId == "SecurityKeycard" then
		return if SupplyService.keycardUses(player) < config.SecurityKeycardUses then nil else "Keycard is full"
	end
	return "Unknown item"
end

local function apply(player: Player, itemId: string)
	if itemId == "ArmorPlate" then
		CombatService.addPlate(player)
	elseif itemId == "AmmoRefill" then
		CombatService.refillAmmo(player)
	elseif itemId == "HealToFull" then
		CombatService.heal(player, GameConfig.Combat.MaxHP)
	elseif itemId == "GadgetCharge" then
		GadgetService.addCharge(player)
	elseif itemId == "AbilityCooldownReset" then
		AbilityService.resetCooldown(player)
	elseif itemId == "SecurityKeycard" then
		keycards[player] = config.SecurityKeycardUses
	end
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") and not DownedService.isOut(player) then
		return root
	end
	return nil
end

local function distanceToCache(cache: Cache, root: BasePart): number
	return (cache.part:GetClosestPointOnSurface(root.Position) - root.Position).Magnitude
end

local function send(player: Player, session: Session?, open: boolean)
	local teamId = TeamService.teamOf(player)
	local info: Types.ShopStateInfo = {
		Open = open,
		CacheId = if session then session.cache.id else "",
		Intel = if teamId then IntelService.balance(teamId) else 0,
		Items = {},
		Buying = if session then session.buying else nil,
		BuySeconds = config.PurchaseSeconds,
	}
	if open and session then
		for _, item in config.Items do
			local reason = unavailable(player, item.Id)
			table.insert(info.Items, {
				Id = item.Id,
				Name = item.Name,
				Price = priceOf(session.cache, item.Price),
				Available = reason == nil,
				Reason = reason or "",
			})
		end
	end
	RemoteService.fireClient("ShopState", player, info)
end

local function close(player: Player)
	local session = sessions[player]
	if session then
		sessions[player] = nil
		session.cache.user = nil
		send(player, nil, false)
	end
end

local function beginOpen(player: Player, cacheId: string): InteractService.Interaction?
	local cache = caches[cacheId]
	local root = rootOf(player)
	if
		not (cache and root and TeamService.teamOf(player))
		or not MatchService.isInMatch()
		or MatchService.phase() == "Insertion"
		or (cache.user ~= nil and cache.user ~= player)
		or distanceToCache(cache, root) > config.InteractStuds
	then
		return nil
	end
	return {
		label = "Supply Cache",
		seconds = config.OpenSeconds,
		stillValid = function()
			local body = rootOf(player)
			return body ~= nil and distanceToCache(cache, body) <= config.InteractStuds + config.SlackStuds
		end,
		complete = function()
			if cache.user ~= nil and cache.user ~= player then
				return
			end
			close(player)
			local session: Session = { cache = cache, buying = nil, buyId = 0 }
			sessions[player] = session
			cache.user = player
			send(player, session, true)
		end,
	}
end

local function onBuy(player: Player, itemId: unknown)
	local session = sessions[player]
	local root = rootOf(player)
	local teamId = TeamService.teamOf(player)
	if not (session and root and teamId) or type(itemId) ~= "string" or session.buying then
		return
	end
	local price: number? = nil
	for _, item in config.Items do
		if item.Id == itemId then
			price = priceOf(session.cache, item.Price)
		end
	end
	if not price or unavailable(player, itemId) or IntelService.balance(teamId) < price then
		send(player, session, true) -- refused: show the shop as it stands
		return
	end
	session.buying = itemId
	session.buyId += 1
	local buyId = session.buyId
	CoverService.expose(player, "Shop") -- buying breaks Cover (spec 17.3)
	send(player, session, true)
	task.delay(config.PurchaseSeconds, function()
		if sessions[player] ~= session or session.buyId ~= buyId then
			return
		end
		session.buying = nil
		local body = rootOf(player)
		if
			body
			and distanceToCache(session.cache, body) <= config.InteractStuds + config.SlackStuds
			and unavailable(player, itemId) == nil
			and IntelService.spend(teamId, price :: number)
		then
			apply(player, itemId)
		end
		send(player, session, true)
	end)
end

local function checkSessions()
	for player, session in sessions do
		local root = rootOf(player)
		if
			not root
			or not MatchService.isInMatch()
			or distanceToCache(session.cache, root) > config.InteractStuds + config.SlackStuds
		then
			close(player)
		end
	end
end

function SupplyService.Init() end

function SupplyService.Start()
	local parts: { BasePart } = {}
	for _, instance in CollectionService:GetTagged(Enums.Tag.SupplyCache) do
		if instance:IsA("BasePart") then
			table.insert(parts, instance)
		end
	end
	-- A fixed order, so an id means the same cache on every server.
	table.sort(parts, function(a, b)
		local pa, pb = a.Position, b.Position
		if pa.Y ~= pb.Y then
			return pa.Y < pb.Y
		elseif pa.X ~= pb.X then
			return pa.X < pb.X
		end
		return pa.Z < pb.Z
	end)
	for index, part in parts do
		local id = `S{index}`
		part:SetAttribute("CacheId", id)
		caches[id] = { part = part, id = id, tier = nil, user = nil }
	end
	InteractService.register("SupplyCache", beginOpen)
	RemoteService.onRequest("RequestShopBuy", onBuy)
	RemoteService.onRequest("RequestShopClose", function(player: Player)
		close(player)
	end)
	MatchService.onPhaseChanged(function(phase)
		if phase == "Insertion" then
			table.clear(keycards)
			for player in sessions do
				close(player)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		local session = sessions[player]
		if session then
			session.cache.user = nil
		end
		sessions[player] = nil
		keycards[player] = nil
	end)
	local interval = 1 / config.CheckHz
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= interval then
			elapsed = 0
			checkSessions()
		end
	end)
end

return SupplyService
