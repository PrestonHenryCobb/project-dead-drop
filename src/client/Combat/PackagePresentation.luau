--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local GameConfig = require(Shared.GameConfig)
local PackagePresentation = {}
local labels = {
	["Take the Package"] = "TAKING PACKAGE",
	["Pass the Package"] = "PASSING PACKAGE",
	["Call extraction"] = "CALLING EXTRACTION",
	Extract = "EXTRACTING",
}

function PackagePresentation.new()
	local phase: Types.Phase? = nil
	local package: Types.PackageStateInfo? = nil
	local extraction: Types.ExtractionStateInfo? = nil
	local cinematicAt: number? = nil
	local holdAt: number? = nil
	local holdSeconds = 0
	local holdLabel: string? = nil
	return {
		phase = function(nextPhase: Types.Phase)
			phase = nextPhase
			if phase == "Lobby" or phase == "Insertion" then
				package, extraction, cinematicAt, holdAt, holdLabel = nil, nil, nil, nil, nil
			elseif phase == "Results" then
				holdAt, holdLabel = nil, nil
			end
		end,
		package = function(info: Types.PackageStateInfo)
			package = info
		end,
		extraction = function(info: Types.ExtractionStateInfo, now: number)
			if info.State == "Extracted" and (not extraction or extraction.State ~= "Extracted") then
				cinematicAt = now
			end
			if info.State ~= "Extracted" then
				cinematicAt = nil
			end
			extraction = info
		end,
		interaction = function(info: Types.InteractStateInfo, now: number)
			holdLabel = if info.Active then labels[info.Kind] else nil
			holdAt = if holdLabel then now else nil
			holdSeconds = info.Seconds
		end,
		view = function(serverNow: number, localNow: number)
			local active = phase == "PackageHeist" or phase == "Overtime"
			local point: Vector3? = nil
			if active and package then
				if
					package.State == "Pedestal"
					or package.State == "Dropped"
					or (package.State == "Carried" and package.PulseUntil ~= nil and serverNow < package.PulseUntil)
				then
					point = package.Position
				end
			end
			local cinematic = active and extraction ~= nil and extraction.State == "Extracted"
			return {
				active = active,
				package = if active then package else nil,
				point = point,
				extraction = if active then extraction else nil,
				holdLabel = if active then holdLabel else nil,
				holdProgress = if holdAt and holdSeconds > 0
					then math.clamp((localNow - holdAt) / holdSeconds, 0, 1)
					else 0,
				cinematic = cinematic,
				cinematicProgress = if cinematicAt
					then math.clamp((serverNow - cinematicAt) / GameConfig.Extraction.CinematicSeconds, 0, 1)
					else 0,
			}
		end,
	}
end

return PackagePresentation
