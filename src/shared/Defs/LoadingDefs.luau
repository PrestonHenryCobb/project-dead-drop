--!strict
-- What each loading screen says (owner 2026-11-25: a themed screen for every kind of load, in the dossier style). Data only; LoadingScreen draws it.
--
--   LoadingDefs.scene(id) -> Scene       a scene by id (asserts it exists)
--   LoadingDefs.bootSceneFor(placeId) -> id      which scene shows when the game starts in a given place
--   LoadingDefs.ids() -> { string }      every scene id
--
-- Briefing lines mark text to black out with [[double brackets]]; the bars are drawn, the words are never sent to the screen. Steps are the status lines
-- under the bar: with real progress they follow the bar, otherwise they advance on a timer. Tips only say what the rules already do.

local GameConfig = require(script.Parent.Parent.GameConfig)

export type Scene = {
	Id: string,
	Kicker: string, -- small caps line above the title: the file reference
	Title: string,
	Subtitle: string,
	Stamp: string, -- the rubber stamp in the corner
	Accent: Color3,
	Briefing: { string },
	Steps: { string },
	Tips: { string },
}

local gold = Color3.fromHex("B88E44")
local cyan = Color3.fromHex("6C9AA5")
local crimson = Color3.fromHex("A8434B")
local sage = Color3.fromHex("7C9A7A")

-- Tips are grouped by theme so a scene can pull the ones that fit what the player is about to do.
local tips = {
	cover = {
		"Guests, staff, security and executives all move differently. Copy the crowd you are dressed as.",
		"Players and NPCs look identical while disguised. Behave like staff, not like a gunman.",
		"Stay Covered and nobody looks twice. Once you are Exposed, everyone nearby knows what you are.",
		"Being Exposed is not the end. Slip away and re-cover to blend back in.",
		"Your cover is a wardrobe, not a wall. Watch the tie and lapel colours to read who ranks above you.",
	},
	intel = {
		"Intel stations are scattered through the whole building. Search every room, not just the obvious ones.",
		"Every NPC keeps a routine. Stand where they stop and you will blend into it.",
		"Rooms are furnished for their purpose. The kitchen, the bar and the library all draw their own crowd.",
	},
	vault = {
		"Vault terminals are hold-to-hack. The progress never decays, so a team can take turns.",
		"The vault markers are always on your screen. Know which one your team is closest to.",
		"A hack shows. An Exposed agent wears a watch on the wrist while hacking or re-covering.",
	},
	team = {
		"Hold the ping key to open the ping wheel and tell your team what you need.",
		"Teammate markers come only from your own team's roster. Nobody else sees them.",
		"Lock in your loadout early. When your whole team is ready the countdown drops to ten seconds.",
	},
	lobby = {
		"Your agent, loadout and cosmetics are saved to your profile between matches.",
		"Check the Dossier before queueing. New unlocks wait there.",
	},
}

local function pool(...: { string }): { string }
	local list: { string } = {}
	for _, group in { ... } do
		for _, tip in group do
			table.insert(list, tip)
		end
	end
	return list
end

local scenes: { [string]: Scene } = {
	Boot = {
		Id = "Boot",
		Kicker = "CASE FILE 0001 · OPENING",
		Title = "Cover Story",
		Subtitle = "Preparing the evening",
		Stamp = "CONFIDENTIAL",
		Accent = gold,
		Briefing = {
			"Tonight's guests include [[four unnamed principals]] and one very patient host.",
			"The vault holds [[the ledger]]. The rest of the building holds everything else.",
			"Nobody is who they say they are. [[Including you.]]",
		},
		Steps = {
			"Unfolding the floor plans",
			"Pressing the uniforms",
			"Setting the tables",
			"Testing the locks",
			"Dimming the lights",
		},
		Tips = pool(tips.cover, tips.intel, tips.vault, tips.team),
	},
	Lobby = {
		Id = "Lobby",
		Kicker = "SAFEHOUSE · BETWEEN JOBS",
		Title = "The Safehouse",
		Subtitle = "Back in from the cold",
		Stamp = "DEBRIEFED",
		Accent = cyan,
		Briefing = {
			"Your last assignment is [[filed and sealed]].",
			"The next contract has not yet been [[assigned]]. Pick an agent and a loadout while you wait.",
			"Rest is a luxury. [[The queue is open.]]",
		},
		Steps = {
			"Hanging up the coat",
			"Pulling your file",
			"Checking the dossier",
			"Opening the Black Market",
			"Warming up the queue",
		},
		Tips = pool(tips.lobby, tips.team, tips.cover),
	},
	Match = {
		Id = "Match",
		Kicker = "THE GALA · NIGHT OF",
		Title = "The Gala",
		Subtitle = "The guests are arriving",
		Stamp = "DEPLOYED",
		Accent = gold,
		Briefing = {
			"Objective: reach [[the vault]] and leave with [[the ledger]].",
			"The guest list is longer than the guard list. [[Use the difference.]]",
			"Stay Covered. Stay [[unremarkable]]. Stay alive.",
		},
		Steps = {
			"Arriving at the gates",
			"Checking the guest list",
			"Seating the crowd",
			"Posting the guards",
			"Raising the curtain",
		},
		Tips = pool(tips.cover, tips.intel, tips.vault),
	},
	ToMatch = {
		Id = "ToMatch",
		Kicker = "INSERTION · TRANSIT",
		Title = "Going In",
		Subtitle = "Your contract has been found",
		Stamp = "EN ROUTE",
		Accent = crimson,
		Briefing = {
			"Your team is assembled. [[Nobody here has met.]]",
			"A car is waiting outside the [[service entrance]].",
			"Everything from here is [[off the record]].",
		},
		Steps = { "Reserving the venue", "Gathering the team", "Handing over the keys", "Driving through the gates" },
		Tips = pool(tips.team, tips.cover, tips.vault),
	},
	ToLobby = {
		Id = "ToLobby",
		Kicker = "EXFILTRATION · DEBRIEF",
		Title = "Heading Home",
		Subtitle = "The night is over",
		Stamp = "EXTRACTED",
		Accent = sage,
		Briefing = {
			"The evening will be remembered as [[a quiet one]].",
			"Your earnings are being [[counted and sealed]].",
			"Wash off the night. [[The next case is already open.]]",
		},
		Steps = { "Leaving the grounds", "Burning the evidence", "Settling the accounts", "Returning to the safehouse" },
		Tips = pool(tips.lobby, tips.team, tips.intel),
	},
}

local LoadingDefs = {}

function LoadingDefs.scene(id: string): Scene
	local scene = scenes[id]
	assert(scene, `Unknown loading scene {id}`)
	return scene
end

function LoadingDefs.ids(): { string }
	local list: { string } = {}
	for id in scenes do
		table.insert(list, id)
	end
	table.sort(list)
	return list
end

-- The scene for a client that has just joined place `placeId`: the Gala at the match place, the safehouse at the lobby place, and the generic opening
-- anywhere else (a single place, or Studio).
function LoadingDefs.bootSceneFor(placeId: number): string
	local matchmaking = GameConfig.Matchmaking
	if matchmaking.MatchPlaceId ~= 0 and placeId == matchmaking.MatchPlaceId then
		return "Match"
	end
	if matchmaking.LobbyPlaceId ~= 0 and placeId == matchmaking.LobbyPlaceId then
		return "Lobby"
	end
	return "Boot"
end

return LoadingDefs
