--!strict
-- Ticket 9b-hud: owner-only state and server-confirmed holds. No roster, identity decoration or predicted outcome.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Types = require(Shared:WaitForChild("Types"))
local HudKit = require(Shared:WaitForChild("Util"):WaitForChild("HudKit"))
local HudTheme = require(Shared:WaitForChild("Util"):WaitForChild("HudTheme"))
local Janitor = require(Shared:WaitForChild("Util"):WaitForChild("Janitor"))
local RemoteController = require(script.Parent.RemoteController)
local DownedController = require(script.Parent.DownedController)

local DownedHudController = {}
local ui = GameConfig.UI
local graphics = HudTheme.get()
local janitor = Janitor.new()
local bleedOutAt: number? = nil
local eliminated = false
local holdAt: number? = nil
local holdSeconds = 0
local holdKind = ""

local function meter(parent: Instance): Frame
	local back = Instance.new("Frame")
	back.BorderSizePixel = 0
	back.BackgroundColor3 = ui.ScanRingDimColor
	back.Position = UDim2.new(0, graphics.PaddingPixels, 1, -graphics.PaddingPixels)
	back.Size = UDim2.new(1, -graphics.PaddingPixels * 2, 0, graphics.ReloadBarPixels)
	back.Parent = parent
	local fill = Instance.new("Frame")
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(0, 1)
	fill.Parent = back
	return fill
end

local function reset()
	bleedOutAt, eliminated, holdAt = nil, false, nil
end

function DownedHudController.Init() end

function DownedHudController.Start()
	local gui = HudKit.screen("DownedHud")
	janitor:Add(gui)
	local down = HudKit.panel(
		gui,
		"LifeState",
		UDim2.fromScale(0.5, graphics.DownedTopFraction),
		Vector2.new(0.5, 0),
		UDim2.fromOffset(graphics.ActionWidthPixels, graphics.ActionHeightPixels)
	)
	local downRoot = down.Parent :: Frame
	HudKit.icon(
		down,
		"Health",
		UDim2.fromOffset(graphics.PaddingPixels, graphics.PaddingPixels),
		graphics.IconPixels,
		ui.CoverColors.Exposed
	)
	local downText = HudKit.text(
		down,
		"Countdown",
		UDim2.fromOffset(graphics.PaddingPixels * 2 + graphics.IconPixels, graphics.PaddingPixels),
		Vector2.zero,
		UDim2.new(1, -graphics.PaddingPixels * 3 - graphics.IconPixels, 0, graphics.IconPixels)
	)
	local bleedFill = meter(down)
	bleedFill.BackgroundColor3 = ui.CoverColors.Exposed
	local action = HudKit.panel(
		gui,
		"Hold",
		UDim2.new(0.5, 0, 0.5, graphics.ActionOffsetPixels),
		Vector2.new(0.5, 0),
		UDim2.fromOffset(graphics.ActionWidthPixels, graphics.ActionHeightPixels)
	)
	local actionRoot = action.Parent :: Frame
	local actionText = HudKit.text(
		action,
		"Action",
		UDim2.fromOffset(graphics.PaddingPixels, graphics.PaddingPixels),
		Vector2.zero,
		UDim2.new(1, -graphics.PaddingPixels * 2, 0, graphics.IconPixels)
	)
	local holdFill = meter(action)
	downRoot.Visible, actionRoot.Visible = false, false
	janitor:Add(RemoteController.connect("Downed", function(info: Types.DownedInfo)
		bleedOutAt, eliminated, holdAt = info.BleedOutAt, false, nil
	end))
	janitor:Add(RemoteController.connect("Revived", reset))
	janitor:Add(RemoteController.connect("Eliminated", function()
		bleedOutAt, eliminated, holdAt = nil, true, nil
	end))
	janitor:Add(RemoteController.connect("InteractState", function(info: Types.InteractStateInfo)
		holdAt = if info.Active then os.clock() else nil
		holdSeconds, holdKind = info.Seconds, info.Kind
	end))
	janitor:Add(Players.LocalPlayer.CharacterAdded:Connect(reset))
	janitor:Add(RunService.RenderStepped:Connect(function()
		downRoot.Visible = bleedOutAt ~= nil or eliminated
		local deadline = bleedOutAt
		if deadline then
			local remaining = math.max(0, deadline - workspace:GetServerTimeNow())
			downText.Text = `DOWNED  {math.ceil(remaining)}s`
			bleedFill.Size = UDim2.fromScale(math.clamp(remaining / GameConfig.Downed.BleedOutSeconds, 0, 1), 1)
		elseif eliminated then
			downText.Text = "ELIMINATED"
			bleedFill.Size = UDim2.fromScale(0, 1)
		end
		local started = holdAt
		actionRoot.Visible = (started ~= nil or DownedController.hasBodyTarget()) and not eliminated and deadline == nil
		if started then
			actionText.Text = string.upper(holdKind)
			holdFill.BackgroundColor3 = if holdKind == "Revive" then ui.CoverColors.Covered else ui.CoverColors.Exposed
			local progress = if holdSeconds > 0 then math.clamp((os.clock() - started) / holdSeconds, 0, 1) else 0
			holdFill.Size = UDim2.fromScale(progress, 1)
		else
			actionText.Text = `[ {GameConfig.Controls.Interact.Name} ] INTERACT`
			holdFill.Size = UDim2.fromScale(0, 1)
		end
	end))
	janitor:Add(script.Destroying:Connect(function()
		janitor:Destroy()
	end))
end

return DownedHudController
