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

## Next up (priority order; work top to bottom)

### Tier 1 — gameplay loop polish (HIGHEST priority)

- [ ] **Quest progress wiring**: hook EnemyBase._die into QuestRegistry
      to increment kill-count objectives by mob_id. Hook lodestone
      discover into the `lodestone_count` objective kind. Hook landmark
      examine into `examine` objective. Auto-call complete_quest when
      all objectives finish. (~80 lines.)
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
