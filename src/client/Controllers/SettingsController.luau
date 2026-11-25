--!strict
-- Spec 21.2: session camera/accessibility preferences and in-match settings access. No gameplay or save-data requests.
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.GameConfig)
local Janitor = require(Shared.Util.Janitor)
local Accessibility = require(Shared.Util.UiAccessibility)
local CameraGuard = require(script.Parent.Parent.Combat.CameraGuard)
local SettingsSchema = require(Shared.Defs.SettingsSchema)
local GraphicsController = require(script.Parent.GraphicsController)
local RemoteController = require(script.Parent.RemoteController)
local SoundPlayer = require(script.Parent.Parent.Combat.SoundPlayer)
local SettingsController = {}
local config = GameConfig.ClientSettings
local player = Players.LocalPlayer
local janitor = Janitor.new()
local ACTION = "CoverStorySettings"
local CLOSE_ACTION = "CoverStoryCloseSettings"
export type Preferences = {
	Fov: number,
	Sensitivity: number,
	ReducedMotion: boolean,
	CameraShake: boolean,
	CombatVolume: number,
	WorldVolume: number, -- ambience, footsteps and every non-weapon cue
	ExposedOutline: boolean, -- outline other players who are Exposed
	ExposedOutlineColor: Color3,
	ShowFps: boolean,
	AdsSensitivity: number, -- a multiple of Sensitivity while the right mouse button is held
	CrosshairColor: Color3,
	CrosshairScale: number,
}
local preferences: Preferences = {
	Fov = GameConfig.UI.FovMin,
	Sensitivity = config.DefaultSensitivity,
	ReducedMotion = false,
	CameraShake = false,
	CombatVolume = GameConfig.ClientAudio.DefaultCombatVolume,
	WorldVolume = GameConfig.ClientAudio.DefaultCombatVolume,
	ExposedOutline = true,
	ExposedOutlineColor = GameConfig.ExposedOutline.DefaultColor,
	ShowFps = false,
	AdsSensitivity = config.DefaultAdsSensitivity,
	CrosshairColor = GameConfig.Combat.Feedback.CrosshairColor,
	CrosshairScale = 1,
}

-- Settings are saved with the profile. Until the saved ones have been read, changes are not sent (they would overwrite the saved values with defaults).
local loaded = false
local applying = false
local saveToken = 0

local function changed()
	if not loaded or applying then
		return
	end
	saveToken += 1
	local token = saveToken
	task.delay(config.SaveDelaySeconds, function()
		if token == saveToken then
			pcall(function()
				RemoteController.invoke("RequestSaveSettings", SettingsController.exportStored())
			end)
		end
	end)
end

local function applyFov()
	local camera = workspace.CurrentCamera
	-- The lobby stage owns its own framing. Apply the selected gameplay FOV after it hands back the camera on spawn.
	if camera and (player.Character or CameraGuard.remoteViewing()) and not CameraGuard.menuOpen() then
		camera.FieldOfView = preferences.Fov
	end
end

function SettingsController.get(): Preferences
	return table.clone(preferences)
end

local function finite(value: number): boolean
	return value == value and math.abs(value) ~= math.huge
end

function SettingsController.setFov(value: number)
	if not finite(value) then
		return
	end
	preferences.Fov = math.clamp(value, GameConfig.UI.FovMin, GameConfig.UI.FovMax)
	applyFov()
	changed()
end

function SettingsController.setSensitivity(value: number)
	if not finite(value) then
		return
	end
	preferences.Sensitivity = math.clamp(value, config.SensitivityMin, config.SensitivityMax)
	UserInputService.MouseDeltaSensitivity = preferences.Sensitivity
	changed()
end

function SettingsController.setAdsSensitivity(value: number)
	if not finite(value) then
		return
	end
	local step = config.AdsSensitivityStep
	preferences.AdsSensitivity =
		math.clamp(math.floor(value / step + 0.5) * step, config.AdsSensitivityMin, config.AdsSensitivityMax)
	changed()
end

function SettingsController.setReducedMotion(on: boolean)
	preferences.ReducedMotion = on
	Accessibility.setReducedMotion(on)
	changed()
end

function SettingsController.setCameraShake(on: boolean)
	preferences.CameraShake = on
	changed()
end

function SettingsController.setCombatVolume(value: number)
	if not finite(value) then
		return
	end
	local step = GameConfig.ClientAudio.CombatVolumeStep
	preferences.CombatVolume = math.clamp(math.floor(value / step + 0.5) * step, 0, 1)
	SoundPlayer.setVolume(preferences.CombatVolume)
	changed()
end

function SettingsController.setWorldVolume(value: number)
	if not finite(value) then
		return
	end
	local step = GameConfig.ClientAudio.CombatVolumeStep
	preferences.WorldVolume = math.clamp(math.floor(value / step + 0.5) * step, 0, 1)
	changed()
end

