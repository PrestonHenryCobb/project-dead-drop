--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local GameConfig = require(Shared.GameConfig)
local ObjectivePresentation = {}

function ObjectivePresentation.new()
	local phase: Types.Phase? = nil
	local balance: number? = nil
	local used: { [string]: boolean } = {}
	local terminals: { Types.VaultTerminalInfo } = {}
	local holdStarted: number? = nil
	local holdSeconds = 0
	local bannerUntil = 0
	return {
		phase = function(nextPhase: Types.Phase, data: Types.PhaseData)
			phase = nextPhase
			bannerUntil = if data.Banner then data.StartedAt + GameConfig.Match.BannerSeconds else 0
			if phase == "Lobby" then
				balance = nil
				table.clear(used)
				table.clear(terminals)
			end
			if phase == "Lobby" or phase == "Insertion" or phase == "Results" then
				holdStarted = nil
			end
		end,
		intel = function(info: Types.IntelUpdateInfo)
			balance = info.Balance
			table.clear(used)
			for _, id in info.Used do
				used[id] = true
			end
		end,
		vault = function(info: Types.VaultProgressInfo)
			terminals = table.clone(info.Terminals)
		end,
		interaction = function(info: Types.InteractStateInfo, now: number)
			holdStarted = if info.Active and info.Kind == "Hack" then now else nil
			holdSeconds = info.Seconds
		end,
		view = function(serverNow: number, localNow: number)
			local active = phase == "Infiltration"
				or phase == "VaultBreach"
				or phase == "PackageHeist"
				or phase == "Overtime"
			local count = 0
			for _ in used do
				count += 1
			end
			return {
				active = active,
				balance = if active then balance else nil,
				used = used,
				usedCount = count,
				hacking = active and holdStarted ~= nil,
				holdProgress = if holdStarted and holdSeconds > 0
					then math.clamp((localNow - holdStarted) / holdSeconds, 0, 1)
					else 0,
				terminals = if phase == "VaultBreach" then terminals else {},
				showVaultBars = phase == "VaultBreach" and serverNow >= bannerUntil and #terminals > 0,
			}
		end,
	}
end

return ObjectivePresentation
