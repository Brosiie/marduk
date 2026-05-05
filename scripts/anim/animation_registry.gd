extends Node

# AnimationRegistry — autoload (added in project.godot autoload list).
#
# Single source of truth for which Mixamo .fbx animations get merged onto
# which character. The runtime AnimationLibraryLoader uses this to build a
# per-character `AnimationLibrary` at spawn time.
#
# Folder layout (under res://assets/animations/):
#
#   shared/
#     locomotion/   idle, walk_*, run, sprint, jump_*, dodge_*
#     combat/       attack_basic, parry, block_*
#     reactions/    hit_react, knockdown, stagger, death*
#     utility/      taunt_battlecry, crouch_to_stand, sit, sheathe, kneel
#   classes/<class_id>/   class signature moves
#   mobs/<mob_id>/        mob attack patterns
#   bosses/<boss_id>/     boss phase moves
#   npcs/<npc_id>/        NPC interaction loops
#
# Every Mixamo character + animation re-imports against
# `SkeletonProfileHumanoid`, so any anim from any folder works on any
# character once retargeted. This registry only declares *intent*: which
# anims a character is supposed to play at a given gameplay slot.
#
# To add a new anim: drop the .fbx into the right folder, then add its
# slot mapping in SHARED_SLOTS or CLASS_SLOTS below. AnimationLibraryLoader
# picks it up next time the character spawns.

# --- Slot constants (gameplay code refers to these, never raw filenames) ---
const SLOT_IDLE         := &"idle"
const SLOT_WALK         := &"walk"
const SLOT_RUN          := &"run"
const SLOT_SPRINT       := &"sprint"
const SLOT_JUMP_UP      := &"jump_up"
const SLOT_JUMP_DOWN    := &"jump_down"
const SLOT_DODGE_FWD    := &"dodge_forward"
const SLOT_DODGE_BACK   := &"dodge_back"
const SLOT_DODGE_LEFT   := &"dodge_left"
const SLOT_DODGE_RIGHT  := &"dodge_right"
const SLOT_HIT_REACT    := &"hit_react"
const SLOT_STAGGER      := &"stagger"
const SLOT_KNOCKDOWN    := &"knockdown"
const SLOT_GET_UP       := &"get_up"
const SLOT_DEATH        := &"death"
const SLOT_DEATH_BACK   := &"death_back"
const SLOT_BLOCK_IDLE   := &"block_idle"
const SLOT_BLOCK_HIT    := &"block_hit"
const SLOT_TAUNT        := &"taunt"
const SLOT_STAND_UP     := &"stand_up"

const SLOT_ATTACK_BASIC := &"attack_basic"
const SLOT_ATTACK_HEAVY := &"attack_heavy"
const SLOT_ATTACK_COMBO_1 := &"attack_combo_1"
const SLOT_ATTACK_COMBO_2 := &"attack_combo_2"
const SLOT_ATTACK_COMBO_3 := &"attack_combo_3"
const SLOT_PARRY        := &"parry"
const SLOT_RIPOSTE      := &"riposte"
const SLOT_CAST_LOOP    := &"cast_loop"
const SLOT_CAST_RELEASE := &"cast_release"

# Class-signature slot prefixes (each class can declare its own list)
const SLOT_BREATH_FORM  := &"breath_form_"   # 1..7 indexable, Ronin
const SLOT_SPELL        := &"spell_"          # 1..7 indexable, Mage
const SLOT_SHAPESHIFT   := &"shapeshift_"     # in/out, Druid
const SLOT_BOW          := &"bow_"            # idle/draw/release/snipe, Ranger
const SLOT_STEALTH      := &"stealth_"        # in/out, Assassin
const SLOT_DEMON_FORM   := &"demon_"          # claw/wing/burst, Demon
const SLOT_HOLY         := &"holy_"           # smite/pillar/heal/aura, Paladins

const ANIM_ROOT := "res://assets/animations"