function SettingsController.setExposedOutline(on: boolean)
	preferences.ExposedOutline = on
	changed()
end

function SettingsController.setExposedOutlineColor(color: Color3)
	preferences.ExposedOutlineColor = color
	changed()
end

function SettingsController.setShowFps(on: boolean)
	preferences.ShowFps = on
	changed()
end

function SettingsController.setCrosshairColor(color: Color3)
	preferences.CrosshairColor = color
	changed()
end

function SettingsController.setCrosshairScale(value: number)
	if not finite(value) then
		return
	end
	local step = config.CrosshairScaleStep
	preferences.CrosshairScale =
		math.clamp(math.floor(value / step + 0.5) * step, config.CrosshairScaleMin, config.CrosshairScaleMax)
	changed()
end

-- The graphics quality and the hand-set shadows and bloom live in GraphicsController; these save them with the rest.
function SettingsController.setGraphicsMode(mode: GraphicsController.Mode)
	GraphicsController.setMode(mode, true)
	changed()
end

function SettingsController.setShadows(on: boolean?)
	GraphicsController.setShadows(on)
	changed()
end

function SettingsController.setBloom(on: boolean?)
	GraphicsController.setBloom(on)
	changed()
end

-- The player's crosshair colour and size (a multiple of the default); read every frame, so it does not clone the table.
function SettingsController.crosshair(): (Color3, number)
	return preferences.CrosshairColor, preferences.CrosshairScale
end

function SettingsController.cameraShakeEnabled(): boolean
	return preferences.CameraShake and not Accessibility.reducedMotion()
end

function SettingsController.reset()
	applying = true -- one save after the whole reset, not one per setting
	SettingsController.setFov(GameConfig.UI.FovMin)
	SettingsController.setSensitivity(config.DefaultSensitivity)
	SettingsController.setAdsSensitivity(config.DefaultAdsSensitivity)
	SettingsController.setReducedMotion(false)
	SettingsController.setCameraShake(false)
	SettingsController.setCombatVolume(GameConfig.ClientAudio.DefaultCombatVolume)
	SettingsController.setWorldVolume(GameConfig.ClientAudio.DefaultCombatVolume)
	SettingsController.setExposedOutline(true)
	SettingsController.setExposedOutlineColor(GameConfig.ExposedOutline.DefaultColor)
	SettingsController.setShowFps(false)
	SettingsController.setCrosshairColor(GameConfig.Combat.Feedback.CrosshairColor)
	SettingsController.setCrosshairScale(1)
	SettingsController.setGraphicsMode("Auto")
	SettingsController.setShadows(nil)
	SettingsController.setBloom(nil)
	applying = false
	changed()
end

local function choiceOf(value: boolean?): string
	return if value == nil then "Auto" elseif value then "On" else "Off"
end

local function valueOf(choice: string): boolean?
	return if choice == "On" then true elseif choice == "Off" then false else nil
end

-- Every saved setting, in the form the profile stores (Defs/SettingsSchema).
function SettingsController.exportStored(): { [string]: any }
	return {
		Fov = preferences.Fov,
		Sensitivity = preferences.Sensitivity,
		AdsSensitivity = preferences.AdsSensitivity,
		ReducedMotion = preferences.ReducedMotion,
		CameraShake = preferences.CameraShake,
		CombatVolume = preferences.CombatVolume,
		WorldVolume = preferences.WorldVolume,
		ExposedOutline = preferences.ExposedOutline,
		ExposedOutlineColor = SettingsSchema.colorToStored(preferences.ExposedOutlineColor),
		ShowFps = preferences.ShowFps,
		CrosshairColor = SettingsSchema.colorToStored(preferences.CrosshairColor),
		CrosshairScale = preferences.CrosshairScale,
		GraphicsMode = GraphicsController.getMode(),
		Shadows = choiceOf(GraphicsController.shadowsChoice()),
		Bloom = choiceOf(GraphicsController.bloomChoice()),
	}
end

-- Applies saved settings (only the valid keys), without saving them straight back.
function SettingsController.applyStored(stored: any)
	local clean = SettingsSchema.sanitize(stored)
	applying = true
	if clean.Fov then
		SettingsController.setFov(clean.Fov)
	end
	if clean.Sensitivity then
		SettingsController.setSensitivity(clean.Sensitivity)
	end
	if clean.AdsSensitivity then
		SettingsController.setAdsSensitivity(clean.AdsSensitivity)
	end
	if clean.ReducedMotion ~= nil then
		SettingsController.setReducedMotion(clean.ReducedMotion)
	end
	if clean.CameraShake ~= nil then
		SettingsController.setCameraShake(clean.CameraShake)
	end
	if clean.CombatVolume then
		SettingsController.setCombatVolume(clean.CombatVolume)
	end
	if clean.WorldVolume then
		SettingsController.setWorldVolume(clean.WorldVolume)
	end
	if clean.ExposedOutline ~= nil then
		SettingsController.setExposedOutline(clean.ExposedOutline)
	end
	local outlineColor = SettingsSchema.storedToColor(clean.ExposedOutlineColor)
	if outlineColor then
		SettingsController.setExposedOutlineColor(outlineColor)
	end
	if clean.ShowFps ~= nil then
		SettingsController.setShowFps(clean.ShowFps)
	end
	local crosshairColor = SettingsSchema.storedToColor(clean.CrosshairColor)
	if crosshairColor then
		SettingsController.setCrosshairColor(crosshairColor)
	end
	if clean.CrosshairScale then
		SettingsController.setCrosshairScale(clean.CrosshairScale)
	end
	if clean.GraphicsMode then
		SettingsController.setGraphicsMode(clean.GraphicsMode)
	end
	if clean.Shadows then
		SettingsController.setShadows(valueOf(clean.Shadows))
	end
	if clean.Bloom then
		SettingsController.setBloom(valueOf(clean.Bloom))
	end
	applying = false
