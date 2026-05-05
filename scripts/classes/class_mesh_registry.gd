extends Node

# Autoload registry mapping class_id -> character mesh + animation aliases.
# When a Player is instantiated for a given class, the spawn logic loads the
# matching .glb / .fbx scene and parents it under MeshRoot.
#
# Mesh pool: Mixamo realistic-proportion characters (auto-rigged Humanoid skeleton).
# Files live under assets/characters/mixamo/{classes,mobs,bosses,npcs}/
# Animations are downloaded separately from Mixamo without skin and merged
# in Godot via AnimationLibrary on the AnimationPlayer per character.
#
# Each .fbx must be re-imported in Godot's Advanced Import Settings:
#   - Skeleton3D > Retarget > BoneMap > New BoneMap
#   - Profile > SkeletonProfileHumanoid
#   - Re-import
# Then animations from the shared library can be applied uniformly.

const MIXAMO_CLASSES := "res://assets/characters/mixamo/classes"
const MIXAMO_MOBS    := "res://assets/characters/mixamo/mobs"
const MIXAMO_BOSSES  := "res://assets/characters/mixamo/bosses"
const MIXAMO_NPCS    := "res://assets/characters/mixamo/npcs"

# Legacy KayKit fallbacks (kept available for chibi-mode toggle / quick swaps)
const KAYKIT_BASE := "res://assets/characters/kaykit/Characters/gltf"
const KAYKIT_SKEL := "res://assets/characters/kaykit_skeletons/Characters/gltf"

# class_id -> mesh path mapping. Each pick reflects the class's archetype.
const CLASS_MESHES := {
	# Berserker - heavy melee, ash-steppe brawler. Maw J Laygo (Mixamo)
	&"berserker":            "res://assets/characters/mixamo/classes/berserker.fbx",
	# Assassin - leather, daggers, hooded rogue silhouette. Nightshade J Friedrich
	&"assassin":             "res://assets/characters/mixamo/classes/assassin.fbx",
	# Ronin - katana swordsman in plated mail. Knight D Pelegrini
	&"ronin":                "res://assets/characters/mixamo/classes/ronin.fbx",
	# Ranger - leather + bow, draws cleanly. Erika Archer With Bow Arrow (bow prop attached)
	&"ranger":               "res://assets/characters/mixamo/classes/ranger.fbx",
	# Mage - robed sorcerer with staff. Ganfaul M Aure
	&"mage":                 "res://assets/characters/mixamo/classes/mage.fbx",
	# Chaos Druid - witchy female with prop, totem-friendly. Maria WProp J J Ong
	&"chaos_druid":          "res://assets/characters/mixamo/classes/chaos_druid.fbx",
	# Demon - LOCKED. Horned/clawed humanoid for unlock reveal. Demon T Wiezzorek
	&"demon":                "res://assets/characters/mixamo/classes/demon.fbx",
	# Paladin Guardian - heavy plate male paladin. Paladin J Nordstrom
	&"paladin_guardian":     "res://assets/characters/mixamo/classes/paladin_guardian.fbx",
	# Paladin Lightbringer - female mail-armored cleric/warrior. Arissa
	&"paladin_lightbringer": "res://assets/characters/mixamo/classes/paladin_lightbringer.fbx",
}

# Mob mesh map. Keep mobs visually distinct from players.
const MOB_MESHES := {
	# Tashmu's invasion forces — castle guards in iron livery
	&"usurper_footman":     "res://assets/characters/mixamo/mobs/usurper_footman.fbx",
	&"usurper_archer":      "res://assets/characters/mixamo/mobs/usurper_archer.fbx",
	# Generic raiders — Mixamo Ch05/Ch24 slim civilians for bandit packs
	&"raider_grunt":        "res://assets/characters/mixamo/mobs/raider_grunt.fbx",
	&"raider_archer":       "res://assets/characters/mixamo/mobs/raider_archer.fbx",
	# Cult ranks — small hooded scuttlers (goblin)
	&"shrine_acolyte":      "res://assets/characters/mixamo/mobs/shrine_acolyte.fbx",
	# Undead — bound bones reanimated by binding magic (skeleton-zombie hybrid)
	&"binding_construct":   "res://assets/characters/mixamo/mobs/binding_construct.fbx",
	# Vampire-tier blood drinker
	&"blood_hunter":        "res://assets/characters/mixamo/mobs/blood_hunter.fbx",
	# Heavy bruiser — Warrok orc-class siege thug (also reused as boss usurper_enforcer)
	&"siege_lieutenant":    "res://assets/characters/mixamo/bosses/usurper_enforcer.fbx",
	# Slots without dedicated Mixamo mesh yet — fall back to thematically-closest Mixamo + scale tint
	&"corrupted_wolf":      "res://assets/characters/mixamo/mobs/binding_construct.fbx",
	&"animated_book":       "res://assets/characters/mixamo/mobs/shrine_acolyte.fbx",
	&"witch_burner":        "res://assets/characters/mixamo/classes/mage.fbx",
	&"chapel_breaker":      "res://assets/characters/mixamo/classes/berserker.fbx",
	# fallback for any zone mob not listed
	&"_default":            "res://assets/characters/mixamo/mobs/usurper_footman.fbx",
}

# Boss mesh map. Bigger / scaled / more imposing.
const BOSS_MESHES := {
	# Enforcer Kazat, the Iron-Faced — Tashmu's lieutenant, Ronin's mini-boss
	&"usurper_enforcer":    "res://assets/characters/mixamo/bosses/usurper_enforcer.fbx",  # Warrok W Kurniawan
	# Slots without dedicated Mixamo mesh yet — fall back to closest archetype + scale up
	&"raid_captain":        "res://assets/characters/mixamo/classes/berserker.fbx",
	&"corrupt_master":      "res://assets/characters/mixamo/classes/mage.fbx",
	&"glade_terror":        "res://assets/characters/mixamo/mobs/binding_construct.fbx",
	&"tower_warden":        "res://assets/characters/mixamo/classes/mage.fbx",
	&"inquisitor_prime":    "res://assets/characters/mixamo/classes/paladin_guardian.fbx",
	&"siege_master":        "res://assets/characters/mixamo/bosses/usurper_enforcer.fbx",
	&"self_that_said_yes":  "res://assets/characters/mixamo/classes/demon.fbx",
	&"_default":            "res://assets/characters/mixamo/bosses/usurper_enforcer.fbx",
}

# NPC mesh map — towns, villagers, quest-givers, vendors.
const NPC_MESHES := {
	&"peasant_male":        "res://assets/characters/mixamo/npcs/peasant_male.fbx",   # Storyteller / Iddinu / villagers
	&"peasant_female":      "res://assets/characters/mixamo/npcs/peasant_female.fbx", # Belitu / market girls
	&"ranger_npc":          "res://assets/characters/mixamo/npcs/ranger_npc.fbx",     # Erika without bow prop, hunters guild
	&"_default":            "res://assets/characters/mixamo/npcs/peasant_male.fbx",
}

func get_class_mesh_path(class_id: StringName) -> String:
	return CLASS_MESHES.get(class_id, "res://assets/characters/mixamo/classes/ronin.fbx")

func get_mob_mesh_path(mob_id: StringName) -> String:
	return MOB_MESHES.get(mob_id, MOB_MESHES.get(&"_default"))

func get_boss_mesh_path(boss_id: StringName) -> String:
	return BOSS_MESHES.get(boss_id, BOSS_MESHES.get(&"_default"))

func get_npc_mesh_path(npc_id: StringName) -> String:
	return NPC_MESHES.get(npc_id, NPC_MESHES.get(&"_default"))
