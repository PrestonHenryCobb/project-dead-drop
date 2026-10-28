--!strict
-- Ticket 17: sub-gadgets (docs/GADGETS_DRAFT.md, SPEC_CHANGES 16.1). Each player carries GameConfig.Gadgets.Slots of them,
-- from their loadout (GadgetIds) or the default picks. Every gadget has three phases:
--   * Equip (keys 1 to 3, RequestGadget "Equip", slot 0 for the weapon): quiet, swaps what the fire button means. Holding a
--     gadget never affects Cover; hidden from others while disguised because nothing is shown for it.
--   * Deploy (the fire button, "Deploy"): the held gadget does its thing and spends a charge. Only this affects Cover, at the
--     gadget's own level (Quiet, Discreet: CoverService.useDiscreetly, or Breaks).
--   * Alternate (the aim button, "Alternate"): for a deployable, e.g. recalling it.
-- The player is told their gadgets, charges and what is held with GadgetState. Charges are full at the start of a match;
-- Supply Caches refill them (Step 18). Each gadget is a module in src/server/Gadgets, listed below as it is built.
--
--   GadgetService.heldSlot(player) -> number     0 when the weapon is held

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GadgetDefs = require(Shared:WaitForChild("Defs"):WaitForChild("GadgetDefs"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Types = require(Shared:WaitForChild("Types"))
local Gadget = require(script.Parent.Parent.Gadgets.Gadget)
local AbilityService = require(script.Parent.AbilityService)
local DownedService = require(script.Parent.DownedService)
local MatchService = require(script.Parent.MatchService)
local MetaProgressionService = require(script.Parent.MetaProgressionService)
local RemoteService = require(script.Parent.RemoteService)

type Slot = { id: string, charges: number }
type Kit = { slots: { Slot }, held: number }

local GadgetService = {}

local config = GameConfig.Gadgets
local gadgets: { [string]: Gadget.Gadget } = {
	MedInjector = require(script.Parent.Parent.Gadgets.MedInjector),
	PlatePack = require(script.Parent.Parent.Gadgets.PlatePack),
	SpringPad = require(script.Parent.Parent.Gadgets.SpringPad),
	NoiseMaker = require(script.Parent.Parent.Gadgets.NoiseMaker),
	DisguiseKit = require(script.Parent.Parent.Gadgets.DisguiseKit),
}
local kits: { [Player]: Kit } = {}

local function build(player: Player): Kit
	local loadout = MetaProgressionService.getLoadout(player)
	local ids = (loadout and loadout.GadgetIds) or config.DefaultPicks
	local slots: { Slot } = {}
	for index = 1, config.Slots do
		local def = ids[index] and GadgetDefs.get(ids[index])
		if def then
			table.insert(slots, { id = def.Id, charges = def.Charges })
		end
	end
	return { slots = slots, held = 0 }
end

local function send(player: Player, kit: Kit)
	local info: Types.GadgetStateInfo = { Slots = {}, Held = kit.held }
	for _, slot in kit.slots do
		table.insert(info.Slots, { Id = slot.id, Charges = slot.charges })
	end
	RemoteService.fireClient("GadgetState", player, info)
end

function GadgetService.heldSlot(player: Player): number
	local kit = kits[player]
	return if kit then kit.held else 0
end

-- Alive, in a match after Insertion, and on their feet.
local function canAct(player: Player): boolean
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil
		and humanoid.Health > 0
		and MatchService.isInMatch()
		and MatchService.phase() ~= "Insertion"
		and not DownedService.isOut(player)
end

local function onRequest(player: Player, action: unknown, slot: unknown)
	if not canAct(player) then
		return
	end
	local kit = kits[player]
	if not kit then
		kit = build(player)
		kits[player] = kit
		send(player, kit)
	end
	if action == "Equip" then
		if
			type(slot) == "number"
			and slot == math.floor(slot)
			and slot >= 0
			and slot <= #kit.slots
			and slot ~= kit.held
		then
			kit.held = slot
			send(player, kit)
		end
		return
	end
	local held = kit.slots[kit.held]
	if not held then
		return
	end
	local gadget = gadgets[held.id]
	if action == "Deploy" and held.charges > 0 then
		local used, reason = gadget.deploy(player, AbilityService.rulesOf(player))
		if used then
			held.charges -= 1
			send(player, kit)
		elseif reason then
			RemoteService.fireClient("Notification", player, reason)
		end
	elseif action == "Alternate" and gadget.alternate then
		gadget.alternate(player)
	end
end

function GadgetService.Init() end

function GadgetService.Start()
	RemoteService.onRequest("RequestGadget", onRequest)
	for _, gadget in gadgets do
		if gadget.start then
			gadget.start()
		end
	end
	-- A new match: full charges, the weapon in hand.
	MatchService.onPhaseChanged(function(phase)
		if phase == "Insertion" then
			for _, player in Players:GetPlayers() do
				local kit = build(player)
				kits[player] = kit
				send(player, kit)
			end
		end
	end)
	local function watch(player: Player)
		player.CharacterAdded:Connect(function()
			local kit = kits[player]
			if kit and kit.held ~= 0 then
				kit.held = 0 -- a new life starts with the weapon
				send(player, kit)
			end
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		kits[player] = nil
	end)
end

return GadgetService
