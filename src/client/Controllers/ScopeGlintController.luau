--!strict
-- Ticket 8.5-client-rules: pooled local scope flares at positions the server authorizes for this rival.
-- No character attachment, roster or identifying metadata. Walls occlude the billboard normally.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Types = require(Shared:WaitForChild("Types"))
local WeaponDefs = require(Shared:WaitForChild("Defs"):WaitForChild("WeaponDefs"))
local Janitor = require(Shared:WaitForChild("Util"):WaitForChild("Janitor"))
local RemoteController = require(script.Parent.RemoteController)

type Slot = { part: Part, gui: BillboardGui, bars: { Frame }, expires: number, seconds: number }
local ScopeGlintController = {}
local look = WeaponDefs.ShotDefaults
local janitor = Janitor.new()
local slots: { Slot } = {}
local cursor = 0

local function clear()
	for _, slot in slots do
		slot.expires = 0
		slot.gui.Enabled = false
	end
end

local function onGlint(info: Types.ScopeGlintInfo)
	if info.Seconds <= 0 then
		return
	end
	local now = os.clock()
	local chosen: Slot? = nil
	local nearest = GameConfig.Combat.FireOriginToleranceStuds
	for _, slot in slots do
		local distance = (slot.part.Position - info.Position).Magnitude
		if slot.expires > now and distance <= nearest then
			chosen, nearest = slot, distance
		end
	end
	if not chosen then
		cursor = cursor % #slots + 1
		chosen = slots[cursor]
	end
	chosen.part.Position = info.Position
	chosen.expires = now + info.Seconds
	chosen.seconds = info.Seconds
	for _, bar in chosen.bars do
		bar.BackgroundTransparency = 0
	end
	chosen.gui.Enabled = true
end

function ScopeGlintController.Init() end

function ScopeGlintController.Start()
	local folder = Instance.new("Folder")
	folder.Name = "CombatScopeGlints"
	folder.Parent = workspace
	janitor:Add(folder)
	-- At most one flare per possible match participant is needed; repeated nearby updates refresh a slot.
	for _ = 1, GameConfig.Match.MaxPlayers do
		local part = Instance.new("Part")
		part.Name = "GlintPosition"
		part.Anchored = true
		part.CanCollide, part.CanQuery, part.CanTouch, part.CastShadow = false, false, false, false
		part.Transparency = 1
		part.Size = Vector3.one
		part.Parent = folder
		local gui = Instance.new("BillboardGui")
		gui.Name = "ScopeGlint"
		gui.Adornee = part
		gui.Size = UDim2.fromOffset(look.ScopeGlintPixels, look.ScopeGlintPixels)
		gui.MaxDistance = GameConfig.Combat.ScopeGlint.RangeStuds
		gui.LightInfluence = 0
		gui.AlwaysOnTop = false
		gui.Enabled = false
		gui.Parent = part
		local bars: { Frame } = {}
		for _, rotation in { 0, 90, 45 } do
			local bar = Instance.new("Frame")
			bar.AnchorPoint = Vector2.new(0.5, 0.5)
			bar.Position = UDim2.fromScale(0.5, 0.5)
			bar.Size = if rotation == 45
				then UDim2.fromScale(look.ScopeGlintCoreFraction, look.ScopeGlintCoreFraction)
				else UDim2.fromScale(1, look.ScopeGlintBarFraction)
			bar.Rotation = rotation
			bar.BackgroundColor3 = look.ScopeGlintColor
			bar.BorderSizePixel = 0
			bar.Parent = gui
			table.insert(bars, bar)
		end
		table.insert(slots, { part = part, gui = gui, bars = bars, expires = 0, seconds = 0 })
	end
	janitor:Add(RemoteController.connect("ScopeGlint", onGlint))
	janitor:Add(Players.LocalPlayer.CharacterRemoving:Connect(clear))
	janitor:Add(RunService.RenderStepped:Connect(function()
		local now = os.clock()
		for _, slot in slots do
			if slot.gui.Enabled then
				if now >= slot.expires then
					slot.gui.Enabled = false
				else
					local fade = 1 - (slot.expires - now) / slot.seconds
					for _, bar in slot.bars do
						bar.BackgroundTransparency = fade
					end
				end
			end
		end
	end))
	janitor:Add(script.Destroying:Connect(function()
		janitor:Destroy()
	end))
end

return ScopeGlintController
