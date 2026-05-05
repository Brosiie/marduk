# Marduk Animation Library

This tree mirrors `AnimationRegistry` (`scripts/anim/animation_registry.gd`).
Every `.fbx` here is a Mixamo "without skin" download retargeted against
`SkeletonProfileHumanoid`. At runtime, `AnimationLibraryLoader` reads the
slot tables in `AnimationRegistry` and merges the matching anims onto
each character's `AnimationPlayer` under the namespace `marduk/<slot>`.

## Tree

```
shared/
  locomotion/   idle, walk, run, sprint, jump_up, jump_land, dodge_*
  combat/       attack_basic, parry, block_idle, block_hit
  reactions/    hit_react, stagger, knockdown, get_up, death, death_back
  utility/      taunt_battlecry (have), crouch_to_stand (have), sit, sheathe, kneel
classes/<class_id>/   class signature moves
mobs/<mob_id>/        mob attack patterns
bosses/<boss_id>/     boss phase moves
npcs/<npc_id>/        NPC interaction loops
```

## What's already in the repo

| File | Slot | Notes |
|------|------|-------|
| `shared/locomotion/dodge_back.fbx`     | `dodge_back`   | Bond download (Standing Dodge Backward) |
| `shared/reactions/death.fbx`           | `death`        | Bond download (Dying) |
| `shared/utility/taunt_battlecry.fbx`   | `taunt`        | Bond download (Standing Taunt Battlecry) |
| `shared/utility/crouch_to_stand.fbx`   | `stand_up`     | Bond download (Crouch To Stand) |

## Priority download list

Mixamo's free tier lets us pull all of these "without skin" so they
share one humanoid skeleton. Drop each into the indicated slot and
they auto-bind on the next character spawn.

### Tier 1 — locomotion (without these the world feels dead)

```
shared/locomotion/idle.fbx          Mixamo: "Standing Idle"
shared/locomotion/walk.fbx          Mixamo: "Walking"
shared/locomotion/run.fbx           Mixamo: "Running"
shared/locomotion/sprint.fbx        Mixamo: "Sprint"
shared/locomotion/jump_up.fbx       Mixamo: "Jump"
shared/locomotion/jump_land.fbx     Mixamo: "Falling To Landing"
shared/locomotion/dodge_forward.fbx Mixamo: "Standing Dodge Forward"
shared/locomotion/dodge_left.fbx    Mixamo: "Standing Dodge Left"
shared/locomotion/dodge_right.fbx   Mixamo: "Standing Dodge Right"
```

### Tier 2 — combat reactions (combat feels real)

```
shared/combat/attack_basic.fbx      Mixamo: "Sword And Shield Slash"
shared/combat/parry.fbx             Mixamo: "Standing Block"
shared/combat/block_idle.fbx        Mixamo: "Sword And Shield Idle Block"
shared/combat/block_hit.fbx         Mixamo: "Sword And Shield Block Hit"
shared/reactions/hit_react.fbx      Mixamo: "Hit Reaction"
shared/reactions/stagger.fbx        Mixamo: "Heavy Hit Reaction"
shared/reactions/knockdown.fbx      Mixamo: "Falling Back Death" (variant)
shared/reactions/get_up.fbx         Mixamo: "Standing Up"
shared/reactions/death_back.fbx     Mixamo: "Falling Back Death"
```

### Tier 3 — class signature moves (download per class as you build out)

#### `classes/berserker/`
```
fury_swing.fbx           Mixamo: "Mma Kick" or "Great Sword Slash"
cleave_1.fbx / 2 / finisher.fbx   Mixamo: 3-hit "Sword Combo"
charge.fbx               Mixamo: "Running Slide"
war_cry.fbx              Mixamo: "Yelling"
leap_smash.fbx           Mixamo: "Jump Attack"
axe_throw.fbx            Mixamo: "Throw Object"
ground_pound.fbx         Mixamo: "Stomping"
```

#### `classes/assassin/`
```
dagger_1/2/3.fbx         Mixamo: "Sword And Shield Slash" series
stealth_in.fbx           Mixamo: "Crouched Sneaking"
stealth_out.fbx          Mixamo: "Standing"
backstab.fbx             Mixamo: "Sword Stab"
throw_kunai.fbx          Mixamo: "Throw Object"
blink_dash.fbx           Mixamo: "Quick Roll"
```