# --- Shared anim slot table ---
# slot -> file under shared/.
# Anything missing on disk is silently skipped at load time (so partial
# Mixamo downloads still play; gameplay falls back to the closest cousin
# slot or to whatever the .fbx already shipped with).
const SHARED_SLOTS := {
	SLOT_DODGE_BACK:  "shared/locomotion/dodge_back.fbx",
	SLOT_DEATH:       "shared/reactions/death.fbx",
	SLOT_TAUNT:       "shared/utility/taunt_battlecry.fbx",
	SLOT_STAND_UP:    "shared/utility/crouch_to_stand.fbx",
	# These are documented expected slots Bond should download next.
	# Filenames Mixamo ships them as in their library:
	SLOT_IDLE:        "shared/locomotion/idle.fbx",
	SLOT_WALK:        "shared/locomotion/walk.fbx",
	SLOT_RUN:         "shared/locomotion/run.fbx",
	SLOT_SPRINT:      "shared/locomotion/sprint.fbx",
	SLOT_JUMP_UP:     "shared/locomotion/jump_up.fbx",
	SLOT_JUMP_DOWN:   "shared/locomotion/jump_land.fbx",
	SLOT_DODGE_FWD:   "shared/locomotion/dodge_forward.fbx",
	SLOT_DODGE_LEFT:  "shared/locomotion/dodge_left.fbx",
	SLOT_DODGE_RIGHT: "shared/locomotion/dodge_right.fbx",
	SLOT_HIT_REACT:   "shared/reactions/hit_react.fbx",
	SLOT_STAGGER:     "shared/reactions/stagger.fbx",
	SLOT_KNOCKDOWN:   "shared/reactions/knockdown.fbx",
	SLOT_GET_UP:      "shared/reactions/get_up.fbx",
	SLOT_DEATH_BACK:  "shared/reactions/death_back.fbx",
	SLOT_BLOCK_IDLE:  "shared/combat/block_idle.fbx",
	SLOT_BLOCK_HIT:   "shared/combat/block_hit.fbx",
	SLOT_PARRY:       "shared/combat/parry.fbx",
	SLOT_ATTACK_BASIC: "shared/combat/attack_basic.fbx",
}

