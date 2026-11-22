--!strict
-- Supply Cache UI: all offers/prices/eligibility and completion come from the private ShopState.
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.GameConfig)
local InputHints = require(Shared.Util.InputHints)
local Types = require(Shared.Types)
local Janitor = require(Shared.Util.Janitor)
local HudKit = require(Shared.Util.HudKit)
local HudTheme = require(Shared.Util.HudTheme)
local HeldItemController = require(script.Parent.HeldItemController)
local RemoteController = require(script.Parent.RemoteController)
local SupplyHudController = {}

function SupplyHudController.Init() end

function SupplyHudController.Start()
	local janitor = Janitor.new()
	local content = Janitor.new()
	janitor:Add(content)
	local theme = HudTheme.get()
	local config = GameConfig.MatchHud
	local current: Types.ShopStateInfo? = nil
	local buying: string? = nil
	local buyingAt = 0
	local requested = false
	local previousSelection: GuiObject? = nil
	local gui = HudKit.screen("SupplyHud")
	gui.DisplayOrder = config.DisplayOrder
	janitor:Add(gui)
	local overlay = Instance.new("TextButton")
	overlay.Name = "SupplyShopOverlay"
	overlay.Text = ""
	overlay.BackgroundColor3 = theme.PanelColor
	overlay.BackgroundTransparency = theme.PanelTransparency
	overlay.AutoButtonColor = false
	overlay.Modal = true
	overlay.Selectable = false
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.Visible = false
	overlay.Parent = gui
	local panel = HudKit.panel(
		overlay,
		"SupplyShop",
		UDim2.fromScale(0.5, 0.5),
		Vector2.new(0.5, 0.5),
		UDim2.fromOffset(config.PanelWidthPixels, config.BriefHeightPixels * 2),
		true
	)
	local title = HudKit.text(
		panel,
		"SupplyTitle",
		UDim2.fromOffset(theme.PaddingPixels, theme.PaddingPixels),
		Vector2.zero,
		UDim2.new(1, -theme.PaddingPixels * 2, 0, config.TitleSize)
	)
	title.Text = "SUPPLY CACHE"
	title.TextSize = config.TitleSize
	local balance = HudKit.text(
		panel,
		"SupplyIntel",
		UDim2.fromOffset(theme.PaddingPixels, theme.PaddingPixels * 2 + config.TitleSize),
		Vector2.zero,
		UDim2.new(1, -theme.PaddingPixels * 2, 0, config.BodySize)
	)
	balance.TextSize = config.BodySize
	local rows = Instance.new("ScrollingFrame")
	rows.Name = "SupplyOffers"
	rows.BackgroundTransparency = 1
	rows.BorderSizePixel = 0
	rows.Position = UDim2.fromOffset(theme.PaddingPixels, theme.PaddingPixels * 3 + config.TitleSize + config.BodySize)
	rows.Size = UDim2.new(
		1,
		-theme.PaddingPixels * 2,
		1,
		-theme.PaddingPixels * 8 - config.TitleSize - config.BodySize - config.BodySize * 2
	)
	rows.CanvasSize = UDim2.new()
	rows.AutomaticCanvasSize = Enum.AutomaticSize.Y
	rows.ScrollBarThickness = theme.ReloadBarPixels
	rows.ScrollBarImageColor3 = theme.AccentColor
	rows.ClipsDescendants = true
	rows.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, theme.PaddingPixels)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = rows
	local progress = Instance.new("Frame")
	progress.Name = "SupplyPurchaseProgress"
	progress.BorderSizePixel = 0
	progress.BackgroundColor3 = theme.AccentColor
	progress.Position = UDim2.new(0, theme.PaddingPixels, 1, -theme.PaddingPixels * 4 - config.BodySize)
	progress.Size = UDim2.fromOffset(0, theme.ReloadBarPixels)
	progress.Visible = false
	progress.Parent = panel
	local status = HudKit.text(
		panel,
		"SupplyStatus",
		UDim2.new(0, theme.PaddingPixels, 1, -theme.PaddingPixels * 5 - config.BodySize),
		Vector2.new(0, 1),
		UDim2.new(1, -theme.PaddingPixels * 2, 0, config.BodySize)
	)
	status.TextSize = theme.CaptionSize
	local close = Instance.new("TextButton")
	close.Name = "CloseSupplyShop"
	close.Text = InputHints.text("CLOSE · ESC", "CLOSE · B")
	janitor:Add(InputHints.onChange(function()
		close.Text = InputHints.text("CLOSE · ESC", "CLOSE · B")
	end))
	close.Font = theme.Font
	close.TextSize = theme.CaptionSize
	close.TextColor3 = theme.TextColor
	close.BackgroundColor3 = theme.PanelColor
	close.Position = UDim2.new(0, theme.PaddingPixels, 1, -theme.PaddingPixels * 2 - config.BodySize)
	close.Size = UDim2.new(1, -theme.PaddingPixels * 2, 0, config.BodySize + theme.PaddingPixels)
	close.Parent = panel
	local function hide()
		local wasOpen = overlay.Visible
		overlay.Visible = false
		current, buying = nil, nil
		requested = false
		content:Cleanup()
		HeldItemController.setInterfaceBlocked(gui, false)
		if wasOpen then
			GuiService.SelectedObject = if previousSelection and previousSelection.Parent
				then previousSelection
				else nil
		end
	end
	local function requestClose()
		if overlay.Visible then
			RemoteController.fire("RequestShopClose")
			hide()
		end
	end
	janitor:Add(close.Activated:Connect(function()
		if not HeldItemController.isInputBlocked(gui) then
			requestClose()
		end
	end))
	janitor:Add(UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Escape then
			requestClose()
		end
	end))
	ContextActionService:BindActionAtPriority("CloseSupplyShop", function(_, state)
		if state == Enum.UserInputState.Begin and overlay.Visible then
			requestClose()
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, false, GameConfig.Combat.InputPriority + 1, Enum.KeyCode.ButtonB, Enum.KeyCode.Backspace)
	janitor:Add(function()
		ContextActionService:UnbindAction("CloseSupplyShop")
	end)
	janitor:Add(RemoteController.connect("ShopState", function(info: Types.ShopStateInfo)
		if not info.Open then
			hide()
			return
		end
		if not overlay.Visible then
			previousSelection = GuiService.SelectedObject
			HeldItemController.setInterfaceBlocked(gui, true)
		end
		overlay.Visible = true
		current = info
		requested = false
		if info.Buying ~= buying then
			buying, buyingAt = info.Buying, os.clock()
		end
		local selected = GuiService.SelectedObject
		local selectedId = if selected and selected:IsDescendantOf(rows) then selected.Name else nil
		content:Cleanup()
		balance.Text = `TEAM INTEL · {info.Intel}`
		local first: TextButton? = nil
		for index, item in info.Items do
			local button = Instance.new("TextButton")
			button.Name = item.Id
			button.LayoutOrder = index
			button.Font = theme.Font
			button.TextSize = config.BodySize
			button.TextColor3 = theme.TextColor
			button.BackgroundColor3 = theme.PanelColor
			button.TextWrapped = true
			local affordable = info.Intel >= item.Price
			local reason = if not item.Available then item.Reason elseif not affordable then "Not enough Intel" else ""
			button.Text = `{item.Name} · {item.Price} INTEL{if reason ~= "" then `\n{reason}` else ""}`
			button.Size = UDim2.new(1, -theme.PaddingPixels, 0, config.BodySize * 2 + theme.PaddingPixels)
			button.Active = item.Available and affordable and info.Buying == nil
			button.Selectable = button.Active
			button.AutoButtonColor = false
			button.BackgroundTransparency = if button.Active then theme.PanelTransparency else 1
			button.Parent = rows
			content:Add(button)
			content:Add(button.Activated:Connect(function()
				if current ~= info or requested or not button.Active or HeldItemController.isInputBlocked(gui) then
					return
				end
				requested = true
				RemoteController.fire("RequestShopBuy", item.Id)
			end))
			if button.Selectable then
				first = first or button
			end
			if button.Name == selectedId and button.Selectable and not HeldItemController.isInputBlocked(gui) then
				GuiService.SelectedObject = button
			end
		end
		if
			not HeldItemController.isInputBlocked(gui)
			and (not GuiService.SelectedObject or not GuiService.SelectedObject.Parent or not selectedId)
		then
			GuiService.SelectedObject = first or close
		end
	end))
	janitor:Add(RunService.RenderStepped:Connect(function()
		local info = current
		if not info or not overlay.Visible then
			return
		end
		if
			not HeldItemController.isInputBlocked(gui)
			and not GuiService.SelectedObject
			and string.find(UserInputService:GetLastInputType().Name, "Gamepad")
		then
			local first: GuiButton? = nil
			for _, item in rows:GetChildren() do
				if item:IsA("GuiButton") and item.Selectable and item.Visible then
					first = item
					break
				end
			end
			GuiService.SelectedObject = first or close
		end
		local fill = if info.Buying and info.BuySeconds > 0
			then math.clamp((os.clock() - buyingAt) / info.BuySeconds, 0, 1)
			else 0
		progress.Size = UDim2.new(fill, -theme.PaddingPixels * 2 * fill, 0, theme.ReloadBarPixels)
		progress.Visible = info.Buying ~= nil
		local buyingName: string? = nil
		for _, item in info.Items do
			if item.Id == info.Buying then
				buyingName = item.Name
				break
			end
		end
		status.Text = if info.Buying
			then `{if buyingName then string.upper(buyingName) else "BUYING"} · BREAKS COVER`
			elseif requested then "REQUEST SENT"
			else "PURCHASES BREAK COVER"
	end))
	janitor:Add(RemoteController.connect("PhaseChanged", function(value: Types.Phase)
		if value == "Lobby" or value == "Insertion" or value == "Results" then
			requestClose()
		end
	end))
	janitor:Add(RemoteController.connect("Downed", requestClose))
	janitor:Add(RemoteController.connect("Eliminated", requestClose))
	janitor:Add(Players.LocalPlayer.CharacterRemoving:Connect(requestClose))
	janitor:Add(requestClose)
	janitor:Add(script.Destroying:Connect(function()
		janitor:Destroy()
	end))
end

return SupplyHudController
