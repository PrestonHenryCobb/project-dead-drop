--!strict
-- Ticket 8.5c-client: all 18 Hardware weapons now live in WeaponDefs with client models and handling.
-- Future server-complete weapons stay here until their client integration is ready for registration.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))

local Pending: { [string]: Types.WeaponDef } = {}
return Pending
