--!strict
-- Ticket 19-agent-sense-lifecycle: explicit local empty-model fixtures; no real character or map edits.
assert(game:GetService("RunService"):IsStudio(), "Studio only")
local shared = game.ReplicatedStorage.Shared:Clone()
shared.Name = "SharedOverride"
local combat = game.StarterPlayer.StarterPlayerScripts.Client.Combat:Clone()
shared.Parent = combat
combat.Parent = game.ServerStorage
local fixtures = Instance.new("Folder")
fixtures.Name = "SenseReviewFixtures"
fixtures.Parent = workspace
local effect: any = nil
local ok, problem = pcall(function()
	local Fx = require(combat.AgentSenseFx)
	local config = require(shared.GameConfig).UI.SenseShimmer
	effect = Fx.new()
	local models = {}
	for _ = 1, config.PoolSize + 2 do
		local model = Instance.new("Model")
		model.Parent = fixtures
		table.insert(models, model)
	end
	local initial = #effect.folder:GetDescendants()
	assert(initial == config.PoolSize)
	for index = 1, 100 do
		effect:show(models[1], 1, index)
	end
	local active = 0
	for _, slot in effect.slots do
		if slot.highlight.Enabled then
			active += 1
			assert(slot.highlight.Adornee == models[1] and slot.highlight.Parent == effect.folder)
		end
	end
	assert(active == 1, "Repeated shimmer created multiple highlights")
	effect:update(100.5)
	assert(effect.slots[1].highlight.Enabled, "Refresh expired early")
	effect:update(101)
	assert(not effect.slots[1].highlight.Enabled and effect.slots[1].highlight.Adornee == nil)
	effect:show(models[1], 2, 110)
	models[1].Parent = game.ServerStorage
	effect:update(110)
	assert(not effect.slots[1].highlight.Enabled, "Stream-out retained shimmer")
	models[1].Parent = fixtures
	for _, model in models do
		effect:show(model, 1, 120)
		assert(#model:GetChildren() == 0, "Effect attached to a model")
	end
	assert(#effect.folder:GetDescendants() == initial, "Pool overflow allocated highlights")
	effect:reset()
	for _, slot in effect.slots do
		assert(slot.model == nil and not slot.highlight.Enabled and slot.highlight.Adornee == nil)
	end
	effect:destroy()
	effect = nil
	print(
		"AGENT_SENSE_FX_NATIVE_PASS",
		initial,
		"pooled highlights; refresh, expiry, stream-out, overflow, model parity and reset"
	)
end)
if effect then
	effect:destroy()
end
fixtures:Destroy()
combat:Destroy()
assert(ok, tostring(problem))
