--!strict
-- Draft-only Talent/Instinct selection. The server validates membership and mastery on submission.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.GameConfig)
local Types = require(Shared.Types)
local Theme = require(script.Parent.Parent.MenuTheme)
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
		for index, item in items do
			local unlock = levels[index] or math.huge
			local available = owned ~= false and mastery >= unlock
			local detail = if available
				then (if item.CooldownSeconds then `{item.CooldownSeconds}s COOLDOWN` else "PASSIVE")
				else `LOCKED · MASTERY {unlock}`
			local button = Theme.secondaryButton({
				Name = item.Id,
				Text = `{item.Name}\n{detail}`,
				Parent = frame,
				LayoutOrder = index,
				Size = UDim2.new(1, 0, 0, config.SecondaryHeightPixels + config.TextSizes.Small),
				Enabled = available,
				OnActivated = function()
					choose(kind, item.Id)
				end,
			})
			button.Instance.TextSize = config.TextSizes.Small
			button.SetSelected(selected == item.Id)
			if selected == item.Id then
				Theme.label({
					Name = "SelectedDescription",
					Text = item.Description,
					Style = "Small",
					Parent = frame,
					LayoutOrder = #items + 1,
				})
			end
		end
	end
	section("Talent", agent.Talents, GameConfig.Mastery.TalentUnlockLevels, talent, 1)
	section("Instinct", agent.Instincts, GameConfig.Mastery.InstinctUnlockLevels, instinct, 2)
end

return KitPicker
