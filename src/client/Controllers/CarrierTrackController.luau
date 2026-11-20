--!strict
-- Private carrier marks and tracked-rival feedback; no actor lookup or decoration.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")
local ContentProvider = game:GetService("ContentProvider")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.GameConfig)
local InputHints = require(Shared:WaitForChild("Util"):WaitForChild("InputHints"))
local Types = require(Shared.Types)
local Janitor = require(Shared.Util.Janitor)
local HudKit = require(Shared.Util.HudKit)
local HudTheme = require(Shared.Util.HudTheme)
local Accessibility = require(Shared.Util.UiAccessibility)
local Package = require(script.Parent.PackageController)
local Remote = require(script.Parent.RemoteController)
local HeldItemController = require(script.Parent.HeldItemController)
local CarrierTrackController = {}
local marks: { Vector3 } = {}
local revision = 0
local expires: number? = nil

local function clearMarks()
	if #marks == 0 and expires == nil then
		return
	end
	marks = {}
	expires = nil
	revision += 1
end

function CarrierTrackController.marks(): ({ Vector3 }, number)
	if expires and os.clock() >= expires then
		clearMarks()
	end
	return table.clone(marks), revision
end

function CarrierTrackController.Init() end

function CarrierTrackController.Start()
	local janitor = Janitor.new()
	local config = GameConfig.CarrierTrackHud
	local theme = HudTheme.get()
	local player = Players.LocalPlayer
	local phase: Types.Phase = "Lobby"
	local carrier = false
	local unavailable = false
	local focused = true
	local pressed: { [Enum.KeyCode]: boolean } = {}
	local cueUntil = 0
	local wasActive = false
	local pendingCue = false
	local alive = true
	local gui = HudKit.screen("CarrierTrackingHud")
	janitor:Add(gui)
	local hint = HudKit.panel(
		gui,
		"CarrierTrackHint",
		UDim2.new(0, theme.MarginPixels, 1, -theme.MarginPixels - theme.VitalsHeightPixels - theme.PaddingPixels),
		Vector2.new(0, 1),
		UDim2.fromOffset(theme.ActionWidthPixels, theme.ActionHeightPixels)
	)
	local hintRoot = hint.Parent :: Frame
	hintRoot.Visible = false
	local label = HudKit.text(
		hint,
		"TrackingControls",
		UDim2.fromOffset(theme.PaddingPixels, theme.PaddingPixels),
		Vector2.zero,
		UDim2.new(1, -theme.PaddingPixels * 2, 1, -theme.PaddingPixels * 2)
	)
	label.TextSize = theme.CaptionSize
	label.TextWrapped = true
	local function controlsText(): string
		return `{InputHints.bracket(config.Key, config.Pad, "TRACK · tap / hold")}\n{GameConfig.CarrierTrack.TapCost} Intel / tap · {GameConfig.CarrierTrack.HoldCostPerSecond} Intel / sec`
	end
	label.Text = controlsText()
	janitor:Add(InputHints.onChange(function()
		label.Text = controlsText()
	end))
	local vignette = HudKit.edgeGlow(gui, config.CueColor)
	local whisper = Instance.new("Sound")
	whisper.Name = "LocalTrackedWhisper"
	whisper.SoundId = config.WhisperSoundId
	whisper.Volume = config.WhisperVolume
	whisper.PlaybackSpeed = config.WhisperSpeed
	whisper.Looped = false
	whisper.Parent = SoundService
	janitor:Add(whisper)
	local filter = Instance.new("EqualizerSoundEffect")
	filter.LowGain = config.WhisperLowGain
	filter.MidGain = config.WhisperMidGain
	filter.HighGain = config.WhisperHighGain
	filter.Parent = whisper
	local function active(): boolean
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		return gui.Enabled
			and not unavailable
			and humanoid ~= nil
			and humanoid.Health > 0
			and (phase == "Infiltration" or phase == "VaultBreach" or phase == "PackageHeist" or phase == "Overtime")
	end
	local function release()
		if next(pressed) ~= nil then
			table.clear(pressed)
			Remote.fire("RequestCarrierTrack", false)
		end
	end
	local function reset()
		release()
		clearMarks()
		cueUntil = 0
		pendingCue = false
		wasActive = false
		vignette.setAll(1)
		whisper:Stop()
		hintRoot.Visible = false
	end
	local function playCue()
		if not alive or not pendingCue or not active() or not whisper.IsLoaded then
			return
		end
		pendingCue = false
		cueUntil = os.clock() + config.CueSeconds
		whisper:Stop()
		whisper.TimePosition = 0
		whisper:Play()
	end
	janitor:Add(whisper.Loaded:Connect(playCue))
	task.spawn(function()
		local ok, reason = pcall(function()
			ContentProvider:PreloadAsync({ whisper })
		end)
		if not alive then
			return
		end
		if not ok then
			warn("[CarrierTrack] Cue preload failed: " .. tostring(reason))
		end
		playCue()
	end)
	ContextActionService:BindActionAtPriority("CarrierTrack", function(_, inputState, input)
		if inputState == Enum.UserInputState.Begin then
			if not active() or not carrier or not focused or HeldItemController.isInputBlocked() then
				return Enum.ContextActionResult.Pass
			end
			local key = input.KeyCode
			if not pressed[key] then
				local first = next(pressed) == nil
				pressed[key] = true
				if first then
					Remote.fire("RequestCarrierTrack", true)
				end
			end
			return Enum.ContextActionResult.Sink
		elseif inputState == Enum.UserInputState.Cancel then
			local had = next(pressed) ~= nil
			release()
			return if had then Enum.ContextActionResult.Sink else Enum.ContextActionResult.Pass
		elseif inputState == Enum.UserInputState.End and input and pressed[input.KeyCode] then
			pressed[input.KeyCode] = nil
			if next(pressed) == nil then
				Remote.fire("RequestCarrierTrack", false)
			end
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, false, GameConfig.Combat.InputPriority + 1, config.Key, config.Pad)
	janitor:Add(function()
		release()
		ContextActionService:UnbindAction("CarrierTrack")
	end)
	janitor:Add(Remote.connect("PackageState", function(info: Types.PackageStateInfo)
		carrier = info.YouCarry
		if not carrier or HeldItemController.isInputBlocked() then
			release()
			clearMarks()
			hintRoot.Visible = false
		end
	end))
	janitor:Add(Remote.connect("CarrierTrackState", function(info: Types.CarrierTrackInfo)
		if info.Mode == "End" then
			clearMarks()
			return
		end
		if not active() or not carrier then
			return
		end
		marks = table.clone(info.Marks)
		expires = if info.Mode == "Ping" then os.clock() + (info.Seconds or 0) else nil
		revision += 1
	end))
	janitor:Add(Remote.connect("TrackedCue", function()
		if not active() then
			return
		end
		cueUntil = os.clock() + config.CueSeconds
		pendingCue = true
		playCue()
	end))
	janitor:Add(Remote.connect("PhaseChanged", function(value: Types.Phase)
		phase = value
		reset()
		if value == "Lobby" or value == "Insertion" then
			carrier = false
			unavailable = false
		end
	end))
	for _, name in { "Downed", "Eliminated" } do
		janitor:Add(Remote.connect(name, function()
			unavailable = true
			reset()
		end))
	end
	janitor:Add(Remote.connect("Revived", function()
		unavailable = false
	end))
	janitor:Add(Remote.connect("ExtractionState", function(info: Types.ExtractionStateInfo)
		if info.State == "Extracted" then
			unavailable = true
			reset()
		end
	end))
	janitor:Add(player.CharacterAdded:Connect(function()
		carrier = false
		unavailable = false
		reset()
	end))
	janitor:Add(UserInputService.WindowFocusReleased:Connect(function()
		focused = false
		release()
	end))
	janitor:Add(UserInputService.WindowFocused:Connect(function()
		focused = true
	end))
	janitor:Add(UserInputService.TextBoxFocused:Connect(release))
	local initial = Package.state()
	carrier = initial ~= nil and initial.YouCarry
	local elapsed = 0
	janitor:Add(RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < config.RefreshSeconds then
			return
		end
		elapsed = 0
		if not active() then
			if wasActive then
				reset()
			end
			return
		end
		wasActive = true
		hintRoot.Visible = carrier
		if not carrier then
			release()
		end
		local remaining = cueUntil - os.clock()
		if remaining <= 0 and cueUntil > 0 then
			cueUntil = 0
			vignette.setAll(1)
			whisper:Stop()
		elseif remaining > 0 then
			-- Reduced Motion keeps a steady, faint edge; normal mode only fades, never pulses or shakes.
			local opacity = 1 - config.CueTransparency
			if not Accessibility.reducedMotion() then
				opacity *= math.clamp(remaining / config.CueSeconds, 0, 1)
			end
			vignette.setAll(1 - opacity)
		end
		CarrierTrackController.marks()
	end))
	janitor:Add(function()
		alive = false
		reset()
	end)
	janitor:Add(script.Destroying:Connect(function()
		janitor:Destroy()
	end))
end

return CarrierTrackController
