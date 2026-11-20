--!strict
-- Shared type definitions. Keep these in step with Enums.luau.

export type Phase = "Lobby" | "Insertion" | "Infiltration" | "VaultBreach" | "PackageHeist" | "Overtime" | "Results"

export type CoverState = "Covered" | "Suspicious" | "Exposed"

export type Mode = "Squads" | "Duos" | "Solos"

export type Role = "Guest" | "Staff" | "Security" | "Executive" | "Warden" | "Curator"

export type Tier = number -- 0 Public, 1 Staff, 2 Security, 3 Executive

export type Activity = "Walk" | "Idle" | "Talk" | "Sit" | "Lean" | "Drink" | "Work" | "Guard"

export type PickupType = "ArmorPlate" | "AmmoBox" | "Funds" | "MedKit"

export type ModeConfig = {
	TeamSize: number,
	MaxTeams: number,
	MinPlayers: number,
	MaxPlayers: number,
}

-- Spec 25.3: an outfit is a data record. Characters are built from these, never from Roblox avatar items.
export type AccessoryKind = "Tie" | "BowTie" | "Lapels" | "PocketSquare" | "LapelPin" | "Fedora" | "Sunglasses"

export type AccessoryDef = {
	Kind: AccessoryKind,
	Color: Color3,
}

export type HairStyle = "Bald" | "Crop" | "Short" | "Long" | "Bun"

export type OutfitDef = {
	OutfitId: string,
	Role: Role,
	Tier: Tier,
	BodyColors: { Skin: Color3, Shoes: Color3 },
	Shirt: { Color: Color3, LongSleeves: boolean },
	Pants: { Color: Color3 },
	Accessories: { AccessoryDef },
	Hair: { Style: HairStyle, Color: Color3 },
	Face: string,
	Scale: { Height: number, Width: number, Depth: number, Head: number },
}

-- Spec 5.3, 6.7: animations built from code. A joint pose is rotation in degrees about x, y, z and an optional
-- offset in studs: { rx, ry, rz, tx, ty, tz }. Missing trailing numbers are zero.
export type JointPose = { number }

export type PoseKeyframe = {
	Time: number,
	Joints: { [string]: JointPose },
}

export type PoseDef = {
	Loop: boolean,
	Priority: "Action" | "Action2",
	Keyframes: { PoseKeyframe },
}

-- Spec 6.3, 6.4: what a player knows about their own disguises. Sent only to that player. Slots has `false` for an
-- empty slot, so it stays a plain array on the wire.
export type DisguiseUpdate = {
	Exposed: boolean, -- true while in True Form
	Worn: string, -- OutfitId currently worn
	Insertion: string, -- OutfitId given at spawn
	Slots: { string | boolean },
}

-- Ticket 16: an agent's ability cooldown ("CooldownUpdate", to the owner only). ReadyAt is server time
-- (workspace:GetServerTimeNow()); the ability can be used once it has passed. Sent at match start and on each use.
export type AbilityCooldownInfo = {
	Name: string,
	Seconds: number, -- the full cooldown
	ReadyAt: number,
}

-- Ticket 16c: Lattice's Sparrow Drone ("SparrowState", to her only). While Active the client views from its own drone (the
-- Drone part in workspace.Shields next to her body; a part sent by remote may not have replicated yet, so it is looked for)
-- and sends RequestSparrowMove; the flight ends at EndsAt (server time) or sooner.
export type SparrowStateInfo = {
	Active: boolean,
	EndsAt: number,
}

-- Ticket auto-recover ("AutoRecoverState", to the owner only). Enabled is the player's Auto re-cover option. While Active a
-- re-cover ring is running: the disguise goes back on Seconds after the ring began unless something cancels it (a new message
-- with Active = false) or the player presses Disguise to do it at once. Sent when the option changes and when a ring begins or ends.
export type AutoRecoverInfo = {
	Enabled: boolean,
	Active: boolean,
	Seconds: number,
}

-- Spec 7: a player's own cover. Sent only to that player; enemies never learn it (spec 25.7).
export type CoverInfo = {
	State: CoverState,
	CanRecover: boolean, -- the conditions for putting a disguise back on are all met
	Blocker: string, -- what stops it: "Lockout", "Minimum", "Seen" or "Zone"; "" if nothing does
	LockoutSeconds: number, -- combat lockout left
	ExposedMinSeconds: number, -- time left before an Exposed player may re-cover at all
}

