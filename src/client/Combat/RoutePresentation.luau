--!strict
-- Pure presentation/state for the server's route result. Never discovers targets locally.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Shared.Types)
local RoutePresentation = {}

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
		clear = function()
			revision += 1
			result, selected = nil, nil
		end,
		cycle = function()
			selected = RoutePresentation.nextTarget(result, selected)
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
			return true
		end,
	}
end

return RoutePresentation
