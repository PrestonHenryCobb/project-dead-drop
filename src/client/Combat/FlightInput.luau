--!strict
-- Shared gamepad sampling for client flight cameras. Never moves a body or changes an authoritative speed.
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared").GameConfig)
local FlightInput = {}

local function filtered(value: Vector2): Vector2
	local magnitude = value.Magnitude
	local deadzone = GameConfig.Controls.StickDeadzone
	if magnitude <= deadzone then
		return Vector2.zero
	end
	return value.Unit * ((math.min(magnitude, 1) - deadzone) / (1 - deadzone))
end

function FlightInput.read(): (Vector2, Vector2, number, boolean)
	local move, look = Vector2.zero, Vector2.zero
	for _, input in UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1) do
		if input.KeyCode == Enum.KeyCode.Thumbstick1 then
			move = filtered(Vector2.new(input.Position.X, input.Position.Y))
		elseif input.KeyCode == Enum.KeyCode.Thumbstick2 then
			look = filtered(Vector2.new(input.Position.X, input.Position.Y))
		end
	end
	local up = (
		if UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, GameConfig.Controls.JumpPad) then 1 else 0
	)
		- (
			if UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, GameConfig.ClientFlight.DownPad)
				then 1
				else 0
		)
	return move,
		look,
		up,
		UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, GameConfig.ClientFlight.BoostPad)
end

return table.freeze(FlightInput)