export type SuspicionInfo = {
	Value: number, -- 0 to SuspicionMax
	Security: number, -- witnesses seeing the player now, by kind
	Npc: number,
	Camera: number,
}

export type TrespassInfo = {
	Restricted: boolean,
	ZoneTier: number,
	Clearance: number,
}

-- Spec 13: weapons. Stats live in Defs/WeaponDefs.luau; the rest of combat's tuning is GameConfig.Combat.
export type Falloff = {
	StartStuds: number, -- full damage up to here
	EndStuds: number, -- damage falls off linearly to MinMult from StartStuds to here, then stays there
	MinMult: number,
}

export type WeaponSpread = {
	Hip: number, -- degrees of cone, hip fire
	Aim: number, -- degrees of cone, aimed
	PerShot: number, -- degrees added by each shot
	MaxExtra: number, -- most the shots can add
	RecoverPerSecond: number, -- degrees lost per second while not firing
	MoveMult: number, -- cone multiplier while moving
}

export type WeaponRecoil = {
	PitchPerShot: number, -- degrees the view climbs per shot
	YawPerShot: number, -- degrees the view drifts per shot, left or right at random
	RecoverRate: number, -- per second, the share of the climb that settles back
	ViewKick: number, -- studs the gun model jolts back per shot
}

export type WeaponSounds = {
	Fire: string,
	Reload: string,
	Empty: string,
}

