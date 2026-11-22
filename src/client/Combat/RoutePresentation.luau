--!strict
-- Pure presentation/state for the server's route result. Never discovers targets locally.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Shared.Types)
local RoutePresentation = {}

function RoutePresentation.effective(result: Types.RouteResult?, preferred: string): (string, Types.RouteInfo?)
	local route = if result then (if preferred == "Clean" then result.Clean else result.Fast) else nil
	if route then
		return preferred, route
	end
	local other = if preferred == "Clean" then "Fast" else "Clean"
	local fallback = if result then (if other == "Clean" then result.Clean else result.Fast) else nil
	return if fallback then other else preferred, fallback
end

local function sameRoute(a: Types.RouteInfo?, b: Types.RouteInfo?): boolean
	if a == b then
		return true
	end
	if not a or not b or #a.Points ~= #b.Points or #a.Steps ~= #b.Steps then
		return false
	end
	for index, point in a.Points do
		if point ~= b.Points[index] then
			return false
		end
	end
	for index, step in a.Steps do
		local other = b.Steps[index]
		if
			step.Index ~= other.Index
			or step.Kind ~= other.Kind
			or step.Detail ~= other.Detail
			or step.Intel ~= other.Intel
			or step.CoverBreak ~= other.CoverBreak
		then
			return false
		end
	end
	return true
end

-- Prices/balances can update the summary without rebuilding identical geometry.
function RoutePresentation.sameMap(a: Types.RouteResult?, b: Types.RouteResult?): boolean
	if a == b then
		return true
	end
	return a ~= nil and b ~= nil and sameRoute(a.Clean, b.Clean) and sameRoute(a.Fast, b.Fast)
end

function RoutePresentation.nextTarget(result: Types.RouteResult?, selected: string?): string?
	if not result or #result.Targets == 0 then
		return nil
	end
	local index = 0
	for i, target in result.Targets do
		if target.Id == selected then
			index = i
			break
		end
	end
	return result.Targets[index % #result.Targets + 1].Id
end

function RoutePresentation.step(step: Types.RouteStepInfo): string
	local text = step.Kind
	if step.Detail then
		text ..= ` · {step.Detail}`
	end
	if step.Intel then
		text ..= ` · {step.Intel} Intel`
	end
	if step.CoverBreak then
		text ..= " · breaks Cover"
	end
	return text
end

function RoutePresentation.summary(name: string, route: Types.RouteInfo?): string
	if not route then
		return `{string.upper(name)} · No route`
	end
	return `{string.upper(name)} · {math.floor(route.Length + 0.5)} studs · {route.HackIntel} Intel · {route.CoverBreaks} Cover breaks{if route.Affordable
		then ""
		else " · Not enough Intel"}`
end

-- A response is accepted only in the same lifetime/target revision as its request.
function RoutePresentation.new()
	local revision = 0
	local result: Types.RouteResult? = nil
	local selected: string? = nil
	local requested: string? = nil
	return {
		revision = function(): number
			return revision
		end,
		result = function(): Types.RouteResult?
			return result
		end,
		selected = function(): string?
			return selected
		end,
		requested = function(): string?
			return requested
		end,
		clear = function()
			revision += 1
			result, selected, requested = nil, nil, nil
		end,
		cycle = function()
			selected = RoutePresentation.nextTarget(result, selected)
			requested = selected
			revision += 1
			-- Preserve the list to permit another cycle; never draw routes for the old target.
			if result then
				result = { Targets = result.Targets, Selected = nil, Intel = result.Intel, Clean = nil, Fast = nil }
			end
		end,
		apply = function(value: Types.RouteResult?, requestRevision: number): boolean
			if requestRevision ~= revision then
				return false
			end
			result = value
			selected = if value then value.Selected else nil
			-- Once an explicitly pinned target disappears, resume automatic nearest-objective guidance.
			if requested and value and value.Selected ~= requested then
				requested = nil
			end
			return true
		end,
	}
end

return RoutePresentation
