--!strict
-- selene: allow(incorrect_standard_library_use)
local e = require("./MeleeFixture")
-- selene: allow(incorrect_standard_library_use)
local service = require("./MeleeServiceActual")
-- selene: allow(incorrect_standard_library_use)
local rules = require("./MeleeRulesActual")
local v = e.Vector3.new
local count = 0
local function check(ok, msg)
	assert(ok, msg)
	count += 1
end
local function press(look)
	service.request(e.player, "Press", look or v(0, 0, -1))
end
local function release(look)
	service.request(e.player, "Release", look or v(0, 0, -1))
end
-- actual Rules is intentionally shared by client/server in the extracted source.
check(rules.damage(0) == 35 and rules.damage(0.749) == 35, "Tap/partial damage changed")
check(rules.damage(0.75) == 50 and rules.damage(10) == 50, "Full charge/cap failed")
check(rules.canTakedown(v(0, 0, 6.49), v(0, 0, -1), v(0, 0, 0), v(0, 0, -1)), "Approved 6.5 reach missing")
check(not rules.canTakedown(v(0, 0, 6.51), v(0, 0, -1), v(0, 0, 0), v(0, 0, -1)), "Extra takedown slack")
check(not rules.canTakedown(v(6, 0, 0), v(-1, 0, 0), v(0, 0, 0), v(0, 0, -1)), "Side accepted as rear")
check(not rules.inReach(v(0, 0, 6), v(0, 0, -1), v(0, 0, 0), 5.5), "Ordinary melee range increased")
e.reset(0, 6)
press()
check(e.state.takedown ~= nil and #e.hits == 0, "Press struck before takedown")
e.now = 100.5
release()
check(e.state.takedown == nil and #e.hits == 0, "Cancelled takedown damaged")
e.reset(0, 6)
press()
e.now = 101.21
service.check(e.now)
check(#e.hits == 1 and e.hits[1] == 90, "Held takedown did not deal 90")
release()
check(#e.hits == 1, "Release duplicated completed takedown")
e.reset(0, -4)
press(v(0, 0, 1))
check(e.state.chargeStartedAt == 100 and #e.hits == 0, "Front press hit instead of charge")
e.now = 100.1
release(v(0, 0, 1))
check(#e.hits == 1 and e.hits[1] == 35, "Tap release failed")
e.reset(0, -4)
press(v(0, 0, 1))
e.now = 100.6
press(v(0, 0, 1))
e.now = 100.76
release(v(0, 0, 1))
check(e.hits[1] == 50, "Repeated press reset/accelerated charge")
e.reset(0, -4)
press(v(0, 0, 1))
e.now = 101
service.request(e.player, "Cancel")
release(v(0, 0, 1))
check(#e.hits == 0, "Cancel released a charged attack")
e.reset(0, 6)
press()
e.blocked = true
e.now = 100.2
service.check(e.now)
check(e.state.takedown == nil and #e.hits == 0, "Hold persisted through wall")
e.reset(0, 6)
press()
e.target.npc.yaw = math.pi
e.now = 100.2
service.check(e.now)
check(e.state.takedown == nil, "Victim turn did not cancel")
e.reset(0, 6)
press()
e.state.lastDamagedAt = 100.1
e.now = 100.2
service.check(e.now)
check(e.state.takedown == nil, "Damage did not cancel hold")
e.reset(0, -4)
press(v(0, 0, 1))
e.player.changing = true
service.check(100.2)
check(e.state.chargeStartedAt == nil, "Disguise swap kept charge")
e.reset(0, -4)
press(v(0, 0, 1))
e.player.down = true
service.check(100.2)
check(e.state.chargeStartedAt == nil, "Downed kept charge")
e.reset(0, 4)
local ally = { team = 1 }
e.target.player = ally
e.target.kind = "Agent"
e.states[ally] = { hp = 100, armor = 0 }
e.roots[ally] = e.target.rootPart
press()
check(e.state.takedown == nil, "Takedown targeted teammate")
service.damage(e.player, e.target, 90, false, v(0, 0, 4))
check(e.states[ally].hp == 100, "Friendly fire dealt damage")
e.reset(0, -4)
press(v(0, 0, 1))
e.now = 100.1
release(v(0, 0, 1))
e.now = 100.2
press(v(0, 0, 1))
check(e.state.chargeStartedAt == nil, "Cooldown bypass")
local theta = math.rad(44.9)
check(
	rules.canTakedown(
		v(6 * math.sin(theta), 0, 6 * math.cos(theta)),
		v(-math.sin(theta), 0, -math.cos(theta)),
		v(0, 0, 0),
		v(0, 0, -1)
	),
	"Inside rear cone rejected"
)
theta = math.rad(45.1)
check(
	not rules.canTakedown(
		v(6 * math.sin(theta), 0, 6 * math.cos(theta)),
		v(-math.sin(theta), 0, -math.cos(theta)),
		v(0, 0, 0),
		v(0, 0, -1)
	),
	"Outside rear cone accepted"
)
check(not rules.canTakedown(v(0, 3.01, 6), v(0, 0, -1), v(0, 0, 0), v(0, 0, -1)), "Height allowance ignored")
e.reset(0, 6)
press()
local info = e.events[#e.events].info
check(info.Kind == "Takedown" and info.Active and info.StartedAt == 1100, "Server-clock takedown acknowledgement lost")
e.reset(0, -4)
press(v(0, 0, 1))
e.now = 100.1
release(v(0, 0, 1))
info = e.events[#e.events].info
check(info.Kind == "Strike" and not info.Active, "Release did not confirm strike")
release(v(0, 0, 1))
check(#e.hits == 1, "Repeated release duplicated melee")
e.reset(0, 4)
e.target.npc.state = "Downed"
press()
check(e.state.takedown == nil, "Stale history allowed takedown on downed NPC")
print(
	"Melee: "
		.. count
		.. " runtime assertions passed against actual server melee/helper bodies and config; engine/service fixtures"
)