end

function SettingsController.Init() end

function SettingsController.Start()
	-- Require only after all controller modules have loaded: the menu panel reads this controller's public state.
	local Panel = require(script.Parent.Parent.Menu.Components.SettingsPanel)
	local host: ScreenGui? = nil
	local root: Frame? = nil
	local originalSensitivity = UserInputService.MouseDeltaSensitivity
	-- Read the saved settings once the profile has loaded; until then changes are not sent.
	task.spawn(function()
		for _ = 1, config.LoadAttempts do
			local ok, snapshot = pcall(RemoteController.invoke, "GetPlayerMetaProfile")
			if ok and type(snapshot) == "table" and snapshot.Profile then
				SettingsController.applyStored(snapshot.Profile.Settings)
				break
			end
			task.wait(config.LoadRetrySeconds)
		end
		loaded = true
	end)
	-- Aiming down sights (the right mouse button held) uses its own sensitivity.
	janitor:Add(game:GetService("RunService").RenderStepped:Connect(function()
		local aiming = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
		UserInputService.MouseDeltaSensitivity = preferences.Sensitivity
			* (if aiming and not CameraGuard.menuOpen() then preferences.AdsSensitivity else 1)
	end))
	SettingsController.setSensitivity(preferences.Sensitivity)
	SoundPlayer.setVolume(preferences.CombatVolume)
	local function toggle()
		if Panel.isOpen() then
			Panel.close()
			return
		end
		local playerGui = player:FindFirstChildOfClass("PlayerGui")
		if not playerGui then
			return
		end
		local menu = playerGui:FindFirstChild("CoverStoryMenuGui")
		local menuRoot = menu and menu:FindFirstChild("Root")
		if menuRoot and menuRoot:IsA("Frame") then
			Panel.open(menuRoot)
			return
		end
		if not host then
			local gui = Instance.new("ScreenGui")
			gui.Name = "SessionSettings"
			gui.IgnoreGuiInset = true
			gui.ResetOnSpawn = false
			gui.DisplayOrder = GameConfig.MatchHud.DisplayOrder + 1
			gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
			gui.Parent = playerGui
			janitor:Add(gui)
			host = gui
			local frame = Instance.new("Frame")
			frame.Name = "Root"
			frame.BackgroundTransparency = 1
			frame.Size = UDim2.fromScale(1, 1)
			frame.Parent = gui
			root = frame
		end
		(host :: ScreenGui).Enabled = true
		Panel.open(root :: Frame)
	end
	ContextActionService:BindActionAtPriority(ACTION, function(_, state)
		if state ~= Enum.UserInputState.Begin or UserInputService:GetFocusedTextBox() or GuiService.MenuIsOpen then
			return Enum.ContextActionResult.Pass
		end
		toggle()
		return Enum.ContextActionResult.Sink
	end, false, GameConfig.Combat.InputPriority + 2, config.Key)
	ContextActionService:BindActionAtPriority(CLOSE_ACTION, function(_, state)
		if state == Enum.UserInputState.Begin and Panel.isOpen() and not UserInputService:GetFocusedTextBox() then
			Panel.close()
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, false, GameConfig.Combat.InputPriority + 2, Enum.KeyCode.ButtonB, Enum.KeyCode.Backspace)
	janitor:Add(GuiService.MenuOpened:Connect(Panel.close))
	janitor:Add(player.CharacterAdded:Connect(function(character)
		Panel.close()
		task.defer(function()
			if player.Character == character then
				applyFov()
			end
		end)
	end))
	janitor:Add(workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(applyFov))
	applyFov()
	janitor:Add(function()
		Panel.close()
		ContextActionService:UnbindAction(ACTION)
		ContextActionService:UnbindAction(CLOSE_ACTION)
		UserInputService.MouseDeltaSensitivity = originalSensitivity
		Accessibility.setReducedMotion(false)
	end)
	janitor:Add(script.Destroying:Connect(function()
		janitor:Destroy()
	end))
end

return SettingsController
