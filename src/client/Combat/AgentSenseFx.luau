--!strict
-- Ticket 19-agent-sense-lifecycle: fixed client-only pool, fed solely by authorized shimmer events.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = script.Parent:FindFirstChild("SharedOverride") or ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.GameConfig)
local config = GameConfig.UI.SenseShimmer
local AgentSenseFx = {}
AgentSenseFx.__index = AgentSenseFx
type Slot = { highlight: Highlight, model: Model?, expires: number }
export type Effect = typeof(setmetatable({} :: { folder: Folder, slots: { Slot } }, AgentSenseFx))

function AgentSenseFx.new(): Effect
	local folder = Instance.new("Folder")
	folder.Name = "LocalSenseEffects"
	folder.Parent = workspace
	local slots: { Slot } = {}
	for _ = 1, config.PoolSize do
		local highlight = Instance.new("Highlight")
		highlight.Enabled = false
		highlight.FillTransparency = 1
		highlight.OutlineColor = GameConfig.UI.TextColor
		highlight.OutlineTransparency = config.OutlineTransparency
		highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop -- preserves the existing authorized shimmer rendering
		highlight.Parent = folder
		table.insert(slots, { highlight = highlight, model = nil, expires = -math.huge })
	end
	return setmetatable({ folder = folder, slots = slots }, AgentSenseFx)
end

function AgentSenseFx.show(self: Effect, model: Model, seconds: number, now: number)
	if seconds <= 0 or not model:IsDescendantOf(workspace) then
		return
	end
	local chosen = self.slots[1]
	for _, slot in self.slots do
		if slot.model == model then
			chosen = slot
			break
		elseif slot.expires < chosen.expires then
			chosen = slot
		end
	end
	chosen.model = model
	chosen.expires = now + seconds
	chosen.highlight.Adornee = model
	chosen.highlight.Enabled = true
end

function AgentSenseFx.update(self: Effect, now: number)
	for _, slot in self.slots do
		local model = slot.model
		if model and (now >= slot.expires or not model:IsDescendantOf(workspace)) then
			slot.model = nil
			slot.expires = -math.huge
			slot.highlight.Enabled = false
			slot.highlight.Adornee = nil
		end
	end
end

function AgentSenseFx.reset(self: Effect)
	for _, slot in self.slots do
		slot.model = nil
		slot.expires = -math.huge
		slot.highlight.Enabled = false
		slot.highlight.Adornee = nil
	end
end

function AgentSenseFx.destroy(self: Effect)
	self.folder:Destroy()
end

return AgentSenseFx
