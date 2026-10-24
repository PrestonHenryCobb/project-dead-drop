# Task queue

Built from `docs/BUILD_ORDER.md`, `docs/STEP8_HANDOFF.md` and `docs/IDEAS_2026-10-24.md`. One step at a time: tickets for
the next step stay `BLOCKED` until the owner starts that step. Owners are proposals; the owner confirms or swaps them.

Status: `TODO`, `IN_PROGRESS (CLAUDE_CODE)` or `IN_PROGRESS (CODEX)`, `READY_FOR_REVIEW`, `DONE`, `BLOCKED`.
Every ticket ends with the `CLAUDE.md` report, `stylua src` and `selene src` clean, and no commit unless the owner asks.

## Step 8: finish weapons (current)
| Id | Ticket | Owner | Needs | Status |
|---|---|---|---|---|
| 8.1 | Test pass in Studio: melee (V), takedown from behind (hold V 1.2 s, breaks at 4 studs or when hurt), reload, empty click, fall damage; ziplines, gondola and vents must not cause fall damage. Fix what fails. **Fixed:** falls are now measured by height (the server's copy of a player's Humanoid state reported Landed mid-fall, so a 40-stud drop did nothing); the first shot after a reload is no longer dropped. Takedown breaking when the attacker is hurt is untested (needs 2 players, 8.4). | CLAUDE_CODE | Studio | READY_FOR_REVIEW |
| 8.2 | Reload cancels on a disguise swap (spec 27 #22). | CLAUDE_CODE | | TODO |
| 8.3 | Check the combat HUD in play (crosshair, hitmarkers, damage direction, HP and plates, ammo, takedown bar) and fix layout bugs. Do **not** tune view-model poses: Step 8B rebuilds them. Owner reported checks all clear on 2026-10-24. | CODEX | | READY_FOR_REVIEW |
| 8.4 | Two-player fire test: cover exposure on firing, red hitmarker, DamageTaken marker. | Owner with either agent | 2 players | TODO |
| 8.5 | Remaining 17 weapons, one agent per ticket (8.5a Guise, b Parapet, c Lattice, d Reticle, e Suture, f Feint): `WeaponDefs` entries and client feel by Codex; any new server rule (unique effects in `STEP8_QUESTIONS.md`) as a hand-off to Claude Code in `CombatService`. Includes Parapet's shorter heavy-SMG falloff and Feint's silent pistol replacing the heavy revolver. | CODEX + CLAUDE_CODE | 8.1 | TODO |
| 8.6 | SMG model in Blender for the owner to upload. | CLAUDE_CODE | Owner uploads | TODO |
| 8.8 | First hit on a Covered or Suspicious agent uses body damage even on the head (SPEC_CHANGES 2026-10-24). | CLAUDE_CODE | | TODO |
| 8.9 | Per-weapon `PostMeleeFireDelay` scaled to weapon strength (brief Q14): field in `WeaponDefs` (Codex), enforced on the server in `CombatService` (Claude Code). Values set case by case with each agent's weapons in 8.5. | CODEX + CLAUDE_CODE | 8.1 | TODO |
| 8.10 | Ammo reconciliation in `WeaponController` (found in 8.1). Holding fire through a reload, the client completes the reload on its own clock and fires at once (mag 29), then the server's reload confirmation (`AmmoUpdate` Mag=30, ReloadSeconds=0) overwrites it, so the client counts one round too many. At the end of that magazine it fires one shot (sound, recoil) that the server rejects with Mag=0. Fix: keep the local count when an AmmoUpdate only confirms a reload the client already completed (same Reserve, Mag at or above the local one). | CODEX | | TODO |
| 8.7 | Step 8 end report (CLAUDE.md format). | CLAUDE_CODE | 8.1 to 8.6 | TODO |

## Step 8B: feel pass (after Step 8)
<!-- Ticket 8.3 progress (CODEX, 2026-10-24): static review found the combat vitals overlapping the disguise badge.
Moved vitals above it via GameConfig.Combat.Hud.VitalsBottomPixels; StyLua and Selene pass (0 errors/warnings).
Owner reported the requested Studio HUD checks "all clear" on 2026-10-24. Verification is owner-reported;
agent capture failed twice (FrameArrived timed out; window capture timed out). Locks released; no commit. -->

In this order; each depends on the one before. Decisions: `IDEAS_2026-10-24.md` and `BUILD_ORDER.md` Step 8B.
| Id | Ticket | Owner | Status |
|---|---|---|---|
| 8B.1 | Slimmer, taller bodies for everyone (height 105-115%, width and depth 80-90%); check hit boxes, doors, vents, camera height, NPC pathing height, clothes. | CLAUDE_CODE | BLOCKED |
| 8B.2 | Full-body first person: torso, legs and feet visible, head and accessories hidden; real arms hold the gun. | CODEX | BLOCKED |
| 8B.3 | Gun always in frame (poses from real FOV and aspect) and the wall tuck (rays, blocks firing when fully tucked). | CODEX | BLOCKED |
| 8B.4 | Held-item switch: one input layer decides whether fire and aim mean weapon or gadget. | CODEX | BLOCKED |
| 8B.5 | Movement feel: gravity about 150, longer jump, ground easing for players **and** NPCs. | CLAUDE_CODE | BLOCKED |
| 8B.6 | Frame stepping: animation 8 a second for everything, other characters' positions 12 a second on the server clock; server rewinds shots to snapped positions. | CLAUDE_CODE | BLOCKED |
| 8B.7 | Hit-box radius about 1.0 stud. | CLAUDE_CODE | BLOCKED |
| 8B.8 | Others see a gun on a character wearing a True Form look (client-side only, no new server message). | CODEX | BLOCKED |

## Step 9: downed, revive, elimination, spectate
| Id | Ticket | Owner | Status |
|---|---|---|---|
| 9.x | Split into tickets when the owner starts Step 9 (spectator rules are in `SPEC_CHANGES.md`). | | BLOCKED |

## Waiting on the owner
- The brief's answers (`docs/IDEAS_2026-10-24_BRIEF.md`) are decided; each lands in the step its table names. Only 8.8 is
  ticketed now. Step 16 needs 12 new Talents and 12 new Instincts designed with the owner first.
- The Deceive Inc. tutorial videos for Step 13C (`IDEAS_2026-10-24.md` Q10).
