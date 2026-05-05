# Marduk Animation Library

Mirror of `AnimationRegistry` (`scripts/anim/animation_registry.gd`).
Every `.fbx` here is a Mixamo "without skin" download retargeted against
`SkeletonProfileHumanoid`. At runtime, `AnimationLibraryLoader` reads the
slot tables in `AnimationRegistry` and merges the matching anims onto
each character's `AnimationPlayer` under namespace `marduk/<slot>`.

## Tree

```
shared/
  locomotion/   idle, walk, run, sprint, jump_*, dodge_*, turn, change_direction
  combat/       attack_basic, parry, block_idle, block_hit
  reactions/    hit_react_*, stagger, knockdown, get_up, death, death_*
  utility/      taunt_battlecry, crouch_to_stand, unarmed_idle, sit, sheathe, kneel
classes/<class_id>/   class signature moves
mobs/<mob_id>/        mob attack patterns
bosses/<boss_id>/     boss phase moves
npcs/<npc_id>/        NPC interaction loops
```

## Already on disk

### shared/locomotion/
- `idle.fbx` (Standing Idle)
- `run.fbx` (Standing Run Forward)
- `run_left.fbx` (Standing Run Left)
- `walk_back.fbx` (Standing Walk Back)
- `walk_left.fbx` (Standing Walk Left)
- `turn_right.fbx` (Standing Turn Right 90)
- `change_direction.fbx` (Change Direction)
- `run_to_turn.fbx` (Running To Turn)
- `dodge_back.fbx` (Standing Dodge Backward)
- `dodge_corkscrew.fbx` (Corkscrew Evade)

### shared/combat/
- `attack_basic.fbx` (Sword And Shield Attack)
- `block_idle.fbx` (Standing Block Idle)

### shared/reactions/
- `death.fbx` (Dying)
- `death_forward.fbx` (Standing Death Forward 01)
- `death_react_forward.fbx` (Standing React Death Forward)
- `death_react_right.fbx` (Standing React Death Right)
- `hit_react_left.fbx` (Standing React Small From Left)
- `hit_react_right.fbx` (Standing React Small From Right)

### shared/utility/
- `taunt_battlecry.fbx` (Standing Taunt Battlecry)
- `crouch_to_stand.fbx` (Crouch To Stand)
- `unarmed_idle.fbx` (Unarmed Idle)
- `unarmed_idle_looking.fbx` (Unarmed Idle Looking Ver. 2)

### classes/ronin/
- `katana_idle.fbx` (Great Sword Idle)
- `katana_blocking.fbx` (Great Sword Blocking)
- `katana_180.fbx` (Great Sword 180 Turn)
- `katana_impact.fbx` (Great Sword Impact)

### classes/mage/
- `cast_release.fbx` (Standing 1H Cast Spell 01)

### npcs/peasant_female/
- `idle.fbx` (Catwalk Idle Twist R)
- `walk.fbx` (Catwalk Walk Forward 02)
- `walk_turn.fbx` (Catwalk Walk Forward Arc 90R)

## Mixamo download checklist

All titles below are the **exact** titles you'll find on `mixamo.com`
under Animations tab. Search by the quoted name, click "Without Skin",
hit Download. Drop the .fbx into the indicated slot folder, then in
Godot open the file → Advanced Import Settings → Skeleton3D → Retarget
→ Bone Map → New BoneMap → Profile = SkeletonProfileHumanoid → Reimport.

### Tier 1 — shared locomotion gaps (fills any hole left in the shared set)

```
shared/locomotion/walk.fbx           → "Walking"
shared/locomotion/sprint.fbx         → "Sprint Forward Roll" or "Sprint"
shared/locomotion/jump_up.fbx        → "Jump"
shared/locomotion/jump_land.fbx      → "Falling To Landing"
shared/locomotion/dodge_forward.fbx  → "Standing Dodge Forward"
shared/locomotion/dodge_left.fbx     → "Standing Dodge Left"
shared/locomotion/dodge_right.fbx    → "Standing Dodge Right"
```

### Tier 2 — shared reactions/combat

