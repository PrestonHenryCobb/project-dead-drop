--!strict
-- Ticket 21-rewards (spec 20.1 to 20.3): account XP, levels and Credits. During a match the services that see something worth XP
-- tell this one; when the match finishes, MatchService hands over who won and who was still up, and each player's total goes to
-- their profile (MetaProgressionService.settleAccount), which pays the level-up Credits, the win bonus and the daily first-win
-- bonus. The player is then sent their own breakdown (MatchRewards), and nobody else sees it.
--
--   RewardService.award(player, event)            an XP event from GameConfig.Rewards.Xp, every time
--   RewardService.awardOnce(player, event)        the same, but only the first time this match
--   RewardService.carrying(player)                called each check while they hold the Package; pays PackageCarried every tick
--   RewardService.vaultPresence(players, dt)      players on a terminal's dais for dt seconds; pays VaultParticipation once a match
--   RewardService.finishMatch(entries)            the match is over: settle everyone
--   RewardService.reset()                         a new match: forget the last one's tallies
--
-- Mastery (MetaProgressionService.recordMatch) is separate: it levels the agent played, this levels the account.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Types = require(Shared:WaitForChild("Types"))
local MetaProgressionService = require(script.Parent.MetaProgressionService)
local RemoteService = require(script.Parent.RemoteService)

local RewardService = {}

export type Entry = { player: Player, won: boolean, survived: boolean }

local config = GameConfig.Rewards

type Tally = {
	lines: { Types.MatchRewardLine },
	once: { [string]: boolean },
	carryAt: number, -- os.clock() of the last carrying() call; 0 before the first
	carrySeconds: number,
	vaultSeconds: number,
}

local tallies: { [Player]: Tally } = {}

local function tallyOf(player: Player): Tally
	local tally = tallies[player]
	if not tally then
		tally = { lines = {}, once = {}, carryAt = 0, carrySeconds = 0, vaultSeconds = 0 }
		tallies[player] = tally
	end
	return tally :: Tally
end

function RewardService.award(player: Player, event: string)
	local amount = (config.Xp :: { [string]: number })[event]
	if amount then
		table.insert(tallyOf(player).lines, { Event = event, Xp = amount })
	end
end

function RewardService.awardOnce(player: Player, event: string)
	local tally = tallyOf(player)
	if not tally.once[event] then
		tally.once[event] = true
		RewardService.award(player, event)
	end
end

function RewardService.carrying(player: Player)
	local tally = tallyOf(player)
	local now = os.clock()
	if tally.carryAt == 0 or now - tally.carryAt > config.CarryTickSeconds then
		tally.carrySeconds = 0 -- they just took it, or had it taken off them for a while
	else
		tally.carrySeconds += now - tally.carryAt
	end
	tally.carryAt = now
	while tally.carrySeconds >= config.CarryTickSeconds do
		tally.carrySeconds -= config.CarryTickSeconds
		RewardService.award(player, "PackageCarried")
	end
end

function RewardService.vaultPresence(players: { Player }, dt: number)
	for _, player in players do
		local tally = tallyOf(player)
		if not tally.once.VaultParticipation then
			tally.vaultSeconds += dt
			if tally.vaultSeconds >= config.VaultParticipationSeconds then
				RewardService.awardOnce(player, "VaultParticipation")
			end
		end
	end
end

function RewardService.finishMatch(entries: { Entry })
	for _, entry in entries do
		local player = entry.player
		RewardService.award(player, "MatchPlayed")
		if entry.won then
			RewardService.award(player, "ExtractionWin")
		end
		if entry.survived then
			RewardService.award(player, "SurvivedToEnd")
		end
		local lines = tallyOf(player).lines
		local total = 0
		for _, line in lines do
			total += line.Xp
		end
		local info = MetaProgressionService.settleAccount(player, total, entry.won)
		if info and player.Parent then
			info.Lines = lines
			RemoteService.fireClient("MatchRewards", player, info)
		end
	end
	table.clear(tallies)
end

function RewardService.reset()
	table.clear(tallies)
end

function RewardService.Init() end

function RewardService.Start()
	Players.PlayerRemoving:Connect(function(player)
		tallies[player] = nil
	end)
end

return RewardService
