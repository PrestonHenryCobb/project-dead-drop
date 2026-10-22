--!strict
-- Client side of disguises (spec 6.3, 6.4, 6.8): the Scan, Disguise and Sprint keys and the small HUD for them.
--
--   Hold Scan while aiming at a character within range: the client names what it is aiming at and the server does the
--   scanning (range, sight and timing are all checked there). A ring around the centre dot fills while it runs.
--   Disguise asks the server to put on the stored disguise, or the insertion disguise if there is none.
--   A badge shows the disguise being worn and the one stored (STYLE_QUESTIONS A1: first person, so you cannot see
--   yourself). Nothing here is sent to anyone else.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local OutfitDefs = require(Shared:WaitForChild("Defs"):WaitForChild("OutfitDefs"))
local Types = require(Shared:WaitForChild("Types"))
local RemoteController = require(script.Parent.RemoteController)

local DisguiseController = {}

local ui = GameConfig.UI
local controls = GameConfig.Controls
local localPlayer = Players.LocalPlayer

local scanHeld = false
local scanSentTarget: string? = nil
local scanStartedAt: number? = nil
local scanSeconds = 0

local ringSegments: { Frame } = {}
local badge: TextLabel? = nil
local toast: TextLabel? = nil
local toastToken = 0

local function newText(parent: Instance, name: string, position: UDim2, anchor: Vector2, size: UDim2): TextLabel
	local text = Instance.new("TextLabel")
	text.Name = name
	text.BackgroundTransparency = 1
	text.Font = ui.Font
	text.TextSize = ui.TextSize
	text.TextColor3 = ui.TextColor
	text.TextStrokeTransparency = 0.5
	text.AnchorPoint = anchor
	text.Position = position
	text.Size = size
	text.Parent = parent
	return text
end

local function buildHud(): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = "DisguiseHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true

	local dot = Instance.new("Frame")
	dot.Name = "Dot"
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.fromScale(0.5, 0.5)
	dot.Size = UDim2.fromOffset(ui.CrosshairPixels, ui.CrosshairPixels)
	dot.BackgroundColor3 = ui.TextColor
	dot.BorderSizePixel = 0
	dot.Parent = gui

	-- A thin ring made of small ticks, lit from the top as the scan progresses.
	for index = 1, ui.ScanRingSegments do
		local angle = (index - 1) / ui.ScanRingSegments * 2 * math.pi
		local tick = Instance.new("Frame")
		tick.Name = `Tick{index}`
		tick.AnchorPoint = Vector2.new(0.5, 0.5)
		tick.Position = UDim2.new(0.5, math.sin(angle) * ui.ScanRingRadius, 0.5, -math.cos(angle) * ui.ScanRingRadius)
		tick.Size = UDim2.fromOffset(2, 6)
		tick.Rotation = math.deg(angle)
		tick.BackgroundColor3 = ui.ScanRingDimColor
		tick.BorderSizePixel = 0
		tick.Visible = false
		tick.Parent = gui
		table.insert(ringSegments, tick)
	end

	local badgeText = newText(gui, "Badge", UDim2.new(0, 16, 1, -16), Vector2.new(0, 1), UDim2.fromOffset(280, 44))
	badgeText.TextXAlignment = Enum.TextXAlignment.Left
	badgeText.TextYAlignment = Enum.TextYAlignment.Bottom
	badge = badgeText

	local toastText = newText(gui, "Toast", UDim2.new(0.5, 0, 0, 80), Vector2.new(0.5, 0), UDim2.fromOffset(420, 24))
	toastText.TextTransparency = 1
	toastText.TextStrokeTransparency = 1
	toast = toastText

	gui.Parent = localPlayer:WaitForChild("PlayerGui")
	return gui
end

local function showToast(text: string)
	local toastText = toast
	if not toastText then
		return
	end
	toastToken += 1
	local token = toastToken
	toastText.Text = text
	toastText.TextTransparency = 0
	toastText.TextStrokeTransparency = 0.5
	task.delay(ui.ToastSeconds, function()
		if token == toastToken then
			toastText.TextTransparency = 1
			toastText.TextStrokeTransparency = 1
		end
	end)
end

local function roleOf(outfitId: string): string
	local outfit = OutfitDefs.byId[outfitId]
	return if outfit then string.upper(outfit.Role) else "?"