```
shared/reactions/hit_react.fbx       → "Hit Reaction"
shared/reactions/stagger.fbx         → "Heavy Hit Reaction"
shared/reactions/knockdown.fbx       → "Falling Back"
shared/reactions/get_up.fbx          → "Standing Up"
shared/reactions/death_back.fbx      → "Falling Back Death"
shared/combat/parry.fbx              → "Standing Block"
shared/combat/block_hit.fbx          → "Sword And Shield Block Hit"
```

### Tier 3 — class signature moves

#### `classes/berserker/` (heavy melee, axe, great sword)

```
fury_swing.fbx           → "Great Sword Slash"
cleave_1.fbx             → "Sword Combo Attack 01"
cleave_2.fbx             → "Sword Combo Attack 02"
cleave_finisher.fbx      → "Great Sword Smash"
charge.fbx               → "Running Slide"
war_cry.fbx              → "Yelling"
leap_smash.fbx           → "Jumping Down"
axe_throw.fbx            → "Throw Object"
ground_pound.fbx         → "Stomping"
```

#### `classes/assassin/` (dual daggers, stealth)

```
dagger_1.fbx             → "Sword And Shield Slash"
dagger_2.fbx             → "Sword And Shield Slash 2"
dagger_3.fbx             → "Sword And Shield Power Attack"
stealth_in.fbx           → "Crouched Sneaking"
stealth_out.fbx          → "Standing Up"
backstab.fbx             → "Sword Stab"
throw_kunai.fbx          → "Throw Object"
blink_dash.fbx           → "Quick Roll"
```

#### `classes/ronin/` (katana, breathing forms — 7 of 49 ship in MVP)

Already have: katana_idle, katana_blocking, katana_180, katana_impact.

```
breath_water.fbx          → "Sword Slash"            (form 1)
breath_thunder.fbx        → "Air Slash" or "Quick Sword Slash" (form 2)
breath_flame.fbx          → "Sword Run Slash"        (form 3)
breath_wind.fbx           → "Spin Attack"            (form 4)
breath_stone.fbx          → "Heavy Sword Slash"      (form 5)
breath_moon.fbx           → "Sword Sweep"            (form 6)
breath_sun.fbx            → "Charging Sword Combo"   (form 7 — endgame)
sheathe.fbx               → "Sheathe Sword"
unsheathe.fbx             → "Unsheathe Sword"
iai_strike.fbx            → "Quick Sword Slash"
riposte.fbx               → "Sword Riposte"
```

#### `classes/ranger/` (bow, hawk companion, traps)

```
bow_idle.fbx              → "Standing Aim Idle"
bow_draw.fbx              → "Standing Aim Recoil"
bow_release.fbx           → "Standing Aim Walk Forward"
bow_snipe.fbx             → "Kneeling Aim"
hawk_command.fbx          → "Standing Whistle"
trap_set.fbx              → "Bending"
arrow_combo.fbx           → "Standing Aim Walk Backward"
```

#### `classes/mage/` (staff, spells)

Already have: cast_release.

```
cast_loop.fbx             → "Standing 2H Magic Attack 01"
fireball.fbx              → "Standing 1H Magic Attack 01"
frost_nova.fbx            → "Standing 1H Magic Attack 02"
lightning_bolt.fbx        → "Standing 1H Magic Attack 03"
teleport.fbx              → "Vanish" or "Standing Up"
meteor.fbx                → "Casting Spell Above"
staff_strike.fbx          → "Staff Smash"
channel_idle.fbx          → "Standing Idle Channel"
```

#### `classes/chaos_druid/` (shapeshifts, totems, vines)

```
shapeshift_in.fbx         → "Crouching"
shapeshift_out.fbx        → "Standing Up"
druid_idle.fbx            → "Standing With Staff"
totem_plant.fbx           → "Bending Down"
vine_lash.fbx             → "Whip Attack"
bear_swipe.fbx            → "Standing Punch"
wolf_pounce.fbx           → "Quadruped Pounce"
```

#### `classes/demon/` (claws, wings, hellfire — LOCKED until unlock)

