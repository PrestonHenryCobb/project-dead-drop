--!strict
-- Spec 21.3 / PING_CONTRACT: input requests and team-only confirmed markers. No character metadata or identity inference.
local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.GameConfig)
local InputHints = require(Shared.Util.InputHints)
local Enums = require(Shared.Enums)
local Types = require(Shared.Types)
local Janitor = require(Shared.Util.Janitor)
local HudKit = require(Shared.Util.HudKit)
local HudTheme = require(Shared.Util.HudTheme)
local HeldItemController = require(script.Parent.HeldItemController)
local RemoteController = require(script.Parent.RemoteController)
local Floors = require(script.Parent.FloorMarkerController)
local PingController = {}
local janitor = Janitor.new()
local config = GameConfig.PingHud
local markerConfig = GameConfig.MatchHud
local theme = HudTheme.get()
local player = Players.LocalPlayer
local CONTEXT_ACTION = "CoverStoryTeamPing"
local DANGER_ACTION = "CoverStoryDangerPing"
local labels = {
	Look = "LOOK HERE",
	Suspect = "SUSPECT",
	Intel = "INTEL",
	Danger = "DANGER",
	Go = "GO HERE",
	Hold = "HOLD HERE",
	Help = "NEED HELP",
	Retreat = "FALL BACK",
}
local wheelConfig = config.Wheel
type Marker = { info: Types.PingInfo, anchor: Part, detail: TextLabel }
local markers: { [number]: Marker } = {}
local folder: Folder? = nil
local phase: Types.Phase? = nil
local ray = RaycastParams.new()
ray.FilterType = Enum.RaycastFilterType.Exclude
-- Use Default ray collision: the character collision group deliberately ignores other bodies.
ray.RespectCanCollide = false -- bodies and authored interactables must remain aimable even when non-colliding

local function remove(id: number)
	local marker = markers[id]
	if marker then
		marker.anchor:Destroy()
		markers[id] = nil
	end
end

local function clear()
	for id in markers do
		remove(id)
	end
end

local function characterAt(instance: Instance): Model?
	local ancestor: Instance? = instance
	while ancestor and ancestor ~= workspace do
		if ancestor:IsA("Model") then
			local root = ancestor:FindFirstChild("HumanoidRootPart")
			if
				root
				and root:IsA("BasePart")
				and (
					ancestor:FindFirstChildOfClass("Humanoid") or ancestor:FindFirstChildOfClass("AnimationController")
				)
			then
				return ancestor
			end
		end
		ancestor = ancestor.Parent
	end
	return nil
end

local function intelAt(instance: Instance): boolean
	local ancestor: Instance? = instance
	while ancestor and ancestor ~= workspace do
		if CollectionService:HasTag(ancestor, Enums.Tag.IntelSpawn) then
			return true
		end
		ancestor = ancestor.Parent
	end
	-- Authored tablet/laptop/rack screens and safe keypads are sibling trim in a room's props folder.
	-- Match only a nearby tagged station touching that small screen's bounds, never the whole room's props.
	if instance:IsA("BasePart") and (instance.Name == "Screen" or instance.Name == "Keypad") then
		for _, station in CollectionService:GetTagged(Enums.Tag.IntelSpawn) do
			if
				station:IsA("BasePart")
				and station.Parent == instance.Parent
				and (station:GetClosestPointOnSurface(instance.Position) - instance.Position).Magnitude
					<= instance.Size.Magnitude / 2
			then
				return true
			end
		end
	end
	return false
end

local function request(danger: boolean, chosen: string?): boolean
	if not HeldItemController.canAct() then
		return false
	end
	local camera = workspace.CurrentCamera
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not camera or not root or not root:IsA("BasePart") then
		return false
	end
	local excluded: { Instance } = { character :: Model }
	if folder then
		table.insert(excluded, folder)
	end
	ray.FilterDescendantsInstances = excluded
	local viewport = camera.ViewportSize
	local aim = camera:ViewportPointToRay(viewport.X / 2, viewport.Y / 2)
	local hit = workspace:Raycast(aim.Origin, aim.Direction * GameConfig.Ping.RangeStuds, ray)
	if not hit then
		return false -- an empty sky is not a surface or an invented world position
	end
	local body = characterAt(hit.Instance)
	local targetRoot = body and body:FindFirstChild("HumanoidRootPart")
	local onBody = not danger
		and (chosen == nil or chosen == "Suspect")
		and targetRoot ~= nil
		and targetRoot:IsA("BasePart")
	if chosen == "Suspect" and not onBody then
		return false -- a Suspect ping needs a person under the crosshair
	end
	local point = if onBody and targetRoot then (targetRoot :: BasePart).Position else hit.Position
	if (point - root.Position).Magnitude > GameConfig.Ping.RangeStuds then
		return false
	end
	local kind = chosen
		or if danger then "Danger" elseif body then "Suspect" elseif intelAt(hit.Instance) then "Intel" else "Look"
	RemoteController.fire("RequestPing", kind, point, if kind == "Suspect" and body then body.Name else nil)
	return true
