# Making Marduk Come Alive
## A creative-design taxonomy of what's missing and what to build next

After 47 commits the game has SYSTEMS but not yet SOUL. Frameworks
don't make players cry or scream; moments do. This document maps the
gap between "engine running" and "world breathing", and lays out the
specific features that close it.

## The four pillars of "alive"

Drawing from what Souls / Witcher 3 / Diablo / Elden Ring / WoW do
that makes their worlds feel real:

### 1. THE WORLD REACTS TO YOU SPECIFICALLY

NPCs remember choices. Quests acknowledge previous quests. Lore
references your past. Items earned tell a story. Marduk has none of
this yet — every NPC says the same line regardless of what you've
done. Fix:

- **NPC dialogue branches by SaveFlags**: Storyteller's greeting
  changes after you kill Kazat, after you save Belitu's brother,
  after you defeat Tiamat. Each milestone permanently alters her
  opening line.
- **Item naming carries history**: a sword that killed Kazat is
  later inscribed "Iron-Stained" in the inventory. Heaven's permanent
  damage stack already does this; extend it to other notable kills.
- **Companion-character memorial**: Saru dies in the Black Citadel
  scripted scene. After that, every visit to Mist Vale shows a
  cairn with her name. NPCs in Ashurim mention her in passing.

### 2. THE WORLD IS INHABITED REGARDLESS OF YOU

Worlds feel dead when nothing happens unless you're the cause. Add:

- **Wildlife**: birds flying overhead in forest regions, deer
  visible in Greenheart Glade, rats running across dungeon floors,
  fish jumping in Lapis Bay. Pure decoration; no gameplay.
- **NPCs walking between waypoints**: Ashurim plaza has 5 NPCs
  but they stand still. Make them path-walk: peasant goes from
  market stall → fountain → home → repeat. Adds 5x the perceived
  population.
- **Smoke + lights at night**: chimneys puff procedural smoke
  particles in towns. Windows light up at dusk. Torches flicker.
  Day/night cycle drives the visual change.
- **Weather**: rain in Verdant Wound, snow drift in Bone Mountains,
  fog thickening in Mist Vale. Per-region weather state via
  SkyDirector + ParticleEffect.
- **Wagons on roads**: a procedural wagon NPC that travels between
  Ashurim and Babilim every in-game day, visible if you're on the
  route at the right time.

### 3. INTERACTIONS HAVE WEIGHT

Combat with no juice feels like clicking spreadsheets. Pickups with
no flair feel like inventory management. Critical fixes:

- **Hit-stop on every damage event**: 60-80ms world freeze on a
  successful hit. Engine.time_scale = 0.05 then back to 1.0 over
  40ms. Costs 5 lines, transforms every swing.
- **Camera shake** proportional to damage dealt. CameraRig has the
  hook; just needs an actual shake() implementation that adds noise
  to the camera's local position for a duration.
- **Slow-mo on critical kills**: 0.4s of time_scale = 0.35 on the
  killing blow that ends a mob's life if the hit was a crit.
  Feels like the killing blow MATTERED.
- **Hit particles**: spark/blood puff at the hit point. Cheap
  GPUParticles3D one-shot.
- **Pickup fanfare**: rare+ item drops play a chime, slow-mo for
  100ms, screen-flash white briefly.
