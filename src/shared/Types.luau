--!strict
-- Shared type definitions. Keep these in step with Enums.luau.

export type Phase = "Lobby" | "Insertion" | "Infiltration" | "VaultBreach" | "PackageHeist" | "Overtime" | "Results"

export type CoverState = "Covered" | "Suspicious" | "Exposed"

export type Mode = "Squads" | "Duos" | "Solos"

export type Role = "Guest" | "Staff" | "Security" | "Executive"

export type Tier = number -- 0 Public, 1 Staff, 2 Security, 3 Executive

export type Activity = "Walk" | "Idle" | "Talk" | "Sit" | "Lean" | "Drink" | "Work" | "Guard"

export type PickupType = "ArmorPlate" | "AmmoBox" | "Funds" | "MedKit"

export type ModeConfig = {
	TeamSize: number,
	MaxTeams: number,
	MinPlayers: number,
	MaxPlayers: number,
}

-- Token-bucket limits for one client -> server remote (GameConfig.Network).
export type RateLimit = {
	PerSecond: number,
	Burst: number,
}

return {}