end

-- The ping wheel: a ring of slices around the middle of the screen, chosen by where the (virtual) cursor points.
local wheelGui: ScreenGui? = nil
local sliceFrames: { Frame } = {}
local wheelOpen = false
local wheelCursor = Vector2.zero
local holdToken = 0
local pressed = false

local function chosenSlice(): number?
	if wheelCursor.Magnitude < wheelConfig.DeadzonePixels then
		return nil
	end
	local count = #wheelConfig.Kinds
	local angle = math.atan2(wheelCursor.X, -wheelCursor.Y) -- 0 is up, clockwise
	return math.floor(angle / (2 * math.pi) * count + 0.5) % count + 1
end

local function paintWheel()
	local picked = chosenSlice()
	for index, slice in sliceFrames do
		slice.BackgroundColor3 = if index == picked then theme.AccentColor else theme.PanelColor
		local label = slice:FindFirstChildOfClass("TextLabel")
		if label then
			label.TextColor3 = if index == picked then theme.PanelColor else theme.TextColor
		end
	end
	local cursor = wheelGui and wheelGui:FindFirstChild("Cursor")
	if cursor and cursor:IsA("Frame") then
		cursor.Position = UDim2.new(0.5, wheelCursor.X, 0.5, wheelCursor.Y)
	end
end

local function buildWheel(): ScreenGui
	local gui = HudKit.screen("PingWheel")
	gui.Enabled = false
	local count = #wheelConfig.Kinds
	for index, kind in wheelConfig.Kinds do
		local angle = (index - 1) / count * 2 * math.pi
		local slice = Instance.new("Frame")
		slice.Name = kind
		slice.AnchorPoint = Vector2.new(0.5, 0.5)
		slice.Size = UDim2.fromOffset(wheelConfig.SlicePixels.X, wheelConfig.SlicePixels.Y)
		slice.Position =
			UDim2.new(0.5, math.sin(angle) * wheelConfig.RadiusPixels, 0.5, -math.cos(angle) * wheelConfig.RadiusPixels)
		slice.BackgroundColor3 = theme.PanelColor
		slice.BackgroundTransparency = 0.2
		slice.BorderSizePixel = 0
		slice.Parent = gui
		local label = HudKit.text(slice, "Label", UDim2.fromScale(0, 0), Vector2.zero, UDim2.fromScale(1, 1))
		label.TextSize = theme.CaptionSize
		label.Text = (labels :: { [string]: string })[kind] or kind
		table.insert(sliceFrames, slice)
	end
	local cursor = Instance.new("Frame")
	cursor.Name = "Cursor"
	cursor.AnchorPoint = Vector2.new(0.5, 0.5)
	cursor.Size = UDim2.fromOffset(wheelConfig.CursorPixels, wheelConfig.CursorPixels)
	cursor.BackgroundColor3 = theme.AccentColor
	cursor.BorderSizePixel = 0
	cursor.Parent = gui
	return gui
end

local WHEEL_FREEZE = "CoverStoryPingWheelLook"

-- While the wheel is open the mouse chooses a slice instead of turning the camera.
local function freezeAction(_: string, _state: Enum.UserInputState, object: InputObject): Enum.ContextActionResult
	if object.UserInputType == Enum.UserInputType.MouseMovement then
		wheelCursor += Vector2.new(object.Delta.X, object.Delta.Y) * wheelConfig.MouseScale
		if wheelCursor.Magnitude > wheelConfig.RadiusPixels then
			wheelCursor = wheelCursor.Unit * wheelConfig.RadiusPixels
		end
	end
	return Enum.ContextActionResult.Sink
end

local function openWheel()
	local gui = wheelGui
	if not gui or wheelOpen or not HeldItemController.canAct() then
		return
	end
	wheelOpen = true
	wheelCursor = Vector2.zero
	gui.Enabled = true
	ContextActionService:BindActionAtPriority(
		WHEEL_FREEZE,
		freezeAction,
		false,
		GameConfig.Combat.InputPriority + 2,
		Enum.UserInputType.MouseMovement
	)
	paintWheel()
end

