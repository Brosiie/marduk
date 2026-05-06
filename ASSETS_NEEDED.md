# Asset Gap: from Dungeon Kit to Open World

Bond's playtest feedback (2026-05-06): the current ZoneComposer spits
out "random walls" because the only environment kit in the repo is
`assets/environments/kaykit_dungeon/` — a *closed underground corridor*
kit. For the world Bond wants (Diablo + Elden Ring + WoW open zones),
we need outdoor / nature / town assets that don't exist in the project
yet. This file documents the gap and the planned fill.

## What's currently in the repo

```
assets/environments/kaykit_dungeon/Assets/gltf/
  floor_*, wall_*, pillar_*, torch_*, banner_*,
  barrel, crate, table, chair, bed, candle, chest, etc.
```

Closed-world dungeon vibe. Wrong for outdoor regions.

## What we need

### 1. Nature pack — grass, trees, rocks, flowers

**Recommended source:** Quaternius "Ultimate Nature Pack" (free, CC0)
- https://quaternius.com/packs/ultimatenature.html
- ~80 stylized trees/bushes/grass tufts/rocks/mushrooms
- Drop into `assets/environments/quaternius_nature/`

Used by region styles: GREENHEART_GLADE, MIST_VALE, VERDANT_WOUND,
EMBER_STEPPES (sparse), THE_REED_WASTES (cattails).

### 2. Buildings — houses, shops, towers, walls

**Recommended source:** Quaternius "Battle Realm" + Kenney "Medieval Town"
- https://quaternius.com/packs/battle.html
- Houses, towers, market stalls, farm structures
- Drop into `assets/environments/quaternius_buildings/`

Used by region styles: ASHURIM (city plaza), BABILIM (capital),
LAPIS_BAY (dock + houses), THE_CRADLE (temple), BLACK_CITADEL (fortress).

### 3. Mountains + caves — cliffs, boulders, cave entrances

**Recommended source:** Quaternius "Battle Royale Caves" + KenneyAssets
"Cave Kit"
- https://kenney.nl/assets/cave-kit
- Cave wall segments, stalactites, ore veins, cliff faces
- Drop into `assets/environments/cave_kit/`

Used by region styles: BONE_MOUNTAINS, SHRIEKING_HIGHLANDS, FIRE_STAIR.

### 4. Water shader + water plane

**Recommended approach:** custom Godot shader for animated water,
applied to a flat plane at y=0.

```gdscript
# scripts/vfx/water_shader.gdshader
# Simple wave-displaced plane with foam at edges
```

Used by region styles: LAPIS_BAY, SUNDERED_COAST, THE_REED_WASTES (marsh
puddles), MIST_VALE (mossy pools).

### 5. Terrain — rolling hills, heightmap-based ground

**Recommended approach:** Godot 4 has built-in `HeightMapShape3D` for
collision + a procedural mesh from a noise function. No plugin needed.

```gdscript
# scripts/world/spawn/terrain_generator.gd
# Generates a heightmap mesh from FastNoiseLite, applies
# blended dirt/grass/rock material based on slope.
```

Replaces the flat 80x80 ground plane in every region with rolling
terrain. Mountains are just spikes in the noise function.

### 6. Skybox per region

**Recommended approach:** ProceduralSkyMaterial already in use; per-region
sky_top/horizon colors plus optional `panorama_sky` for dramatic regions
(Black Citadel = stormy purple, Babilim = bright sun, Mist Vale = grey
fog). Cheap to author.

### 7. NPC walking sprites + animal sprites

**Recommended source:** Mixamo (already have access) + Quaternius
"Animated Animals"
- Birds, deer, rats, wolves
- Drop into `assets/characters/quaternius_animals/`

## Implementation phases

### Phase A (no asset download needed, ship in the loop tonight)

- [ ] **TerrainGenerator script**: procedural heightmap mesh + slope-blended
      material. Replaces the flat ground plane. Mountains via noise spikes.
      All 13 regions inherit it.
- [ ] **Water plane prefab**: 50x50 flat plane with custom shader, drop
      into LAPIS_BAY + SUNDERED_COAST + MIST_VALE.
- [ ] **Skybox-per-region tuning**: per-region color stops on the
      ProceduralSkyMaterial.
- [ ] **Strip dungeon-kit walls** from outdoor region styles in
      ZoneComposer (already done for SWORD_VOW_RUINS in this commit).

### Phase B (Bond downloads asset packs)

- [ ] **Quaternius Ultimate Nature** -> `assets/environments/quaternius_nature/`
- [ ] **Quaternius Battle Realm** -> `assets/environments/quaternius_buildings/`
- [ ] **KenneyAssets Cave Kit** -> `assets/environments/cave_kit/`
- [ ] **Quaternius Animated Animals** -> `assets/characters/quaternius_animals/`

These are all CC0 free download. Bond grabs them, drops the zip into
the right folder, the loop's next iteration wires ZoneComposer to use
them per region.

### Phase C (per-region rebuilds)

Each region's `_build_*` function in zone_composer.gd gets rewritten
to use the right asset family:

| Region | Asset focus |
|--------|-------------|
| THE_CRADLE         | Sumerian temple buildings (Battle Realm) + sand terrain |
| THE_REED_WASTES    | Marsh terrain + cattails (Nature) + plank pathways |
| LAPIS_BAY          | Coastal dock buildings + water plane + boats |
| BONE_MOUNTAINS     | Cliff terrain (heightmap spikes) + bones (rubble) |
| VERDANT_WOUND      | Corrupted forest (Nature, dark-tinted) + tilted ruins |
| EMBER_STEPPES      | Wide grass plain + scattered fire pits + tents |
| MIST_VALE          | Foggy grove (Nature + heavy fog) + standing stones |
| SHRIEKING_HIGHLANDS| Wind-cliffs (heightmap) + runestones |
| SUNDERED_COAST     | Broken cliffs + shipwreck + water plane |
| BLACK_CITADEL      | Dark fortress (Battle Realm towers) |
| FIRE_STAIR         | Basalt stair (heightmap spiral) + lava water |
| ASHURIM            | Town hub: market stalls + houses + plaza fountain |
| BABILIM            | Capital city: cathedral + colonnades + holy plaza |

## What's good NOW (don't change)

- ZoneComposer architecture: per-style functions, parameterized size
- Lodestone placement: 27 stones, persists via SaveFlags
- Boss arena lockdown: invisible cage on engage
- Mob spawn pools: per-region mob ids ready to wire

## Decisions for Bond

Three choices that shape the loop's next 10-15 iterations:

1. **Asset packs**: download the Quaternius/Kenney packs above, OR use
   only the existing KayKit dungeon kit + procedural shapes? Quaternius
   is one zip ~30MB, no licensing concerns (CC0). I'd lean Quaternius.

2. **Terrain plugin**: built-in Godot 4 procedural mesh (free, simple),
   OR install the Terrain3D plugin (more powerful, heightmap painting,
   but plugin install). Built-in is easier; Terrain3D is prettier.

3. **Aesthetic**: lean stylized-low-poly (matches KayKit chibi style)
   OR realistic (Mixamo character realism + matching realistic textures)?
   The current characters are realistic Mixamo. The world should match:
   realistic textures + lighting. KayKit chibi-stylized doesn't match
   Mixamo characters well anyway.
