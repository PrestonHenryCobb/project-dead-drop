--!strict
-- Ticket studio-test-loadout: deterministic choices from implemented weapons only. No invented agent abilities.
local Shared = script.Parent.Parent
local GameConfig = require(Shared.GameConfig)
local WeaponDefs = require(Shared.Defs.WeaponDefs)
local Types = require(Shared.Types)
local TestLoadout = {}
local byAgent: { [string]: { Types.WeaponDef } } = {}
local allWeapons: { Types.WeaponDef } = {}
for _, def in WeaponDefs.byId do
	table.insert(allWeapons, def)
	local weapons = byAgent[def.Agent] or {}
	byAgent[def.Agent] = weapons
	table.insert(weapons, def)
end
-- Ticket studio-all-weapons: registry-driven, so new weapons need no selector edits.
table.sort(allWeapons, function(a, b)
	local order = GameConfig.Debug.TestLoadout.AgentOrder
	local aRank = table.find(order, a.Agent) or math.huge
	local bRank = table.find(order, b.Agent) or math.huge
	if aRank ~= bRank then
		return aRank < bRank
	elseif a.Agent ~= b.Agent then
		return a.Agent < b.Agent
	end
	return a.Id < b.Id
end)
for _, weapons in byAgent do
	table.sort(weapons, function(a, b)
		return a.Id < b.Id
	end)
end

function TestLoadout.nextWeapon(currentId: string, action: string): Types.WeaponDef?
	local current = WeaponDefs.get(currentId)
	if not current then
		return nil
	end
	if action == "Sync" then
		return current
	end
	if action == "All" then
		local index = table.find(allWeapons, current) or 1
		return allWeapons[index % #allWeapons + 1]
	end
	if action == "Weapon" then
		local choices = byAgent[current.Agent]
		local index = table.find(choices, current) or 1
		return choices[index % #choices + 1]
	elseif action == "Agent" then
		local order = GameConfig.Debug.TestLoadout.AgentOrder
		local index = table.find(order, current.Agent) or 0
		for offset = 1, #order do
			local choices = byAgent[order[(index + offset - 1) % #order + 1]]
			if choices and #choices > 0 then
				return choices[1]
			end
		end
	end
	return nil
end

return table.freeze(TestLoadout)
