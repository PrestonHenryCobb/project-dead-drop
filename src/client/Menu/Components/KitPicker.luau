--!strict
-- Draft-only Talent/Instinct selection. The server validates membership and mastery on submission.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.GameConfig)
local Types = require(Shared.Types)
local Theme = require(script.Parent.Parent.MenuTheme)
local MenuIcons = require(script.Parent.MenuIcons)
local AgentLooks = require(Shared.Defs.AgentLooks)
local MenuArtDefs = require(Shared.Defs.MenuArtDefs)
local config = GameConfig.Menu
local KitPicker = {}

function KitPicker.resolve(items: { Types.AgentKitItem }, levels: { number }, mastery: number, wanted: string?): string
	for index, item in items do
		if item.Id == wanted and mastery >= (levels[index] or math.huge) then
			return item.Id
		end
	end
	return items[1].Id
end

function KitPicker.mount(
	parent: Instance,
	agent: Types.AgentDef,
	mastery: number,
	talent: string,
	instinct: string,
	choose: (string, string) -> (),
	owned: boolean?
)
	local function section(
		kind: string,
		items: { Types.AgentKitItem },
		levels: { number },
		selected: string,
		order: number
	)
		local frame = Instance.new("Frame")
		frame.Name = kind .. "Picker"
		frame.BackgroundTransparency = 1
		frame.Size = UDim2.new(1, 0, 0, 0)
		frame.AutomaticSize = Enum.AutomaticSize.Y
		frame.LayoutOrder = order
		frame.Parent = parent
		Theme.stack(frame)
		Theme.label({ Name = "Title", Text = string.upper(kind), Style = "Kicker", Parent = frame, LayoutOrder = 0 })
		-- One description under the list: the chosen item's, or whichever item is hovered or focused, locked ones included (owner 2026-11-25: a player
		-- can always read what a locked ability does, and what unlocks it).
		local description = Theme.label({
			Name = "Description",
			Text = "",
			Style = "Small",
			Parent = frame,
			LayoutOrder = #items + 1,
		})
		local function describe(item: Types.AgentKitItem, unlock: number, available: boolean): string
			local text = item.Description
			if not available then
				text ..= if owned == false then "\nOwn this agent to use it." else `\nUnlocks at Mastery {unlock}.`
			end
			return text
		end
		local chosenText = ""
		for index, item in items do
			local unlock = levels[index] or math.huge
			local available = owned ~= false and mastery >= unlock
			local button = Theme.secondaryButton({
				Name = item.Id,
				Text = item.Name,
				Parent = frame,
				LayoutOrder = index,
				Size = UDim2.new(1, 0, 0, config.SecondaryHeightPixels + config.TextSizes.Small),
				OnActivated = function()
					if available then
						choose(kind, item.Id)
					end
				end,
			})
			button.Instance.TextSize = config.TextSizes.Small
			MenuIcons.leadArt(
				button.Instance,
				MenuArtDefs.kit(item.Id),
				MenuIcons.classIcon(agent.Class),
				AgentLooks.accent(agent.Id)
			)
			if not available then
				button.Instance.TextTransparency = config.Icons.LockedTextTransparency
				MenuIcons.badge(button.Instance, "Lock", `LVL {unlock}`)
			elseif item.CooldownSeconds then
				MenuIcons.badge(button.Instance, "Clock", `{item.CooldownSeconds}s`)
			else
				MenuIcons.badge(button.Instance, "Passive", "PASSIVE")
			end
			button.SetSelected(selected == item.Id)
			local text = describe(item, unlock, available)
			if selected == item.Id then
				chosenText = text
			end
			local function show()
				description.Text = text
			end
			local function revert()
				description.Text = chosenText
			end
			button.Instance.MouseEnter:Connect(show)
			button.Instance.SelectionGained:Connect(show)
			button.Instance.MouseLeave:Connect(revert)
			button.Instance.SelectionLost:Connect(revert)
		end
		description.Text = chosenText
	end
	section("Talent", agent.Talents, GameConfig.Mastery.TalentUnlockLevels, talent, 1)
	section("Instinct", agent.Instincts, GameConfig.Mastery.InstinctUnlockLevels, instinct, 2)
end

return KitPicker
