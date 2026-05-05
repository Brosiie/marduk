# Marduk Roadmap

This is the build path. Each phase is a meaningful milestone. Don't skip phases.

## Phase 0 - Scaffold (DONE)

What landed:
- Godot 4.6 project structure
- Player CharacterBody3D, Diablo-cam, HUD bars
- 7 classes as Resources (Berserker, Assassin, Ronin, Ranger, Mage, Chaos Druid, Demon-locked)
- Resource mechanics (rage, mana, focus, stance, corruption, form_energy)
- 49 Ronin breathing forms across 7 styles (Water/Flame/Mist/Thunder/Stone/Wind/Sun)
- Sun Breathing gate (post-Tiamat + 2 styles mastered + lvl 18)
- Demon class gate (post-Lucifer)
- Druid shapeshift forms (Wolf/Bear/Raven/Serpent/Tiamat-spawn dragon)
- Stat system with level cap 100
- Prestige (Champion's Cycle): reset level + run flags, keep skills + permanent unlocks, 2x diff per cycle
- 20 zones across 14 regions, level scaling per Diablo 4 model
- Class-unique intro zones (6 unique starts, converge at Ashurim lvl 5)
- Combat: AbilityRunner, hitbox/hurtbox, damage_calc stub, status effects, posture/stagger, lock-on, dodge/parry, hit-stop + camera shake
- Items, inventory, loot tables (prestige-aware multiplier)
- Quests, NPCs, dialogue resources
- Save system (6 slots, character-keyed)
- VFX hooks, audio bus, time-of-day, weather
- Multiplayer scaffold (Phase 4 use)
- World lore in STORY.md

## Phase 1 - First Playable (next)

Goal: a level 1 character can run from one intro zone to Ashurim, kill their mini-boss, and meet the Storyteller.

- [ ] Author one full intro scene (suggest Ronin's Sword-Vow Ruins for combat showcase)
- [ ] Mini-boss AI: Enforcer Kazat with simple attack pattern + posture bar
- [ ] First 3 breathing forms playable (Water 1-3) for Ronin testing
- [ ] AbilityRunner wires hitbox spawning per ability target_mode
- [ ] HUD ability bar shows Q/E/R/F slots and cooldowns
- [ ] Damage popup floating numbers
- [ ] Death + respawn at zone entrance
- [ ] Loot pickup interaction (E to pick up)
- [ ] Ashurim placeholder scene with the Storyteller NPC
- [ ] Bond's damage formula filled in at scripts/combat/damage_calc.gd

Deliverable: 5-10 minute playable demo. Ronin only. One zone, one fight, one cutscene.

## Phase 2 - Class + Vertical

Goal: all 6 starting classes playable through their intro + first 5 levels.

- [ ] Author all 6 intro zones (placeholder geometry OK)
- [ ] One signature ability per class wired into AbilityRunner
- [ ] All 6 mini-boss encounters with distinct mechanics
- [ ] Skill tree visual (Q opens skill panel, can spend points)
- [ ] Ashurim convergence scene (Storyteller dialogue with class-specific lines)
- [ ] Iron Crown Outskirts: open zone with mob waves, level 6-12
- [ ] Save/load fully wired (slot select on title screen)
- [ ] Pause menu

Deliverable: full prologue, 30-60 minute experience per class.

## Phase 3 - Mid Game

Goal: Babilim, faction quests, mid-tier zones.

- [ ] Babilim hub fully built (8 districts, vendors, fast-travel anchor)
- [ ] Reed Wastes, Lapis Bay, Bone Mountains, Verdant Wound playable
- [ ] Faction reputation system (Crown, Inquisition, Druids, Six Breaths, Black Sail)
- [ ] Each breathing dojo has a master who teaches Forms 4-6 with quest gates
- [ ] Loot rarity affixes (prefix/suffix system)
- [ ] Equipment 6-slot full implementation
- [ ] Status effect VFX hooks (burn = fire particles on enemy, etc)
- [ ] Settings menu (audio, video, key rebinding)

Deliverable: ~10 hours of content per class, 30+ zones.

## Phase 4 - Multiplayer

Goal: 2-4 player co-op dungeon mode.

- [ ] Authoritative host architecture validated end-to-end
- [ ] Player MultiplayerSynchronizer on transform + stats
- [ ] RPC for ability casts, host-validates damage and broadcasts results
- [ ] Lobby system (host code + join code)
- [ ] Drop-in / drop-out support
- [ ] Co-op-only dungeon list (curated set of dungeons that benefit from grouping)
- [ ] PvP balance pass (separate damage multiplier track for PvP zones)

Deliverable: stable 4-player co-op for at least one curated dungeon.

## Phase 5 - Endgame

Goal: Tiamat, Lucifer, Demon class, prestige loop.

- [ ] Black Citadel 6-tier dungeon stack (lvl 70-85)
- [ ] Tiamat 3-phase boss (Drowned -> Risen -> True Mother-of-Monsters dragon)
- [ ] Tiamat kill -> sun_breathing_unlocked permanent + tiamat_defeated run flag
- [ ] Sun Gate accessible after Tiamat
- [ ] Fire Stair zone (lvl 85-100)
- [ ] Lucifer 3-phase secret boss (Diplomat dialogue check -> Ember -> Fallen)
- [ ] Lucifer kill -> demon_class_unlocked permanent + lucifer_defeated run flag
- [ ] Ascension Plane zone (prestige-only hub)
- [ ] Prestige flow tested end-to-end
- [ ] NG+ vendors with soul-fragment currency

Deliverable: full game arc, full ascension loop.

## Phase 6 - Procedural Content + Polish

- [ ] Prefab-room dungeon stitcher
- [ ] Themed dungeon variants per region
- [ ] Daily / weekly events
- [ ] Achievements system
- [ ] Leaderboard for prestige depth
- [ ] Steam Workshop or similar for community content
- [ ] Performance pass

## Phase 7 - Beyond

Free DLC ideas after launch:
- More breathing styles (Sound, Beast, Insect, Love, Serpent inspired)
- New regions (Mountains of Heaven, the Apsu underwater realm)
- Dual-class system unlocked at prestige tier 3
- Raid-tier 8-player encounters

## Asset Strategy

**Use placeholders aggressively in Phases 1-3.** Capsule characters, KayKit dungeon kits, Mixamo animations. Build *systems* that are robust; bespoke art comes after the systems prove out.

**Mocap pipeline (cheap):**
- Rokoko Vision (free) for from-phone-video mocap
- Mixamo (free) for action library
- Both export FBX/glTF that drops into Godot

**Modeling pipeline (when ready):**
- Blender 4.x for character meshes
- Sculpt + retopo for hero models, box-modeling for crowds and props
- One Action per breathing form, NLA strips on export
- 5-15k tris per character, 32k for boss models

## What Bond Does, What I Do

| You | Me |
|-----|----|
| Design calls (damage formula, ability concepts, class identity tweaks) | System architecture and code |
| Aesthetic decisions (palette, font, music style) | Tooling, save systems, networking scaffolds |
| Blender modeling and animation (when ready) | Skinning glue, shader configuration |
| Voice direction and narrative beats | Dialogue tree wiring, quest logic |
| Playtesting and feel feedback | Iteration on mechanics based on feedback |

Decision points still open at start of Phase 1:
1. Damage formula in `scripts/combat/damage_calc.gd` (pick: linear / Diablo-diminishing / soulslike-multiplicative)
2. Aesthetic: pure cel-shade or pixelated overlay
3. Sun Breathing prereq policy (hardcode any-2 or design specific style pairings)
4. PvP damage track decision (split now or in Phase 4)
