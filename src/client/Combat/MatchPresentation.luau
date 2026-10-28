--!strict
-- Read-only presentation of server PhaseChanged data. Never advances a phase or invents match results.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local GameConfig = require(Shared.GameConfig)
local MatchPresentation = {}

function MatchPresentation.clock(endsAt: number?, now: number): string
	if not endsAt then
		return "—"
	end
	local remaining = math.max(0, math.ceil(endsAt - now))
	return string.format("%02d:%02d", math.floor(remaining / 60), remaining % 60)
end

function MatchPresentation.new()
	local phase: Types.Phase? = nil
	local data: Types.PhaseData? = nil
	return {
		apply = function(nextPhase: Types.Phase, nextData: Types.PhaseData)
			phase, data = nextPhase, nextData
		end,
		view = function(now: number)
			local current = data
			if not current then
				return nil
			end
			local insertion = phase == "Insertion"
			local active = phase == "Infiltration"
				or phase == "VaultBreach"
				or phase == "PackageHeist"
				or phase == "Overtime"
			local span = (current.EndsAt or (current.StartedAt + GameConfig.Match.InsertionSeconds)) - current.StartedAt
			return {
				phase = phase,
				banner = if current.Banner and now < current.StartedAt + GameConfig.Match.BannerSeconds
					then current.Banner
					else nil,
				brief = if insertion then current.Brief else nil,
				insertion = insertion,
				fade = if insertion then math.clamp((now - current.StartedAt) / math.max(span, 0.001), 0, 1) else 1,
				mainTimer = if active then MatchPresentation.clock(current.MainEndsAt, now) else nil,
				phaseTimer = MatchPresentation.clock(current.EndsAt, now),
				results = if phase == "Results" then current.Results else nil,
				ready = if phase == "Lobby" then current.ReadyPlayers else nil,
			}
		end,
	}
end

return MatchPresentation
