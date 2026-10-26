--!strict
-- Ticket 19-coverbreak-feedback: invisible Edit-mode fixtures. Does not play, rebuild or change world/camera.
assert(game:GetService("RunService"):IsStudio(), "Studio only")
local shared = game.ReplicatedStorage.Shared:Clone()
shared.Name = "SharedOverride"
local combat = game.StarterPlayer.StarterPlayerScripts.Client.Combat:Clone()
shared.Parent = combat
combat.Parent = game.ServerStorage
local screen = Instance.new("ScreenGui")
screen.Name = "CoverBreakReview"
screen.Enabled = false
screen.Parent = game:GetService("CoreGui")
local fx: any = nil
local ok, problem = pcall(function()
	local Effect = require(combat.CoverBreakFx)
	local config = require(shared.GameConfig).UI.CoverBreak
	fx = Effect.new(screen)
	assert(#fx.bars == 8 and fx.root.BackgroundTransparency == 1)
	local initial = #screen:GetDescendants()
	for index = 1, 100 do
		fx:trigger(index)
		fx:update(index, false)
		assert(fx.root.Visible)
		for _, bar in fx.bars do
			assert(math.abs(bar.BackgroundTransparency - config.StartTransparency) < 0.00001)
		end
		fx:update(index + config.Seconds / 2, true)
		assert(not fx.root.Visible, "Reduced-motion geometry remained visible")
		fx:update(index + config.Seconds * 2, false)
		assert(not fx.root.Visible, "Pulse did not expire")
	end
	assert(#screen:GetDescendants() == initial, "Pulse allocated GUI instances")
	fx:reset()
	assert(not fx.root.Visible)
	fx:destroy()
	fx = nil
	assert(#screen:GetChildren() == 0, "Effect cleanup retained GUI")
	print("COVER_BREAK_NATIVE_PASS", initial, "prebuilt descendants; 100 pulses, reduced motion and cleanup")
end)
if fx then
	fx:destroy()
end
screen:Destroy()
combat:Destroy()
assert(ok, tostring(problem))