# --- Per-class slot tables ---
# Each class owns a dict[slot] -> file_under_classes_dir. The slot can be
# any constant above OR a class-specific composite slot like
# &"breath_form_1" or &"spell_3".
const CLASS_SLOTS := {
	&"berserker": {
		SLOT_ATTACK_HEAVY:    "berserker/fury_swing.fbx",
		SLOT_ATTACK_COMBO_1:  "berserker/cleave_1.fbx",
		SLOT_ATTACK_COMBO_2:  "berserker/cleave_2.fbx",
		SLOT_ATTACK_COMBO_3:  "berserker/cleave_finisher.fbx",
		&"charge":            "berserker/charge.fbx",
		&"war_cry":           "berserker/war_cry.fbx",
		&"leap_smash":        "berserker/leap_smash.fbx",
		&"axe_throw":         "berserker/axe_throw.fbx",
		&"ground_pound":      "berserker/ground_pound.fbx",
	},
	&"assassin": {
		SLOT_ATTACK_COMBO_1:  "assassin/dagger_1.fbx",
		SLOT_ATTACK_COMBO_2:  "assassin/dagger_2.fbx",
		SLOT_ATTACK_COMBO_3:  "assassin/dagger_3.fbx",
		&"stealth_in":        "assassin/stealth_in.fbx",
		&"stealth_out":       "assassin/stealth_out.fbx",
		&"backstab":          "assassin/backstab.fbx",
		&"throw_kunai":       "assassin/throw_kunai.fbx",
		&"blink_dash":        "assassin/blink_dash.fbx",
	},
	&"ronin": {
		# 7 representative breathing forms (full 49 unlock progressively)
		&"breath_form_1":     "ronin/breath_water.fbx",
		&"breath_form_2":     "ronin/breath_thunder.fbx",
		&"breath_form_3":     "ronin/breath_flame.fbx",
		&"breath_form_4":     "ronin/breath_wind.fbx",
		&"breath_form_5":     "ronin/breath_stone.fbx",
		&"breath_form_6":     "ronin/breath_moon.fbx",
		&"breath_form_7":     "ronin/breath_sun.fbx",
		&"katana_idle":       "ronin/katana_idle.fbx",
		&"sheathe":           "ronin/sheathe.fbx",
		&"unsheathe":         "ronin/unsheathe.fbx",
		&"iai_strike":        "ronin/iai_strike.fbx",
		SLOT_PARRY:           "ronin/parry.fbx",
		SLOT_RIPOSTE:         "ronin/riposte.fbx",
	},
	&"ranger": {
		&"bow_idle":          "ranger/bow_idle.fbx",
		&"bow_draw":          "ranger/bow_draw.fbx",
		&"bow_release":       "ranger/bow_release.fbx",
		&"bow_snipe":         "ranger/bow_snipe.fbx",
		&"hawk_command":      "ranger/hawk_command.fbx",
		&"trap_set":          "ranger/trap_set.fbx",
	},
	&"mage": {
		SLOT_CAST_LOOP:       "mage/cast_loop.fbx",
		SLOT_CAST_RELEASE:    "mage/cast_release.fbx",
		&"spell_1":           "mage/fireball.fbx",
		&"spell_2":           "mage/frost_nova.fbx",
		&"spell_3":           "mage/lightning_bolt.fbx",
		&"spell_4":           "mage/teleport.fbx",
		&"spell_5":           "mage/meteor.fbx",
		&"staff_strike":      "mage/staff_strike.fbx",
		&"channel_idle":      "mage/channel_idle.fbx",
	},
	&"chaos_druid": {
		&"shapeshift_in":     "chaos_druid/shapeshift_in.fbx",
		&"shapeshift_out":    "chaos_druid/shapeshift_out.fbx",
		&"druid_idle":        "chaos_druid/druid_idle.fbx",
		&"totem_plant":       "chaos_druid/totem_plant.fbx",
		&"vine_lash":         "chaos_druid/vine_lash.fbx",
		&"bear_swipe":        "chaos_druid/bear_swipe.fbx",
		&"wolf_pounce":       "chaos_druid/wolf_pounce.fbx",
	},
	&"demon": {
		&"demon_idle":        "demon/demon_idle.fbx",
		&"demon_claw":        "demon/claw_rake.fbx",
		&"demon_wing_flap":   "demon/wing_flap.fbx",
		&"demon_burst":       "demon/hellfire_burst.fbx",
		&"demon_drain":       "demon/soul_drain.fbx",
		&"demon_glide":       "demon/wing_glide.fbx",
	},
	&"paladin_guardian": {
		&"shield_block":      "paladin_guardian/shield_block.fbx",
		&"shield_bash":       "paladin_guardian/shield_bash.fbx",
		&"holy_smite":        "paladin_guardian/sword_smite.fbx",
		&"holy_pillar":       "paladin_guardian/holy_pillar.fbx",
		&"judgment_strike":   "paladin_guardian/judgment_strike.fbx",
		&"kneel_pray":        "paladin_guardian/kneel_pray.fbx",
	},
	&"paladin_lightbringer": {
		&"holy_blessing":     "paladin_lightbringer/blessing_cast.fbx",
		&"holy_sun_beam":     "paladin_lightbringer/sun_beam.fbx",
		&"holy_aura":         "paladin_lightbringer/healing_aura.fbx",
		&"holy_shield":       "paladin_lightbringer/divine_shield.fbx",
		&"mace_swing":        "paladin_lightbringer/mace_swing.fbx",
		&"hymn_idle":         "paladin_lightbringer/hymn_idle.fbx",
	},
}