end

local function showDisguise(update: Types.DisguiseUpdate)
	local text = badge
	if not text then
		return
	end
	local stored = update.Slots[1]
	local storedLine = if type(stored) == "string" then roleOf(stored) else "EMPTY"
	text.Text = `WEARING {roleOf(update.Worn)}\nSTORED {storedLine}`
end

local function setRing(progress: number?)
	for index, tick in ringSegments do
		tick.Visible = progress ~= nil
		if progress then
			tick.BackgroundColor3 = if index / #ringSegments <= progress then ui.ScanRingColor else ui.ScanRingDimColor
		end
	end
end

-- The character under the centre of the screen, if it is close enough to be worth asking the server about.
local function aimedTarget(): string?
	local camera = workspace.CurrentCamera
	local character = localPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (camera and character and root and root:IsA("BasePart")) then
		return nil
	end
	local viewport = camera.ViewportSize
	local ray = camera:ViewportPointToRay(viewport.X / 2, viewport.Y / 2)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local reach = (camera.CFrame.Position - root.Position).Magnitude + GameConfig.Cover.ScanRange + 2
	local hit = workspace:Raycast(ray.Origin, ray.Direction * reach, params)
	local model = hit and hit.Instance:FindFirstAncestorOfClass("Model")
	if
		not model or not (model:FindFirstChildOfClass("Humanoid") or model:FindFirstChildOfClass("AnimationController"))
	then
		return nil
	end
	local targetRoot = model:FindFirstChild("HumanoidRootPart")
	if not (targetRoot and targetRoot:IsA("BasePart")) then
		return nil
	end
	local offset = targetRoot.Position - root.Position
	if Vector3.new(offset.X, 0, offset.Z).Magnitude > GameConfig.Cover.ScanRange then
		return nil
	end
	return model.Name
end

local function onScan(_: string, state: Enum.UserInputState)
	if state == Enum.UserInputState.Begin then
		scanHeld = true
	elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
		scanHeld = false
		if scanSentTarget then
			scanSentTarget = nil
			RemoteController.fire("RequestScan", nil)
		end
	end
	return Enum.ContextActionResult.Pass
end

local function onDisguise(_: string, state: Enum.UserInputState)
	if state == Enum.UserInputState.Begin then
		RemoteController.fire("RequestDisguise")
	end
	return Enum.ContextActionResult.Pass
end

local function onSprint(_: string, state: Enum.UserInputState)
	if state == Enum.UserInputState.Begin then
		RemoteController.fire("RequestSprint", true)
	elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
		RemoteController.fire("RequestSprint", false)
	end
	return Enum.ContextActionResult.Pass
end

function DisguiseController.Init() end

function DisguiseController.Start()
	buildHud()

	ContextActionService:BindAction("Scan", onScan, false, controls.Scan, controls.ScanPad)
	ContextActionService:BindAction("Disguise", onDisguise, false, controls.Disguise, controls.DisguisePad)
	ContextActionService:BindAction("Sprint", onSprint, false, controls.Sprint)

	RemoteController.connect("DisguiseUpdate", function(update: Types.DisguiseUpdate)
		showDisguise(update)
	end)
	RemoteController.connect("Notification", function(text: string)
		showToast(text)
	end)
	RemoteController.connect("ScanState", function(info: { State: string, Seconds: number? })
		if info.State == "Started" then
			scanStartedAt = os.clock()
			scanSeconds = info.Seconds or GameConfig.Cover.ScanSeconds
		else
			-- Hold or re-aim to try again; the same aim is not sent twice, so a finished scan does not repeat.
			scanStartedAt = nil
			setRing(nil)
			if info.State == "Done" then
				showToast("Disguise stored")
			end
		end
	end)

	RunService.RenderStepped:Connect(function()
		if scanHeld then
			-- Tell the server what we are aiming at whenever it changes; it does the rest.
			local target = aimedTarget()
			if target ~= scanSentTarget then
				scanSentTarget = target
				RemoteController.fire("RequestScan", target)
			end
		end
		if scanStartedAt then
			setRing(math.clamp((os.clock() - scanStartedAt) / scanSeconds, 0, 1))
		end
	end)
end

return DisguiseController