- **Boss intro cutscenes**: name fade across screen ("ENFORCER
  KAZAT, IRON-FACED"), camera pan around boss, music swell, arena
  gates close visibly with a thud.
- **Death screen**: slow-mo to 0.1x, red overdraw fade, "YOU DIED"
  large serif text, sad music sting, fade-to-black, fade-back at
  lodestone with bird-eye shot of the player capsule for 0.5s
  before control returns.

### 4. PROGRESSION TELLS A STORY

Loot is just numbers unless it has narrative weight. Achievements
are just checkboxes unless they unlock something visible. Fixes:

- **Itemization affixes**: 30 prefixes ("Cruel", "Bloodied",
  "Heaven-Touched") + 30 suffixes ("of the Bear", "of Three Vows",
  "of the Sword-Vow"). Each rolled on a drop modifies stats AND
  changes the displayed name. "Iron Sword" becomes "Cruel Iron
  Sword of the Bear", carrying a flavor sentence in its tooltip.
- **Set bonuses**: 5-piece sets (Ash-Step Raider's Garb, Sun-Sworn
  Vestments, Inkstone Initiate's Robes). 2/5 = +20 hp; 3/5 = +5%
  crit; 5/5 = unique proc.
- **Heaven sword tally is visible**: when wearing it, the HUD shows
  "Demon kills: 247". Crossing 1000 triggers the whisper line.
- **Title system**: defeating Kazat unlocks "Iron-Faced Reckoner"
  as a title the player can display under their name.
- **Achievement toast popup**: animated banner slides across the
  top with the achievement name + icon + 3-second hold.

## The seven iconic moments to engineer

Every great ARPG has 5-10 moments players never forget. Marduk's
should be:

1. **First lodestone attunement** (currently flat)
   - Crystal flashes gold, brief slow-mo (0.3s @ 0.6x), music
     swells with a low brass note, codex banner slides in
     ("REGION DISCOVERED: The Cradle"), camera pulls back briefly
     to show the world map perspective.
   - Implementation: Lodestone.gd._attune already has the logic;
     just needs the cinematic layer.

2. **First boss intro** (currently: walk in, fight starts)
   - Approach the throne. Boss arena trigger fires. Camera
     auto-rotates to face Kazat. Arena gates SLAM closed with a
     thud + camera shake. Boss name "ENFORCER KAZAT, IRON-FACED"
     fades in across the screen in serif type. Music swell.
     1.5s grace before combat begins.
   - Implementation: BossArena.gd already has the engagement
     trigger; needs the camera lock + name fade + delayed
     combat enable.

3. **First crit-kill on a boss** (currently: number pops, mob
   disappears)
   - Slow-mo to 0.35x, camera zooms tight on the boss, last hit
     plays in dramatic time, blood/dust burst, then music shifts
     and the boss falls in slow-mo for 1 full second before
     time resumes.
   - Implementation: extend crit detection in damage_calc.gd to
     trigger a `signal cinematic_crit_kill(target)` when the hit
     is fatal AND a crit. Camera + time wrapper listens.

4. **First death** (currently: instant respawn)
   - Time slows to 0.1x as HP hits zero. Red color-grade overdraw
     pulses. "YOU DIED" big serif fades in over 1.5s. Sad music
     sting. Black screen for 1s. Fade back in at lodestone, brief
     0.5s bird-eye shot before control returns.
   - Implementation: Player._die already triggers respawn; needs
     the fade chain in front of it.

5. **Heaven sword first pickup** (currently: just an item drop)
   - Bright gold pillar of light shoots from the pickup location.
     Music explodes into the Heaven theme. Player auto-rotates to
     face the sword. 2-second pickup animation (lifted overhead).
     "HEAVEN, THE SUN-FORGED" displays as a banner.
   - Implementation: special-case in collect_item() when item.id
     == &"i_heaven".

6. **Saru's sacrifice** (currently: not implemented)
   - During the Black Citadel boss fight at <30% boss HP, a
     scripted attack swings at Player. Saru jumps in the way at
     the last frame. Time slows to 0.1x. Her body falls. Quiet.
     Music drops to a single ambient layer. She speaks 3 lines.
     Memorial cairn pop in Mist Vale at her location.
   - Implementation: BossBase.gd phase trigger fires Saru's
     scripted death sequence.

7. **Killing Tiamat** (currently: not implemented)
   - Multi-phase fight. On final HP zero: world goes white, brief
     2s pause, vision returns to a cracked seal mending itself,
     followed by a cinematic flash of Lucifer at the bottom of
     the Fire Stair laughing. Tease + reward.
   - Implementation: scripted boss_defeated handler on tiamat
     boss_id triggers a cinematic scene swap.

## What to ship NEXT (priority-ordered)

### Tier 1 — combat juice + iconic moments (this iteration's batch)

- [x] Hit-stop on every damage event
- [x] Camera shake on damage (proportional to dmg %)
- [x] Slow-mo on critical-fatal-blows
- [x] Boss intro cutscene (name fade + arena lockdown thud)
- [x] Death screen (slow-mo + red fade + YOU DIED + lodestone respawn)
- [x] Achievement / lodestone discovery toasts

### Tier 2 — ambient world life

- [ ] Birds flying in forest regions (sprite-3D billboards)
- [ ] NPC walking schedules in Ashurim
- [ ] Smoke from chimneys (GPUParticles3D)
- [ ] Per-region weather (rain, snow, fog)
- [ ] Day/night brings different mob types
- [ ] Wildlife (deer, wolves, rabbits)

### Tier 3 — narrative depth

- [ ] Itemization affixes (30 prefixes, 30 suffixes)
- [ ] Set bonuses (3 starter 5-piece sets)
- [ ] Heaven sword kill counter visible on HUD
- [ ] Title system (unlock + display under name)
- [ ] Saru's sacrifice cutscene
- [ ] Storyteller dialogue branches by SaveFlags milestones

### Tier 4 — endgame replay

- [ ] NG+ cycle reset with carry-over gear/skills/Codex
- [ ] Prestige UI badge + difficulty scaling
- [ ] Daily bounty board in Ashurim
- [ ] Roguelike challenge dungeon
- [ ] PvP arena scaffold

## Why this order

Tier 1 transforms how 30 seconds of play feels. That's the highest
impact-per-line work available. Once combat has weight, every
existing system (lodestones, items, bosses, quests) instantly feels
better without changing them. Tier 2 closes "feels real" gap. Tier
3 closes "feels meaningful" gap. Tier 4 keeps players coming back.

Each tier should ship in 3-4 small commits rather than one huge one.
Easier to verify, easier to roll back, more visible progress.
