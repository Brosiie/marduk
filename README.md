# Marduk

Babylonian fantasy ARPG. Champion of Marduk versus Tiamat and her spawn.
Stylized low-poly + cel-shading. Diablo-style camera, soulslike combat depth,
D&D-style classes and abilities. Online dungeon co-op as Phase 4 stretch.

**Free and open source under [MIT license](LICENSE).** Donations welcome via Ko-fi
($1 prompt on first login each day, fully skippable). All code public on
[github.com/Brosiie/marduk](https://github.com/Brosiie/marduk).

**Design specs:**
- [ROADMAP.md](ROADMAP.md) — phase build order
- [STORY.md](STORY.md) — full lore
- [CHARACTER_DESIGN.md](CHARACTER_DESIGN.md) — races, classes, customization, Heaven Rule, living-character systems
- [EQUIPMENT_VISUAL.md](EQUIPMENT_VISUAL.md) — per-item mesh map across all 145+ authored items
- [DEMON_VISUAL_TRANSFORMATION.md](DEMON_VISUAL_TRANSFORMATION.md) — Demon class visual transformation + Sacrifice Ritual

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
- [x] **Phase 1** Ronin demo: Sword-Vow Ruins → Enforcer Kazat (mini-boss with 2 phases, sweep + lunge + fast-sweep) → Ashurim Storyteller. Water Forms 1-3 with chain bonuses (W1 → W2 = 1.35×, W2 → W3 = 1.60×, 1.8s window, 0.4s whiff lock on W3). HUD ability bar with Q/E/R/F slots and cooldowns. Damage floaters via CombatBus autoload. Death + respawn at lodestone. Loot pickup (V key) — Kazat drops bronze katana via ItemPickup.
- [ ] **Phase 2** All 6 starter intros + their mini-bosses. One signature ability per class. Skill tree visual UI (K). Save/load slot select. Pause menu.
- [ ] **Phase 3** Babilim hub. Faction reputation. Loot rarity affixes. 6-slot equipment fully wired. Per-class signature mesh authoring in Blender.
- [ ] **Phase 4** Authoritative networking. 2-4 player co-op dungeons. Lobby system. PvP zones (separate damage track).
- [ ] **Phase 5** Black Citadel + Tiamat (3-phase). Sun Gate unlock. Lucifer secret boss. Demon class unlock. Prestige loop.
- [ ] **Phase 6** Procedural dungeon stitcher. Daily/weekly events. Achievements. Leaderboards.

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
| **Demon** | Hybrid | **Blood (kill-fed)** | **LOCKED.** Lifesteal vampire. Heals from damage dealt + max-HP gain on each kill. Each Blood point = +1% ability damage. Day/night flips +/-20% damage. Unlocks after defeating Lucifer. |

### Lucifer Arc (post-Tiamat secret)

Tiamat is the climax of the visible game. After her, a hidden gate opens. The player descends through a fire-stair into Lucifer's domain. Defeating Lucifer sets the save flag `lucifer_defeated`, which unlocks the Demon class on the character creation screen for ALL future characters on that save profile.

### Demon mechanics (clarified)

Demons do NOT use a corruption resource. Their economy is built on three
always-on passives plus the kill-fed Blood pool (see "Resource Mechanics"
above for the full table):

- **Lifesteal passive:** every hit heals 5% of damage dealt back to the Demon.
- **Kill-heal:** every kill restores 5% of max HP.
- **Blood pool (0-100):** fills only on kills (+5 mob, +25 boss). Each Blood
  point grants +1% ability damage. Demon abilities themselves cost nothing,
  so the gameplay loop is: kill -> stack Blood -> bigger hits -> bigger
  lifesteal swings -> heal back to full -> repeat. Glass-cannon economy
  built around momentum, not self-bleed.
- **Day/Night cycle:** Day -20% damage with no auto-regen; Night +20% damage
  + 4 HP/sec regen. Demons play around the cycle.

(There is one item, `Lucifer's Shed`, that re-routes Blood gain through
damage taken and reduces ability HP costs by half. It is the *only* place
"corruption" is referenced in the systems and it is an opt-in equip-bonus,
not the core class economy.)

## Character Customization

Characters are built from **Class × Race × Gender × Appearance**. All combinations valid. Race nudges stats and silhouette but never dominates the build — class drives identity. Full design in [CHARACTER_DESIGN.md](CHARACTER_DESIGN.md).

### The Five Races

Marduk is Mesopotamian-mythic. Races are ethnographic types from the world's regions, not Tolkien fantasy peoples. All races can play all classes; affinity is a visual suggestion in the creator, not a gate.

| Race | Origin | Build | Stat Lean | Class Affinity |
|------|--------|-------|-----------|----------------|
| **Anunnaki-Blooded** | Babilim — Iron Crown court, Inkstone Sanctum | Tall, slender, fine-boned (1.05× height) | +Int, +Dex, -Str | Mage, Paladin Lightbringer, Assassin |
| **Ash-Born** | The ash-steppes east of Bone Mountains | Broad, dense, scar-prone (1.0×) | +Str(2), +Vit, -Int | Berserker, Paladin Guardian, Demon |
| **Reed-Walker** | Reed Wastes, Lapis Bay deltas | Lean, wiry, weathered (0.98×) | +Dex(2), +Vit, -Str | Ronin, Ranger, Assassin |
| **Mountain-Forged** | Bone Mountains forge-cities | Stocky, beard-heavy (0.85× — distinctly shorter) | +Vit(2), +Str, -Dex | Berserker, Paladin Guardian, Mage, Druid |
| **Wound-Marked** | Verdant Wound corruption-frontier | Hollow, long-limbed, vine-veined (1.02×) | +Int, +Dex, -Vit | Chaos Druid, Mage, Demon |

Each race ships with 5 skin tones, 6 hair colors (Wound-Marked includes moss-green and vine-purple), 5 eye colors, plus race-specific cultural cosmetics (war-paint, tattoos, jewelry, hair traditions).

### Gender System

Both **male** and **female** mesh variants per class. Gender does not affect stats. Some cosmetics are gender-locked (beards male-only, certain hairstyles). Pick freely.

### Appearance Presets

Diablo-tighter than ESO sliders, looser than Diablo 4. The full [CharacterAppearance Resource](scripts/player/character_appearance.gd) covers:

- 3 body types per gender (lean / athletic / stocky)
- 5 face presets per race+gender
- 8 hair styles
- 6 hair colors (race-gated palette)
- 5 eye colors (race-gated)
- 5 beard styles (male only)
- Scar overlays, war-paint overlays, cultural markings, jewelry sets
- 4 voice packs per gender (race-tinted accent)
- Class-specific toggles (Mage/Sun-Breather glow eyes, aura intensity)

Race definitions live in [resources/races/](resources/races/) — `anunnaki.tres`, `ash_born.tres`, `reed_walker.tres`, `mountain_forged.tres`, `wound_marked.tres`.

The [AppearanceRegistry autoload](scripts/player/appearance_registry.gd) loads all 5 races, applies skin/hair/eye tint at runtime, scales the player to the race's height baseline, spawns time-of-creation gifts (eclipse halos, founder marks), and applies apothecary saturation tints from heavy potion use.

### Time-of-Creation Gifts

Characters created during specific real-world dates earn permanent appearance gifts:

| Event | Window | Gift |
|-------|--------|------|
| Eclipse Day | Real-world solar eclipse | Permanent dim crescent halo |
| Blood Moon | Real-world lunar eclipse | Permanent red eye-glow option (no Demon needed) |
| Sun Festival | Real-world summer solstice | Permanent gold dawn-aura at sunrise |
| Dark Solstice | Real-world winter solstice | Permanent shadow-trail at sunset |
| Founding Day | May 8 (game launch anniversary) | Founder's mark sigil with creation year |

Characters become timestamps. Year-1 founders are visibly recognizable forever.

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
- **The Sanctum-Mother** (Druid leader at Verdant Wound, reads BOTH Tiamat and Wound tiers; quest-giver for stabilization)
- **Captain Vashtu** (Inquisition Captain, mirrors Sanctum-Mother with inverted political voice; burn-the-glade quest giver)
- **High Magus Iddinu** (gatekeeps the arcane council)
- **General Sin-Mushezib** (Crown contracts)
- **Black-Sail the First** (pirate king, three opening insults)
- **Sahirum the Witch-Burner** (Inquisition prime, knows your mother's name)
- **The Oracle Attendant** (always out of chalk)
- **The Seventh Master** (wordless, at Sun Gate, visibility-gated on pilgrimage flag)
- **Refugees** (reactive, day/night variants per fleeing faction, no quest, pure presence)
- **Lucifer** (the offer, the catch, the refuse)

All major NPCs route their opening line through [NPCLines.pick_contextual_greeting()](scripts/npcs/npc_lines.gd) so the world reacts to Tiamat, Wound, faction conflicts, glyph count, walked-back state, and class without each NPC re-implementing the priority logic.

## Minimap

Top-right HUD component. 200px circular minimap showing player at center, mobs as red dots, NPCs green, landmarks blue diamonds (faded if undiscovered), bosses orange. Rotates with camera yaw. 60-metre scan radius.

## Locked Design Decisions

Originally locked 2026-05-05 (combat, aesthetic, Heaven access). Extended 2026-05-08 with the character / customization / sacrifice systems.

### Combat & Aesthetic (2026-05-05)

1. **Damage formula:** soulslike multiplicative. 8 layers (base × attribute × crit × defense × variance × pvp × heaven × status). Defense uses Diablo diminishing curve (`armor / (armor + 100)`). See [damage_calc.gd](scripts/combat/damage_calc.gd).
2. **Aesthetic:** pure cel-shade. Toon shader is the canonical material for player + environments + enemies. No pixelated overlay. Octopath-crunch could ship later as a settings toggle but is not the default.
3. **Sun Breathing prereq:** master ALL 6 base styles (Form 7 unlocked in each) + Tiamat defeated + level 18+. Sun Form 1 alone costs 5 skill points. The total Ronin commitment to reach Sun is 54 base style points + 5 + 18 to fully complete Sun = ~67 of 99 lifetime skill points.
4. **PvP damage track:** hook in place at `damage_calc.gd:PVP_HOOK_ENABLED = false`. Flip when PvP zones land in Phase 4. Default scaling is 0.5x in PvP.

### Character System (2026-05-08)

5. **Race system:** 5 ethnographic races mapped to the world's regions (no Tolkien fantasy peoples). All races can play all classes. Stat lean is small (±1 to ±2). Class drives identity. See [CHARACTER_DESIGN.md § 2.5](CHARACTER_DESIGN.md).
6. **Gender per class:** male + female mesh variants for every class. No stat impact. Some cosmetics gender-locked (beards male-only, certain hairstyles).
7. **Customization depth:** preset-driven (5 face presets, 8 hair styles, 6 hair colors, 5 skin tones, 3 body types). Tighter than ESO sliders, looser than Diablo 4. Race gates the available palettes.
8. **Transmog:** unlocked at character level 10 via Ashurim "Wardrobe-Master" NPC. Pay coin to apply any unlocked item's appearance over an equipped item. Achievement-locked appearances layer on top.
9. **Sun Breathing inheritance:** Sun Breathing class **inherits** the originating Ronin's race, gender, face, hair. Gi swaps to white-and-gold; sun-disc mempo permanent. Optional re-creation at unlock.

### The Heaven Rule (2026-05-08)

10. **Heaven cannot bind to Demons.** A Demon attempting to equip Heaven is offered the **Sacrifice Ritual** — a one-way modal with full information disclosed upfront. Accept = walk back through Lucifer's gate, restore pre-Lucifer class, lose all Demon mechanics, gain Heaven if pre-Lucifer was Ronin. Refuse = keep Demon, Heaven sits inert. The gate does not open twice. See [DEMON_VISUAL_TRANSFORMATION.md § 18](DEMON_VISUAL_TRANSFORMATION.md).
11. **Heaven access (unchanged):** Ronin only, Sun Breathing required to wield. Drop refuses to roll for non-Ronin killers. Wielding by an unworthy Ronin (no Sun Form 1) returns the sword to dormant katana mode.

### Pending Bond Review

12. **Demon visual transformation system** — full spec in [DEMON_VISUAL_TRANSFORMATION.md](DEMON_VISUAL_TRANSFORMATION.md), implementation gated on Bond's checklist sign-off (8 cosmetic transformation layers + per-prior-class Demon variants + Ascendance progression + Mortal Echo + Pact Marks + Echo Abilities + Day of Reckoning + Crown of Names + Faction reactions to Demons).

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
| The Sun Gate | Sun Gate | 80-90 | Post-Tiamat unlock. Seventh Master meets you here, wordless. Scene authored: noon-pale, sourceless light, no shadows. |
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

## Living Character Systems

The character body is a logbook of what the player has done. Every system here turns playtime into visible character history. Designed in [CHARACTER_DESIGN.md § 8.5](CHARACTER_DESIGN.md).

### Combat Scars (shipping in Phase 1)

Every hit that takes ≥ 25% of max HP leaves a visible scar on the body. Element-respecting (fire = charred, frost = frostbitten, holy = gold-edged, shadow = ink-black). Up to 16 visible at once; oldest non-boss heal first. **Boss scars never fully heal** — they fade to silver lines but stay forever. A maxed character is visibly mapped with their kill list.

[scar_manager.gd](scripts/player/scar_manager.gd) attaches to the player and listens to `take_damage`. Cosmetic-only; toggle off via Settings > Display > "Show Combat Scars: Off."

### Tattoo Glyphs — the Codex of Marks

First-time boss kills earn a unique **Glyph** — a small geometric mark associated with that boss's identity. Glyphs can be **inscribed** as tattoos at the Inkstone Sanctum vendor for a tiny stat bonus (+0.5% damage vs that boss's faction) and a permanent visible mark.

- Costs gold + a token from that boss's drop table
- Tattoo location is player-choice (chest, back, arm, neck, leg, face)
- Glyph stack: a player can be covered in a sleeve of glyphs that tells their kill story
- Visible to other players in PvP / parties — hovering shows the glyph list

Veterans become walking museums. New players learn the bestiary by reading vets' bodies. [GlyphRegistry autoload](scripts/items/glyph_registry.gd) auto-listens to `CombatBus.kill_registered` for first-time boss kills.

### The Inkstone Sage

The personality NPC. The Sage chronicles the player's character in flowing prose generated each visit from current state. Class-aware opening, race flavor, scar count, glyph count, dominant potion type, time-of-creation gifts, Wound mutation stage, walked-back-from-Demon recognition.

> *"You came back. I've seen people make a lot of choices in this hall — that one I respect more than most. The sword has decided you. It doesn't decide many."*

Implementation: [inkstone_sage.gd](scripts/npcs/inkstone_sage.gd), all 9 classes have unique opening lines plus a Heaven-Rule walked-back override.

### Apothecary Saturation

Drinking potions over 1000 lifetime drinks per type permanently changes appearance. HP-stackers redden, mana-stackers tint blue, stamina-stackers turn windswept-green, Champion's-Draught drinkers gain gold streaks. Stacks: a player who drinks heavily of mana AND stamina shows blue-green hybrid features. Cosmetic-only; reads as identity at a glance.

### Race-Specific Earned Cosmetics

Each race has a cultural progression rewarded by race-themed engagement:

- **Anunnaki-Blooded:** *Royal Bearing* — silver thread accents, gold robe lining, noble-posture idle anim. Earned via Crown court quests.
- **Ash-Born:** *Ritual Scars* — visible scarification adds patterns per major boss kill.
- **Reed-Walker:** *Salt-Crust Accents* — sea-air weathered face, fish-scale beadwork. 50+ hours in coastal/marsh zones.
- **Mountain-Forged:** *Forge-Burn Brands* — geometric burn patterns. Craft 50+ items.
- **Wound-Marked:** *Wound Ascendance* — gradual mutation in 4 stages: longer fingers, deeper green tint, vine-veins, +5% nature damage. **Player-toggleable lock** so characters can stop at the stage they like.

### Tier 2 Roadmap (designed, awaiting implementation)

These systems are fully specced in [CHARACTER_DESIGN.md § 8.5](CHARACTER_DESIGN.md) and ready to ship after Phase 2:

- **Soul-Binding** — bind one weapon + one armor permanently; bound items fuse to the body, scale with player level, can never be lost
- **Shadow History** — every death is a Shadow Memory phantom replay at the death-marker, visible to other players
- **Time-of-Creation Gifts** — already wired in [AppearanceRegistry](scripts/player/appearance_registry.gd) (eclipse, blood moon, founding day)
- **Inkstone Sage prose-export** — transcribe the Sage's chronicle as a paper-doll journal screenshot

## World State Systems

The world reacts. Three autoload registries own the cosmic and political weather, dozens of independent subscribers (NPCs, spawners, music, HUD widgets, quest gates, vendors) read from them. State authority is concentrated; world reactions are decentralized. None of the subscribers know about each other.

### Tiamat's Awakening (cosmic dread meter)

[TiamatRegistry](scripts/world/tiamat_registry.gd) autoload. A 0..100 counter that climbs as the player rouses Tiamat through play, then drops as druid stabilization quests bleed it back down. Five tiers, each a behavioral breakpoint:

| Tier | Range | Effect |
|------|-------|--------|
| DORMANT | 0..14 | World quiet. No glyph. No dread layer. |
| STIRRING | 15..34 | Music dread floor lifts +0.05. NPCs whisper. HUD shows ⏣. |
| WAKING | 35..59 | Dread floor +0.15. Sanctum-Mother greeting changes. HUD shows 𒈗. |
| WAKING_2 | 60..84 | Dread floor +0.30. Lodestone use triggers vision overlay. HUD shows 𒀭. |
| AWAKE | 85..100 | Dread floor +0.50. End-game posture. HUD shows 𒋾. |

Per-source deltas (auditable, all in one file): main boss kills +5, tiamat-spawn mob kills +1, faction conflict tier-up +2, druid stabilization quest -3, Inquisition burn-the-glade quest +4, prologue arrival in Ashurim +8, Wound-glyph application +4.

### The Wound (mortal/ecological creep meter)

[WoundRegistry](scripts/world/wound_registry.gd) autoload. Separate from Tiamat. Tracks how far The Verdant Wound has spread.

| Tier | Range | Effect |
|------|-------|--------|
| CONTAINED | 0..14 | Verdant Wound is a wound, not a spread. |
| SEEPING | 15..34 | Sanctum-Mother urgency rises. |
| BLEEDING | 35..59 | Refugee dialog gets heavier near Wound borders. |
| UNCONTAINED | 60..84 | Druid faction starts losing standing in cities. |
| CONSUMING | 85..100 | End-game ecological collapse posture. |

Drivers: Druid stabilization quests -5, Inquisition burn-the-glade quest +4, Wound-mutation cosmetic stage gain +2.

### Faction Conflict State Machine

[FactionConflictRegistry](scripts/factions/faction_conflict_registry.gd) autoload. Three pair-state machines:

- `druid_vs_inquisition`
- `crown_vs_black_sail`
- `crown_vs_druid`

Each pair walks: **COLD -> TENSE -> SKIRMISH -> OPEN_WAR**, driven by score deltas from quest completions, mob kills, and rep changes. Pair states cool back down passively when the player stops feeding them.

Five independent downstream consumers, none aware of each other:
1. **NPC greetings** (Sanctum-Mother and Captain Vashtu speak the war they are losing).
2. **Conflict-aware spawners** at border zones (Reed Wastes, Bone Mountains, Ember Steppes, Sundered Coast) swap their mob pool: peacetime pool at COLD/TENSE, `pool_skirmish` at SKIRMISH, `pool_open_war` at OPEN_WAR.
3. **Refugee spawners** in safe cities (Ashurim, Babilim, Lapis Bay, The Cradle) spawn fleeing civilians when their watched pair hits SKIRMISH+, despawn them when it cools.
4. **Quest gates**: quests with `disabled_during_open_war_with` go cold when a pair is at war, re-open when it cools. Soft-gate, not permanent. Game rewards de-escalation.
5. **Music director**: a `_conflict_floor` (SKIRMISH 0.10, OPEN_WAR 0.25) raises the music intensity passively during war, on top of combat triggers.

### The Seventh Breath (hidden three-stage chain)

A wordless meta-arc gated entirely on player behavior, not menus. Three stages, all in [QuestRegistry](scripts/quests/quest_registry.gd):

1. **The Sixth Master finds you** (after mastering Form 7 of all six base breathing styles + Tiamat defeated). He does not give a quest, he points east.
2. **Pilgrimage to The Sun Gate.** Walk. No marker. No fast travel target. The lodestone at Sun-Gate Threshold sets `seventh_breath_pilgrimage_done`.
3. **The Seventh Master is at the gate, wordless.** [seventh_master_npc.gd](scripts/npcs/seventh_master_npc.gd) is visibility-gated on `seventh_breath_pilgrimage_done AND NOT seventh_breath_known`. The interaction sets `seventh_breath_known`, the Master vanishes from the world forever. The Seventh Breath is now a player ability.

The Sun Gate scene itself ([sun_gate.tscn](scenes/world/regions/sun_gate.tscn)) is noon-pale, sourceless light, no shadows. Players reading the scene should sense the world is thin here.

### NPC Contextual Greeting Priority Chain

[NPCLines.pick_contextual_greeting()](scripts/npcs/npc_lines.gd) is a static helper that takes eight inputs (npc_id, player class, walked-back flag, glyph count, Tiamat tier, Wound tier, faction-pair state, time of day) and walks a seven-layer priority chain. The first hit wins:

1. **Walked-back** (Heaven Rule, *"The gate does not open twice"* recognition)
2. **Glyph saturation** (10+ tattoo glyphs unlocks dense-codex lines)
3. **Faction conflict at SKIRMISH+** (NPC speaks the war they care about)
4. **Wound dread at BLEEDING+** (NPC speaks of the green creep)
5. **Tiamat dread at WAKING+** (NPC speaks of what stirs beneath)
6. **Class-specific** (e.g., Sanctum-Mother greets a Druid differently than a Ronin)
7. **Default** (no state hits, fall through to baseline greeting)

Each NPC writes ~20 lines, gets hundreds of contextual combinations. Adding a new state layer is one branch, not a combinatorial rewrite.

### New NPCs (shipped this arc)

- **The Sanctum-Mother** ([sanctum_mother_npc.gd](scripts/npcs/sanctum_mother_npc.gd)) at Verdant Wound. Reads both Tiamat AND Wound tiers. Quest-giver for the stabilization chain that lowers Wound creep.
- **Captain Vashtu** ([captain_vashtu_npc.gd](scripts/npcs/captain_vashtu_npc.gd)) at Inquisition outposts. Same priority chain, inverted political voice. Burn-the-glade quest giver (the one that raises both Tiamat AND Wound, the player choice that costs the world).
- **The Seventh Master** ([seventh_master_npc.gd](scripts/npcs/seventh_master_npc.gd)) at Sun Gate. Wordless. Visibility-gated.
- **Refugees** ([refugee_npc.gd](scripts/npcs/refugee_npc.gd)) reactive in cities. Per-faction day-line and night-line variants. The day-line is what they tell strangers. The night-line is what they say to the fire when they think no one is listening.

### NPCRoster (declarative central placement)

[NPCRoster](scripts/world/npc_roster.gd) autoload. Zone-keyed NPC registry. Instead of placing every NPC in their region .tscn, NPCs that are visibility-gated or that change based on world state are declared in one central registry and spawned per scene load. Keeps .tscn files clean and visibility logic readable in one file. Asymmetric pattern: most autoloads are pure state owners, this one side-effects the scene tree, works because the contract is narrow.

### Save Versioning

[SaveSystem](scripts/save/save_system.gd) now stamps every save with `meta.save_version` (currently 1). Loader walks a `_migrate_v1`...`_migrate_vN` chain to upgrade old saves on load. Saves without the version key are treated as v0 and run through the full chain. Old save files keep working when new flags are added.

### UITheme (central UI constants)

[UITheme](scripts/ui/ui_theme.gd) module owns palette, font sizes, layout spacing, button sizes, and helper builders (`panel_box`, `make_title`, `make_body`, `make_hint`, `make_header_row`). Every UI panel that touched layout was migrated to read from here. One value change re-themes every dialog.

### Vendor Faction Tier Pricing

Vendors now price by faction rep tier. Hated buys at +50% markup and won't sell rare stock. Neutral is base price. Friendly is -10%. Honored is -20% + access to a faction-only catalog. Reading the vendor's price line tells you where you stand without opening a menu.

### Quest Faction Gates

[Quest](scripts/quests/quest.gd) resources now carry two new fields:
- `min_faction_rep`: a faction key + threshold. Quest hidden until the player crosses it.
- `disabled_during_open_war_with`: a pair key. Quest temporarily cold while a conflict pair is at OPEN_WAR. Re-opens when the conflict cools.

### Other System Additions

- **Boss `faction_rep_on_kill`**: bosses can grant or remove faction rep on kill, threading faction politics into climactic moments.
- **Element-typed boss telegraphs**: each boss telegraph carries its element (fire / shadow / void / holy / arcane / nature) so the player can read the screen and dodge by color.
- **Class-tinted crits**: crit numbers tint by player class element (Ronin gold, Mage arcane-blue, Druid green, etc.) so the screen reads class identity in a fight.
- **Lodestone vision overlay**: at Tiamat tier WAKING_2+, touching a lodestone triggers a brief cosmic-dread overlay. The world is thin here too.
- **Boss nameplate cinematic**: first encounter with a named boss flashes their title across the screen with audio sting.
- **Boss victory trophy**: kill the last boss in a region, get a region-specific trophy item that hangs in your character profile.

### Tooling / Harness

[playtest_bot.gd](scripts/test/playtest_bot.gd) is a 50-scenario headless harness covering every system on this page end-to-end. Run with `--headless --script playtest_bot.gd`. Last green run: 50 PASS, 0 FAIL.

Em-dash sweep done in code and user-visible strings, replaced with comma/colon/period per Bond's preference. README still legacy-mixed (out of scope for this pass).

## The Heaven Rule

**Heaven does not bind to the fallen.** The Heaven katana is the antithesis of Demonhood — the sword refuses corrupted wielders. A Demon-class character attempting to equip Heaven is offered a one-way ritual: **Walk Back through Lucifer's gate and reclaim mortality.** Full design in [CHARACTER_DESIGN.md § 8.4](CHARACTER_DESIGN.md), technical spec in [DEMON_VISUAL_TRANSFORMATION.md § 18](DEMON_VISUAL_TRANSFORMATION.md).

### The Sacrifice Prompt

When a Demon attempts to equip Heaven, [Inventory.equip](scripts/items/inventory.gd) emits `sacrifice_required(item, class_def)`. The [SacrificePrompt UI](scripts/ui/dialogs/sacrifice_prompt.gd) catches it, pauses the game, and shows a modal disclosing the full cost:

> *The katana lies still in your demon-hand. It will not warm to you.*
>
> *You may walk back through Lucifer's gate. Once.*
>
> *The Demon you became will dissolve. The soul you walked into Lucifer with will return. You will be mortal again.*
>
> *Your race, your face, the marks you bear from the fight to here — these stay. The horns, the veins, the hunger — these go.*
>
> *The gate does not open twice. Once chosen, this cannot be undone.*

The prompt also discloses **Pre-Lucifer class** and the **binding outcome**: a Demon-Ronin sees `Heaven will bind: YES`; a Demon-Mage sees `Heaven will bind: NO — the sword remains Ronin-only`. Full information upfront. No surprise sacrifices.

### What Walking Back Does

If the player accepts, [SacrificeRitual.walk_back](scripts/player/sacrifice_ritual.gd) executes:

- Demon class **permanently locked** for this character (cannot become Demon again)
- Pre-Lucifer class **restored** (whichever soul walked Lucifer's gate)
- Pre-Lucifer skill tree progression **restored** from snapshot taken at Demon creation
- All Demon abilities and the 49-node Demon skill tree progression **stripped**
- Demon visual overlay **removed** (horns dissolve, veins fade, claws revert, eye glow off)
- Permanent **white HOLY-element scar** on the chest, never fades
- Demon-only items become **Inheritance Trinkets** (lore-only, stats zeroed)
- Title awarded: **"The Mortal Returned"** (display variant: *Twice-Walker*)
- Cinematic: warm dawn-flash + slow-motion + audio cue + toast: *"THE GATE DOES NOT OPEN TWICE"*
- If pre-Lucifer was Ronin: Heaven auto-equips

NPCs update their dialogue. The Storyteller and Inkstone Sage gain new opening lines for walked-back characters — their previous Demon greetings are replaced.

### Why This Rule

- **Lore-aligned:** Heaven is the divine antithesis of Demonhood. The sword choosing a corrupted wielder breaks the entire mythology.
- **Player agency with weight:** the choice is meaningful. The Demon is real (49-node tree, +200% damage at full Blood, lifesteal, day/night swing). Sacrificing it weighs decades of investment.
- **Inheritance pays off:** the prior-class choice at Demon creation now matters mechanically. A Demon-Ronin can pursue this arc; a Demon-Mage can walk back to mortality but Heaven still won't bind.
- **One-way doors are powerful storytelling:** *the gate does not open twice* is a phrase players will remember.

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

- Actual 3D scenes for the remaining open-world zones (Sword-Vow Ruins + Ashurim + The Cradle + Babilim + Lapis Bay + Verdant Wound + Sun Gate + four border zones shipped; the rest Phase 2-3)
- Per-class character creator UI scene (data layer ready: [CharacterAppearance](scripts/player/character_appearance.gd) + [AppearanceRegistry](scripts/player/appearance_registry.gd) + 5 race resources; UI scene authoring in Phase 2)
- Per-class male/female mesh variants (existing Mixamo meshes are gender-locked; alternate-gender meshes are Phase 2 art)
- Animation clips on player AnimationPlayer (49 breathing form anims to author or alias)
- Bespoke ability hitbox geometry (AbilityRunner has the spawn hook, ability resources need shape data per target_mode)
- Skill tree visual UI scene file (script exists, .tscn for it not yet built)
- Wardrobe-Master transmog vendor + Inkstone Sage tattoo vendor screens (base vendor UI shipped, these two specialized screens not yet authored)
- Real lighting and weather scenes per region (some shipped: Verdant Wound green palette, Sun Gate noon-pale; rest Phase 2)
- Per-item meshes, currently using kayKit fallbacks. [Blender procedural generator](blender/scripts/generate_placeholders.py) is ready to crank ~125 placeholders in one run; hand-modeled hero assets are Tier 2 work.
- Demon visual transformation system implementation (full spec in [DEMON_VISUAL_TRANSFORMATION.md](DEMON_VISUAL_TRANSFORMATION.md), gated on Bond's review)
- README em-dash legacy sweep (code + user-visible strings are em-dash free; doc-level cleanup deferred)

See [ROADMAP.md](ROADMAP.md) for the build order.
