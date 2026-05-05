# Marduk Asset Pipeline

Marduk uses placeholder capsule meshes by default so the project runs immediately.
This document is the path from "capsules" to "shipped game" using free CC0 / royalty-free
assets, with optional Blender authoring on top.

## TL;DR for tonight (play with placeholders + 1 hour of work)

You can play right now with capsule meshes. To make it look like a game without
authoring anything yourself:

```
1. Download KayKit Adventurers + Skeletons    (free, CC0, includes animations)
2. Download Quaternius medieval kit            (free, CC0, environment)
3. Drop FBX into assets/characters/ and assets/environments/
4. Replace the Player's MeshRoot with the imported model
5. Replace the EnemyBase mesh with a skeleton or generic enemy
```

That gets you ~80% of the visual fidelity of a finished indie ARPG demo.

## Recommended Source: CC0 / Royalty-Free

### Characters + Animations

**KayKit (CC0, no attribution required)**
- [Adventurers Pack](https://kaylousberg.itch.io/kaykit-adventurers): 4 rigged, animated low-poly heroes. 75 animations. `.fbx` and `.gltf`. Single-atlas 1024x1024 texture.
- [Skeletons Pack](https://kaylousberg.itch.io/kaykit-skeletons): 4 skeletons, 90+ animations. Perfect for undead mobs.
- [Prototype Bits](https://kaylousberg.itch.io/prototype-bits): 64+ low-poly props (crates, barrels, weapons).

**Quaternius (CC0)**
- [Free game assets](https://quaternius.com/): characters, nature, medieval items, animated assets, buildings.
- Use the **Medieval Village MegaKit** for Babilim placeholder geometry.
- Use the **Animated Animals** pack for druid wild-shape forms.

**Mixamo (free, free signup, royalty-free)**
- [mixamo.com](https://www.mixamo.com): free character library + 2000+ animations.
- Auto-rigger: upload your own model, get a skeleton + animations bound automatically.
- Workflow for Marduk:
  1. Pick a character (or upload your own from Blender)
  2. Apply animations: `Idle`, `Walking`, `Running`, `Sword Slash`, `Hit Reaction`, `Death`
  3. Download as FBX (with skin)
  4. Import into Godot - retarget via SkeletonProfileHumanoid

### Environments

**KayKit Dungeon Pack** (CC0)
- Wall tiles, floor tiles, chests, torches, doors. Drop into a zone scene as static geometry.

**Quaternius Medieval / Castle / Nature kits** (CC0)
- Free buildings, trees, props, terrain pieces.

**Synty Studios** (paid, ~$30-200/pack but extremely high quality)
- POLYGON Fantasy Kingdom Pack, POLYGON Dungeon Realms.
- Worth budgeting for one Synty pack near launch; not needed tonight.

### Audio (free)

- [Kenney CC0 audio](https://kenney.nl/assets): SFX library, no attribution.
- [Freesound.org](https://freesound.org): mostly CC-BY, some CC0; great for ambient.
- [OpenGameArt](https://opengameart.org): mixed licenses; filter for CC0 + CC-BY.
- For music, [Pixabay Music](https://pixabay.com/music) has CC0 royalty-free tracks.

## Godot 4.6 Import Workflow

### Importing a KayKit FBX

1. Drag the `.fbx` (or `.gltf`) into `assets/characters/<name>/` in the Godot editor.
2. Godot auto-imports. Open the Import tab, set:
   - **Mesh > Generate Tangents:** on
   - **Materials > Use Named Skins:** on
3. Double-click the imported file to open Advanced Import Settings.
4. Select the Skeleton3D node, find the **Retarget** section in the Inspector.
5. Click the dropdown next to **Bone Map > New BoneMap**.
6. Set **Profile > SkeletonProfileHumanoid**.
7. Map any bones Godot didn't auto-detect (red bones in the preview).
8. Click **Reimport**.

### Importing Mixamo Animations

1. Visit [mixamo.com](https://www.mixamo.com), choose a character, choose animations.
2. **Download settings:** FBX for Unity (.fbx), Without Skin (after the first download which has the skin).
3. Drop the .fbx into `assets/animations/<character>/`.
4. In Godot's import settings, find the AnimationPlayer node, expand each animation, check "Save to File", and save as `.res` to `resources/animations/`.
5. Build an `AnimationLibrary` resource that references the .res files.
6. Attach the library to your character's AnimationPlayer.

### Replacing the Player capsule

In `scenes/world/intros/sword_vow_ruins.tscn`:

1. Open the scene.
2. Find `Player > MeshRoot > Mesh` (the capsule).
3. Replace by deleting the CapsuleMesh node and adding the imported character as a child of MeshRoot.
4. Scale the imported character to ~1.7m height (matches the collider).
5. Add an AnimationPlayer node to the character if not already present.
6. Wire the player.gd's `anim_player` reference to the AnimationPlayer.

## Marduk-Specific Asset Targets (priority order)

Based on what exists in the project today:

### Phase 1 - Sword-Vow Ruins (Ronin demo)
- [ ] Ronin character mesh + idle/walk/run/swing/death animations
- [ ] Tashmu's Footman mob mesh + walk/attack/death animations
- [ ] Tashmu's Archer mob mesh + walk/draw/release/death animations
- [ ] Enforcer Kazat boss mesh + windup/swing/slam/charge animations
- [ ] Stone fortress wall pieces + ruined courtyard floor tiles
- [ ] Sword swing SFX, footstep SFX, hit grunt SFX

### Phase 2 - All 9 class intros
- [ ] One placeholder hero mesh per class (8 unique + 1 reskin for Demon)
- [ ] One mini-boss mesh per intro (some can share rigs)
- [ ] Per-zone environment kit: village hut, ruined fortress, glade trees,
      shrine pillars, druid stones, chapel benches, fire stair basalt, etc.
- [ ] One signature ability VFX per class (uses BreathingVFX hooks already built)

### Phase 3 - Babilim
- [ ] City buildings: ziggurats, shop fronts, market stalls, hanging gardens
- [ ] NPC meshes: Belitu, Storyteller, Iddinu, Sin-Mushezib, etc.
- [ ] Iron Pillar centerpiece with engraved Edict text
- [ ] Music tracks per district

## Authoring with Blender (when CC0 isn't enough)

Bond has Blender installed. The path from Mixamo to bespoke is:

1. Download Mixamo character as base mesh + skeleton
2. Open in Blender, sculpt/retopo/edit to taste
3. Re-export as glTF 2.0 (.glb preferred, smaller than FBX)
4. Drop .glb into Godot - it auto-imports without retargeting

For bespoke from-scratch:
1. Use Blender's metarig (Add > Armature > Human Meta-Rig from Rigify addon)
2. Sculpt or box-model the mesh
3. Auto-weight to the metarig
4. Generate the Rigify control rig
5. Animate in Blender
6. Export as .glb with NLA strips (one strip per animation)

## Storage layout

```
assets/
├── characters/
│   ├── ronin/
│   │   ├── ronin.glb
│   │   └── animations/   (or use a shared mixamo library)
│   ├── kazat/
│   └── ...
├── environments/
│   ├── kaykit_dungeon/   (entire pack dropped here)
│   ├── quaternius_medieval/
│   └── ...
├── audio/
│   ├── music/
│   └── sfx/
└── vfx/
    ├── particles/
    └── shaders/
```

## License notes

KayKit and Quaternius are CC0 (no attribution required, can ship in any commercial product). Mixamo is royalty-free under Adobe's license (no attribution required, can ship as-is). Synty packs are paid but have a "use in your projects" license.

When in doubt, **add attributions to a CREDITS.md** file even when the license doesn't require it. Goodwill costs nothing.
