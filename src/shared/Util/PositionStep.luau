--!strict
-- The moment other characters are drawn at (step 8B.6). Positions move in steps of 1 / Animation.PositionStepHz on the
-- shared server clock, so every client steps on the same beat, and the server rewinds a shot to the same stepped moment
-- the shooter saw. Both sides call this one function so they always agree.
--
--   PositionStep.snap(serverTime) -> number   the start of the step that serverTime falls in

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))

local PositionStep = {}

local hz = GameConfig.Animation.PositionStepHz

function PositionStep.snap(serverTime: number): number
	return math.floor(serverTime * hz) / hz
end

return PositionStep
