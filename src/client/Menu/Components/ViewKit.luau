--!strict
-- menu-views: shared view lifetime, profile subscription and accessible layout primitives.
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Janitor = require(Shared.Util.Janitor)
local Types = require(Shared.Types)
local Theme = require(script.Parent.Parent.MenuTheme)
local config = require(Shared.GameConfig).Menu
local Art = require(script.Parent.DecoArt)
local Remote = require(script.Parent.Parent.Parent.Controllers.RemoteController)
local RequestFeedback = require(script.Parent.Parent.RequestFeedback)
local Kit = {}
Kit.Theme = Theme
Kit.Remote = Remote

function Kit.frame(parent: Instance, name: string, position: UDim2, size: UDim2): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundTransparency = 1
	frame.Position = position
	frame.Size = size
	frame.Parent = parent
	return frame
end

function Kit.text(parent: Instance, value: string, y: number, height: number, large: boolean?): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromOffset(0, y)
	label.Size = UDim2.new(1, 0, 0, height)
	label.Font = if large then Theme.Fonts.Bold else Theme.Fonts.Body
	label.TextSize = if large then Theme.TextSizes.Display else config.Art.BodyTextPixels
	label.TextColor3 = Theme.Colors.Text
	label.TextStrokeColor3 = Theme.Colors.Canvas
	label.TextStrokeTransparency = config.Cinematic.TextShadowTransparency
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.TextWrapped = true
	label.Text = value
	label.Parent = parent
	return label
end

function Kit.scroll(parent: Instance, name: string, position: UDim2, size: UDim2): ScrollingFrame
	local frame = Instance.new("ScrollingFrame")
	frame.Name = name
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Position = position
	frame.Size = size
	frame.CanvasSize = UDim2.new()
	frame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	frame.ScrollBarThickness = config.Art.ScrollbarPixels
	frame.ScrollingDirection = Enum.ScrollingDirection.Y
	frame.VerticalScrollBarInset = Enum.ScrollBarInset.Always
	frame.ClipsDescendants = true
	frame.ScrollBarImageTransparency = 0
	frame.ScrollBarImageColor3 = Theme.Colors.Brass
	frame.Parent = parent
	return frame
end

function Kit.stack(parent: Instance)
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, config.GapPixels)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = parent
end

-- Token-sized footer cues remain visible even when Roblox fades the scrollbar.
function Kit.scrollRegion(
	parent: Instance,
	name: string,
	position: UDim2,
	size: UDim2,
	caption: string
): (ScrollingFrame, Frame)
	local region = Kit.frame(parent, name .. "Region", position, size)
	local cueHeight = config.ChipHeightPixels + config.GapPixels
	local scroll = Kit.scroll(region, name, UDim2.new(), UDim2.new(1, 0, 1, -cueHeight))
	local cue = Kit.text(region, caption, 0, cueHeight)
	cue.Name = "ScrollCue"
	cue.Position = UDim2.new(0, 0, 1, -cueHeight)
	cue.Font = config.Fonts.Mono
	cue.TextSize = config.TextSizes.Small
	cue.TextColor3 = config.Colors.TextDim
	return scroll, region
end

-- Content-measured panels avoid fixed-height overflow when labels wrap or button tokens change.
function Kit.flowPanel(parent: Instance, name: string): Frame
	local panel = Theme.infoPanel({ Name = name, Parent = parent })
	panel.Size = UDim2.new(1, -config.PaddingPixels, 0, 0)
	Kit.stack(panel)
	return panel
end

function Kit.flowText(parent: Instance, name: string, value: string, order: number, large: boolean?): TextLabel
	return Theme.label({
		Name = name,
		Text = value,
		Parent = parent,
		LayoutOrder = order,
		Style = if large then "Display" else "Body",
	})
end

function Kit.button(
	parent: Instance,
	text: string,
	y: number,
	action: (() -> ())?,
	enabled: boolean?,
	primary: boolean?
)
	local props = {
		Name = text,
		Text = text,
		Parent = parent,
		Position = UDim2.fromOffset(0, y),
		OnActivated = action,
		Enabled = enabled,
	}
	local button = if primary then Theme.primaryButton(props) else Theme.secondaryButton(props)
	button.Instance.TextWrapped = true
	return button
end

function Kit.panel(parent: Instance, name: string, position: UDim2, size: UDim2): Frame
	local panel = Theme.infoPanel({ Name = name, Parent = parent, Position = position, Size = size })
	Art.trim(panel)
	return panel
end

