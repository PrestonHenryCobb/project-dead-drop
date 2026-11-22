--!strict
-- Original vault-door outline with an inset identity letter; shared by global pings and progress dials.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local HudKit = require(Shared.Util.HudKit)
local HudTheme = require(Shared.Util.HudTheme)
local VaultBadge = {}

export type View = { update: (string, Color3) -> () }

local DOOR = {
	{ 0.15, 0.08, 0.85, 0.08 },
	{ 0.85, 0.08, 0.85, 0.92 },
	{ 0.85, 0.92, 0.15, 0.92 },
	{ 0.15, 0.92, 0.15, 0.08 },
	{ 0.08, 0.25, 0.22, 0.25 },
	{ 0.08, 0.75, 0.22, 0.75 },
	{ 0.78, 0.35, 0.92, 0.35 },
	{ 0.92, 0.35, 0.92, 0.65 },
}

function VaultBadge.letter(id: string): string
	return string.upper(string.match(id, "^Vault([%a%d]+)$") or string.sub(id, 1, 1))
end

function VaultBadge.new(parent: Instance, pixels: number): View
	local theme = HudTheme.get()
	local logo = HudKit.icon(parent, "VaultBadge", UDim2.fromScale(0.5, 0.5), pixels, theme.TextColor, DOOR)
	logo.AnchorPoint = Vector2.new(0.5, 0.5)
	local letter =
		HudKit.text(logo, "Letter", UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5), UDim2.fromScale(0.6, 0.7))
	letter.TextScaled = true
	local color: Color3? = nil
	return {
		update = function(id: string, nextColor: Color3)
			letter.Text = VaultBadge.letter(id)
			if color ~= nextColor then
				color = nextColor
				letter.TextColor3 = nextColor
				for _, child in logo:GetChildren() do
					if child:IsA("Frame") then
						child.BackgroundColor3 = nextColor
					end
				end
			end
		end,
	}
end

return VaultBadge