```
demon_idle.fbx            → "Brutal Idle"
claw_rake.fbx             → "Zombie Punching"
wing_flap.fbx             → "Flying"
hellfire_burst.fbx        → "Roaring"
soul_drain.fbx            → "Vampire Drink"
wing_glide.fbx            → "Hovering"
fall_to_kneel.fbx         → "Falling To Kneeling"
```

#### `classes/paladin_guardian/` (heavy plate, sword and shield)

```
shield_block.fbx          → "Sword And Shield Block"
shield_bash.fbx           → "Sword And Shield Slash 2"
sword_smite.fbx           → "Charging Sword"
holy_pillar.fbx           → "Casting Spell Above"
judgment_strike.fbx       → "Sword And Shield Smash"
kneel_pray.fbx            → "Kneeling Idle"
```

#### `classes/paladin_lightbringer/` (mail, mace, healing)

```
blessing_cast.fbx         → "Praying"
sun_beam.fbx              → "Casting Spell Beam"
healing_aura.fbx          → "Standing Pray"
divine_shield.fbx         → "Standing Shield Up"
mace_swing.fbx            → "Standing 1H Bash"
hymn_idle.fbx             → "Standing Idle Sing"
```

### Tier 4 — mob signature moves

```
mobs/usurper_footman/spear_thrust.fbx   → "Sword And Shield Slash"
mobs/usurper_footman/shield_raise.fbx   → "Sword And Shield Block"
mobs/usurper_archer/bow_draw.fbx        → "Standing Aim Recoil"
mobs/usurper_archer/bow_release.fbx     → "Standing Aim Walk Forward"
mobs/raider_grunt/club_swing.fbx        → "Standing Punch"
mobs/raider_grunt/overhead_smash.fbx    → "Great Sword Smash"
mobs/raider_archer/bow_draw.fbx         → "Standing Aim Recoil"
mobs/raider_archer/bow_release.fbx      → "Standing Aim Walk Forward"
mobs/shrine_acolyte/dagger_jab.fbx      → "Sword Stab"
mobs/shrine_acolyte/chant.fbx           → "Praying"
mobs/binding_construct/bone_swing.fbx   → "Zombie Punching"
mobs/binding_construct/reanimate.fbx    → "Standing Up"
mobs/blood_hunter/claw.fbx              → "Standing Punch"
mobs/blood_hunter/feed.fbx              → "Vampire Drink"
```

### Tier 5 — boss phase moves

```
bosses/usurper_enforcer/halberd_combo.fbx   → "Great Sword Combo"
bosses/usurper_enforcer/iron_charge.fbx     → "Running Slide"
bosses/usurper_enforcer/iron_quake.fbx      → "Stomping"
bosses/usurper_enforcer/intro_roar.fbx      → "Roaring"
```

### Tier 6 — NPC interaction loops

```
npcs/peasant_male/talk.fbx              → "Talking"
npcs/peasant_male/sit_chair.fbx         → "Sitting Idle"
npcs/peasant_male/sweep.fbx             → "Sweeping Floor"
npcs/peasant_female/talk.fbx            → "Talking"
npcs/peasant_female/carry_basket.fbx    → "Walking With Bag"
npcs/ranger_npc/talk.fbx                → "Talking"
npcs/ranger_npc/point_directions.fbx    → "Pointing"
```

## Workflow per anim file

1. Drop `.fbx` into the right slot folder
2. Open Godot. The editor auto-imports as PackedScene.
3. Open the file → Advanced Import Settings
4. Skeleton3D → Retarget → Bone Map → New BoneMap
5. Profile → SkeletonProfileHumanoid
6. Reimport
7. Hit Play. `AnimationLibraryLoader` picks it up next time the matching
   character spawns. The animation is then named `marduk/<slot>` on the
   `AnimationPlayer` and `ANIM_ALIASES` in `player.gd` already resolves
   to it.

## "Without Skin" vs "With Skin"

Always pick **Without Skin** on Mixamo. With-skin downloads bundle a
duplicate copy of the character mesh, bloat repo size, and force Godot
to instantiate a discardable mesh just to read the animation.
