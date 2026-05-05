extends Node

# Autoload registry mapping class_id -> character mesh + animation aliases.
# When a Player is instantiated for a given class, the spawn logic loads the
# matching .glb scene and parents it under MeshRoot.
#
# Current pool: KayKit Adventurers (chibi-stylized, CC0). Future: swap to
# Mixamo for realistic-proportion characters by replacing the mesh paths
# below; the animation alias map remains valid.

const KAYKIT_BASE := "res://assets/characters/kaykit/Characters/gltf"
const KAYKIT_SKEL := "res://assets/characters/kaykit_skeletons/Characters/gltf"

# class_id -> mesh path mapping. Each pick reflects the class's archetype.
const CLASS_MESHES := {
	# Berserker - heavy melee, axes/bludgeons, plate. Barbarian fits.
	&"berserker":            "res://assets/characters/kaykit/Characters/gltf/Barbarian.glb",
	# Assassin - leather, daggers, hood. Hooded rogue is the iconic match.
	&"assassin":             "res://assets/characters/kaykit/Characters/gltf/Rogue_Hooded.glb",
	# Ronin - katana, leather, light. Plain Rogue (no hood) fits the swordsman silhouette.
	&"ronin":                "res://assets/characters/kaykit/Characters/gltf/Rogue.glb",
	# Ranger - mail, bow. Rogue with a bow weapon attachment until we get a proper archer.
	&"ranger":               "res://assets/characters/kaykit/Characters/gltf/Rogue.glb",
	# Mage - cloth, robe, staff. Mage is the obvious match.
	&"mage":                 "res://assets/characters/kaykit/Characters/gltf/Mage.glb",
	# Chaos Druid - leather, staff/totem, nature. Hooded rogue rebranded; future replace.
	&"chaos_druid":          "res://assets/characters/kaykit/Characters/gltf/Rogue_Hooded.glb",
	# Demon - plate, hybrid. Reuses Knight as a starting silhouette; future custom mesh.
	&"demon":                "res://assets/characters/kaykit/Characters/gltf/Knight.glb",
	# Paladin Guardian - heavy plate, shield. Knight is the canonical match.
	&"paladin_guardian":     "res://assets/characters/kaykit/Characters/gltf/Knight.glb",
	# Paladin Lightbringer - mail, mace. Knight (lighter loadout) until a separate cleric mesh.
	&"paladin_lightbringer": "res://assets/characters/kaykit/Characters/gltf/Knight.glb",
}

# Mob mesh map. Keep mobs visually distinct from players.
const MOB_MESHES := {
	&"raider_grunt":           "res://assets/characters/kaykit/Characters/gltf/Barbarian.glb",
	&"raider_archer":          "res://assets/characters/kaykit/Characters/gltf/Rogue.glb",
	&"shrine_acolyte":         "res://assets/characters/kaykit/Characters/gltf/Rogue_Hooded.glb",
	&"usurper_footman":        "res://assets/characters/kaykit_skeletons/Characters/gltf/Skeleton_Warrior.glb",
	&"usurper_archer":         "res://assets/characters/kaykit_skeletons/Characters/gltf/Skeleton_Rogue.glb",
	&"corrupted_wolf":         "res://assets/characters/kaykit_skeletons/Characters/gltf/Skeleton_Minion.glb",
	&"binding_construct":      "res://assets/characters/kaykit_skeletons/Characters/gltf/Skeleton_Warrior.glb",
	&"animated_book":          "res://assets/characters/kaykit_skeletons/Characters/gltf/Skeleton_Mage.glb",
	&"blood_hunter":           "res://assets/characters/kaykit/Characters/gltf/Knight.glb",
	&"witch_burner":           "res://assets/characters/kaykit/Characters/gltf/Mage.glb",
	&"siege_lieutenant":       "res://assets/characters/kaykit/Characters/gltf/Knight.glb",
	&"chapel_breaker":         "res://assets/characters/kaykit/Characters/gltf/Barbarian.glb",
	# fallback for any zone mob not listed
	&"_default":               "res://assets/characters/kaykit_skeletons/Characters/gltf/Skeleton_Warrior.glb",
}

# Boss mesh map. Bigger / scaled / more imposing.
const BOSS_MESHES := {
	&"raid_captain":      "res://assets/characters/kaykit/Characters/gltf/Barbarian.glb",
	&"corrupt_master":    "res://assets/characters/kaykit/Characters/gltf/Mage.glb",
	&"usurper_enforcer":  "res://assets/characters/kaykit/Characters/gltf/Knight.glb",
	&"glade_terror":      "res://assets/characters/kaykit_skeletons/Characters/gltf/Skeleton_Minion.glb",
	&"tower_warden":      "res://assets/characters/kaykit_skeletons/Characters/gltf/Skeleton_Mage.glb",
	&"inquisitor_prime":  "res://assets/characters/kaykit/Characters/gltf/Mage.glb",
	&"siege_master":      "res://assets/characters/kaykit/Characters/gltf/Knight.glb",
	&"self_that_said_yes": "res://assets/characters/kaykit/Characters/gltf/Rogue_Hooded.glb",
	&"_default":          "res://assets/characters/kaykit/Characters/gltf/Knight.glb",
}

func get_class_mesh_path(class_id: StringName) -> String:
	return CLASS_MESHES.get(class_id, "res://assets/characters/kaykit/Characters/gltf/Rogue.glb")

func get_mob_mesh_path(mob_id: StringName) -> String:
	return MOB_MESHES.get(mob_id, MOB_MESHES.get(&"_default"))

func get_boss_mesh_path(boss_id: StringName) -> String:
	return BOSS_MESHES.get(boss_id, BOSS_MESHES.get(&"_default"))
