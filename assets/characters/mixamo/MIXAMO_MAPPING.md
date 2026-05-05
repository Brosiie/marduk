# Mixamo Mesh Mapping

20 Mixamo `.fbx` characters mapped to canonical Marduk slots.
All files renamed from their Mixamo titles to their slot ID.

## Player classes (9 / 9)

| Slot | Mixamo character | File |
|------|-------------------|------|
| `berserker` | Maw J Laygo | `classes/berserker.fbx` |
| `assassin` | Nightshade J Friedrich | `classes/assassin.fbx` |
| `ronin` | Knight D Pelegrini | `classes/ronin.fbx` |
| `ranger` | Erika Archer (with bow prop) | `classes/ranger.fbx` |
| `mage` | Ganfaul M Aure | `classes/mage.fbx` |
| `chaos_druid` | Maria WProp J J Ong | `classes/chaos_druid.fbx` |
| `demon` | Demon T Wiezzorek | `classes/demon.fbx` |
| `paladin_guardian` | Paladin J Nordstrom | `classes/paladin_guardian.fbx` |
| `paladin_lightbringer` | Arissa | `classes/paladin_lightbringer.fbx` |

## Mobs (7 dedicated + 4 reused)

| Slot | Mixamo character | File |
|------|-------------------|------|
| `usurper_footman` | Castle Guard 02 | `mobs/usurper_footman.fbx` |
| `usurper_archer` | Castle Guard 02 (variant) | `mobs/usurper_archer.fbx` |
| `raider_grunt` | Ch05_nonPBR | `mobs/raider_grunt.fbx` |
| `raider_archer` | Ch24_nonPBR | `mobs/raider_archer.fbx` |
| `shrine_acolyte` | goblin_d_shareyko | `mobs/shrine_acolyte.fbx` |
| `binding_construct` | Skeletonzombie T Avelange | `mobs/binding_construct.fbx` |
| `blood_hunter` | Vampire A Lusth | `mobs/blood_hunter.fbx` |
| `siege_lieutenant` | (reuses `bosses/usurper_enforcer.fbx`, scale 0.85) | shared |
| `corrupted_wolf` | (reuses `binding_construct`, tinted) | shared |
| `animated_book` | (reuses `shrine_acolyte`, tinted) | shared |
| `witch_burner` | (reuses `classes/mage`) | shared |
| `chapel_breaker` | (reuses `classes/berserker`) | shared |

## Bosses (1 dedicated + 7 reused)

| Slot | Mixamo character | File |
|------|-------------------|------|
| `usurper_enforcer` | Warrok W Kurniawan | `bosses/usurper_enforcer.fbx` |
| `raid_captain` | (reuses `classes/berserker`, scale 1.4) | shared |
| `corrupt_master` | (reuses `classes/mage`, scale 1.3) | shared |
| `glade_terror` | (reuses `binding_construct`, scale 1.5) | shared |
| `tower_warden` | (reuses `classes/mage`, scale 1.3) | shared |
| `inquisitor_prime` | (reuses `classes/paladin_guardian`, scale 1.3) | shared |
| `siege_master` | (reuses `usurper_enforcer`, scale 1.4) | shared |
| `self_that_said_yes` | (reuses `classes/demon`, scale 1.3) | shared |

## NPCs (3)

| Slot | Mixamo character | File |
|------|-------------------|------|
| `peasant_male` | Peasant Man | `npcs/peasant_male.fbx` |
| `peasant_female` | Peasant Girl | `npcs/peasant_female.fbx` |
| `ranger_npc` | Erika Archer (without bow prop) | `npcs/ranger_npc.fbx` |

## Slots still needing dedicated Mixamo download

When you grab more characters from Mixamo, these are next:

- **`corrupted_wolf`** — quadruped wild wolf with corruption growths. Mixamo has only humanoids; consider Quaternius animated-animals pack instead.
- **`animated_book`** — flying tome (no humanoid available; use a particle effect + custom prop).
- **`witch_burner`** — robed inquisitor with torch. Mixamo has Inquisitor characters under "Mage" tag.
- **`chapel_breaker`** — heretical barbarian smashing chapel pews. Could share berserker + helmet swap.
- **`tower_warden`** — wizard-tier shielded mage. Could grab "Sorcerer" tier from Mixamo.
- **`inquisitor_prime`** — bigger paladin variant in white robes. Mixamo "Cleric" archetype.
- **`raid_captain`** — barbarian boss. Mixamo "Mremireh O Desbiens" or similar bigger frame.
- **`corrupt_master`** — necromancer-tier mage. Mixamo "Lich" or "Necromancer" archetype.
- **`siege_master`** — orc-tier boss. Already share Warrok at bigger scale; could get a "Mutant" or "Ogre" archetype later.
- **`self_that_said_yes`** — the Demon's mirror self for Demon-class encounter. Use "Demon" but with horns and red tint.

## Animation strategy

Each `.fbx` was downloaded "with skin" so it carries Mixamo's auto-rigged humanoid skeleton.
Animations are downloaded separately from `mixamo.com` as `.fbx` files **without skin**:

```
Recommended starter set (download these once, share across all humanoids):
  Idle (looping) — `Standing Idle`
  Walking — `Walking`
  Running — `Running` or `Fast Run`
  Sprint — `Sprint`
  Jump — `Jumping`
  Dodge — `Roll Dodge` or `Quick Dodge`
  Attack 1H — `Sword And Shield Slash`
  Attack 2H — `Great Sword Slash` or `Mma Kick`
  Bow Draw — `Standing Draw Arrow`
  Bow Shoot — `Standing Aim Walk Forward`
  Spell Cast — `Standing 2H Magic Attack 01`
  Hit Reaction — `Hit Reaction`
  Stagger — `Heavy Hit React`
  Death — `Dying`
  Death Backwards — `Falling Back Death`
```

Drop them into `mixamo/animations/` and merge into a shared `AnimationLibrary` resource.
The library binds to each character's `AnimationPlayer` because all share the Mixamo humanoid skeleton — one animation file works for all 20 characters via Godot's `SkeletonProfileHumanoid` retargeting.

## Godot import workflow per character

For each `.fbx` above:

1. Drag into Godot — auto-imports
2. Click `Advanced Import Settings`
3. Find `Skeleton3D > Retarget` in the Inspector
4. `Bone Map > New BoneMap`
5. `Profile > SkeletonProfileHumanoid`
6. Map any unmapped bones manually if Mixamo's auto-rig deviated
7. Reimport

Then in the player/enemy spawn code, the existing `class_mesh_registry.gd` paths resolve to the correct file.
