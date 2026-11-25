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
}

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

function SettingsController.setFov(value: number)
	if value ~= value or math.abs(value) == math.huge then
		return
	end
	preferences.Fov = math.clamp(value, GameConfig.UI.FovMin, GameConfig.UI.FovMax)
	applyFov()
end

function SettingsController.setSensitivity(value: number)
	if value ~= value or math.abs(value) == math.huge then
		return
	end
	preferences.Sensitivity = math.clamp(value, config.SensitivityMin, config.SensitivityMax)
	UserInputService.MouseDeltaSensitivity = preferences.Sensitivity
end

function SettingsController.setReducedMotion(on: boolean)
	preferences.ReducedMotion = on
	Accessibility.setReducedMotion(on)
end

function SettingsController.setCameraShake(on: boolean)
	preferences.CameraShake = on
end

function SettingsController.setCombatVolume(value: number)
	if value ~= value or math.abs(value) == math.huge then
		return
	end
	local step = GameConfig.ClientAudio.CombatVolumeStep
	preferences.CombatVolume = math.clamp(math.floor(value / step + 0.5) * step, 0, 1)
	SoundPlayer.setVolume(preferences.CombatVolume)
end

function SettingsController.setWorldVolume(value: number)
	if value ~= value or math.abs(value) == math.huge then
		return
	end
	local step = GameConfig.ClientAudio.CombatVolumeStep
	preferences.WorldVolume = math.clamp(math.floor(value / step + 0.5) * step, 0, 1)
end

function SettingsController.setExposedOutline(on: boolean)
	preferences.ExposedOutline = on
end

function SettingsController.setExposedOutlineColor(color: Color3)
	preferences.ExposedOutlineColor = color
end

function SettingsController.setShowFps(on: boolean)
	preferences.ShowFps = on
end

function SettingsController.cameraShakeEnabled(): boolean
	return preferences.CameraShake and not Accessibility.reducedMotion()
end

function SettingsController.reset()
	SettingsController.setFov(GameConfig.UI.FovMin)
	SettingsController.setSensitivity(config.DefaultSensitivity)
	SettingsController.setReducedMotion(false)
	SettingsController.setCameraShake(false)
	SettingsController.setCombatVolume(GameConfig.ClientAudio.DefaultCombatVolume)
	SettingsController.setWorldVolume(GameConfig.ClientAudio.DefaultCombatVolume)
	SettingsController.setExposedOutline(true)
	SettingsController.setExposedOutlineColor(GameConfig.ExposedOutline.DefaultColor)
	SettingsController.setShowFps(false)
end

function SettingsController.Init() end

function SettingsController.Start()
	-- Require only after all controller modules have loaded: the menu panel reads this controller's public state.
	local Panel = require(script.Parent.Parent.Menu.Components.SettingsPanel)
	local host: ScreenGui? = nil
	local root: Frame? = nil
	local originalSensitivity = UserInputService.MouseDeltaSensitivity
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