# --- Mob slot tables ---
# Each mob just needs idle/walk/run/attack/hit/death; everything else
# falls through to the shared library.
const MOB_SLOTS := {
	&"usurper_footman": {
		SLOT_ATTACK_BASIC:    "usurper_footman/spear_thrust.fbx",
		&"shield_raise":      "usurper_footman/shield_raise.fbx",
	},
	&"usurper_archer": {
		&"bow_draw":          "usurper_archer/bow_draw.fbx",
		&"bow_release":       "usurper_archer/bow_release.fbx",
	},
	&"raider_grunt": {
		SLOT_ATTACK_BASIC:    "raider_grunt/club_swing.fbx",
		SLOT_ATTACK_HEAVY:    "raider_grunt/overhead_smash.fbx",
	},
	&"raider_archer": {
		&"bow_draw":          "raider_archer/bow_draw.fbx",
		&"bow_release":       "raider_archer/bow_release.fbx",
	},
	&"shrine_acolyte": {
		SLOT_ATTACK_BASIC:    "shrine_acolyte/dagger_jab.fbx",
		&"chant":             "shrine_acolyte/chant.fbx",
	},
	&"binding_construct": {
		SLOT_ATTACK_BASIC:    "binding_construct/bone_swing.fbx",
		&"reanimate":         "binding_construct/reanimate.fbx",
	},
	&"blood_hunter": {
		SLOT_ATTACK_BASIC:    "blood_hunter/claw.fbx",
		&"feed":              "blood_hunter/feed.fbx",
	},
}

# --- Boss slot tables ---
# Bosses get attack pattern slots. Phase-2/Phase-3 are explicit slots so
# the boss AI can swap between them.
const BOSS_SLOTS := {
	&"usurper_enforcer": {
		&"phase_1_combo":     "usurper_enforcer/halberd_combo.fbx",
		&"phase_2_charge":    "usurper_enforcer/iron_charge.fbx",
		&"phase_3_quake":     "usurper_enforcer/iron_quake.fbx",
		&"intro_roar":        "usurper_enforcer/intro_roar.fbx",
	},
}

# --- NPC slot tables ---
# NPCs need talk loops, idle variations, vendor anims.
const NPC_SLOTS := {
	&"peasant_male": {
		&"talk":              "peasant_male/talk.fbx",
		&"sit":               "peasant_male/sit_chair.fbx",
		&"sweep":              "peasant_male/sweep.fbx",
	},
	&"peasant_female": {
		&"talk":              "peasant_female/talk.fbx",
		&"carry_basket":      "peasant_female/carry_basket.fbx",
	},
	&"ranger_npc": {
		&"talk":              "ranger_npc/talk.fbx",
		&"point":             "ranger_npc/point_directions.fbx",
	},
}

# --- Public API ---

func get_shared_slot_map() -> Dictionary:
	return SHARED_SLOTS

func get_class_slot_map(class_id: StringName) -> Dictionary:
	return CLASS_SLOTS.get(class_id, {})

func get_mob_slot_map(mob_id: StringName) -> Dictionary:
	return MOB_SLOTS.get(mob_id, {})

func get_boss_slot_map(boss_id: StringName) -> Dictionary:
	return BOSS_SLOTS.get(boss_id, {})

func get_npc_slot_map(npc_id: StringName) -> Dictionary:
	return NPC_SLOTS.get(npc_id, {})

# Resolve slot file -> absolute res:// path
func slot_to_path(relative: String) -> String:
	return "%s/%s" % [ANIM_ROOT, relative]

# Slot lookup that walks shared first, then character-specific.
# Returns "" if the slot is not declared anywhere.
func resolve_slot(slot: StringName, role: String, role_id: StringName) -> String:
	var role_map: Dictionary = {}
	match role:
		"class": role_map = get_class_slot_map(role_id)
		"mob":   role_map = get_mob_slot_map(role_id)
		"boss":  role_map = get_boss_slot_map(role_id)
		"npc":   role_map = get_npc_slot_map(role_id)
	if role_map.has(slot):
		return slot_to_path(role_map[slot])
	if SHARED_SLOTS.has(slot):
		return slot_to_path(SHARED_SLOTS[slot])
	return ""
