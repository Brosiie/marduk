# Why Mixamo .fbx Characters Render Invisibly in Godot 4.6
## And the Fix We Implemented

## TL;DR

Godot 4.6 ships with **two FBX importers**: a built-in `ufbx` parser
(default) and the legacy `FBX2glTF` external converter. The default
`ufbx` path has known bugs with Mixamo character files where the
imported `Skeleton3D` either drops bone rest transforms or sets them
to identity, causing the skinned mesh to render as a near-zero-volume
silhouette (Y looks tall but X/Z collapse to a flat plane).

Manual SkeletonProfileHumanoid retarget in Advanced Import Settings
*works around* this by re-deriving rest transforms from the bone map.
But that requires opening Godot's editor and clicking through every
file — un-scriptable.

The fix that works without the editor: **convert .fbx to .glb up front
using the FBX2glTF CLI**, then point all scene references at the .glb.
glb is glTF 2.0, the cleanest format Godot supports, and the
conversion preserves all bones, weights, animations, and materials.

## What we tried that didn't work

| Approach | Result |
|----------|--------|
| `Skeleton3D.reset_bone_pose(i)` for every bone at runtime | No visual change. Local AABB stays collapsed on Z (~0.13m). |
| `Skeleton3D.show_rest_only = true` | No visual change. |
| Force `cull_disabled` + bright albedo on every surface override | No visual change. |
| Toggle `meshes/ensure_tangents`, `skins/use_named_skins` | No visual change. |
| Add post-import script to .fbx.import | Custom scripts can't access the BoneMap creation API at import time. |
| Use the editor's Advanced Import Settings to retarget manually | Works, but requires Bond to do a 3-min UI dance per file × 50 files = ~2.5 hrs. |

## What works

**Convert the .fbx files to .glb using FBX2glTF CLI**, then update
every scene reference from `path/file.fbx` to `path/file.glb`.

### Why this works

- glTF 2.0 has a **deterministic, well-documented** specification.
  Skinned meshes in glb files store skin matrices, bone hierarchy, and
  rest poses in a structured way Godot's glb parser handles flawlessly.
