# Autonomous Improvement Queue

Self-paced work queue for Claude /loop iterations. The strategic
phase plan lives in `ROADMAP.md`; this file is the tactical "what to
build next, in order" picked from those phases plus opportunistic
polish.

## How to work this list (for the looped agent)

1. `cd ~/marduk && git fetch origin && git status` — confirm sync
2. Read this file. Pick the topmost `[ ]` item under "Next up".
3. Build it end-to-end:
   - new files in the right folder
   - integrations into existing autoloads / scenes
   - sanity-grep for typos and missing imports
4. Commit with a thorough message (no em-dashes per Bond's preference).
5. `git push origin main`.
6. Mark this entry `[x]` and add a one-line summary of what shipped.
7. Exit. The next /loop firing handles the next entry.

**Quality bar**: 1 well-tested change > 5 rushed ones. If an item turns
out to be larger than expected, split it into sub-tasks and add them
back here, then ship the first piece.

## What absolutely needs Bond's hands (do not script)

- Mixamo `.fbx` retarget pass in Godot's Advanced Import Settings →
  Skeleton3D → Retarget → New BoneMap → SkeletonProfileHumanoid →
  Reimport. ~30 files. **No editor API. Tell Bond if blocked.**
- Smoke test in Godot after major batches.
- Visual QA / look-and-feel review.

## Done so far (this loop's own log; see `git log` for full history)

- [x] Mixamo character + animation registries, runtime loader, BREATHING.md
- [x] 13 region scenes with ZoneComposer geometry
- [x] 27 lodestones, World Map fast-travel
- [x] 134-item ItemRegistry + IconAtlas + LootGenerator + ItemPickup
- [x] DamageFloater + procedural AudioBus.play_cue
- [x] Q/W/E/R class kits + BreathTrail VFX (8 styles)
- [x] WoW UI: ability bar, minimap, nameplates, mount + pet
- [x] Mob HP scaling, BossArena lockdown, Boss bar, Kazat phases
- [x] 3 Ashurim quest-givers, 3 starter quests, 12 achievements
- [x] Start menu + character creation .tscns, save round-trip
- [x] QuestTrackerHUD + CombatLog + AutoSave + MusicDirector
- [x] TrainerNPC + VendorNPC variants

## Bond's vision pillars (re-prioritized 2026-05-06)

Bond chose maximalist: ALL FOUR moods (Soulslike grim + Diablo loot + WoW
MMO + Demon Slayer anime). ALL emotional registers (sad/love/angry/happy).
**Iconic story**, **deep lore**, **dark fantasy**, **never bored**, **PvP
deeply balanced**. Six load-bearing pillars now drive priority:

1. Story emotional beats (named companion arcs, betrayal, love, sacrifice)
2. Lore engine (Codex, memory items, environmental notes, books)
3. PvP arena + ranked + balanced damage curve
4. Replayability scaffold (NG+, prestige cycles, daily bounties, challenge dungeons)
5. Combat juice (hitstop, screenshake, slow-mo, status effects)
6. Itemization depth (affixes, set bonuses, sockets, salvage/crafting)

## Next up (priority order; work top to bottom)

### Tier 1 — story emotional beats (HIGHEST priority)

- [x] **Codex autoload (sub-task A of Codex menu)**: shipped in commit
      `c4e871a`. CodexRegistry autoload with register / unlock /
      is_unlocked / entries_by_category / get_entry API. Persistence
      via SaveFlags `codex_<id>` permanent flags. 6 standard categories
      (regions, characters, items, lore, bestiary, achievements).
      Tolerant unlock: stubs an entry if unlock fires before register.
- [x] **Codex panel UI (sub-task B)**: shipped in commit `<pending>`.
      New scripts/ui/panels/codex_panel.gd with two-column layout
      (categories left, scrollable cards right). Live-refreshes via
      CodexRegistry.entry_unlocked signal. New &"codex" tab in
      MenuPanel.TABS. New `toggle_codex` action bound to L. HUD
      _unhandled_input + menu hint string updated.
- [ ] **Codex seed entries (sub-task C)**: register() entries for all
      14 regions, 9 player classes, 12 starter NPCs, top 25 unique
      items in ItemRegistry, and the ~80 existing achievements. Lore
      prose pulled from existing registries' lore + display_name
      fields. (~150 lines, mostly data.)
- [ ] **First-encounter unlock hooks (sub-task D)**: region scenes
      call CodexRegistry.unlock(&"r_<region_id>") on _ready; NPCs call
      unlock on first dialogue; ItemPickup calls unlock on first
      pickup of a unique item; AchievementRegistry.unlock pairs with
      a codex unlock per achievement. (~50 lines across files.)
- [ ] **Memory item flashback system**: certain items carry a
      `memory_id` that, on first pickup, fades the camera into a 4-6s
      scripted flashback (camera moves through a posed Tableau in the
      world, voiceover-style label scrolls). Wire 3 starter memories:
      Lord Ennum's broken sword, Belitu's brother's pendant, the
      Storyteller's first verse. (~100 lines per memory + system.)
- [ ] **Belitu's Brother quest payoff**: the brother is alive in the
      Cradle, dying. Player must escort him back to Ashurim (slow walk,
      stamina bar drains as he leans on you). He dies in the plaza in
      front of Belitu. Quest reward is a memorial sash item. (~150 lines.)
- [ ] **Iddinu betrayal arc**: 3rd quest from Iddinu reveals a coded
      ledger in his crate. Player can confront him; he draws steel.
      Combat encounter with custom dialogue. Killing him opens a new
      quest line tracing the Tashmu spy network. (~200 lines.)
- [ ] **Companion NPC: Saru the Wandering Ronin**: rescued in Bone
      Mountains; joins party as a follower (uses TrainerNPC-style
      follower AI but combat-capable, fights alongside you). 10
      conversation beats unlock as you progress. Sacrifices themselves
      in Black Citadel boss fight (scripted death). Memorial tomb at
      Mist Vale unlocks a weapon engraved with their name + stats.
- [ ] **Festival of Marduk** (post-Tiamat): scene swap when player
      enters Ashurim with `tiamat_defeated` save flag set. Plaza
      decorated (banners, candles, NPC dance loops), music shifts to
      G-major bright pad, special vendor sells festival cosmetics.

### Tier 2 — lore engine

- [ ] **Lore notes scattered**: each region scene gets 3-5 readable
      notes placed as Area3D pickups. Reading adds a Codex entry. ~50
      notes total across 13 regions.
- [ ] **Books in Inkstone Tower**: dedicated library room with 10
      readable tomes, each a paragraph of world history. Codex entries.
- [ ] **Environmental graffiti**: scratched messages on dungeon walls
      using Label3D. "TASHMU LIES", "the seal weeps", "she comes from
      below". Souls-style flavor.
- [ ] **NPC ambient barks**: every named NPC gets 5-10 random barks
      that fire when player walks past. Builds a sense of "they were
      already living here when you arrived."

### Tier 3 — PvP scaffold

- [ ] **PvP damage track** in damage_calc.gd: 0.4x multiplier when
      target is Player class. Per-ability tuning override allowed.
- [ ] **Arena scene** scenes/pvp/colosseum.tscn: 60m circular sandstone
      arena, 1v1 / 3v3 / 5v5 spawn anchors, gates that open on round
      start. King-of-the-hill capture point at center.
- [ ] **Match server** in backend/: WebSocket relay matchmaker over
      existing RealtimeChannel. ELO ranking. Cloudflare Worker.
- [ ] **Spectator mode**: dead players become camera-free observers
      with all 6 ability slots replaced by camera position presets.
- [ ] **Seasonal cosmetic rewards**: top-100 ranked players each
      season get a unique title + nameplate glow. Cosmetic only; never
      power.

### Tier 4 — replayability scaffold

- [ ] **NG+**: on Tiamat defeat, dialog offers "Begin again, harder."
      Resets player to level 1 + zone state but keeps gear/skills/Codex.
      Mob HP/damage bumped 1.5x per cycle.
- [ ] **Prestige cycle reward**: Prestige autoload exists. Hook the
      ascend ritual scene + +difficulty + permanent stat bonus +
      cycle-counter UI badge.
- [ ] **Daily bounty board** in Ashurim plaza: 3 randomly-generated
      kill quests refresh every in-game day (WorldClock dawn). Gold
      reward scales with player level.
- [ ] **Challenge dungeon**: roguelike mode. Random ZoneComposer style
      chained 7 levels deep. Permadeath in dungeon. Score = depth +
      kills. Leaderboard per cycle.
- [ ] **Faction reputation**: Iron Crown / Sun-Sworn / Whisper Shrine.
      Killing certain mobs raises one and lowers another. Vendors gate
      stock by rep.

### Tier 5 — combat juice (impact-per-line)

- [ ] **Hitstop**: 80ms `Engine.time_scale = 0.05` on every hit landing.
      Tween-back over 40ms.
- [ ] **CameraRig.shake(magnitude, duration)**: real implementation.
      Hook into BossAttackPattern execute, player crit-kill, boss
      phase transition.
- [ ] **Slow-mo on critical kills**: 0.4s of `time_scale = 0.35` on
      the killing blow that ends a mob's life when crit was rolled.
- [ ] **Status effects with icons**: burn / freeze / poison / slow /
      stun / bleed. Element interactions (frozen + lightning =
      shatter, double damage). Resistances per mob tag (undead resist
      physical, take +30% holy).
- [ ] **Knockback on heavy hits**: ability_kit entries with
      `knockback_force` field. Apply impulse to enemy CharacterBody3D.
- [ ] **Footsteps** per surface: stone / grass / wood / sand. Hooked
      to move_and_slide ground contact.
- [ ] **Damage number scaling pop**: tween scale 0.6→1.2→1.0 in 0.15s
      on spawn.

### Tier 6 — itemization depth

- [ ] **Affixes**: 30 prefixes ("Cruel", "Bloodied", "Heaven-Touched")
      + 30 suffixes ("of the Bear", "of Three Vows"). Roll 0-2 per drop
      weighted by rarity. Tooltips show full rolled name.
- [ ] **Set items**: 5-piece sets with cumulative bonuses. 3 starter
      sets: Ash-Step Raider's Garb, Sun-Sworn Vestments, Inkstone
      Initiate's Robes.
- [ ] **Sockets + gems**: RARE+ items roll 0-3 sockets. Gems craft via
      a new Crafting NPC in Ashurim.
- [ ] **Salvage**: right-click items in inventory to break into
      crafting materials.
- [ ] **Item comparison in tooltip**: hover an item, show "+12 atk,
      -4 dex vs equipped" in red/green delta.

### Already done

- [x] **Quest progress wiring**: shipped in commit `06733e4`. EnemyBase._die
      and LodestoneRegistry.discover both call QuestRegistry.progress(kind,
      target_id, 1). Per-active-quest counters live in `_progress` parallel
      to `_active`. Auto-completes via complete_quest when all objectives
      reach required_count. Quest reward also pays gold. Landmark
      examine hook deferred until landmarks are placed in scenes.
- [ ] **Spawn cradle search marker** in the_cradle.tscn boss room so
      Belitu's Brother quest has a target. Cheap Area3D + Label3D "?"
      that the player walks over to complete the objective.
- [ ] **Mob spawn pools per region**: Spawner currently uses fallback
      pools. Read region's metadata/region_id and pull from
      MobRegistry.mobs_in_zone(zone_id) so each region populates with
      its lore-correct mobs.
- [ ] **Status effect display**: small icon row under each enemy's
      WowNameplate showing active debuffs. Renders from a new
      EnemyBase._statuses array.
- [ ] **Damage type modifiers**: hook DamageCalc to read item element
      fields and apply +30% holy vs undead, +30% fire vs ice mobs,
      etc. Currently most damage falls back to PHYSICAL.

### Tier 2 — content density

- [ ] **More NPCs in Ashurim**: vendor (general goods), Ronin trainer,
      innkeeper (rest to full HP for 5 gold).
- [ ] **NPCs in Babilim**: capital city must feel populated. Paladin
      trainer, high priest, 3 ambient peasants.
- [ ] **Landmark interactables**: each region scene gets 1-3 landmarks
      from LandmarkRegistry placed as Area3D triggers that pop a lore
      panel on V.
- [ ] **+10 side quests**: kill-X-mobs, fetch-Y-item, escort-NPC,
      examine-landmark patterns spread across regions.
- [ ] **Bosses for the other 12 regions**: BossRegistry has more than
      Kazat. Each region's BossSpawn pulls a level-appropriate boss
      with attack patterns from BossAnchor's _build_patterns.

### Tier 3 — combat depth

- [ ] **Parry windows**: Ronin's Parry (F) reflects damage if pressed
      within 0.3s of a boss windup ending.
- [ ] **Combo chain bonus**: BreathingForm.chain_predecessor exists
      already. Track _last_ability_id + timestamp; apply
      chain_bonus_mult when player casts a successor inside the
      perfect_window_seconds.
- [ ] **Stance charges (Ronin)**: implement resource_mechanic `stance`
      properly — gain charge on parry/kill, spend on higher-form abilities.
- [ ] **Crit feedback**: camera shake + brief slow-mo on crit hits via
      CameraRig.shake() + Engine.time_scale tween.
- [ ] **Ranger arrow projectile**: ability_1 spawns an Arrow Area3D
      that flies forward instead of melee hitbox.

### Tier 4 — UI polish

- [ ] **Drag-and-drop equip**: clicking an item in InventoryPanel
      auto-equips it into the matching slot.
- [ ] **Rich item tooltips on hover**: stats + flavor + class
      restrictions, color-coded by rarity.
- [ ] **Death screen**: black fade with "You have died" + "Respawning
      at <lodestone name>..." instead of instant respawn.
- [ ] **Boss intro cutscene**: 1.5s zoom-in + camera shake when
      crossing into the boss arena.
- [ ] **Achievement toast**: slide a centered banner with name + icon
      for 3 seconds when an achievement unlocks.
- [ ] **Settings persistence**: GameSettings sliders persist to
      `user://settings.cfg` and load on _ready.

### Tier 5 — content / lore

- [ ] **Storyteller dialogue branches**: real conversation tree,
      multi-line, with choices.
- [ ] **Cradle lore landmarks**: 7 examinable landmarks (Lord Ennum's
      vows, Iron Crown insignia, broken sword, etc).
- [ ] **Class-specific intros**: each of the 9 classes routes from
      CharacterCreation to its tailored intro scene.

### Tier 6 — multiplayer (Phase 4 — defer)

- [ ] WebSocket party manager handshake
- [ ] Shared boss arenas (multiple players, same boss)
- [ ] Trade UI

## Working notes for future-me

- Procedural audio is intentionally placeholder. When .ogg files ship,
  replace `AudioBus.play_cue(name, pos)` with `AudioBus.play_sfx_3d(path, pos)`.
- IconAtlas paints procedural icons. Override by setting `Item.icon`
  to a real Texture2D in `.tres` files; the atlas falls through.
- HUD font sizes / margins are hand-tuned for 1280x720. Larger
  resolutions need a 1280-anchored CanvasLayer scale.
- BREATHING.md is the source of truth for Ronin form design.
- LFS handles all binaries. Never `git add` .fbx/.glb/.gltf/.blend/
  .ogg/.mp3/.wav/.exr/.hdr without LFS being initialized first.
- Force-push is blocked by sandbox. If history rewrites are needed,
  write the prompt asking Bond to run the command himself.
