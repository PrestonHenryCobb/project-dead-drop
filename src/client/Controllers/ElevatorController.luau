--!strict
-- Glass elevator selector: replicated stops and status; server-authoritative travel.
local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enums = require(Shared:WaitForChild("Enums"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local InputHints = require(Shared:WaitForChild("Util"):WaitForChild("InputHints"))
local Janitor = require(Shared:WaitForChild("Util"):WaitForChild("Janitor"))
local RemoteController = require(script.Parent.RemoteController)

local ElevatorController = {}

local ACTION = "CoverStoryElevatorFloor"
local CHECK_SECONDS = GameConfig.SecurityHud.RefreshSeconds
local controls = GameConfig.Controls
local rideConfig = GameConfig.Doors.Elevators
local localPlayer = Players.LocalPlayer

local janitor = Janitor.new()
local current: BasePart? = nil

local function insideCab(): BasePart?
	local root = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return nil
	end
	for _, instance in CollectionService:GetTagged(Enums.Tag.ElevatorCab) do
		if instance:IsA("BasePart") then
			local offset = instance.CFrame:PointToObjectSpace(root.Position)
			local half = instance.Size / 2
			if
				math.abs(offset.X) <= half.X + rideConfig.CabSlackStuds
				and math.abs(offset.Z) <= half.Z + rideConfig.CabSlackStuds
				and offset.Y >= -half.Y - rideConfig.CabSlackStuds
				and offset.Y <= rideConfig.CabHeightStuds
			then
				return instance
			end
		end
	end
	return nil
end

-- The level names of a cab, lowest first, from its Stops attribute ("G:0,M:24,T:48").
local function levelsOf(cab: BasePart): { string }
	local stops: { { name: string, height: number } } = {}
	local text = cab:GetAttribute("Stops")
	for entry in string.gmatch(if type(text) == "string" then text else "", "[^,]+") do
		local name, height = string.match(entry, "^(%a+):(%-?[%d%.]+)$")
		local numericHeight = if height then tonumber(height) else nil
		if name and numericHeight then
			table.insert(stops, { name = name, height = numericHeight })
		end
	end
	table.sort(stops, function(a, b)
		return a.height < b.height
	end)
	local names: { string } = {}
	for _, stop in stops do
		table.insert(names, stop.name)
	end
	return names
end

local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local HudKit = require(Shared.Util.HudKit)
local HudTheme = require(Shared.Util.HudTheme)
local HeldItemController = require(script.Parent.HeldItemController)

function ElevatorController.Init() end

function ElevatorController.Start()
	local theme = HudTheme.get()
	local content = Janitor.new()
	janitor:Add(content)
	local gui = HudKit.screen("ElevatorSelector")
	gui.DisplayOrder = GameConfig.MatchHud.DisplayOrder
	janitor:Add(gui)
	local panel = HudKit.panel(
		gui,
		"ElevatorLevels",
		UDim2.new(1, -theme.MarginPixels, 0.5, 0),
		Vector2.new(1, 0.5),
		UDim2.fromOffset(theme.ActionWidthPixels, theme.ActionHeightPixels)
	)
	local root = panel.Parent :: Frame
	root.Visible = false
	local title = HudKit.text(
		panel,
		"CabStatus",
		UDim2.fromOffset(theme.PaddingPixels, theme.PaddingPixels),
		Vector2.zero,
		UDim2.new(1, -theme.PaddingPixels * 2, 0, theme.CaptionSize)
	)
	title.TextSize = theme.CaptionSize
	local rows = Instance.new("Frame")
	rows.BackgroundTransparency = 1
	rows.Position = UDim2.fromOffset(theme.PaddingPixels, theme.CaptionSize + theme.PaddingPixels * 2)
	rows.Size = UDim2.new(1, -theme.PaddingPixels * 2, 1, -theme.CaptionSize - theme.PaddingPixels * 3)
	rows.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, theme.PaddingPixels)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = rows
	local opened = false
	local previous: GuiObject? = nil
	local signature = ""
	local phase = "Lobby"
	local unavailable = false
	local function close()
		opened = false
		signature = ""
		HeldItemController.setInterfaceBlocked(gui, false)
		if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(rows) then
			GuiService.SelectedObject = if previous and previous.Parent then previous else nil
		end
		previous = nil
	end
	local function button(name: string, text: string, order: number, enabled: boolean, callback: () -> ()): TextButton
		local item = Instance.new("TextButton")
		item.Name = name
		item.Text = text
		item.Font = theme.Font
		item.TextSize = theme.CaptionSize
		item.TextColor3 = if enabled then theme.TextColor else theme.DimTextColor
		item.BackgroundColor3 = theme.PanelColor
		item.BackgroundTransparency = theme.PanelTransparency
		item.AutoButtonColor = true
		item.Modal = opened -- releases the first-person mouse only while choosing a destination
		item.Active = enabled
		item.Selectable = enabled
		item.TextWrapped = true
		item.Size = UDim2.new(1, 0, 0, theme.CaptionSize + theme.PaddingPixels * 2)
		item.LayoutOrder = order
		item.Parent = rows
		content:Add(item)
		content:Add(item.Activated:Connect(function()
			if item.Active and HeldItemController.canAct(gui) then
				callback()
			end
		end))
		return item
	end
	local function open()
		if not current or opened or not HeldItemController.canAct(gui) then
			return
		end
		previous = GuiService.SelectedObject
		opened = true
		signature = ""
		HeldItemController.setInterfaceBlocked(gui, true)
	end
	local function refresh()
		local cab = current
		root.Visible = cab ~= nil and gui.Enabled
		if not cab then
			close()
			return
		end
		local state = cab:GetAttribute("State")
		local level = cab:GetAttribute("Level")
		local stops = cab:GetAttribute("Stops")
		local key = tostring(stops)
			.. "/"
			.. tostring(state)
			.. "/"
			.. tostring(level)
			.. tostring(opened)
			.. tostring(InputHints.isGamepad())
		if key == signature then
			return
		end
		signature = key
		title.Text = if state == "Moving"
			then "ELEVATOR · MOVING"
			else `ELEVATOR · {if type(level) == "string" and level ~= "" then level else "—"} · {if type(
					state
				) == "string"
				then string.upper(state)
				else ""}`
		local selected = GuiService.SelectedObject
		local selectedName = if selected and selected:IsDescendantOf(rows) then selected.Name else nil
		content:Cleanup()
		local count = 1
		local first: TextButton? = nil
		local preferred: TextButton? = nil
		if opened then
			for index, name in levelsOf(cab) do
				local enabled = (state == "Idle" or state == "Open") and name ~= level
				local item = button(
					name,
					`LEVEL {string.upper(name)}{if name == level then " · HERE" else ""}`,
					index,
					enabled,
					function()
						if current ~= cab or insideCab() ~= cab or cab:GetAttribute("State") == "Moving" then
							return
						end
						RemoteController.fire("RequestElevatorFloor", name)
						close()
					end
				)
				if enabled then
					first = first or item
					if name == selectedName then
						preferred = item
					end
				end
				count += 1
			end
			local back = button("CloseElevator", InputHints.text("CLOSE · ESC", "CLOSE · B"), count, true, close)
			first = first or back
		else
			first = button(
				"ChooseLevel",
				InputHints.bracket(controls.Interact, controls.InteractPad, "SELECT LEVEL"),
				1,
				true,
				open
			)
		end
		root.Size = UDim2.fromOffset(
			theme.ActionWidthPixels,
			theme.CaptionSize + theme.PaddingPixels * 3 + count * (theme.CaptionSize + theme.PaddingPixels * 3)
		)
		if opened and not HeldItemController.isInputBlocked(gui) then
			GuiService.SelectedObject = preferred or first
		end
	end
	ContextActionService:BindActionAtPriority(ACTION, function(_, state)
		if state ~= Enum.UserInputState.Begin or not current or not HeldItemController.canAct(gui) then
			return Enum.ContextActionResult.Pass
		end
		if opened then
			close()
		else
			open()
		end
		refresh()
		return Enum.ContextActionResult.Sink
	end, false, GameConfig.Combat.InputPriority + 1, controls.Interact, controls.InteractPad)
	ContextActionService:BindActionAtPriority("CloseElevatorSelector", function(_, state)
		if state == Enum.UserInputState.Begin and opened then
			close()
			refresh()
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, false, GameConfig.Combat.InputPriority + 1, Enum.KeyCode.ButtonB, Enum.KeyCode.Backspace)
	janitor:Add(UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Escape and opened then
			close()
			refresh()
		end
	end))
	janitor:Add(RemoteController.connect("PhaseChanged", function(value)
		phase = value
		if value == "Lobby" or value == "Insertion" then
			unavailable = false
		end
	end))
	for _, event in { "Downed", "Eliminated" } do
		janitor:Add(RemoteController.connect(event, function()
			unavailable = true
			close()
		end))
	end
	janitor:Add(RemoteController.connect("Revived", function()
		unavailable = false
	end))
	janitor:Add(RemoteController.connect("ExtractionState", function(info)
		if info.State == "Extracted" then
			unavailable = true
			close()
		end
	end))
	janitor:Add(localPlayer.CharacterAdded:Connect(function()
		unavailable = false
		close()
	end))
	local elapsed = 0
	janitor:Add(game:GetService("RunService").Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < CHECK_SECONDS then
			return
		end
		elapsed = 0
		local character = localPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local running = phase == "Infiltration"
			or phase == "VaultBreach"
			or phase == "PackageHeist"
			or phase == "Overtime"
		local cab = if running
				and not unavailable
				and humanoid
				and humanoid.Health > 0
				and gui.Enabled
			then insideCab()
			else nil
		if cab ~= current then
			close()
			signature = ""
		end
		current = cab
		refresh()
		if
			opened
			and not HeldItemController.isInputBlocked(gui)
			and not GuiService.SelectedObject
			and string.find(UserInputService:GetLastInputType().Name, "Gamepad")
		then
			for _, item in rows:GetChildren() do
				if item:IsA("GuiButton") and item.Selectable and item.Visible then
					GuiService.SelectedObject = item
					break
				end
			end
		end
	end))
	janitor:Add(function()
		close()
		ContextActionService:UnbindAction(ACTION)
		ContextActionService:UnbindAction("CloseElevatorSelector")
	end)
	janitor:Add(gui.Destroying:Connect(function()
		janitor:Destroy()
	end))
end

return ElevatorController
