--!strict
-- The studio intro (owner 2026-11-25): the Never Seen Swag logo draws itself on the dark ground, the studio name and "presents" fade in under it, then
-- the whole card fades out. Any key press or click skips it. Client only; play() yields until it is over.
--
--   StudioIntro.play()

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local GameConfig = require(script.Parent.Parent.GameConfig)
local StudioLogo = require(script.Parent.StudioLogo)

local config = GameConfig.StudioIntro

local StudioIntro = {}

local TAGLINE_GAP = 28 -- space between the logo and the studio name
local LOGO_CENTER = 0.45 -- the logo's height on screen, as a fraction

function StudioIntro.play()
	if not config.Enabled then
		return
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "StudioIntro"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ScreenInsets = Enum.ScreenInsets.None
	gui.DisplayOrder = GameConfig.Loading.DisplayOrder + 1
	gui:SetAttribute("AlwaysVisible", true) -- the menu switches every other ScreenGui off

	local root = Instance.new("CanvasGroup")
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundColor3 = config.BackgroundColor
	root.BorderSizePixel = 0
	root.GroupTransparency = 1
	root.Parent = gui

	local logo = StudioLogo.build(root, config.LogoSizePixels)
	logo.root.AnchorPoint = Vector2.new(0.5, 0.5)
	logo.root.Position = UDim2.fromScale(0.5, LOGO_CENTER)

	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Font = Enum.Font.GothamBold
	name.Text = config.StudioName .. "  ·  " .. config.Tagline
	name.TextSize = config.TaglineSize
	name.TextColor3 = config.InkColor
	name.TextTransparency = 1
	name.AnchorPoint = Vector2.new(0.5, 0)
	name.Position = UDim2.new(0.5, 0, LOGO_CENTER, config.LogoSizePixels * 0.7 + TAGLINE_GAP)
	name.Size = UDim2.fromOffset(logo.root.Size.X.Offset * config.LogoSizePixels / 100, config.TaglineSize + 4)
	name.Parent = root

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local skipped = false
	local connection = UserInputService.InputBegan:Connect(function(input: InputObject)
		local kind = input.UserInputType
		if
			kind == Enum.UserInputType.Keyboard
			or kind == Enum.UserInputType.MouseButton1
			or kind == Enum.UserInputType.Touch
			or kind == Enum.UserInputType.Gamepad1
		then
			skipped = true
		end
	end)

	-- Waits for a duration but gives up at once if skipped; false when it was skipped.
	local function pause(seconds: number): boolean
		local started = os.clock()
		while os.clock() - started < seconds do
			if skipped then
				return false
			end
			task.wait()
		end
		return not skipped
	end

	local function tween(instance: Instance, seconds: number, goal: { [string]: any }, style: Enum.EasingStyle?)
		TweenService:Create(instance, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad), goal):Play()
	end

	local function run(): boolean
		tween(root, config.FadeInSeconds, { GroupTransparency = 0 })
		if not pause(config.FadeInSeconds) then
			return false
		end
		for _, letter in logo.letters do
			tween(letter, config.LetterFadeSeconds, { TextTransparency = 0 })
			if not pause(config.LetterStaggerSeconds) then
				return false
			end
		end
		for index, bar in logo.bars do
			tween(
				bar,
				config.BarStampSeconds,
				{ Size = UDim2.fromOffset(bar.Size.X.Offset, logo.barHeights[index]) },
				Enum.EasingStyle.Back
			)
		end
		if not pause(config.BarStampSeconds + config.WifiRingSeconds) then
			return false
		end
		tween(logo.dot, config.WifiRingSeconds, { BackgroundTransparency = 0 })
		for _, ring in logo.rings do
			if not pause(config.WifiRingSeconds) then
				return false
			end
			for _, segment in ring do
				tween(segment, config.WifiRingSeconds, { BackgroundTransparency = 0 })
			end
		end
		if not pause(config.WifiRingSeconds) then
			return false
		end
		tween(logo.slash, config.StrikeSeconds, { Size = UDim2.fromOffset(logo.slashLength, logo.slash.Size.Y.Offset) })
		tween(name, config.TaglineFadeSeconds, { TextTransparency = 0 })
		return pause(config.StrikeSeconds + config.HoldSeconds)
	end

	run()
	connection:Disconnect()
	local fade = TweenService:Create(root, TweenInfo.new(config.FadeOutSeconds), { GroupTransparency = 1 })
	fade:Play()
	fade.Completed:Wait()
	gui:Destroy()
end

return StudioIntro
