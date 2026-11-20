--!strict
-- Ticket audio-defs (Step 20, spec 23): every sound cue that is not a weapon, in one table. The cue system (AudioCueController) plays
-- these; a cue whose Id is "" is skipped, so the game is silent for that cue until a real sound is put here and nothing else changes.
--
-- SPEC-QUESTION: no id below is set. Claude Code cannot audition or verify a Roblox library id from here, and an id that does not load
-- would play nothing anyway. Put an `rbxassetid://` id on each line you want (the weapon, hitmarker and impact sounds are elsewhere
-- and already have ids). Volumes are 0 to 1 and are first guesses.
--
--   AudioDefs.Cues[name] -> Cue
--   AudioDefs.Ambient[tier] -> Cue        a loop under the player while they are in that tier (0 Public to 3 Executive)
--   AudioDefs.Crowd -> Cue                the crowd's murmur, louder with more people near
--   AudioDefs.Siren -> Cue                loops at Lockdown

export type Cue = { Id: string, Volume: number }

local function cue(volume: number): Cue
	return { Id = "", Volume = volume }
end

local AudioDefs = {
	Cues = {
		ExposedSting = cue(1), -- spec 23: heard by the exposed player and everyone within 60 studs
		DisguiseSwap = cue(0.5), -- soft fabric swish
		VaultUnlock = cue(0.9), -- the Vault Breach begins
		VaultOpened = cue(0.9), -- a vault terminal is hacked
		PackageDropped = cue(0.9),
		PackageReturned = cue(0.9),
		ExtractionCalled = cue(0.9),
		HelicopterArrival = cue(1),
		LastMinuteTick = cue(0.7), -- once a second in the last 60 s of the match
		FootstepWalk = cue(0.35), -- the same for an NPC and an agent (rule 3)
		FootstepSprint = cue(0.6), -- the heavier set
	} :: { [string]: Cue },
	Ambient = {
		[0] = cue(0.4), -- gala music (string quartet)
		[1] = cue(0.4), -- kitchen clatter
		[2] = cue(0.4), -- server hum
		[3] = cue(0.3), -- quiet ambience
	} :: { [number]: Cue },
	Crowd = cue(0.5),
	Siren = cue(0.8),
}

return AudioDefs