#### `classes/ronin/`  (49 forms unlock progressively, ship 7)
```
breath_water.fbx          Mixamo: "Sword Slash 1"  (form 1)
breath_thunder.fbx        Mixamo: "Air Slash"      (form 2)
breath_flame.fbx          Mixamo: "Sword Run Slash" (form 3)
breath_wind.fbx           Mixamo: "Spin Attack"    (form 4)
breath_stone.fbx          Mixamo: "Heavy Slash"    (form 5)
breath_moon.fbx           Mixamo: "Sword Sweep"    (form 6)
breath_sun.fbx            Mixamo: "Charging Sword Combo" (form 7 — endgame)
katana_idle.fbx           Mixamo: "Sword And Shield Idle"
sheathe.fbx               Mixamo: "Sheathe Sword"
unsheathe.fbx             Mixamo: "Unsheathe Sword"
iai_strike.fbx            Mixamo: "Quick Sword Slash"
parry.fbx                 Mixamo: "Sword Parry"
riposte.fbx               Mixamo: "Sword Riposte"
```

#### `classes/ranger/`
```
bow_idle.fbx              Mixamo: "Standing Aim Idle"
bow_draw.fbx              Mixamo: "Standing Aim Recoil"
bow_release.fbx           Mixamo: "Standing Aim Walk Forward"
bow_snipe.fbx             Mixamo: "Kneeling Aim"
hawk_command.fbx          Mixamo: "Standing Whistle"
trap_set.fbx              Mixamo: "Bending"
```

#### `classes/mage/`
```
cast_loop.fbx             Mixamo: "Standing 2H Magic Attack 01"
cast_release.fbx          Mixamo: "Standing 2H Cast Spell 01"
fireball.fbx              Mixamo: "Standing 1H Magic Attack 01"
frost_nova.fbx            Mixamo: "Standing 1H Magic Attack 02"
lightning_bolt.fbx        Mixamo: "Standing 1H Magic Attack 03"
teleport.fbx              Mixamo: "Vanish"
meteor.fbx                Mixamo: "Casting Spell Above"
staff_strike.fbx          Mixamo: "Staff Smash"
channel_idle.fbx          Mixamo: "Idle Channel Spell"
```

#### `classes/chaos_druid/`
```
shapeshift_in.fbx         Mixamo: "Crouching"
shapeshift_out.fbx        Mixamo: "Standing"
druid_idle.fbx            Mixamo: "Standing With Staff"
totem_plant.fbx           Mixamo: "Bending Down"
vine_lash.fbx             Mixamo: "Whip Attack"
bear_swipe.fbx            Mixamo: "Standing Punch"
wolf_pounce.fbx           Mixamo: "Quadruped Pounce"
```

#### `classes/demon/`
```
demon_idle.fbx            Mixamo: "Brutal Idle"
claw_rake.fbx             Mixamo: "Zombie Punching"
wing_flap.fbx             Mixamo: "Flying"
hellfire_burst.fbx        Mixamo: "Roaring"
soul_drain.fbx            Mixamo: "Vampire Drink"
wing_glide.fbx            Mixamo: "Hovering"
```

#### `classes/paladin_guardian/`
```
shield_block.fbx          Mixamo: "Sword And Shield Block"
shield_bash.fbx           Mixamo: "Sword And Shield Slash 2"
sword_smite.fbx           Mixamo: "Charging Sword"
holy_pillar.fbx           Mixamo: "Casting Spell Above"
judgment_strike.fbx       Mixamo: "Sword And Shield Smash"
kneel_pray.fbx            Mixamo: "Kneeling Idle"
```

#### `classes/paladin_lightbringer/`
```
blessing_cast.fbx         Mixamo: "Praying"
sun_beam.fbx              Mixamo: "Casting Spell Beam"
healing_aura.fbx          Mixamo: "Standing Pray"
divine_shield.fbx         Mixamo: "Standing Shield Up"
mace_swing.fbx            Mixamo: "Standing 1H Bash"
hymn_idle.fbx             Mixamo: "Standing Idle Sing"
```

### Tier 4 — mob/boss/NPC anims

Mobs share most locomotion + reactions. Each mob just needs:

```
mobs/<mob_id>/attack_basic.fbx   (and one signature, e.g. shield_raise)
```

Boss `usurper_enforcer` slots:

```
bosses/usurper_enforcer/halberd_combo.fbx
bosses/usurper_enforcer/iron_charge.fbx
bosses/usurper_enforcer/iron_quake.fbx
bosses/usurper_enforcer/intro_roar.fbx
```

## Workflow per anim file

1. Drop `.fbx` into the right slot folder
2. Open Godot → editor reimports automatically as PackedScene
3. Open the file → Advanced Import Settings
4. Skeleton3D → Retarget → Bone Map → New BoneMap
5. Profile → SkeletonProfileHumanoid
6. Reimport
7. Hit Play. `AnimationLibraryLoader` will pick it up the next time a
   character with that slot in its registry spawns.

The animation player will then have animations named `marduk/<slot>`
which the gameplay code (`player.gd` ANIM_ALIASES, etc.) already
resolves to.