-- Closes the wheel; with commit, pings the chosen slice.
local function closeWheel(commit: boolean)
	if not wheelOpen then
		return
	end
	wheelOpen = false
	ContextActionService:UnbindAction(WHEEL_FREEZE)
	if wheelGui then
		wheelGui.Enabled = false
	end
	local picked = chosenSlice()
	if commit and picked then
		request(false, wheelConfig.Kinds[picked])
	end
end

local function padChord(): boolean
	return UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, config.ModifierPad)
end

local function input(action: string, state: Enum.UserInputState, object: InputObject): Enum.ContextActionResult
	local pad = object.KeyCode == config.Pad or object.KeyCode == config.DangerPad
	if pad and not padChord() then
		return Enum.ContextActionResult.Pass
	end
	if not HeldItemController.canAct() then
		return Enum.ContextActionResult.Pass
	end
	if
		action == DANGER_ACTION
		or (state == Enum.UserInputState.Begin and UserInputService:IsKeyDown(config.DangerModifier))
	then
		if state == Enum.UserInputState.Begin then
			request(true)
		end
		return Enum.ContextActionResult.Sink
	end
	if state == Enum.UserInputState.Begin then
		-- Hold to open the wheel; letting go sooner is a plain ping of what you aim at.
		pressed = true
		holdToken += 1
		local token = holdToken
		if object.UserInputType ~= Enum.UserInputType.Touch then
			task.delay(wheelConfig.HoldSeconds, function()
				if pressed and holdToken == token then
					openWheel()
				end
			end)
		end
	elseif state == Enum.UserInputState.End and pressed then
		pressed = false
		holdToken += 1
		if wheelOpen then
			closeWheel(true)
		else
			request(false)
		end
	elseif state == Enum.UserInputState.Cancel then
		pressed = false
		holdToken += 1
		closeWheel(false)
	end
	return Enum.ContextActionResult.Sink
end

local function add(info: Types.PingInfo)
	if
		phase == "Lobby"
		or phase == "Insertion"
		or phase == "Results"
		or info.ExpiresAt <= workspace:GetServerTimeNow()
	then
		return
	end
	local title = (labels :: { [string]: string })[info.Kind]
	local parent = folder
	if not title or not parent then
		return
	end
	remove(info.Id)
	-- The server caps each sender. Keep a whole-match bound without treating duplicate display names as identities.
	local count, oldestId, earliest = 0, nil :: number?, math.huge
	for id, marker in markers do
		count += 1
		if marker.info.ExpiresAt < earliest then
			oldestId, earliest = id, marker.info.ExpiresAt
		end
	end
	if count >= GameConfig.Match.MaxPlayers * GameConfig.UI.MaxPingsPerPlayer and oldestId then
		remove(oldestId)
	end
	local anchor = Instance.new("Part")
	anchor.Name = "TeamPing"
	anchor.Anchored = true
	anchor.Transparency = 1
	anchor.CanCollide, anchor.CanTouch, anchor.CanQuery = false, false, false
	anchor.Size = Vector3.one
	anchor.Position = info.Position
	anchor.Parent = parent
	local gui = Instance.new("BillboardGui")
	gui.Name = "PingMarker"
	gui.Adornee = anchor
	gui.AlwaysOnTop = true
	gui.Size =
		UDim2.fromOffset(markerConfig.MarkerSizePixels * 12, markerConfig.MarkerSizePixels + theme.CaptionSize * 3)
	gui.StudsOffsetWorldSpace = Vector3.new(0, markerConfig.MarkerHeightStuds, 0)
	gui.Parent = anchor
	local color = if info.Kind == "Danger"
		then GameConfig.Combat.Feedback.LowHealthColor
		elseif info.Kind == "Suspect" or info.Kind == "Help" or info.Kind == "Retreat" then GameConfig.UI.WarningColor
		else theme.AccentColor
	local diamond = Instance.new("Frame")
	diamond.AnchorPoint = Vector2.new(0.5, 0.5)
	diamond.Position = UDim2.new(0.5, 0, 0, markerConfig.MarkerSizePixels / 2)
	diamond.Size = UDim2.fromOffset(markerConfig.MarkerSizePixels / 2, markerConfig.MarkerSizePixels / 2)
	diamond.Rotation = 45
	diamond.BackgroundColor3 = color
	diamond.BorderSizePixel = 0
	diamond.Parent = gui
	local function text(name: string, row: number): TextLabel
		local label = HudKit.text(
			gui,
			name,
			UDim2.fromOffset(0, markerConfig.MarkerSizePixels + row * theme.CaptionSize),
			Vector2.zero,
			UDim2.new(1, 0, 0, theme.CaptionSize)
		)
		label.TextSize = theme.CaptionSize
		label.RichText = false
		label.TextTruncate = Enum.TextTruncate.AtEnd
		return label
	end
	text("Kind", 0).Text = title
	text("From", 1).Text = info.From
	local detail = text("DistanceAndFloor", 2)
	detail.TextColor3 = color
	markers[info.Id] = { info = info, anchor = anchor, detail = detail }
