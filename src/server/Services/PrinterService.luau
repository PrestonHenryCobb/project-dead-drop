--!strict
-- Gap-closing (2026-10-28): the Tier 4 keycard printer (SPEC_CHANGES: keycards, docs/MAP_PLAN_RELAYOUT.md).
--
--   * The map has five printer spots (tag KeycardPrinterSpot, invisible, unmarked). At Insertion KeycardPrinter.ActiveSpots of them
--     are chosen at random and a printer is made on each; the others stay empty. Nothing marks which one is active.
--   * Holding Interact (kind "KeycardPrinter") on the printer for Doors.KeycardPrinter.Seconds costs the team Cost intel (taken when
--     the hold ends) and gives that agent a Tier 4 keycard. It is hacking-like, so it is suspicious if witnessed. One card at a time.
--   * The card is single use (SecurityService spends it with useCard) and is lost when its holder is eliminated. A new match clears
--     every card.
--
--   PrinterService.hasCard(player) -> boolean
--   PrinterService.useCard(player) -> boolean     spends the card

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enums = require(Shared:WaitForChild("Enums"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local CoverService = require(script.Parent.CoverService)
local DownedService = require(script.Parent.DownedService)
local IntelService = require(script.Parent.IntelService)
local InteractService = require(script.Parent.InteractService)
local MatchService = require(script.Parent.MatchService)
local RemoteService = require(script.Parent.RemoteService)
local TeamService = require(script.Parent.TeamService)

local PrinterService = {}

local settings = GameConfig.Doors.KeycardPrinter
local printerConfig = settings.Printer
local rng = Random.new()
local cards: { [Player]: boolean } = {}
local printers: { [string]: BasePart } = {}
local folder: Folder? = nil

local mapParams = RaycastParams.new()
mapParams.CollisionGroup = GameConfig.Rig.CollisionGroup
mapParams.RespectCanCollide = true

function PrinterService.hasCard(player: Player): boolean
	return cards[player] == true
end

function PrinterService.useCard(player: Player): boolean
	if cards[player] then
		cards[player] = nil
		return true
	end
	return false
end

local function begin(player: Player, printerId: string): InteractService.Interaction?
	local printer = printers[printerId]
	local teamId = TeamService.teamOf(player)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if
		not (printer and teamId and root and root:IsA("BasePart"))
		or not MatchService.isInMatch()
		or MatchService.phase() == "Insertion"
		or DownedService.isOut(player)
	then
		return nil
	end
	local function inReach(): boolean
		local offset = printer:GetClosestPointOnSurface(root.Position) - root.Position
		if offset.Magnitude > printerConfig.InteractStuds then
			return false
		end
		local hit = workspace:Raycast(
			root.Position,
			offset - offset.Unit * math.min(printerConfig.WallSlackStuds, offset.Magnitude),
			mapParams
		)
		return hit == nil or hit.Instance == printer
	end
	if not inReach() then
		return nil
	end
	if cards[player] then
		RemoteService.fireClient("Notification", player, "You already hold a keycard")
		return nil
	end
	if IntelService.balance(teamId) < settings.Cost then
		RemoteService.fireClient("Notification", player, `Needs {settings.Cost} intel`)
		return nil
	end
	CoverService.noteHacking(player)
	return {
		label = "Print keycard",
		seconds = settings.Seconds,
		stillValid = function()
			CoverService.noteHacking(player)
			return not DownedService.isOut(player)
				and inReach()
				and not cards[player]
				and IntelService.balance(teamId) >= settings.Cost
		end,
		complete = function()
			if cards[player] or not IntelService.spend(teamId, settings.Cost) then
				return
			end
			cards[player] = true
			RemoteService.fireClient("Notification", player, "Tier 4 keycard printed")
		end,
	}
end

local function clear()
	table.clear(cards)
	table.clear(printers)
	if folder then
		folder:Destroy()
		folder = nil
	end
end

local function setup()
	clear()
	local spots: { BasePart } = {}
	for _, instance in CollectionService:GetTagged(Enums.Tag.KeycardPrinterSpot) do
		if instance:IsA("BasePart") then
			table.insert(spots, instance)
		end
	end
	table.sort(spots, function(a, b)
		return tostring(a:GetAttribute("PrinterId")) < tostring(b:GetAttribute("PrinterId"))
	end)
	local holder = Instance.new("Folder")
	holder.Name = "KeycardPrinters"
	holder.Parent = workspace
	folder = holder
	for _ = 1, math.min(settings.ActiveSpots, #spots) do
		local spot = table.remove(spots, rng:NextInteger(1, #spots)) :: BasePart
		local id = tostring(spot:GetAttribute("PrinterId"))
		local printer = Instance.new("Part")
		printer.Name = "KeycardPrinter"
		printer.Anchored = true
		printer.Size = printerConfig.Size
		printer.Color = printerConfig.Color
		printer.Material = Enum.Material.Neon
		printer.CFrame = CFrame.new(spot.Position + Vector3.new(0, spot.Size.Y / 2 + printerConfig.Size.Y / 2, 0))
		printer:SetAttribute("PrinterId", id)
		printer.Parent = holder
		CollectionService:AddTag(printer, Enums.Tag.KeycardPrinter)
		printers[id] = printer
		if GameConfig.Debug.PrintEvents then
			print(`[PrinterService] printer on {id}`)
		end
	end
end

function PrinterService.Init() end

function PrinterService.Start()
	InteractService.register("KeycardPrinter", begin)
	MatchService.onPhaseChanged(function(phase)
		if phase == "Insertion" then
			setup()
		elseif phase == "Lobby" then
			clear()
		end
	end)
	-- A card is carried: its holder's elimination loses it, as for Assets (SPEC-QUESTION).
	DownedService.onEliminated(function(player)
		cards[player] = nil
	end)
	Players.PlayerRemoving:Connect(function(player)
		cards[player] = nil
	end)
end

return PrinterService
