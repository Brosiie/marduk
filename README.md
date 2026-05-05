# Marduk

Babylonian fantasy ARPG. Champion of Marduk versus Tiamat and her spawn.
Stylized low-poly + cel-shading. Diablo-style camera, soulslike combat depth,
D&D-style classes and abilities. Online dungeon co-op as Phase 4 stretch.

**Free and open source under [MIT license](LICENSE).** Donations welcome via Ko-fi
($1 prompt on first login each day, fully skippable). All code public on
[github.com/Brosiie/marduk](https://github.com/Brosiie/marduk).

## Account + Backend

- **Cloudflare Workers + D1** backend at `api.marduk.game` (see [CLOUDFLARE_DEPLOY.md](CLOUDFLARE_DEPLOY.md))
- **Account features:** register, login, refresh tokens, character sync, leaderboards
- **Auth client** in [scripts/auth/auth_client.gd](scripts/auth/auth_client.gd) handles login flow, encrypted credential persistence, automatic token refresh
- **Launcher** (Phase 2): Tauri-based PC app, downloads Godot build, manages updates, signs in to Cloudflare
- **Mobile build:** Godot's Android/iOS export, virtual joystick, touch ability bar with toolbar customization

## Controls

**PC default bindings (all rebindable in Settings):**

| Action | Key |
|--------|-----|
| Move | WASD |
| Sprint | Shift |
| Dodge / Roll | C |
| Jump | Space |
| Attack | Left-click |
| Parry | Right-click (tap) |
| Block | Right-click (hold) |
| Lock-on | Tab (cycle with Shift+Tab, Esc to release) |
| Abilities 1-4 | Q E R F |
| Items 1-5 | 1-5 |
| Health/Mana/Stamina potion quick-use | 6 / 7 / 8 |
| Camera rotate | Left/Right arrows or mouse drag |
| Zoom | Scroll wheel |
| Inventory | I |
| Skill tree | K |
| Quest log | J |
| Map | M |
| Character sheet | C (rebindable) |
| Settings / pause | Esc |

**Mobile:**
- Virtual joystick bottom-left
- Ability buttons (Q/E/R/F equivalent) bottom-right in 2x2 grid
- Item quick-slots row above abilities
- Big DODGE button beside abilities
- Long-press any slot → toolbar customization picker
- All key bindings respect mobile platform overrides

## Settings (full menu, sectioned)

- **Display:** fullscreen, resolution, vsync, fps cap, render scale (Octopath crunch at 0.5), MSAA, brightness, contrast, UI scale
- **Audio:** master, music, SFX, ambient, voice volumes; mute when unfocused
- **Controls:** mouse sensitivity, invert Y, camera smoothing, sprint toggle vs hold, auto-target, click-to-move (Diablo style)
- **Key Bindings:** click any action to rebind; supports key, mouse, gamepad
- **Gameplay:** difficulty warnings, damage numbers, loot text, auto-pickup, minimap toggle, objective markers, HUD scale
- **Accessibility:** screen shake intensity (0 = off), hit-stop intensity, color blind mode (proton/deutan/tritan), reduced motion, subtitle size, high-contrast HUD
- **Privacy:** anonymous telemetry opt-in, crash reports
- **Mobile (when active):** joystick size, joystick position L/R, ability button size, toolbar customization



## Engine

Godot 4.6 (Forward+). Pick from https://godotengine.org/download.
GDScript for gameplay. Optionally drop into C# or GDExtension later for hot paths.

## Run

1. Open Godot 4.6.
2. Import Project, point at `~/marduk/project.godot`.
3. Press F5 (Play). Capsule = you. WASD to move, Q/E rotate camera, scroll to zoom, space to jump.

## Project Layout

```
project.godot              # engine config + input map + render settings
icon.svg                   # placeholder Marduk star
scenes/
  main.tscn                # entry: floor, player, camera, HUD
  ui/hud.tscn              # health/mana/xp bars
  player/                  # (room for player.tscn variants per class)
  enemies/                 # (Tiamat spawn scenes go here)
  dungeons/                # (room prefabs go here)
scripts/
  player/
    player.gd              # CharacterBody3D controller, camera-relative move
    camera_rig.gd          # SpringArm Diablo-cam, free yaw + zoom
    player_stats.gd        # HP/mana/XP/level live state, recompute_derived()
  classes/
    player_class.gd        # Class as Resource (data) -> base stats, growth
  skills/
    ability.gd             # Ability resource (cost, cooldown, damage shape)
    skill_node.gd          # One node in the tree (effect + prerequisites)
    skill_tree.gd          # Container, can_unlock(), unlock(), apply_effect
  combat/
    damage_calc.gd         # *** YOUR DAMAGE FORMULA LIVES HERE ***
    hitbox.gd              # Spawned on swing, scans Hurtboxes, deals damage
    hurtbox.gd             # Defensive volume on damageable actors
  enemies/
    enemy_base.gd          # State machine: idle/chase/attack/recover/dead
  ui/
    hud.gd                 # binds to Player signals, draws bars
resources/
  classes/                 # *.tres class definitions (Asaru, Mushlahhu, etc.)
  skills/                  # *.tres skill trees
  abilities/               # *.tres ability definitions
shaders/
  toon.gdshader            # cel-shaded spatial shader for anime vibe
assets/
  characters/              # Mixamo / Blender .glb exports go here
  environments/            # KayKit / Quaternius dungeon kits go here
  audio/                   # SFX and music
```

## MVP Scope Ladder (single-player first)

- [x] **Phase 0** Project scaffold, capsule running on a floor with Diablo-cam.
- [ ] **Phase 1** First class (Warrior/Asaru). Basic attack hitbox. One Tiamat-spawn enemy. One dungeon room. Death + respawn.
- [ ] **Phase 2** XP gain, level-up, mana, one active ability per class. 3-node skill tree.
- [ ] **Phase 3** Save/load. Second class (Mage/Asaruludu). Enemy variety. Loot drops.
- [ ] **Phase 4** Networking via Godot MultiplayerAPI. Host + 1-3 clients. Authoritative host.
- [ ] **Phase 5** Procedural dungeons (prefab rooms stitched).
- [ ] **Phase 6** Tiamat boss fight. Multi-phase, telegraphed attacks.

## Asset Pipeline

Blender stays the content factory. Recommended starting assets while modeling:

- **Characters and animations**: [Mixamo](https://www.mixamo.com) (free, auto-rig, .fbx + anims). Drop into `assets/characters/`. Convert to `.glb` if you want smaller files.
- **Dungeon kits**: [KayKit Dungeon Pack](https://kaylousberg.itch.io/kaykit-dungeon) or [Quaternius](https://quaternius.com/) (CC0). Drop into `assets/environments/`.
- **Audio**: [Kenney CC0 audio](https://kenney.nl/assets) until you commission custom.

When you build your own characters in Blender:
- Low-poly (5-15k tris).
- Quads only on deforming parts.
- Edge loops at elbows, knees, shoulders, jaw.
- Rig with Rigify, weight paint by hand at joints.
- NLA strips per animation (idle, walk, run, attack_01, attack_02, hit, die).
- Export `.glb` (preferred for Godot) with "Limit to selection" + armature.

## Attributes (10) and Leveling

User-allocated attributes via `PlayerAttributes`:
1. **Health** - +12 max HP, +0.2 HP regen per point
2. **Stamina** - +5 max stamina, +0.4 stamina regen per point
3. **Mana** - +10 max mana, +0.5 mana regen per point
4. **Strength** - +1.5% melee damage per point
5. **Accuracy** - +0.3% hit chance, +0.4% crit chance per point (95% hit cap)
6. **Spellpower** - +1.5% spell damage, -0.2% spell mana cost per point (-50% cap)
7. **Wisdom** - +0.5% XP gain, +0.5% drop chance per point
8. **Vitality** - +0.5 HP regen, +0.5% status duration reduction per point
9. **Endurance** - +0.4 stamina regen, +1 carry capacity per point
10. **Luck** - +0.3% rare drop chance, +0.5% crit multiplier per point

**Leveling:** alternating reward across 100 levels.
- Even levels (2, 4, ... 100): **+3 attribute points** (150 total)
- Odd levels (3, 5, ... 99): **+1 skill point** (49 total)

## Resources by Class

| Class | Primary Resource | Regen |
|-------|------------------|-------|
| Berserker | Rage (0-100) | 0/sec passive, builds from damage taken/dealt, decays OOC |
| Assassin | Stamina (100) | 4/sec |
| Ronin | Stamina (100) + stance charges | 4/sec stamina; stance from parry/kill |
| Ranger | Stamina (100) + focus stacks | 4/sec stamina; focus from consecutive hits |
| Mage | Mana (100) | **1/sec base**; surge potions = 10x for 10s |
| **Chaos Druid** | **Mana (100) + Stamina pool in form** | 1/sec mana; stamina drains while transformed; form abilities cost stamina |
| **Demon** | **Blood (0-100)** | **0/sec.** Fills only on kill (+5 mob, +25 boss). Each point = +1% ability damage. Abilities cost nothing. |
| Paladin Guardian | Mana (100) | 3.5/sec |
| Paladin Lightbringer | Mana (130) | 5/sec |

### Demon Day/Night System

```
DAY    (time_of_day 0.20-0.80)    Damage -20%, NO auto HP regen
NIGHT  (time_of_day 0.80-0.20)    Damage +20%, +4 HP/sec auto regen
```

**Always-on:**
- Lifesteal passive: 5% of all damage dealt heals
- Kill-heal: +5% max HP on each kill
- Blood gain: +5 per mob, +25 per boss

A Demon at full Blood at night with surge potion burns: 1.2x (night) × 2.0x (full Blood) × ... composes multiplicatively. Day Demon is intentionally weaker; the class plays around the cycle.

WorldClock autoload tracks `time_of_day: float` and `is_night() / is_day()`. Bond can hand-set time via `WorldClock.set_to_dusk()` etc for testing.

**Stamina vs Mana balance (Bond's rule):** stamina regenerates 4x faster than mana, but stamina abilities deal 1/4 the damage of equivalent mana abilities. The math is enforced in `damage_calc.gd` layer 7c. Net DPS over time roughly equal; pacing differs.

**Berserker rage scaling:** at 100 rage you swing for **+50% damage**, **+30% attack speed**, **+15% movement**, all linear with rage value. Read by combat layer via `Player.get_rage_buffs()`.

**Mage 1/sec mana regen:** Mages must use spells deliberately or carry mana potions. Mana Surge Draught accelerates regen to 10/sec for 10 seconds. Higher-tier spells cost up to 100 mana; the 49-spell tree spans cheap (5 mana Spark) to climactic (100 mana Word of Unmaking).

## Mage Spell Schools (49 spells)

Seven schools, seven spells each, mana cost 5-100, unlocked via Mage skill tree:

| School | Identity | Capstone (Tier 7) |
|--------|----------|-------------------|
| Fire | AOE, burn DoT, ignite chains | Rain of Cinders (60m sky-fire, 4 sec channel) |
| Frost | Control, slow, freeze, single-target burst | Heart of Winter (full-screen freeze 4 sec) |
| Lightning | Chain, fast cast, low CD | Adad's Hammer (12-strike chain in 0.5 sec) |
| Arcane | Raw damage, mana efficiency | Word of Unmaking (480 base damage, 2 sec cast) |
| Holy | +damage to demons/undead, smite, healing | Light of Marduk (12m radiant pillar, 4 sec) |
| Shadow | DoT, drain, mark, life-tap | Tiamat's Whisper (curse all, +50% taken dmg, bleed 30s) |
| Void | High dmg with HP self-cost, anti-armor | Word from the Apsu (600 dmg AOE, costs 30% HP) |

## Stealth (Assassin signature)

Toggle ability. While active:
- Mob detection radius reduced to **3m** (vs 9m default)
- Other players cannot target this player (PvP)
- First strike from stealth gets **+50% damage** AND **guaranteed crit**
- Breaks on dealing damage, taking damage, or duration expiry

Implementation: `StealthAbility` resource + `Player.enter_stealth()` / `Player.exit_stealth()` + `EnemyBase._acquire_target` reads `get_detection_radius_override()`.

## Class System

Classes are data, not subclasses. Defined in `scripts/classes/class_registry.gd` (autoload `ClassRegistry`).

Each class carries: base stats, per-level growth, primary attribute, **resource mechanic**, starting abilities, skill tree, optional shapeshift forms (Druid only), and optional unlock gating (Demon only).

### Class Prologues (level 1-5, all converge at Ashurim)

Every class has its own intro zone, mini-boss, and chapter title. The Storyteller in Ashurim recognizes you when you arrive. Full lore in [STORY.md](STORY.md).

| Class | Intro Zone | Mini-Boss | Chapter |
|-------|-----------|-----------|---------|
| Berserker | The Ash-Step Camp | Hassu the Hooked | The Last of Ash-Step |
| Assassin | The Whisper Shrine | Master Sapum, Five-Mouthed | The Master's Lie |
| Ronin | The Sword-Vow Ruins | Enforcer Kazat, Iron-Faced | Sword Without Lord |
| Ranger | The Greenheart Glade | The Glade Terror | The Spawn That Came Through |
| Mage | The Inkstone Tower | The Tower Warden | Pages and Ash |
| Chaos Druid | The Coven Glen | Sahirum the Witch-Burner | The Coven Burned |
| **Paladin Guardian** | The Sun-Sworn Chapel | Beleti the Siege-Master | The Chapel Stood |
| **Paladin Lightbringer** | The Sun-Sworn Chapel | Beleti the Siege-Master | The Chapel Wept |
| **Demon** (locked) | The Pyre-Ascent (Fire Stair) | The Self-That-Said-Yes | The Self That Said Yes |

The Demon intro is unique: it's only available to characters created **after** another character on the same save profile has defeated Lucifer. The Demon player wakes at the bottom of the Fire Stair, climbs back up, and confronts the version of themselves who would have accepted Lucifer's offer.

### Armor Types (4 tiers)

Cloth (cloth-only mages) < Leather (rogues, rangers, druids, ronin) < Mail (rangers, paladin healer) < Plate (berserkers, demon, paladin guardian).

Each class has `max_armor_type`. Equip is rejected if item.armor_type > class.max_armor_type. Cloaks/belts/accessories have armor_type = NONE.

### Canonical Roster (9 classes)

| Class | Primary | Resource | Identity |
|-------|---------|----------|----------|
| Berserker | Strength | Rage | Wounds fuel fury. At 100 rage: +50% dmg, +30% atk speed, +15% move. |
| Assassin | Dexterity | Stamina | Stealth signature. First strike from stealth: +50% dmg, auto-crit. |
| Ronin | Dexterity | Stamina + stance charges | 49 breathing forms across 7 styles. Hardest class to play. |
| Ranger | Dexterity | Stamina + focus stacks | Bow specialist. Focus stacks reward consecutive hits. |
| Mage | Intellect | Mana (1/sec) | 49 spells across 7 elemental schools. Slow regen, big hits. |
| Chaos Druid | Intellect | Form Energy | Shapeshifts. Capstone: Spawn of Tiamat dragon. |
| **Paladin Guardian** | Strength/Vitality | Mana | **TANK.** Plate, shield + hammer, protection auras, heavy mitigation. |
| **Paladin Lightbringer** | Intellect | Mana (130) | **HEALER.** Mail (no plate), shield + ceremonial mace, strong heals. |
| **Demon** | Hybrid | Corruption | **LOCKED.** Drains own HP for devastation. Unlocks after defeating Lucifer. |

### Lucifer Arc (post-Tiamat secret)

Tiamat is the climax of the visible game. After her, a hidden gate opens. The player descends through a fire-stair into Lucifer's domain. Defeating Lucifer sets the save flag `lucifer_defeated`, which unlocks the Demon class on the character creation screen for ALL future characters on that save profile.

The Demon class fights on *borrowed life*: most signature abilities cost HP (drained into corruption), corruption then fuels devastation finishers. Glass cannon with self-bleed economy.

## Skill Trees (49 nodes per class)

Every class has a 49-node tree, organized as **7 branches × 7 tiers**.

| Class | Branches |
|-------|----------|
| Berserker | War / Blood / Fury / Berserk / Sunder / Endurance / Roar |
| Assassin | Shadow / Venom / Crimson / Dagger / Agility / Lethality / Espionage |
| Ronin | Water / Flame / Mist / Thunder / Stone / Wind / Sun (Sun gated to all 6 others mastered) |
| Ranger | Marksman / Beast / Traps / Survival / Tracking / Ambush / Storm |
| Mage | Fire / Frost / Lightning / Arcane / Holy / Shadow / Void |
| Chaos Druid | Wild / Grove / Chaos / Thorn / Beast / Elemental / Tiamat |
| Demon | Legion / Hunger / Damnation / Abyss / Nightborn / Infernal / Wrath |
| Paladin Guardian | Aegis / Wrath / Ward / Vow / Tenacity / Vindication / Banner |
| Paladin Lightbringer | Mercy / Light / Salt / Devotion / Compassion / Wrath of Dawn / Grace |

### Multi-Rank Passives

Skill points come in two flavors:
- **Ability unlocks (1 SP each):** unlock a new active ability or toggle.
- **Passive ranks (1-5 SP, configurable per node):** each rank stacks the bonus. A "+5% damage per rank, max 5" node costs 5 SP fully maxed for +25% total. Capstones cost 5 SP each.

`SkillNode.max_ranks` declares how many ranks. `PlayerStats.node_ranks` tracks current investment. `SkillTree.unlock(id)` purchases one rank at a time.

### Single-Target vs AOE

Every class has both. Skill trees are designed so you can build a pure ST damage character or an AOE clear-character or hybrid. Examples:

| Class | Single Target | AOE |
|-------|--------------|-----|
| Berserker | Reckless Swing, World-Ender (charged) | Cleave, Earth-Shaker, Whirlwind |
| Assassin | Backstab, Throat Cut, Decapitate | Crimson Spray, Plague Cloud, Red Wedding |
| Ronin | Form 1 of any style, Thunderclap & Flash | Form 2/4 (cone/AOE), Constant Flow |
| Ranger | Aimed Shot, Piercing Shot | Multishot, Death From Above, Storm Quiver |
| Mage | Magic Missile, Smite, Word of Unmaking | Cinder Cloud, Blizzard, Adad's Hammer |
| Druid | Spark, Wild Bolt | Earthquake, Garden of the Dying |
| Demon | Hellfire Bolt, Curse of Pain | Sulfur Cloud, Plague Mark, Pyre |
| Paladin Guardian | Provoke, Hammer's Decree | Crashing Verdict, Sun-Standard, Marduk's Mantle |
| Paladin Lightbringer | Smite, Mending Light | Solar Pulse, Day-Bringer, Communion |

### Lock-on (Tab Cycle)

`LockOn` system already wired:
- **Tab:** acquire nearest enemy (or cycle to next while locked)
- **Shift+Tab:** cycle to previous target
- **Esc:** release lock
- **Middle-click:** toggle

Player rotation, abilities, and camera all respect the locked target when active.

## Mounts and Pets

**Mounts (ground-only, +100% movement, paid):** 10 SKUs from $4.99 to $29.99 founder edition. Free starter `Chestnut Horse` at level 5. All mounts mechanically identical (+100% speed); difference is aesthetic. Owned mounts persist forever, cross-prestige.

**Pets (cosmetic + 1 utility):** 11 SKUs. The **Bone-Mountains Pack-Yak** ($9.99) is the only utility pet: while summoned, every party member within 30m gains **+30 inventory slots**. Other pets are pure cosmetic flavor. Free starter `Alley Cat` at level 3.

Both in [`MountRegistry`](scripts/mounts/mount_registry.gd) and [`PetRegistry`](scripts/pets/pet_registry.gd). Ownership stored as permanent SaveFlag. Purchase via Stripe through Cloudflare Workers.

## Party + Social

**Party (max 4):** +10% XP boost at full 4 members. Loot modes: round-robin / free-for-all / leader-decides. LFG finder via /v1/party/lfg endpoints. Server-authoritative; clients mirror via WebSocket.

**Friends + Block lists:** persisted per-account on backend. Auto-unfriend on block.

## Worlds

**4 worlds at launch, max 12 concurrent players each.** Tight Mortal-Online / classic-Tibia density.

| Server | Region | PvP |
|--------|--------|-----|
| Iron Pillar (1) | NA | No |
| Lapis Bay (2) | EU | No |
| Bone Mountains (3) | Global | No |
| Mist Vale PvP (4) | Global | Yes |

Cross-world transfer 24h cooldown.

## Open World Respawn

`Spawner` nodes seed mobs with `respawn_seconds` timer (60s + 6s jitter default). Won't respawn if player within 8m. `DungeonInstance` resets on entry: spawners restart, boss respawns, completion flags clear. Multiple parties run separate instances simultaneously.

**Max 4 in a dungeon** (matches party cap).

## Achievement + Title System

**60+ achievements, 50+ titles.** Combat / Feats / Exploration / Professions / Story / Collection / Meta categories. Plus a humor track: "Has a Glade Problem" (die to the same beast 3x), "Apothecary's Best Friend" (50 potions in one dungeon), "Briefly Royal" (sit on Tiamat's skull-throne), "Single-Buyer Economy" (empty a vendor's stock).

**Cool feat titles:**
- *Mother-Slayer* (Tiamat down) | *Walker of the Stair* (Lucifer down)
- *the Untouched* (Tiamat no-hit) | *the Mother-Cracker* (Tiamat under 60s)
- *Crown of Salt and Fire* (final two bosses under 60s combined)
- *of the Seven Breaths* (49 breathing forms unlocked)
- *the Word-Keeper* (49 mage spells unlocked)
- *Marduk's Hands* (all 4 professions maxed)
- *the Sword-Chosen* (Heaven obtained)
- *Closer of Cycles* (prestige 10)

**Humor titles:**
- *Has a Glade Problem* | *the Pillar-Puncher* | *the Dragon-Paddler*
- *the 1-HP Hero* | *the Returned-Hand* | *Single-Buyer Economy*
- *Sun-Cooked* | *the Terrible Diplomat* | *Regular at the Goat*

`AchievementTracker` listens for boss kills, no-hit fights, kill counts, profession milestones, zone discoveries, prestige cycles, item obtains. Awards XP, gold, and titles. Persists via permanent SaveFlags.

## Mobs (60+ across 12 zones)

Each mob has lore. A patient player who reads every codex entry learns half the world's history through environmental storytelling. Per-zone roster in `MobRegistry`.

## Dungeons (14)

Discrete instanced runs inside zones. Each has its own boss, mob layout, and mini-story. From The Caravan Pit (lvl 6 tutorial) to The Fire Stair (lvl 92 mythic). Full list in `DungeonRegistry` and `STORY.md`.

## Landmarks (35+)

Points of Interest scattered through the world. Examining one fires lore-on-discover, awards XP, ticks Explorer achievements. From the Iron Pillar's edict to the Silent Gate's hairline crack to Tiamat's skull-throne.

## Quests (25+)

8 class prologues + 5 main story beats + 6 faction quests + 8 side quests. Each quest tracks objectives via QuestLog, awards XP/gold/items/skill-points, and can set permanent or run flags.

## Dialogue Trees

`DialogueRegistry` autoload holds branching trees for all major NPCs:
- **The Storyteller** (knows your face from cycles past, drops cycle hints)
- **Belitu** (Singing Goat innkeeper, hides her ledger problem)
- **The Sanctum-Mother** (knows there's a traitor druid, won't say which)
- **High Magus Iddinu** (gatekeeps the arcane council)
- **General Sin-Mushezib** (Crown contracts)
- **Black-Sail the First** (pirate king, three opening insults)
- **Sahirum the Witch-Burner** (Inquisition prime, knows your mother's name)
- **The Oracle Attendant** (always out of chalk)
- **Lucifer** (the offer, the catch, the refuse)

## Minimap

Top-right HUD component. 200px circular minimap showing player at center, mobs as red dots, NPCs green, landmarks blue diamonds (faded if undiscovered), bosses orange. Rotates with camera yaw. 60-metre scan radius.

## Locked Design Decisions (2026-05-05)

These were open after the major build. Now committed:

1. **Damage formula:** soulslike multiplicative. 8 layers (base × attribute × crit × defense × variance × pvp × heaven × status). Defense uses Diablo diminishing curve (`armor / (armor + 100)`). See [damage_calc.gd](scripts/combat/damage_calc.gd).
2. **Aesthetic:** pure cel-shade. Toon shader is the canonical material for player + environments + enemies. No pixelated overlay. Octopath-crunch could ship later as a settings toggle but is not the default.
3. **Sun Breathing prereq:** master ALL 6 base styles (Form 7 unlocked in each) + Tiamat defeated + level 18+. Sun Form 1 alone costs 5 skill points. The total Ronin commitment to reach Sun is 54 base style points + 5 + 18 to fully complete Sun = ~67 of 99 lifetime skill points.
4. **PvP damage track:** hook in place at `damage_calc.gd:PVP_HOOK_ENABLED = false`. Flip when PvP zones land in Phase 4. Default scaling is 0.5x in PvP.
5. **Heaven access:** Ronin only, Sun Breathing required to wield. Drop refuses to roll for non-Ronin killers. Wielding by an unworthy Ronin (no Sun Form 1) returns the sword to dormant katana mode.

### Ronin Breathing System

Ronin is the **highest skill ceiling, lowest skill floor** class. Trades safety (lowest melee HP, light armor, no passive resource regen) for the deepest mechanical toolkit: **7 breathing styles x 7 forms = 49 unique abilities**.

**Resource: Stance Charges (3 max).** Build from successful parries (+1) and kills (+1). No passive regen. Forms consume 1-3 charges. Run out, you fight bare.

**Chain bonuses.** Casting a form within ~2.5s of its `chain_predecessor` triggers a 1.4-1.8x damage multiplier. Mastery is learning the right sequences for each style.

**Cast times are real.** Capstone forms (Form 7) have 1-4 second windups and `miss_punishment_seconds` lockouts on whiff. Telegraph + commit + recover loop. Sekiro/Ghost-of-Tsushima-style read-and-react.

| Style | Element | Identity | Capstone (Form 7) |
|-------|---------|----------|-------------------|
| Water | Water | Flow, parry, sustain, mid-arc | Constant Flow (3s blade flurry, 120 dmg) |
| Flame | Fire | Aggression, burn DoT, momentum | Crimson Suffering Sun (cone, 12s scorch, 140 dmg) |
| Mist | Shadow | Illusion, single-target burst, teleport-strike | Obscuring Clouds (5s invis + 200% guaranteed crit) |
| Thunder | Lightning | One-form mastery, fastest single hits | Flaming Thunder God (hits 7 enemies in 0.4s, 220 dmg) |
| Stone | Physical | Heavy, slow, defensive, armor pen | Mountain Splitter (ignores 100% armor, 260 dmg) |
| Wind | Physical | Mobility, multi-hit, sweeping | Gale, Sudden Gusts (8m tornado, 12s sustain) |
| **Sun** (locked) | Holy | All elements, screen-wide ultimates | Beneficent Radiance (13-hit, 4s channel, 420 dmg) |

**Sun Breathing unlock conditions:**
1. `tiamat_defeated` save flag set.
2. Ronin must already have unlocked Form 7 of at least 2 other styles.
3. Player level >= 18.

The skill tree presents all 6 base styles from level 1; Sun reveals itself only after the gates clear.

### Chaos Druid Forms

| Form | Stat Profile | Vibe |
|------|-------------|------|
| Dire Wolf | Fast melee, +crit, light armor | Pack hunter, mobile |
| Iron Bear | Tank, +HP, +armor, slow | Soak hits |
| Storm Raven | Aerial, fragile, scout | Untouchable by ground enemies |
| Venom Serpent | Poison DoT, low cooldown | Damage-over-time specialist |
| **Spawn of Tiamat** (capstone) | +180% HP, +240% damage, 18-sec auto-revert, 100 energy cost | Skill-tree gated. Mini-Tiamat dragon, blue-fire breath. Final druid unlock. |

Forms swap mesh, stat multipliers, and ability bar. Lock human abilities by default. Revert via duration timeout, manual cancel, or form_energy depletion.

## Aesthetic

- Low-poly meshes, flat shading where possible.
- Toon shader at `shaders/toon.gdshader`. Apply via ShaderMaterial on character meshes for the cel-shaded look.
- Limited palette: warm Babylonian gold + lapis blue + obsidian black, with sickly green for Tiamat-tainted areas.
- Optional pixelation: viewport scale 0.5 with nearest filtering for an Octopath-style crunch.

## Networking Plan (Phase 4 only)

- Godot's high-level MultiplayerAPI. Authoritative host (peer 1).
- One Player scene per peer, MultiplayerSynchronizer on transform + stats.
- RPC for ability casts and damage calls; host validates damage and broadcasts results.
- ENet transport for desktop, WebSocket later if browser build is desired.
- Do **not** start networking until Phases 1-3 feel good single-player.

## World Map

20 zones across 14 regions. Diablo-4-style scaling: each zone has a min level (won't scale below) and recommended level. Class intros at level 1-5, convergence at Ashurim (lvl 5), full open world from Babilim (the Iron Crown).

Full lore in [STORY.md](STORY.md).

| Zone | Region | Lv Range | Notes |
|------|--------|---------|-------|
| Ash-Step Camp | Cradle | 1-5 | Berserker intro |
| Whisper Shrine | Cradle | 1-5 | Assassin intro |
| Sword-Vow Ruins | Cradle | 1-5 | Ronin intro |
| Greenheart Glade | Cradle | 1-5 | Ranger intro |
| Inkstone Tower | Cradle | 1-5 | Mage intro |
| Coven Glen | Cradle | 1-5 | Druid intro |
| Ashurim | Cradle | 5-8 | Convergence town |
| Babilim, the Iron Crown | Iron Crown | 1-100 | Main city, hub |
| Iron Crown Outskirts | Iron Crown | 6-12 | First open zone |
| The Reed Wastes | Reed Wastes | 10-20 | Demon incursions |
| Lapis Bay | Lapis Bay | 15-25 | Salt Sea, Water Dojo |
| Pirate Isles | Lapis Bay | 18-28 | Three pirate kings |
| The Bone Mountains | Bone Mts | 25-40 | Stone Dojo |
| Anshar's Foothold | Bone Mts | 25-40 | Stone Breathing temple |
| The Verdant Wound | Verdant Wound | 30-45 | Druid Sanctum |
| Mother-Tree Sanctum | Verdant Wound | 30-45 | Druid hold |
| The Ember Steppes | Ember Steppes | 35-50 | Flame Temple |
| Pillar of Nergal | Ember Steppes | 35-50 | Flame Breathing temple |
| The Mist Vale | Mist Vale | 40-55 | Mist Temple |
| The Shrieking Highlands | Shrieking | 50-65 | Thunder Dojo |
| The Sundered Coast | Sundered | 60-75 | Tiamat-spawn nesting |
| The Black Citadel | Black Citadel | 70-85 | Tiamat boss climb |
| The Sun Gate | Sun Gate | 80-90 | Post-Tiamat unlock |
| The Fire Stair | Fire Stair | 85-100 | Lucifer secret boss |
| The Ascension Plane | Ascension | 1-100 | Prestige-only hub |

## Prestige (Champion's Cycle)

Level cap is 100. **Prestige cap is 10.** Difficulty is one tier only; world gets harder per cycle, not by user choice. At max level you can ascend.

- **Keeps:** unspent skill points, unlocked skill nodes, permanent unlocks (Demon class, Sun Breathing, Heaven sword + its kill stack).
- **Resets:** level -> 1, XP -> 0, all run flags (Tiamat alive again, quests reset, NPCs forget).
- **Scales:** enemy HP/damage/XP-reward by `1 + prestige_level`. Loot drop chance and rolls increase too.
- **Badge:** Cycle 1-3 bronze, 4-6 silver, 7-9 gold, 10 black-with-sun. Shown next to player name in HUD, in character creation, multiplayer lobby, **and on every enemy nameplate so the world knows the badge of honor.**

After prestige, you keep your toolkit but face a much harder world. Cycle 1 = 2x. Cycle 10 = 11x and bragging rights.

## Bosses

**9 main bosses** at character levels 9, 19, 29, 39, 49, 59, 69, 79, 89. Each gates a region or storyline beat. Multi-phase HP gates, Elden-Ring-tuned cadence, no difficulty modifier other than prestige.

| # | Boss | Lv | Zone |
|---|------|----|----|
| 1 | Etemenanki the Pillar-Wraith | 9 | Iron Crown Outskirts |
| 2 | Mu-Ash, Throat of the Wastes | 19 | Reed Wastes |
| 3 | Black-Sail the First | 29 | Pirate Isles |
| 4 | Ushar of the Single Step | 39 | Bone Mountains |
| 5 | The Mother of Wrong Things | 49 | Verdant Wound |
| 6 | Nergal-Iddin, Sun-Eater | 59 | Ember Steppes |
| 7 | Lahmu, Whisperer in Cloud | 69 | Mist Vale |
| 8 | Adad-Mukin, Last of the Hammer | 79 | Shrieking Highlands |
| 9 | Kingu, the Tablet-Bearer | 89 | Sundered Coast |
| Final | **Tiamat, Mother of Wrong** | 99 | Black Citadel |
| Secret | **Lucifer, the Fall and the Light** | 100 | Fire Stair |

Plus **6 class-intro mini-bosses** (1 per class prologue) and **24+ zone mini-bosses** scattered through the regions. See `scripts/enemies/boss_registry.gd` for the full roster + lore lines.

## Item Catalog

134 hand-crafted items in `ItemRegistry` covering 13 equipment slots and 19 weapon types. Each weapon has element + element_damage_pct, attack_speed, weapon_range. Two-handed weapons lock the off-hand slot.

### Equipment Slots (13)

`WEAPON_MAIN`, `WEAPON_OFFHAND`, `HEAD`, `CHEST`, `LEGS`, `FEET`, `HANDS`, `BACK` (cloak), `BELT`, `RING_LEFT`, `RING_RIGHT`, `AMULET`, `CHARM`.

### Weapon Types (19)

**1H melee:** Sword, Axe, Bludgeon (mace), Dagger, Fist, Whip, Katana
**2H melee:** Greatsword, Greataxe, Great-Bludgeon (maul), Nodachi, Polearm, Scythe
**Casters:** Staff (2H), Wand (1H)
**Ranged:** Bow (2H), Crossbow (2H), Throwing Knives (1H stack), Shuriken (1H stack)

### Off-hand Types

Shield, Book, Tome (focus crystal), Parrying Dagger, Quiver, Totem (Druid), Focus.

### Class Weapon Proficiency

Each class has +20% damage and +10% attack speed on weapons they specialize with, neutral on tolerated weapons, -10% damage on off-class weapons. `ClassProficiencyRegistry` autoload holds the matrix.

| Class | Proficient | Off-Class |
|-------|-----------|-----------|
| Berserker | Axe, Greataxe, Bludgeon, Maul, Greatsword | Staff, Wand, Bow, Dagger, Crossbow |
| Assassin | Dagger, Throwing Knives, Shuriken | Greatsword, Greataxe, Maul, Staff |
| Ronin | Katana, Nodachi | Greataxe, Maul, Staff, Wand |
| Ranger | Bow, Crossbow, Throwing Knives | Staff, Wand, Greatsword, Greataxe, Maul |
| Mage | Staff, Wand | Sword, Axe, Greatsword, Bow, Crossbow, Katana, Nodachi |
| Chaos Druid | Staff, Polearm, Scythe | Greatsword, Greataxe |
| Demon | Katana, Greatsword, Scythe | (none, hybrid) |

### Notable Items by Tier

**Heaven (Heaven tier):** Pure white katana. Ronin only. Sun Breathing required to wield. 0.5% from final/secret bosses.

**Legendaries (Gold, 1 per class):** Hassu's Hooked Spear, Five-Mouthed Whisper, Vow's End, Glade-Mother's Bow, Asaridu's Final Page, Sanctum's Ash, Lucifer's Shed.

**Very Rare unique-drop examples:** Black-Sail Cutlass (from Pirate-King I), Etemenanki's Bone-Edge (from boss 1), Ennum's Lost Blade (from Citadel Tier 5, Ronin only), Throat-Eater greataxe (from boss 2), Pillar-Stone Diadem, Pillar-Threaded Robe, Sun-Drop amulet, Pillar Seal Ring, Kingu's Marker Ring.

**Class-restricted Very Rares:** Ronin's Breath-Master Katana, Mage's Asaridu's Left-Hand Book, Ranger's Glade Widow's Quiver, Druid's Dragon-Pup Totem, Assassin's Silent Step boots, Berserker's Hassu's Kin-Axe.

## Loot Rarity Tiers

| Color | Tier | Drops |
|-------|------|-------|
| Gray | Junk | Vendor trash, dismantle for materials |
| White | Basic | Usable, no affixes, low stats |
| Green | Common | 1 affix, low-mid stats |
| Blue | Rare | 2 affixes, mid stats |
| Purple | Very Rare | 3 affixes, high stats. **Bosses guarantee one.** |
| Gold | Legendary | 4 affixes, unique mechanic, class-bound. **One per class. 1% from any boss.** |
| White-glow | **Heaven** | The Heaven katana. Soulbound. Singular. Cannot drop again once obtained. |

## Class Legendaries (7 unique items)

Each class has one bound legendary. Boss kills roll 1% chance to drop the killer's class legendary. Final/Secret bosses additionally roll 1% any-class legendary (for trading) and 0.5% Heaven.

| Class | Legendary | Identity |
|-------|-----------|----------|
| Berserker | Hassu's Hooked Spear | Rage gain x2, +50% damage at low HP, killing blow refunds rage |
| Assassin | The Five-Mouthed Whisper | Crits inflict stacking poison, stealth-broken hits guaranteed crit, vanish-cloud per kill |
| Ronin | Vow's End | Chain bonus x2, perfect parry deals posture damage back, double stance charges |
| Ranger | Glade-Mother's Bow | Pierces all in line, focus stacks 3x faster, crit kills shatter into seekers |
| Mage | Asaridu's Final Page | Spells cost 30% less mana, crits hit twice, mana regen 2x while still |
| Chaos Druid | The Sanctum's Ash | Form duration +50%, dragon free without capstone, in-form regen at half rate |
| Demon | Lucifer's Shed | Corruption from damage dealt instead of self-bleed, HP costs halved, 15% damage reduction |

## Heaven (the soulbound katana)

```
Ronin only. Wielding requires Sun Breathing (Form 1 minimum, which requires
mastering Form 7 of all 6 base breathing styles + tiamat_defeated + lvl 18).
Soulbound. Cannot drop, trade, or auction. Returns to inventory if removed.
Heals self and all allies within 6m for 5 HP/sec at all times.
Instantly slays any demon or undead struck. Kills turn to ash, absorb into the blade.
Each absorbed kill increases all damage by 0.01% permanently.
The stack does not reset on prestige.
Drops once per save profile. From the Final Boss or Secret Boss (0.5% each, Ronin killer only).
```

The sword chooses the seven-breath master. It does not bond to anyone else. Drop chance
silently fails to roll for non-Ronin killers. A Ronin who has not yet mastered all six
base styles (and thus cannot access Sun Breathing) carries Heaven as a heavy katana
with no passives, no aura, no one-shot. The sword waits.

## Auction House

`AuctionHouse` autoload manages listings. Sellers list tradeable items with starting bid + optional buyout. Bidding rules: must beat current bid by 1g, auto-buyout if bid >= buyout. Listings expire after duration (default 24h). On expiration with bids, highest bid wins; without bids, returned to seller.

5% listing fee at creation. 10% sale tax on completion. Soulbound items (Heaven, quest items) cannot be listed.

Search filter: class, slot, rarity range, item-level range, max price, name substring. Sort by current bid, time left, item level, rarity.

Multiplayer: host owns the listing book; clients query and submit via RPC. Single-player: persisted to `user://auction_house.cfg`.

## Professions

Four parallel profession tracks, each level 1-100 independent of character level.

| Profession | Activity |
|-----------|----------|
| **Mining** | Harvest ore from rock nodes (copper, iron, lapis, obsidian, mithril, void-iron) |
| **Woodcutting** | Harvest wood from tree nodes (pine, ash, ironwood, blood-oak, sun-cedar) |
| **Smithing** | Forge weapons + armor from ingots. Recipes unlock per profession level. |
| **Crafting** | Combine materials into consumables, charms, accessories, dye, runes. |

Each gather node has a min profession level + harvest time + respawn cooldown + primary/secondary yield. Recipes have inputs + output + profession requirement + optional class restriction.

XP curve: `int(50 * pow(level, 1.7))` per level. ~half a million total XP from 1 -> 100 per profession.

## Combat Architecture

| System | What it does |
|--------|-------------|
| AbilityRunner | Cooldowns, cast windups, hitbox spawning. Routes all ability casts. |
| Hitbox / Hurtbox | Team-layered Area3D pair. Hitbox spawns on swing, scans Hurtboxes for damage. |
| Posture | Sekiro-style stagger track separate from HP. Filling = stance break + deathblow window. |
| StatusEffectsHolder | Burn, poison, slow, stun, bleed, regen, marks. Stack-aware DoT/HoT ticking. |
| LockOn | Tab/MMB to lock onto nearest enemy in cone. Cycle with directional input. |
| DodgeParry | Shift dodge with i-frames. RMB tap = parry window (180ms, no damage + posture push). RMB hold = block. |
| CombatFeedback | Floating damage numbers, hit-stop frames, camera shake on impact + crit + kill + parry + stance break. |
| DamageCalc | **Stub. Bond's design call.** Linear / Diablo-diminishing / soulslike-multiplicative. |

## Save System

- 6 save slots at `user://saves/slot_N.cfg`
- Per-character: class, name, stats, inventory, equipment, quests, position
- Global state in SaveFlags (permanent + run namespaces)
- Permanent flags survive prestige; run flags reset

## What is Missing on Purpose

- Actual 3D scenes for zones (placeholder.tscn for now)
- Animation clips on player AnimationPlayer (49 breathing form anims to author or alias)
- Bespoke ability hitbox geometry (AbilityRunner has the spawn hook, ability resources need shape data per target_mode)
- Skill tree visual UI scene file (script exists, .tscn for it not yet built)
- Vendor / shop UI (NPC system supports it, UI screen not authored)
- Quest log UI (data layer ready, panel not authored)
- Real lighting and weather scenes per region

See [ROADMAP.md](ROADMAP.md) for the build order.