end

function PingController.Init() end

function PingController.Start()
	local container = Instance.new("Folder")
	container.Name = "PrivateTeamPings"
	container.Parent = workspace
	folder = container
	janitor:Add(container)
	local gui = HudKit.screen("PingHud")
	janitor:Add(gui)
	local wheel = buildWheel()
	wheelGui = wheel
	janitor:Add(wheel)
	-- The right stick chooses a slice while the wheel is open (gamepad).
	janitor:Add(UserInputService.InputChanged:Connect(function(object: InputObject)
		if wheelOpen and object.KeyCode == Enum.KeyCode.Thumbstick2 then
			local stick = Vector2.new(object.Position.X, -object.Position.Y)
			wheelCursor = if stick.Magnitude >= wheelConfig.StickDeadzone
				then stick.Unit * wheelConfig.RadiusPixels
				else Vector2.zero
		end
	end))
	local hint = HudKit.text(
		gui,
		"PingControls",
		UDim2.new(0.5, 0, 1, -theme.MarginPixels),
		Vector2.new(0.5, 1),
		UDim2.fromOffset(theme.ActionWidthPixels, theme.CaptionSize * 2)
	)
	hint.TextSize = theme.CaptionSize
	hint.TextWrapped = true
	hint.Visible = false
	local function controls(inputType: Enum.UserInputType)
		hint.Text = if inputType == Enum.UserInputType.Touch
			then "PING / DANGER · Aim at a person to mark a suspect"
			else InputHints.text(
				"[ MMB ] PING · HOLD FOR WHEEL · [ ALT + MMB ] DANGER",
				"[ LT + D-PAD RIGHT ] PING · HOLD FOR WHEEL · [ LT + RB ] DANGER"
			)
	end
	controls(UserInputService:GetLastInputType())
	janitor:Add(UserInputService.LastInputTypeChanged:Connect(controls))
	ContextActionService:BindActionAtPriority(
		CONTEXT_ACTION,
		input,
		true,
		GameConfig.Combat.InputPriority + 1,
		config.Key,
		config.Pad
	)
	ContextActionService:BindActionAtPriority(
		DANGER_ACTION,
		input,
		true,
		GameConfig.Combat.InputPriority + 1,
		config.DangerPad
	)
	ContextActionService:SetTitle(CONTEXT_ACTION, "PING")
	ContextActionService:SetTitle(DANGER_ACTION, "DANGER")
	ContextActionService:SetPosition(CONTEXT_ACTION, config.TouchPosition)
	ContextActionService:SetPosition(DANGER_ACTION, config.DangerTouchPosition)
	janitor:Add(RemoteController.connect("PingPlaced", add))
	janitor:Add(RemoteController.connect("PingCleared", remove))
	janitor:Add(RemoteController.connect("PhaseChanged", function(value: Types.Phase)
		phase = value
		if value == "Lobby" or value == "Insertion" or value == "Results" then
			clear()
		end
	end))
	janitor:Add(RunService.RenderStepped:Connect(function()
		hint.Visible = HeldItemController.canAct()
		if wheelOpen then
			if HeldItemController.canAct() then
				paintWheel()
			else
				pressed = false
				closeWheel(false)
			end
		end
		local now = workspace:GetServerTimeNow()
		local camera = workspace.CurrentCamera
		for id, marker in markers do
			if now >= marker.info.ExpiresAt then
				remove(id)
				continue
			end
			local target = marker.info.TargetId and workspace:FindFirstChild(marker.info.TargetId)
			local root = target and target:IsA("Model") and target:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				marker.anchor.Position = root.Position
			end
			if camera then
				local point = marker.anchor.Position
				local distance = math.floor((point - camera.CFrame.Position).Magnitude)
				local floor = Floors.hint(point)
				marker.detail.Text = `{distance} studs{if floor ~= "" then ` · {floor}` else ""}`
			end
		end
	end))
	janitor:Add(function()
		clear()
		folder = nil
		ContextActionService:UnbindAction(CONTEXT_ACTION)
		ContextActionService:UnbindAction(DANGER_ACTION)
	end)
	janitor:Add(script.Destroying:Connect(function()
		janitor:Destroy()
	end))
end

return PingController