-- Original illustrated plate: separate ivory title band keeps contrast independent of the engraving.
function Kit.documentArt(parent: Instance, title: string, position: UDim2, size: UDim2)
	local kind = if string.find(title, "MINT")
		then "Mint"
		elseif string.find(title, "COLLECTION") then "Market"
		else "Archive"
	return Art.plate(parent, title, position, size, kind)
end

-- Preserve controller focus when a profile push or selection rebuilds a view.
function Kit.rememberFocus(root: Instance): (Instance) -> ()
	local selected = GuiService.SelectedObject
	local name = if selected and selected:IsDescendantOf(root) then selected.Name else nil
	return function(replacement: Instance)
		if not name then
			return
		end
		local fallback: GuiButton? = nil
		for _, child in replacement:GetDescendants() do
			if child:IsA("GuiButton") and child.Selectable then
				fallback = fallback or child
				if child.Name == name then
					GuiService.SelectedObject = child
					return
				end
			end
		end
		GuiService.SelectedObject = fallback
	end
end

function Kit.session(stage: Frame, title: string, navigator: Types.MenuNavigator?)
	local janitor = Janitor.new()
	local margin = config.GapPixels * 2
	local root =
		Kit.frame(stage, "CollectionView", UDim2.fromOffset(margin, margin), UDim2.new(1, -margin * 2, 1, -margin * 2))
	janitor:Add(root)
	local heading = Kit.text(root, title, 0, 42, true)
	local titleParts = string.split(title, " / ")
	if #titleParts > 1 then
		heading.Text = titleParts[1]
		heading.Size = UDim2.new(0.55, 0, 0, 42)
		local context = Kit.text(root, table.concat(titleParts, " / ", 2), 0, 42)
		context.Name = "SectionContext"
		context.Position = UDim2.new(0.56, 0, 0, 0)
		context.Size = UDim2.new(0.44, 0, 0, 42)
		context.TextSize = config.TextSizes.Small
		context.TextXAlignment = Enum.TextXAlignment.Right
		context.TextYAlignment = Enum.TextYAlignment.Center
		context.TextColor3 = Theme.Colors.TextDim
	end
	local body = Kit.frame(root, "Body", UDim2.fromOffset(0, 50), UDim2.new(1, 0, 1, -84))
	local status = Kit.text(root, "Connecting…", 0, 28)
	status.Position = UDim2.new(0, 0, 1, -28)
	local active = true
	local busy = false
	local snapshot: Types.MetaSnapshot? = nil
	local onProfile: ((Types.MetaSnapshot) -> ())? = nil
	local session = { Root = root, Body = body, Janitor = janitor }
	local function spawn(callback: () -> ())
		local thread = task.spawn(callback)
		janitor:Add(function()
			if coroutine.status(thread) ~= "dead" and thread ~= coroutine.running() then
				task.cancel(thread)
			end
		end)
	end
	function session.alive(): boolean
		return active
	end
	function session.snapshot(): Types.MetaSnapshot?
		return snapshot
	end
	function session.status(value: string)
		if active then
			status.Text = value
		end
	end
	function session.request(name: string, payload: any, completed: (() -> ())?)
		if busy or not active then
			return
		end
		busy = true
		session.status("Awaiting server confirmation…")
		spawn(function()
			local success, ok, reason = pcall(Remote.invoke, name, payload)
			if not active then
				return
			end
			busy = false
			session.status(
				if success and ok
					then "Confirmed."
					else if success then RequestFeedback.declined(reason) else "Connection unavailable. Try again."
			)
			if success and ok and completed then
				completed()
			end
		end)
	end
	function session.watch(callback: (Types.MetaSnapshot) -> ())
		onProfile = callback
		local function receive(value: Types.MetaSnapshot)
			if not active then
				return
			end
			snapshot = value
			session.status("")
			callback(value)
		end
		if navigator then
			janitor:Add(navigator.onSnapshot(receive))
			local current = navigator.snapshot()
			if current then
				receive(current)
			end
			return
		else
			janitor:Add(Remote.connect("ProfileStateUpdated", receive))
		end
		spawn(function()
			local ok, value = pcall(Remote.invoke, "GetPlayerMetaProfile")
			if active and ok and value and not snapshot then
				snapshot = value
				session.status("")
				callback(value)
			elseif active and not snapshot then
				session.status("Profile unavailable. Reopen to retry.")
			end
		end)
	end
	function session.refresh()
		if snapshot and onProfile then
			onProfile(snapshot)
		end
	end
	function session.destroy()
		active = false
		janitor:Destroy()
	end
	return session
end
return Kit
