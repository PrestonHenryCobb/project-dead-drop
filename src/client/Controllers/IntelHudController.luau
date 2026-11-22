--!strict
-- Ticket 11b. Private balance/taken stations and server-acknowledged Hack progress. No interaction requests.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.GameConfig)
local Enums = require(Shared.Enums)
local Janitor = require(Shared.Util.Janitor)
local HudKit = require(Shared.Util.HudKit)
local HudTheme = require(Shared.Util.HudTheme)
local HudLayout = require(script.Parent.Parent.Combat.HudLayout)
local Presentation = require(script.Parent.Parent.Combat.ObjectivePresentation)
local RemoteController = require(script.Parent.RemoteController)
local IntelHudController = {}
local janitor = Janitor.new()
local state = Presentation.new()
local theme = HudTheme.get()
local layout = HudLayout.regions(theme)
local config = GameConfig.MatchHud
local stations: { [BasePart]: boolean } = {}
local checks: { BillboardGui } = {}
local params = RaycastParams.new()
params.CollisionGroup = GameConfig.Rig.CollisionGroup
params.RespectCanCollide = true

function IntelHudController.Init() end

function IntelHudController.Start()
	local gui = HudKit.screen("IntelHud")
	janitor:Add(gui)
	local panel = HudKit.panel(
		gui,
		"TeamIntel",
		HudLayout.position(layout.Intel),
		HudLayout.anchor(layout.Intel),
		UDim2.fromOffset(theme.CoverWidthPixels, theme.CoverHeightPixels)
	)
	local panelRoot = panel.Parent :: Frame
	panelRoot.Visible = false
	HudKit.icon(
		panel,
		"Intel",
		UDim2.fromOffset(theme.PaddingPixels, theme.PaddingPixels),
		theme.IconPixels,
		theme.TextColor
	)
	local balance = HudKit.text(
		panel,
		"Balance",
		UDim2.fromOffset(theme.PaddingPixels * 2 + theme.IconPixels, theme.PaddingPixels),
		Vector2.zero,
		UDim2.new(1, -theme.PaddingPixels * 3 - theme.IconPixels, 0, config.BodySize)
	)
	balance.TextSize = config.BodySize
	balance.TextXAlignment = Enum.TextXAlignment.Left
	local taken = HudKit.text(
		panel,
		"TakenCount",
		UDim2.new(0, theme.PaddingPixels, 1, -theme.PaddingPixels),
		Vector2.new(0, 1),
		UDim2.new(1, -theme.PaddingPixels * 2, 0, theme.CaptionSize)
	)
	taken.TextSize = theme.CaptionSize
	taken.TextXAlignment = Enum.TextXAlignment.Left
	local action = HudKit.panel(
		gui,
		"IntelHack",
		UDim2.new(0.5, 0, 0.5, theme.ActionOffsetPixels),
		Vector2.new(0.5, 0),
		UDim2.fromOffset(theme.ActionWidthPixels, theme.ActionHeightPixels)
	)
	local actionRoot = action.Parent :: Frame
	actionRoot.Visible = false
	local actionText = HudKit.text(
		action,
		"Hack",
		UDim2.fromOffset(theme.PaddingPixels, theme.PaddingPixels),
		Vector2.zero,
		UDim2.new(1, -theme.PaddingPixels * 2, 0, theme.CaptionSize)
	)
	actionText.Text = "HACKING INTEL"
	local bar = Instance.new("Frame")
	bar.BorderSizePixel = 0
	bar.BackgroundColor3 = theme.AccentColor
	bar.Position = UDim2.new(0, theme.PaddingPixels, 1, -theme.PaddingPixels)
	bar.Size = UDim2.fromOffset(0, theme.ReloadBarPixels)
	bar.Parent = action
	local folder = Instance.new("Folder")
	folder.Name = "PrivateTakenStations"
	folder.Parent = workspace
	janitor:Add(folder)
	for _ = 1, GameConfig.Intel.GlintMax do
		local check = Instance.new("BillboardGui")
		check.Name = "TakenStation"
		check.Enabled = false
		check.AlwaysOnTop = false
		check.Size = UDim2.fromOffset(config.MarkerSizePixels * 2, config.MarkerSizePixels * 2)
		check.StudsOffsetWorldSpace = Vector3.new(0, config.MarkerHeightStuds, 0)
		check.Parent = folder
		local icon = HudKit.text(check, "Taken", UDim2.fromScale(0, 0), Vector2.zero, UDim2.fromScale(1, 1))
		icon.Text = "✓"
		icon.TextColor3 = theme.AccentColor
		icon.TextSize = config.TitleSize
		table.insert(checks, check)
	end
	local function track(instance: Instance)
		if instance:IsA("BasePart") then
			stations[instance] = true
		end
	end
	janitor:Add(CollectionService:GetInstanceAddedSignal(Enums.Tag.IntelSpawn):Connect(track))
	janitor:Add(CollectionService:GetInstanceRemovedSignal(Enums.Tag.IntelSpawn):Connect(function(instance)
		if instance:IsA("BasePart") then
			stations[instance] = nil
		end
	end))
	for _, instance in CollectionService:GetTagged(Enums.Tag.IntelSpawn) do
		track(instance)
	end
	janitor:Add(RemoteController.connect("IntelUpdate", state.intel))
	janitor:Add(RemoteController.connect("PhaseChanged", state.phase))
	janitor:Add(RemoteController.connect("InteractState", function(info)
		state.interaction(info, os.clock())
	end))
	janitor:Add(RunService.RenderStepped:Connect(function()
		local view = state.view(workspace:GetServerTimeNow(), os.clock())
		panelRoot.Visible = view.active
		balance.Text = if view.balance ~= nil then tostring(view.balance) else "—"
		taken.Text = tostring(view.usedCount) .. " ✓"
		actionRoot.Visible = view.hacking
		bar.Size = UDim2.new(view.holdProgress, -theme.PaddingPixels * 2 * view.holdProgress, 0, theme.ReloadBarPixels)
	end))
	local elapsed = 0
	janitor:Add(RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < GameConfig.Match.TickSeconds then
			return
		end
		elapsed = 0
		local view = state.view(workspace:GetServerTimeNow(), os.clock())
		local camera = workspace.CurrentCamera
		local shown = 0
		if view.active and camera then
			for station in stations do
				local id = station:GetAttribute("IntelId")
				local offset = station.Position - camera.CFrame.Position
				if
					station.Parent
					and type(id) == "string"
					and view.used[id]
					and offset.Magnitude <= GameConfig.Intel.GlintRange
				then
					local hit = workspace:Raycast(camera.CFrame.Position, offset, params)
					if not hit or hit.Instance == station then
						shown += 1
						checks[shown].Adornee = station
						checks[shown].Enabled = true
						if shown == #checks then
							break
						end
					end
				end
			end
		end
		for index = shown + 1, #checks do
			checks[index].Enabled = false
			checks[index].Adornee = nil
		end
	end))
	janitor:Add(function()
		table.clear(stations)
		table.clear(checks)
	end)
	janitor:Add(script.Destroying:Connect(function()
		janitor:Destroy()
	end))
end

return IntelHudController