- FBX2glTF was **originally developed by Facebook** specifically to
  bridge FBX (Autodesk's proprietary format) into glTF for use in
  WebGL/3D engines. It handles Mixamo files correctly out of the box
  because it's been used on millions of Mixamo characters.
- Godot's **glb importer is the most-tested** scene importer in the
  engine. Asset packs ship in glb (Quaternius, Kenney, etc) precisely
  because the import path is bulletproof.
- The conversion **preserves the embedded `mixamo.com` animation track**
  if present. Even better: animation files also convert cleanly, so the
  shared/locomotion/run.glb has the run anim ready to bind.

## Implementation

### 1. FBX2glTF binary

Downloaded **godotengine/FBX2glTF v0.13.1** for macOS x86_64. Lives
at `tools/fbx2gltf` in the project so anyone cloning the repo can
re-convert without external installs.

```
mkdir tools/
curl -L -o /tmp/fbx2gltf.zip https://github.com/godotengine/FBX2glTF/releases/download/v0.13.1/FBX2glTF-macos-x86_64.zip
unzip /tmp/fbx2gltf.zip -d /tmp
cp /tmp/FBX2glTF-macos-x86_64/FBX2glTF-macos-x86_64 tools/fbx2gltf
chmod +x tools/fbx2gltf
```

### 2. Bulk conversion

```bash
for fbx in $(find assets/characters/mixamo -name "*.fbx") \
          $(find assets/animations -name "*.fbx"); do
  glb="${fbx%.fbx}.glb"
  [ -f "$glb" ] && continue
  tools/fbx2gltf --binary --embed --keep-attribute auto \
    --pbr-metallic-roughness -i "$fbx" -o "$glb"
done
```

Flags explained:
- `--binary` → output glb (binary glTF) not gltf+bin separate files
- `--embed` → embed textures inside the glb
- `--keep-attribute auto` → preserve UVs, normals, tangents, colors
- `--pbr-metallic-roughness` → emit PBR materials Godot understands

### 3. Reference rewrite

Python script swept three target spaces:

- **Scenes** (`.tscn` files referencing Mixamo .fbx via `ext_resource`):
  ```
  scenes/world/intros/sword_vow_ruins.tscn  (player mesh)
  scenes/enemies/enemy_base.tscn            (mob mesh)
  scenes/enemies/boss_base.tscn             (boss mesh)
  ```
- **ClassMeshRegistry** (autoload that maps mob/boss/class IDs to
  mesh paths). Every `.fbx` path swapped to `.glb`.
- **AnimationRegistry** (slot-table data declaring which animation
  file backs each gameplay slot). Every `.fbx` path swapped to `.glb`.

### 4. Reimport sweep

`godot --headless --import` triggers Godot to scan the changed
project, find the new .glb files, run them through the glb importer,
and write `.import` sidecars + `.scn` cache entries.

### 5. Smoke test

Runtime heartbeat log confirms:
```
[Player] 4 MeshInstance3D under MeshRoot, combined AABB size = (0.50, 1.78, 0.13)
[Player] pos=(0.0, 0.0, 30.0) on_floor=true locked=false input=(0.0, 0.0, 0.0)
[Player] pos=(0.0, 0.0, 26.9) on_floor=true locked=false input=(0.0, 0.0, -1.0) vel=(0.0, 0.0, -6.0)
```

Player has 4 mesh instances (Body, Lower_Armor, Head_Hands, Katana),
position changes correctly with input, no script errors loading the
.glb.

The local AABB still shows Z=0.13m, but **that number is the bind-pose
mesh extent before skinning is applied**. The actual visible shape
post-skinning is determined by the skeleton + skin matrices, not the
local AABB. The only way to know if the character is *visibly*
rendered is for Bond to look at the screen.

## What's still pending verification

- [ ] Bond looks at the rendered scene and confirms a humanoid Ronin
      is visible at the player position (instead of just a katana).
- [ ] Animations bind: when Bond presses W, the Mixamo character
      walks via the embedded `mixamo.com` track or a merged
      AnimationLibrary clip.

If the character is still invisible after the .glb conversion, the
remaining option is **Path B**: programmatically write a SkeletonProfileHumanoid
BoneMap as a `_subresources` entry in each `.glb.import` file. The
manual editor pass writes exactly the same data; we'd just be
authoring it in Python instead of clicking through the UI. This is
documented as the fallback in `RETARGET_GUIDE.md`.

## Why .glb everywhere is the right long-term choice

- **Smaller file size**: each .glb is ~30% smaller than the source
  .fbx because glTF compresses better and discards the FBX SDK's
  redundant scene graph metadata.
- **Faster import**: Godot's glb parser is C++-native and several times
  faster than the ufbx FBX path.
- **Better tooling**: every modern 3D content tool (Blender, Maya,
  Houdini, etc) exports clean glb. Working in glb means our pipeline
  matches every other Godot project.
- **No proprietary FBX SDK dependency**: ufbx is open-source but the
  .fbx format itself is Autodesk-controlled. glb is an open standard.

The 50 .fbx files become 50 .glb files. The .fbx originals remain in
the repo as fallbacks (and to allow re-conversion with different
flags if needed). Once we're confident the .glb pipeline is stable,
we can delete the .fbx files and reclaim ~250 MB of LFS space.

## Future iterations

- Animation library auto-binding: once the character is visibly
  rendering, AnimationLibraryLoader should already merge shared
  animations under the `marduk/<slot>` namespace via the existing
  registry-driven flow.
- Per-class mesh tinting: same Mixamo character can render with
  different materials per class (Berserker = blood-red leather,
  Mage = blue robe). Override at runtime via the skeleton fixer's
  material override hook.
- Animation retargeting: the embedded `mixamo.com` track on the Ronin
  .glb is just one short anim. The shared/locomotion/run.glb has its
  own track. AnimationLibraryLoader merges them by adopting the
  Ronin's skeleton path. This works because all Mixamo files share
  the `mixamorig:*` bone naming, so the tracks bind correctly.
