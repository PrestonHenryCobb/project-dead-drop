--!strict
-- selene: allow(incorrect_standard_library_use)
-- Engine/service fixtures only. Gameplay decisions are extracted from the real service by check-melee.cjs.
local e =
	{ config = require("./MeleeConfig"), states = {}, events = {}, hits = {}, roots = {}, now = 100, blocked = false }
local vector = {}
local function v(x, y, z)
	return setmetatable({ X = x, Y = y, Z = z, _vector = true }, vector)
end
vector.__sub = function(a, b)
	return v(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
vector.__index = function(a, k)
	if k == "Magnitude" then
		return math.sqrt(a.X * a.X + a.Y * a.Y + a.Z * a.Z)
	end
	if k == "Unit" then
		local n = a.Magnitude
		return v(a.X / n, a.Y / n, a.Z / n)
	end
end
e.Vector3 = { new = v, zero = v(0, 0, 0), zAxis = v(0, 0, 1) }
e.typeof = function(a)
	return if type(a) == "table" and a._vector then "Vector3" else typeof(a)
end
e.os = {
	clock = function()
		return e.now
	end,
}
e.workspace = {
	GetServerTimeNow = function()
		return e.now + 1000
	end,
	Raycast = function()
		return if e.blocked then {} else nil
	end,
}
e.RemoteService = {
	fireClient = function(name, player, info)
		table.insert(e.events, { name = name, player = player, info = info })
	end,
}
e.TeamService = {
	areTeammates = function(a, b)
		return a.team == b.team
	end,
}
e.CoverService = { expose = function() end, startLockout = function() end, onNpcKilled = function() end }
e.DisguiseService = {
	isChanging = function(player)
		return player.changing == true
	end,
}
e.History = { targets = {} }
e.NPCService = {
	hitNpc = function(npc, damage)
		table.insert(e.hits, damage)
		npc.hp -= damage
		return npc.hp <= 0
	end,
	-- R5-takedown: a takedown holds an NPC still for its duration.
	setHeld = function(npc, held)
		npc.held = held
		return true
	end,
}
e.aliveParts = function(player)
	return if player.down then nil else { Health = 100 }, e.roots[player]
end
e.isDowned = function(player)
	return player.down == true
end
function e.reset(x, z)
	table.clear(e.states)
	table.clear(e.events)
	table.clear(e.hits)
	e.now = 100
	e.blocked = false
	e.player = { team = 1 }
	e.roots[e.player] = { Position = v(x, 0, z), CFrame = { LookVector = v(0, 0, 1) } }
	e.state = { dead = false, reloadEndsAt = 0, lastMeleeAt = -math.huge, lastDamagedAt = -math.huge }
	e.states[e.player] = e.state
	e.target = {
		id = "npc",
		kind = "Npc",
		rootPart = { Position = v(0, 0, 0), CFrame = { LookVector = v(0, 0, -1) } },
		npc = {
			yaw = 0,
			hp = 200,
		},
	}
	e.History.targets = { npc = e.target }
end
return e
