# Mixamo Retarget Guide

The `.fbx` files under `assets/characters/mixamo/` and `assets/animations/`
all share the Mixamo Humanoid skeleton. They need to be retargeted against
Godot's `SkeletonProfileHumanoid` so animations bind correctly. This is a
one-time setup that takes ~5-15 minutes.

## Path A: auto-retarget (try first, usually works)

Mixamo's `mixamorig:` bone naming is the standard Godot auto-detects, so
in most cases all you need to do is reimport the folder.

```
1. Open Godot.
2. Wait for project load.
3. In the FileSystem dock, right-click  assets/characters/mixamo
4. Click  "Reimport"
5. Walk away ~5 minutes.
6. Hit Play on  scenes/world/intros/sword_vow_ruins.tscn
7. Watch the Ronin walk + attack.
```

If the Ronin moves correctly, you're done. Skip Path B.

## Path B: manual master BoneMap (if T-poses persist)

If the character is still T-posed after Path A, Godot didn't auto-bind.
Do one file manually to set the master BoneMap, then a script handles
the rest.

### Step 1: create the master BoneMap (do once)

```
1. In Godot, double-click  assets/characters/mixamo/classes/ronin.fbx
2. In the import dialog, top-right click  "Advanced Import Settings"
3. In the node tree on the left, find the Skeleton3D node
   (usually under  Armature). Click it.
4. In the Inspector on the right, scroll to find  Retarget.
5. Bone Map dropdown ->  "New BoneMap"
6. The BoneMap editor opens.
   Profile dropdown ->  "SkeletonProfileHumanoid"
7. Godot auto-maps Mixamo bones. Most show green. A few may show red
   (usually  RightToeBase  /  LeftToeBase  /  LeftEye  /  RightEye).
8. For each red slot:
   - Click the empty slot.
   - Pick the closest Mixamo bone (toes ->  mixamorig:RightToeBase).
   - Eyes are optional; leave unmapped if no Mixamo bone fits.
9. Click  Save  on the BoneMap dialog.
10. Save path:  res://assets/characters/mixamo/mixamo_humanoid.tres
11. Click  "Reimport"  bottom-right.
```

### Step 2: bulk-patch every other .fbx

Once the master BoneMap exists, a Python script patches every other
`.fbx.import` file to point at it, so Godot reimports them all on next
open with the same retarget.

Tell Claude `bonemap saved` and the loop will run the patch. You then
right-click `assets/characters/mixamo` and `assets/animations` -> Reimport,
and walk away.

## Verifying the retarget worked

Hit Play on `scenes/world/intros/sword_vow_ruins.tscn`. Check:

- Ronin's arms + legs move when you press WASD (not stuck at sides)
- Press Q (Iai Strike). The katana swings, not a frozen pose.
- A footman aggros you. They swing at you with real arm motion.

If those three work, the retarget is done permanently. The animation
library auto-loads `marduk/<slot>` clips on every spawn from now on.

## Why this is a one-time cost

Once a `.fbx` is retargeted, the `.import` sidecar file caches the
mapping. Godot reuses it on every subsequent build, run, and export.
You never have to do this again unless you add new Mixamo files to the
project (and even then, the script-patch path takes ~30 seconds).

## Common gotchas

- **"My BoneMap looks all green but the character is still T-posed."**
  You probably forgot to click  Reimport  bottom-right after saving
  the BoneMap. Try the file again.

- **"I don't see a Skeleton3D node in the tree."**
  The Mixamo file might have an unusual scene structure. Look for an
  Armature node - the Skeleton3D is usually a child of that.

- **"Some animations look fine but breathing forms are still T-posed."**
  Animation files (under `assets/animations/`) need their own retarget
  pass. Path B's script-patch covers them; or run Path A on the
  `assets/animations` folder too.

- **"Animations work but the character's mesh is huge / tiny."**
  That's the cm-vs-meters issue, not retarget. The mesh transform in
  the parent scene already applies a 0.01 (mobs / classes) or 0.014
  (bosses) scale to convert Mixamo cm to Godot meters.

## Bonus: doing this entirely from the CLI

This is theoretically possible via `--headless --import`, but Godot 4.6
sometimes corrupts the BoneMap when written outside the editor. Stick
with Path A or B. The total time cost (~5-15 minutes once) is small.