export type WeaponDef = {
	Id: string,
	Name: string,
	Agent: string,
	Automatic: boolean, -- holding the trigger keeps firing
	Damage: number,
	HeadshotMult: number,
	RPM: number,
	MagSize: number,
	ReserveAmmo: number,
	ReloadSeconds: number,
	Falloff: Falloff?, -- nil: no falloff
	Quiet: boolean, -- heard only GameConfig.Audio.SuppressedWeaponRadius away (spec 23), and no muzzle flash
	Spread: WeaponSpread,
	Recoil: WeaponRecoil,
	AimZoom: number, -- the field of view is multiplied by this while aiming
	Sounds: WeaponSounds,
	-- Ticket 8.11: optional per-weapon visuals; omitted fields use WeaponDefs.ShotDefaults. Quiet suppresses both.
	TracerColor: Color3?,
	TracerWidth: number?,
	TracerLength: number?,
	TracerSpeed: number?,
	FlashColor: Color3?,
	FlashSize: Vector3?,
	-- Ticket 8.9: seconds after a melee strike before this weapon may fire (brief Q14), set per weapon by strength.
	-- nil: no delay. The server enforces it; the client should wait the same time so no shot is predicted in vain.
	PostMeleeFireDelay: number?,
	-- Ticket 8.5: the server's part of each weapon's unique effect (STEP8_QUESTIONS "Unique effects"). All optional; the
	-- client must follow the same firing rules so it never predicts a shot the server refuses.
	Pellets: number?, -- rays per trigger pull (shotguns); FireRequest then sends a list of exactly this many directions
	Burst: WeaponBurst?, -- fires Count shots at RPM, then waits DelaySeconds before the next burst
	SpinUp: WeaponSpinUp?, -- held fire climbs from StartRPM to RPM over Seconds; a pause starts it again
	AimedRPM: number?, -- the rate while aiming, if different (Suture's pistols: one gun, half the rate)
	Pierce: WeaponPierce?, -- the shot passes through Count people; each one after the first takes DamageMult more
	AmbushMult: number?, -- a shot fired while disguised (Covered or Suspicious) deals this many times the damage
	ScopeGlint: boolean?, -- while aiming, rival agents she can see within Combat.ScopeGlint.RangeStuds see a glint
	HearStuds: number?, -- how far the shot is heard, instead of the Quiet or default radius
	SoundOffset: NumberRange?, -- listeners hear the shot this many studs from the shooter, in a random direction
	-- Tickets 8.5a/b/e/f (server handoffs). A weapon with Melee has no ammo and never fires: V uses these numbers.
	Melee: WeaponMelee?,
	Projectile: WeaponProjectile?, -- FireRequest throws or launches a server-simulated projectile instead of a ray
	ReloadPerShell: boolean?, -- ReloadSeconds is per round; a shot keeps the rounds already loaded (pump shotgun)
	SurvivesFullHealth: boolean?, -- one pull cannot take an agent who started it at full health below 1 HP
	Stagger: WeaponStagger?,
	Smoke: WeaponSmoke?,
	-- Ticket 8.5c-server (Lattice): see WeaponTracker and WeaponTaser. MaxRange stops the ray that far from the shooter (the taser's
	-- 25 studs); nil uses Combat.MaxShotStuds.
	MaxRange: number?,
	Tracker: WeaponTracker?,
	Taser: WeaponTaser?,
}

-- V while this weapon is held (garrote, breaching hammer). Fields left nil use GameConfig.Combat.Melee and .Takedown.
export type WeaponMelee = {
	SwingDamage: number,
	SwingSeconds: number, -- the earliest the next swing or takedown may start after one
	SwingReach: number, -- studs, before GameConfig.Combat.Melee.ReachSlackStuds
	ChargeSeconds: number?, -- holding V this long before release makes the swing a charged one
	ChargeDamage: number?,
	ShoveStuds: number?, -- a charged hit pushes its target this far sideways, along the swinger's right
	TakedownSeconds: number?, -- the rear hold; nil: Combat.Takedown.HoldSeconds
	TakedownDamage: number?, -- nil: Combat.Takedown.Damage
}

-- A server-simulated arcing projectile. Damage and HeadshotMult on the WeaponDef are the direct-hit numbers.
export type WeaponProjectile = {
	Kind: "Flare" | "Knife",
	Speed: number, -- studs a second at launch, along the aim direction
	Gravity: number, -- studs a second squared, downward (a knife's arc is shallow, a flare's pronounced)
	MaxSeconds: number, -- in flight at most this long, then it lands where it is
	SplashDamage: number?, -- Flare: others within SplashRadius of the landing point, with a clear line to it
	SplashRadius: number?,
	LightSeconds: number?, -- Flare: the landing point lights the area this long; no damage
	GlowSeconds: number?, -- Flare: a direct-hit target glows for the shooter's team this long
	PickupStuds: number?, -- Knife: how close an agent must be to pick up a landed one
}

-- A close-range hit with most pellets slows the target briefly and bumps their aim (pump shotgun).
export type WeaponStagger = {
	MinPellets: number,
	WithinStuds: number, -- the target is no further than this from the shooter
	SlowMult: number, -- walking speed multiplier
	Seconds: number,
	AimBumpDegrees: number, -- Studio tuning; drawn by the victim's client
}

-- The last Rounds rounds of a magazine leave a smoke cloud where they land (Feint's smoke SMG).
export type WeaponSmoke = { Rounds: number, Radius: number, Seconds: number }

-- Lattice's burst rifle: landing every round of one burst on the same agent marks them for the shooter alone for Seconds (shown
-- through TargetGlow to the shooter only). NPCs are never marked.
export type WeaponTracker = { Seconds: number }

-- Lattice's taser: a hit on a player slows them (SlowMult is a speed multiplier) for SlowSeconds and stops their ability and gadgets for
-- LockoutSeconds. NPCs take the damage and nothing else.
export type WeaponTaser = { SlowMult: number, SlowSeconds: number, LockoutSeconds: number }

export type WeaponBurst = { Count: number, DelaySeconds: number }
export type WeaponSpinUp = { StartRPM: number, Seconds: number }
export type WeaponPierce = { Count: number, DamageMult: number }

-- Ticket 8.5: a scoped DMR's glint, sent to each rival agent who can see the scope (drawn by the client).
export type ScopeGlintInfo = { Position: Vector3, Seconds: number }

-- Combat messages. All are sent only to the player they concern, except ShotInfo (to players within earshot).
export type HitConfirm = { Kind: "Npc" | "Agent", Head: boolean } -- the shooter's hitmarker (spec 8.4)
-- Step 9: a hold-interaction began (Active) or ended. Kind is what it does, for the HUD ("Revive", "Execute").
export type InteractStateInfo = { Kind: string, Seconds: number, Active: boolean }
-- Step 9: sent to a player who goes down; BleedOutAt is on the server clock.
-- R4-body-animation: Fall and Posture name the poses the client plays (Util/Knockdown), the same set NPCs use.
export type DownedInfo = { BleedOutAt: number, Fall: string, Posture: string }
-- Sent to a player who is eliminated. FromStanding: they went straight from their feet (Solos), so the fall plays first.
export type EliminatedInfo = { Fall: string, Posture: string, FromStanding: boolean }

-- Tickets 8.5a/b/e/f. A projectile is in flight (to the shooter and to players within Combat.Projectile.ViewStuds). The
-- client draws it from Origin with Velocity under Gravity from StartedAt (server clock); Own is true for the shooter,
-- who may already have predicted it.
export type ProjectileLaunchInfo = {
	Id: number,
	Kind: string, -- "Flare" or "Knife"
	Origin: Vector3,
	Velocity: Vector3,
	Gravity: number,
	StartedAt: number,
	Own: boolean,
}

-- The projectile ended. Reason: "Wall", "Agent", "Npc" or "Expired" (out of flight time). A flare sets LightUntil
-- (server clock): the area at Position is lit until then. A knife that lands is a LandedKnife part in the world.
export type ProjectileImpactInfo = {
	Id: number,
	Reason: string,
	Position: Vector3,
	Normal: Vector3?,
	LightUntil: number?,
}

-- A smoke cloud (a radius around Position) until ExpiresAt on the server clock. Sent to everyone.
export type SmokeCloudInfo = { Position: Vector3, Radius: number, ExpiresAt: number }

-- To Suture's team only: the character TargetId (the body's model name, the same for an NPC and a player) glows
-- until ExpiresAt. Drawn client-side with line of sight; it follows the character through disguise changes. ThroughWalls (the
-- Lattice burst rifle's tracker mark, sent to the shooter alone) is drawn even when the body is behind a wall.
export type TargetGlowInfo = { TargetId: string, ExpiresAt: number, ThroughWalls: boolean? }

-- To the victim only. "Taser": walk at SlowMult for Seconds (applied by the server); their ability and gadgets are also locked. "Stagger": walk at SlowMult for Seconds (the server already applies the slow) and bump the aim
-- AimBumpDegrees, away from From. "Shove": move Studs along Direction over Seconds (the server cannot move a player's
-- body; their client does it, and falls like any walk).
export type CombatStatusInfo = {
	Kind: string,
	Seconds: number,
	SlowMult: number?,
	AimBumpDegrees: number?,
	From: Vector3?,
	Direction: Vector3?,
	Studs: number?,
}

-- Ticket 9c: what a spectator is watching, sent to them alone. Mode: "Teammate", "Player", "Drone" or "None".
-- DronePosition is set when the server puts the drone somewhere (its start, or a correction).
export type SpectateStateInfo = { Mode: string, TargetUserId: number?, CanDrone: boolean, DronePosition: Vector3? }

-- Ticket 9c: one spectator chat line, already filtered for its reader.
export type SpectatorChatInfo = { Sender: string, Text: string }

-- Ticket 19-pings: a team ping to draw. Kind is one of GameConfig.Ping.Kinds. TargetId (Suspect only) is a model name the client
-- already sees; the marker rides above that body and says nothing about what it is. From is the pinger's display name.
export type PingInfo = { Id: number, Kind: string, Position: Vector3, TargetId: string?, ExpiresAt: number, From: string }

-- Step 9: a team's roster, sent only to its own members (CLAUDE.md rule 3).
export type TeamRosterInfo = { TeamId: number, Members: { Player } }

-- Brief Q6: a disguise-swap marker. ExpiresAt is on the server clock (workspace:GetServerTimeNow()).
export type SwapMarkerInfo = { Position: Vector3, ExpiresAt: number }

-- Ticket studio-test-loadout: WeaponId discards late ammo corrections from a previous selection.
export type AmmoInfo = { Mag: number, Reserve: number, ReloadSeconds: number, WeaponId: string? }
export type TestLoadoutInfo = { WeaponId: string, Mag: number, Reserve: number, Reset: boolean }
export type HealthInfo = { HP: number, Armor: number }
export type DamageInfo = { Position: Vector3, Amount: number } -- where the shot came from, for the direction marker
export type ShotInfo = { Origin: Vector3, Hit: Vector3, WeaponId: string, Struck: boolean } -- Struck: a person was hit
-- Ticket 8.22: owner-only action acknowledgements. Strike confirms an attack, not a down/elimination.
export type MeleeKind = "Takedown" | "Charge" | "Strike"
export type MeleeState = { Kind: MeleeKind, Seconds: number, Active: boolean, StartedAt: number?, Result: MeleeResult? }
-- R5-takedown: what a completed takedown did, server-confirmed. Only "Downed" or "Eliminated" may trigger a cosmetic
-- finisher; "Hit" (the target survived the damage) never does. Absent on every other MeleeState.
export type MeleeResult = "Downed" | "Eliminated" | "Hit"
-- R5-takedown: sent only to a player who is being taken down, so their own character plays the struggle.
export type TakedownVictimInfo = { Active: boolean, Seconds: number, StartedAt: number? }

-- Ticket menu-phase0: agents, loadouts, agent select and the meta profile. Keep in step with Enums.
export type AgentId = "Guise" | "Parapet" | "Lattice" | "Reticle" | "Suture" | "Feint"
export type AgentClass = "Deceiver" | "Enforcer" | "Specialist"
export type QueueMode = "Solos" | "Duos" -- the modes the menu queues for (SPEC_CHANGES: Duos and Solos)
export type MenuTab = "Play" | "Agents" | "Assets" | "Dossiers" | "BlackMarket" | "Profile" | "Hardware" | "Mint"
export type AssetRarity = "FieldAgent" | "Infiltrator" | "BlackOps" | "Ghost"
export type DossierTrack = "Free" | "Premium"
export type ItemState = "Equipped" | "Owned" | "Available" | "Locked"

-- One of an agent's three Hardware items, in slot order (AgentDefs). Def is the weapon's firing record once it is built;
-- nil means the weapon is designed (STEP8_QUESTIONS) but not playable yet, so it can be shown but never equipped.
export type AgentHardware = {
	Id: string,
	Agent: AgentId,
	Slot: number, -- 1, 2, 3 (Enums.HardwareSlot)
	UnlockMasteryLevel: number, -- GameConfig.Mastery.HardwareUnlockLevels[Slot]
	Name: string,
	Category: string, -- what kind of weapon, for the menu ("SMG", "Pump shotgun", "Melee")
	Def: WeaponDef?,
}

-- A Talent (ability, CooldownSeconds set) or an Instinct (passive, no cooldown). Text from AGENTS_DRAFT.
export type AgentKitItem = {
	Id: string, -- a Talent's Id names its Ability module and its GameConfig.Talents entry; an Instinct's names GameConfig.Instincts
	Name: string,
	Description: string,
	CooldownSeconds: number?,
}

export type AgentHardwareEntry = { Id: string, Name: string, Category: string }

export type AgentDef = {
	Id: AgentId,
	DisplayName: string,
	Epithet: string, -- "the Chameleon"
	Class: AgentClass,
	Role: string, -- "Disguise master"
	Hardware: { AgentHardwareEntry }, -- ordered W1, W2, W3; read it through WeaponDefs.getForAgent
	-- SPEC_CHANGES 15/16: three of each per agent. Only the first of each is designed so far (the rest are Step 16).
	Talents: { AgentKitItem },
	Instincts: { AgentKitItem },
}

-- A sub-gadget (docs/GADGETS_DRAFT.md): carried two to a player, used with keys 2 and 3.
export type GadgetCategory = "Recon" | "Infiltration" | "Evasion" | "Support"
export type GadgetDef = {
	Id: string,
	Name: string,
	Category: GadgetCategory,
	Charges: number,
	Description: string,
}

-- Ticket 18c, the Supply Cache shop ("ShopState", to the shopper only). Sent when the shop opens, after every purchase or
-- refusal, and with Open = false when it closes. Price is already this cache's price (discount included); Reason says why an
-- item cannot be bought now ("", or for example "Armour is full"). While Buying names an item, its purchase runs for BuySeconds
-- and breaks Cover; the shopper buys one thing at a time.
export type ShopItemInfo = { Id: string, Name: string, Price: number, Available: boolean, Reason: string }
export type ShopStateInfo = {
	Open: boolean,
	CacheId: string,
	Intel: number,
	Items: { ShopItemInfo },
	Buying: string?,
	BuySeconds: number,
}

-- Ticket 17d: where a player's standing Bug Cams are and the way each faces ("BugCamState", to the owner only); the view of each
-- is taken from its CFrame. Sent whenever one is placed or goes.
export type BugCamStateInfo = { Cams: { CFrame } }

-- Ticket 17: a player's gadgets for the HUD ("GadgetState", to the owner only). Held is 0 for the weapon, else the slot.
export type GadgetStateInfo = {
	Slots: { { Id: string, Charges: number } },
	Held: number,
}

-- An Asset (docs/ASSETS_DESIGN.md): Values is a fraction for each rarity (-0.15 is 15 percent less, 0.4 is 40 percent more).
export type AssetDef = {
	Id: string,
	Name: string,
	Description: string,
	Values: { [AssetRarity]: number },
}

-- Ticket 18e ("AssetState", to the owner only): the four Asset slots in rarity order, which Asset each holds, and whether it has
-- been found yet. Sent at the start of a match and whenever one is found or lost.
export type AssetStateInfo = {
	Slots: { { Rarity: AssetRarity, AssetId: string, Found: boolean } },
}

-- What a player takes into a match. Cosmetics (Step 21) join this when their defs exist.
export type PlayerLoadout = {
	AgentId: AgentId,
	HardwareId: string, -- must be one of AgentId's Hardware, built, and unlocked by mastery
	GadgetIds: { string }?, -- up to Gadgets.Slots built gadgets (GadgetDefs); nil takes Gadgets.DefaultPicks
	AssetIds: { string }?, -- four different Assets (AssetDefs), one for each rarity slot in order; nil takes Assets.DefaultPicks
	TalentId: string?, -- one of AgentId's Talents, unlocked by mastery; nil takes the first (ticket kits-24)
	InstinctId: string?, -- one of AgentId's Instincts, unlocked by mastery; nil takes the first
}

export type AgentMastery = { Level: number, XP: number }

-- Ticket dossier (docs/DOSSIER_DRAFT.md): one reward on a Dossier tier. Kind is "Credits" or "Stocks" (Amount) or "Cosmetic" (CosmeticId, an id
-- from CosmeticDefs). A tier has a Free list and a Premium list; both are claimed by the player.
export type DossierReward = { Kind: string, Amount: number?, CosmeticId: string? }
export type DossierTier = { Free: { DossierReward }, Premium: { DossierReward } }
export type DossierDef = { Id: string, Name: string, Tiers: { DossierTier } }
-- Any owned cosmetic: Attire from the Black Market and the Dossier-only kinds. Kind is "Attire", "Title", "Card", "Spray", "Finish", "Takedown" or "Extraction".
export type CosmeticEntry = { Id: string, Name: string, Kind: string, AgentId: string? }

export type DossierProgress = {
	XP: number,
	Premium: boolean,
	Claimed: { number }, -- tiers already claimed: n for the free track, n plus GameConfig.Dossier.PremiumClaimOffset for the premium track (a list, so it survives a remote)
}

-- Career numbers the Profile shows; all come from finished matches.
export type CareerStats = {
	Matches: number,
	Extractions: number,
	IntelGathered: number,
	Eliminations: number,
	Takedowns: number,
	MatchesUncompromised: number, -- matches finished without ever being Exposed
}

-- A player's meta profile, sent only to that player. String keys throughout so every table crosses a remote intact.
export type MetaProfile = {
	Level: number, -- the account level (spec 20.2)
	XP: number, -- account XP toward the next level
	LastWinDay: number, -- the UTC day number of the last win, for the daily first-win bonus (spec 20.3); 0 for never
	Credits: number, -- earned in play
	Stocks: number, -- premium, bought in the Mint
	OwnedAgents: { [string]: boolean }, -- keyed by AgentId
	StarterPicksLeft: { [string]: boolean }, -- keyed by AgentClass: classes whose free first-launch pick is still open
	Mastery: { [string]: AgentMastery }, -- keyed by AgentId
	OwnedCosmetics: { [string]: boolean },
	ActiveDossierId: string?,
	Dossiers: { [string]: DossierProgress },
	Career: CareerStats,
}

-- Ticket 21-rewards (spec 20.1 to 20.3): what a finished match gave one player, sent to that player alone. Lines is the XP
-- breakdown in the order earned. LevelAfter, XpIntoLevel and XpForLevel place them on the level bar after the match.
export type MatchRewardLine = { Event: string, Xp: number }
export type MatchRewardsInfo = {
	Lines: { MatchRewardLine },
	TotalXp: number,
	LevelBefore: number,
	LevelAfter: number,
	XpIntoLevel: number,
	XpForLevel: number,
	LevelCredits: number, -- 250 for each level gained
	WinCredits: number, -- the win bonus, 0 on a loss
	DailyCredits: number, -- the first win of the day, 0 otherwise
	DossierId: string?, -- the active Dossier the match XP went into (ticket dossier), nil if none
	DossierXp: number?, -- that Dossier's XP after the match
}

-- The modes a player can queue for on this server. Until matchmaking (Step 22) a server plays one mode, so Available
-- holds only that one; the menu shows the other as needing matchmaking.
export type QueueInfo = { Mode: QueueMode, Available: { QueueMode } }

-- GetPlayerMetaProfile's result and ProfileStateUpdated's payload. Loadout is nil until the player owns an agent
-- (first launch: the free picks come first).
export type MetaSnapshot = { Profile: MetaProfile, Loadout: PlayerLoadout?, Queue: QueueInfo }

-- Ticket matchmaking: "MatchmakingState", to the owner only. Searching while queued, Found as the teleport starts, Failed with a reason
-- (a teleport error or a queue error), Idle after a cancel.
export type MatchmakingStateInfo = { State: string, Mode: string?, Reason: string? }

-- Ticket shop-skeleton: one Black Market item. Attire is made for one agent (META_DRAFT). Owning it only marks it in the profile
-- until the art exists. Currency says what it costs; Tier picks the price in GameConfig.Shop.TierPrices.
export type CosmeticOffer = {
	Id: string,
	Name: string,
	Kind: string, -- "Attire"
	AgentId: string,
	Tier: string, -- "Everyday" | "Premium" | "Legendary"
	Currency: string, -- "Credits" | "Stocks"
	Price: number,
}
-- The weekly featured bundle: several items for Stocks at a discount.
export type CosmeticBundle = { Id: string, Name: string, ItemIds: { string }, Items: { CosmeticOffer }, Price: number }
-- GetBlackMarketOffers' result. Daily and Featured are what the server will sell right now; ResetsAt is the server clock
-- (workspace:GetServerTimeNow) time the day's list changes, FeaturedResetsAt the bundle's.
export type BlackMarketState = {
	Daily: { CosmeticOffer },
	Featured: CosmeticBundle,
	ResetsAt: number,
	FeaturedResetsAt: number,
}
-- The Mint's package list (shown by the client from GameConfig.Shop.Mint; this is the shape of its entries).
export type MintPackage = { Id: string, Stocks: number, Robux: number, ProductId: number }

-- RequestEquipLoadout and RequestLockInPreDeploy send this; the server checks every field.
export type LoadoutRequest = {
	AgentId: string,
	HardwareId: string,
	GadgetIds: { string }?,
	AssetIds: { string }?,
	TalentId: string?,
	InstinctId: string?,
}

-- Agent select (META_DRAFT: the full 30 seconds, picks revisable until the cutoff, no duplicate agent on a team).
-- Sent only to the members of one team, so no rival learns a team's agents (CLAUDE.md rule 3).
export type PreDeployMember = {
	UserId: number,
	DisplayName: string,
	LockedIn: boolean,
	AgentId: AgentId?,
	HardwareId: string?,
}

export type PreDeployState = {
	Active: boolean,
	Mode: QueueMode,
	EndsAt: number, -- server clock (workspace:GetServerTimeNow()); the client counts down to it
	Members: { PreDeployMember },
}

-- Ticket 13a: the Package (PackageState) and the extraction (ExtractionState), each sent per player.
export type PackageStateInfo = {
	State: "Hidden" | "Pedestal" | "Carried" | "Dropped",
	Position: Vector3?, -- Pedestal and Dropped: where it lies; Carried: only to rivals during a ping pulse
	YouCarry: boolean,
	TeamCarries: boolean, -- the receiver's team has it
	PulseUntil: number?, -- server clock: a ping pulse runs until then
	ReturnsAt: number?, -- Dropped: when it goes back to the pedestal
}
export type ExtractionStateInfo = {
	State: "Idle" | "Countdown" | "Hover" | "Open" | "Extracted",
	SiteId: string?,
	Position: Vector3?,
	EndsAt: number?, -- server clock: Countdown end, Hover end, or the Open window's expiry once a channel failed
	ByYourTeam: boolean, -- your team called it
}

-- Ticket 12a: the vault terminals (VaultProgress, to everyone once the Vault Breach begins). Progress is 0 to 1 and global:
-- one bar per terminal that every team's hacking adds to.
export type VaultTerminalInfo = {
	VaultId: string,
	Position: Vector3,
	Progress: number,
	Contested: boolean, -- agents of two or more teams stand on it, so it is paused
	Hacked: boolean,
}
export type VaultProgressInfo = { Terminals: { VaultTerminalInfo } }

-- Ticket 11a: a team's Intel (IntelUpdate, to that team only).
export type IntelUpdateInfo = { Balance: number, Used: { string } } -- Used: the station ids this team has already taken

-- Ticket 10a: the match phases (spec 2). PhaseChanged(phase, PhaseData) goes to every client on each transition, and to
-- the players in the lobby whenever the wait for the match changes. All times are on the server clock
-- (workspace:GetServerTimeNow()). Fields that do not apply to a phase are nil.
export type MatchBrief = {
	Mode: string, -- a key of GameConfig.Modes
	TeamId: number, -- the receiving player's own team; GameConfig.Lobby.TeamColors[TeamId] is its colour
	Teams: number, -- how many teams are in the match
	Players: number,
}

export type ResultsMember = { UserId: number, DisplayName: string, AgentId: AgentId?, Out: boolean }

export type ResultsTeam = { TeamId: number, Won: boolean, Members: { ResultsMember } }

export type MatchResults = {
	WinnerTeamId: number?, -- nil: Mission Failed for everyone
	Reason: "Extracted" | "MissionFailed",
	Teams: { ResultsTeam }, -- revealed only now, once the match is over
}

export type PhaseData = {
	StartedAt: number,
	EndsAt: number?, -- when the phase's own timer ends (Insertion, Results, and the Lobby wait for more teams)
	MainEndsAt: number?, -- Infiltration onward: when the main match timer ends
	ForcedVaultAt: number?, -- Infiltration: when the Vault unlocks whatever the Intel total
	Banner: string?, -- large centred text for GameConfig.Match.BannerSeconds
	Brief: MatchBrief?, -- Insertion
	Results: MatchResults?, -- Results
	ReadyPlayers: number?, -- Lobby, once this player's team has finished agent select: players waiting for the match
}

-- Ticket menu-phase0: a menu screen. Views are plain modules in src/client/Menu/Views (not Controllers: the client boot
-- requires every Controller). MenuController requires each one, mounts it into its stage frame when its tab opens and
-- unmounts it when the tab closes; Unmount must destroy everything Mount made. Context carries deep-link data, for
-- example { AgentId = "Guise" } when Play's "Customize loadout" opens Hardware.
export type MenuNavigator = {
	navigateTo: (tab: MenuTab, context: { [string]: any }?) -> (),
	back: () -> (),
	canOpen: (tab: MenuTab) -> boolean, -- false while that screen is not built yet
	-- The 3D stage behind the menu: show this agent holding this Hardware (nil: the agent's equipped or W1 item).
	focusAgent: (agentId: AgentId, hardwareId: string?) -> (),
	-- The latest profile and loadout from the server (nil until the first answer), and a listener for changes; the
	-- returned function disconnects it, so call it from Unmount.
	snapshot: () -> MetaSnapshot?,
	onSnapshot: (listener: (MetaSnapshot) -> ()) -> () -> (),
}

export type MenuView = {
	Tab: MenuTab,
	Mount: (stage: Frame, navigator: MenuNavigator, context: { [string]: any }?) -> (),
	Unmount: () -> (),
}

-- GPS (docs/GPS_DESIGN.md): the answer to RequestRoute. Targets are what the match has revealed to this player; Selected is the
-- one the routes lead to. Clean keeps the current disguise's clearance and Cover; Fast may hack tier doors and use the ways that
-- break Cover. Either is nil when there is no such route. Points is the polyline from the player to the target; each Step names
-- what happens at the point Index (a floor change, a hack with its intel price, a Cover-breaking way).
export type RouteStepInfo = {
	Index: number,
	Kind: string, -- "Hack", "Restricted", "Stair", "Elevator", "Vent", "Zipline", "Gondola" or "Ladder"
	Detail: string?, -- "Door" or "Elevator" for a Hack
	Intel: number?, -- the intel a Hack costs
	CoverBreak: boolean,
}
export type RouteInfo = {
	Points: { Vector3 },
	Length: number,
	HackIntel: number,
	CoverBreaks: number,
	Affordable: boolean, -- the team's intel pays for every hack on it
	Steps: { RouteStepInfo },
}
export type RouteTargetInfo = { Id: string, Name: string, Kind: string } -- Kind: "Terminal", "Extraction" or "Teammate"
export type RouteResult = {
	Targets: { RouteTargetInfo },
	Selected: string?,
	Clean: RouteInfo?,
	Fast: RouteInfo?,
	Intel: number, -- the team's intel now
}

-- GPS carrier tracking (docs/GPS_DESIGN.md), to the Package carrier only. A "Ping" is one mark (the nearest rival) that the
-- client shows for Seconds; "Live" is every rival in range, sent again each update while the key is held; "End" clears them.
-- Marks are positions only: never who they are, and never a crowd NPC.
export type CarrierTrackInfo = {
	Mode: "Ping" | "Live" | "End",
	Marks: { Vector3 },
	Seconds: number?,
	Intel: number, -- the team's intel after paying
}

-- Token-bucket limits for one client -> server remote (GameConfig.Network).
export type RateLimit = {
	PerSecond: number,
	Burst: number,
}

return {}
