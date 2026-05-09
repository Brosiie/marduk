extends Node

# AnimationRegistry, autoload (added in project.godot autoload list).
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
# Directional locomotion variants (added for Mixamo's strafe / arc / turn anims)
const SLOT_WALK_BACK       := &"walk_back"
const SLOT_WALK_LEFT       := &"walk_left"
const SLOT_RUN_LEFT        := &"run_left"
const SLOT_TURN_RIGHT      := &"turn_right"
const SLOT_CHANGE_DIRECTION := &"change_direction"
const SLOT_RUN_TO_TURN     := &"run_to_turn"
const SLOT_DODGE_CORKSCREW := &"dodge_corkscrew"
# Directional death/hit variants (Mixamo distinguishes left/right/forward)
const SLOT_DEATH_FORWARD       := &"death_forward"
const SLOT_DEATH_REACT_FORWARD := &"death_react_forward"
const SLOT_DEATH_REACT_RIGHT   := &"death_react_right"
const SLOT_HIT_REACT_LEFT      := &"hit_react_left"
const SLOT_HIT_REACT_RIGHT     := &"hit_react_right"
# Unarmed variants for casters / NPCs
const SLOT_UNARMED_IDLE        := &"unarmed_idle"
const SLOT_UNARMED_IDLE_LOOK   := &"unarmed_idle_looking"
# Ronin greatsword/katana stance set
const SLOT_KATANA_IDLE     := &"katana_idle"
const SLOT_KATANA_BLOCKING := &"katana_blocking"
const SLOT_KATANA_180      := &"katana_180"
const SLOT_KATANA_IMPACT   := &"katana_impact"
const SLOT_KATANA_TURN     := &"katana_turn"
const SLOT_KATANA_STRAFE   := &"katana_strafe"
const SLOT_KATANA_POWER_UP := &"katana_power_up"
const SLOT_KATANA_JUMP_ATTACK := &"katana_jump_attack"
# Aerial / dive / 2H death slots (shared but expressive enough to deserve names)
const SLOT_AERIAL_EVADE    := &"aerial_evade"
const SLOT_DIVE_FORWARD    := &"dive_forward"
const SLOT_DEATH_2H        := &"death_2h"

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
	# --- Already on disk (Bond's drops) ---
	SLOT_IDLE:               "shared/locomotion/idle.glb",                # Standing Idle
	SLOT_RUN:                "shared/locomotion/run.glb",                 # Standing Run Forward
	SLOT_RUN_LEFT:           "shared/locomotion/run_left.glb",            # Standing Run Left
	SLOT_WALK_BACK:          "shared/locomotion/walk_back.glb",           # Standing Walk Back
	SLOT_WALK_LEFT:          "shared/locomotion/walk_left.glb",           # Standing Walk Left
	SLOT_TURN_RIGHT:         "shared/locomotion/turn_right.glb",          # Standing Turn Right 90
	SLOT_CHANGE_DIRECTION:   "shared/locomotion/change_direction.glb",    # Change Direction
	SLOT_RUN_TO_TURN:        "shared/locomotion/run_to_turn.glb",         # Running To Turn
	SLOT_DODGE_BACK:         "shared/locomotion/dodge_back.glb",          # Standing Dodge Backward
	SLOT_DODGE_CORKSCREW:    "shared/locomotion/dodge_corkscrew.glb",     # Corkscrew Evade
	SLOT_ATTACK_BASIC:       "shared/combat/attack_basic.glb",            # Sword And Shield Attack
	SLOT_BLOCK_IDLE:         "shared/combat/block_idle.glb",              # Standing Block Idle
	SLOT_HIT_REACT_LEFT:     "shared/reactions/hit_react_left.glb",       # Standing React Small From Left
	SLOT_HIT_REACT_RIGHT:    "shared/reactions/hit_react_right.glb",      # Standing React Small From Right
	SLOT_DEATH:              "shared/reactions/death.glb",                # Dying
	SLOT_DEATH_FORWARD:      "shared/reactions/death_forward.glb",        # Standing Death Forward 01
	SLOT_DEATH_REACT_FORWARD: "shared/reactions/death_react_forward.glb", # Standing React Death Forward
	SLOT_DEATH_REACT_RIGHT:  "shared/reactions/death_react_right.glb",    # Standing React Death Right
	SLOT_TAUNT:              "shared/utility/taunt_battlecry.glb",        # Standing Taunt Battlecry
	SLOT_STAND_UP:           "shared/utility/crouch_to_stand.glb",        # Crouch To Stand
	SLOT_UNARMED_IDLE:       "shared/utility/unarmed_idle.glb",           # Unarmed Idle
	SLOT_UNARMED_IDLE_LOOK:  "shared/utility/unarmed_idle_looking.glb",   # Unarmed Idle Looking Ver. 2

	# --- Bond's 2026-05-07 drop ---
	SLOT_DODGE_FWD:    "shared/locomotion/dodge_forward.glb",   # Standing Dodge Forward
	SLOT_DODGE_LEFT:   "shared/locomotion/dodge_left.glb",      # Standing Dodge Left
	SLOT_DODGE_RIGHT:  "shared/locomotion/dodge_right.glb",     # Standing Dodge Right
	SLOT_JUMP_DOWN:    "shared/locomotion/jump_land.glb",       # Falling -> Landing
	SLOT_AERIAL_EVADE: "shared/locomotion/aerial_evade.glb",    # Aerial Evade (jump-dodge)
	SLOT_DIVE_FORWARD: "shared/locomotion/dive_forward.glb",    # Standing Dive Forward
	SLOT_DEATH_2H:     "shared/reactions/death_2h.glb",         # Two Handed Sword Death

	# --- Not yet on disk; declared so Mixamo download targets are obvious ---
	SLOT_WALK:        "shared/locomotion/walk.glb",            # Walking
	SLOT_SPRINT:      "shared/locomotion/sprint.glb",          # Sprint
	SLOT_JUMP_UP:     "shared/locomotion/jump_up.glb",         # Jump
	SLOT_HIT_REACT:   "shared/reactions/hit_react.glb",        # Hit Reaction (generic)
	SLOT_STAGGER:     "shared/reactions/stagger.glb",          # Heavy Hit Reaction
	SLOT_KNOCKDOWN:   "shared/reactions/knockdown.glb",        # Falling Back Death (mid-loop)
	SLOT_GET_UP:      "shared/reactions/get_up.glb",           # Standing Up
	SLOT_DEATH_BACK:  "shared/reactions/death_back.glb",       # Falling Back Death
	SLOT_BLOCK_HIT:   "shared/combat/block_hit.glb",           # Sword And Shield Block Hit
	SLOT_PARRY:       "shared/combat/parry.glb",               # Standing Block (deflect)
}

# --- Per-class slot tables ---
# Each class owns a dict[slot] -> file_under_classes_dir. The slot can be
# any constant above OR a class-specific composite slot like
# &"breath_form_1" or &"spell_3".
const CLASS_SLOTS := {
	&"berserker": {
		SLOT_ATTACK_HEAVY:    "berserker/fury_swing.glb",
		SLOT_ATTACK_COMBO_1:  "berserker/cleave_1.glb",
		SLOT_ATTACK_COMBO_2:  "berserker/cleave_2.glb",
		SLOT_ATTACK_COMBO_3:  "berserker/cleave_finisher.glb",
		&"charge":            "berserker/charge.glb",
		&"war_cry":           "berserker/war_cry.glb",
		&"leap_smash":        "berserker/leap_smash.glb",
		&"axe_throw":         "berserker/axe_throw.glb",
		&"ground_pound":      "berserker/ground_pound.glb",
	},
	&"assassin": {
		SLOT_ATTACK_COMBO_1:  "assassin/dagger_1.glb",
		SLOT_ATTACK_COMBO_2:  "assassin/dagger_2.glb",
		SLOT_ATTACK_COMBO_3:  "assassin/dagger_3.glb",
		&"stealth_in":        "assassin/stealth_in.glb",
		&"stealth_out":       "assassin/stealth_out.glb",
		&"backstab":          "assassin/backstab.glb",
		&"throw_kunai":       "assassin/throw_kunai.glb",
		&"blink_dash":        "assassin/blink_dash.glb",
	},
	&"ronin": {
		# Greatsword stance set - on disk:
		#   katana_idle, katana_blocking, katana_180, katana_impact (initial drop)
		#   katana_walk, katana_run, katana_turn, katana_strafe         (2026-05-07 drop)
		#   katana_power_up, katana_jump_attack                          (2026-05-07 drop)
		SLOT_KATANA_IDLE:        "ronin/katana_idle.glb",       # Great Sword Idle
		SLOT_KATANA_BLOCKING:    "ronin/katana_blocking.glb",   # Great Sword Blocking
		SLOT_KATANA_180:         "ronin/katana_180.glb",        # Great Sword 180 Turn
		SLOT_KATANA_IMPACT:      "ronin/katana_impact.glb",     # Great Sword Impact
		SLOT_KATANA_TURN:        "ronin/katana_turn.glb",       # Great Sword Turn (smooth pivot)
		SLOT_KATANA_STRAFE:      "ronin/katana_strafe.glb",     # Great Sword Strafe
		SLOT_KATANA_POWER_UP:    "ronin/katana_power_up.glb",   # Great Sword Power Up (buff/cast)
		SLOT_KATANA_JUMP_ATTACK: "ronin/katana_jump_attack.glb",# Great Sword Jump Attack (downward slam)
		# Override shared locomotion so Ronin moves in katana stance,
		# not unarmed run/walk. Visible in any Ronin scene.
		SLOT_IDLE:               "ronin/katana_idle.glb",
		SLOT_WALK:               "ronin/katana_walk.glb",       # Great Sword Walk
		SLOT_RUN:                "ronin/katana_run.glb",        # Great Sword Run
		# 7 representative breathing forms (full 49 unlock progressively)
		&"breath_form_1":     "ronin/breath_water.glb",
		&"breath_form_2":     "ronin/breath_thunder.glb",
		&"breath_form_3":     "ronin/breath_flame.glb",
		&"breath_form_4":     "ronin/breath_wind.glb",
		&"breath_form_5":     "ronin/breath_stone.glb",
		&"breath_form_6":     "ronin/breath_moon.glb",
		&"breath_form_7":     "ronin/breath_sun.glb",
		&"sheathe":           "ronin/sheathe.glb",
		&"unsheathe":         "ronin/unsheathe.glb",
		&"iai_strike":        "ronin/iai_strike.glb",
		SLOT_RIPOSTE:         "ronin/riposte.glb",
	},
	&"ranger": {
		&"bow_idle":          "ranger/bow_idle.glb",
		&"bow_draw":          "ranger/bow_draw.glb",
		&"bow_release":       "ranger/bow_release.glb",
		&"bow_snipe":         "ranger/bow_snipe.glb",
		&"hawk_command":      "ranger/hawk_command.glb",
		&"trap_set":          "ranger/trap_set.glb",
	},
	&"mage": {
		SLOT_CAST_LOOP:       "mage/cast_loop.glb",
		SLOT_CAST_RELEASE:    "mage/cast_release.glb",
		&"spell_1":           "mage/fireball.glb",
		&"spell_2":           "mage/frost_nova.glb",
		&"spell_3":           "mage/lightning_bolt.glb",
		&"spell_4":           "mage/teleport.glb",
		&"spell_5":           "mage/meteor.glb",
		&"staff_strike":      "mage/staff_strike.glb",
		&"channel_idle":      "mage/channel_idle.glb",
	},
	&"chaos_druid": {
		&"shapeshift_in":     "chaos_druid/shapeshift_in.glb",
		&"shapeshift_out":    "chaos_druid/shapeshift_out.glb",
		&"druid_idle":        "chaos_druid/druid_idle.glb",
		&"totem_plant":       "chaos_druid/totem_plant.glb",
		&"vine_lash":         "chaos_druid/vine_lash.glb",
		&"bear_swipe":        "chaos_druid/bear_swipe.glb",
		&"wolf_pounce":       "chaos_druid/wolf_pounce.glb",
	},
	&"demon": {
		&"demon_idle":        "demon/demon_idle.glb",
		&"demon_claw":        "demon/claw_rake.glb",
		&"demon_wing_flap":   "demon/wing_flap.glb",
		&"demon_burst":       "demon/hellfire_burst.glb",
		&"demon_drain":       "demon/soul_drain.glb",
		&"demon_glide":       "demon/wing_glide.glb",
	},
	&"paladin_guardian": {
		&"shield_block":      "paladin_guardian/shield_block.glb",
		&"shield_bash":       "paladin_guardian/shield_bash.glb",
		&"holy_smite":        "paladin_guardian/sword_smite.glb",
		&"holy_pillar":       "paladin_guardian/holy_pillar.glb",
		&"judgment_strike":   "paladin_guardian/judgment_strike.glb",
		&"kneel_pray":        "paladin_guardian/kneel_pray.glb",
	},
	&"paladin_lightbringer": {
		&"holy_blessing":     "paladin_lightbringer/blessing_cast.glb",
		&"holy_sun_beam":     "paladin_lightbringer/sun_beam.glb",
		&"holy_aura":         "paladin_lightbringer/healing_aura.glb",
		&"holy_shield":       "paladin_lightbringer/divine_shield.glb",
		&"mace_swing":        "paladin_lightbringer/mace_swing.glb",
		&"hymn_idle":         "paladin_lightbringer/hymn_idle.glb",
	},
}

# --- Mob slot tables ---
# Each mob just needs idle/walk/run/attack/hit/death; everything else
# falls through to the shared library.
const MOB_SLOTS := {
	&"usurper_footman": {
		SLOT_ATTACK_BASIC:    "usurper_footman/spear_thrust.glb",
		&"shield_raise":      "usurper_footman/shield_raise.glb",
	},
	&"usurper_archer": {
		&"bow_draw":          "usurper_archer/bow_draw.glb",
		&"bow_release":       "usurper_archer/bow_release.glb",
	},
	&"raider_grunt": {
		SLOT_ATTACK_BASIC:    "raider_grunt/club_swing.glb",
		SLOT_ATTACK_HEAVY:    "raider_grunt/overhead_smash.glb",
	},
	&"raider_archer": {
		&"bow_draw":          "raider_archer/bow_draw.glb",
		&"bow_release":       "raider_archer/bow_release.glb",
	},
	&"shrine_acolyte": {
		SLOT_ATTACK_BASIC:    "shrine_acolyte/dagger_jab.glb",
		&"chant":             "shrine_acolyte/chant.glb",
	},
	&"binding_construct": {
		SLOT_ATTACK_BASIC:    "binding_construct/bone_swing.glb",
		&"reanimate":         "binding_construct/reanimate.glb",
	},
	&"blood_hunter": {
		SLOT_ATTACK_BASIC:    "blood_hunter/claw.glb",
		&"feed":              "blood_hunter/feed.glb",
	},
}

# --- Boss slot tables ---
# Bosses get attack pattern slots. Phase-2/Phase-3 are explicit slots so
# the boss AI can swap between them.
const BOSS_SLOTS := {
	&"usurper_enforcer": {
		&"phase_1_combo":     "usurper_enforcer/halberd_combo.glb",
		&"phase_2_charge":    "usurper_enforcer/iron_charge.glb",
		&"phase_3_quake":     "usurper_enforcer/iron_quake.glb",
		&"intro_roar":        "usurper_enforcer/intro_roar.glb",
	},
}

# --- NPC slot tables ---
# NPCs need talk loops, idle variations, vendor anims.
const NPC_SLOTS := {
	&"peasant_male": {
		&"talk":              "peasant_male/talk.glb",
		&"sit":               "peasant_male/sit_chair.glb",
		&"sweep":             "peasant_male/sweep.glb",
	},
	&"peasant_female": {
		# Catwalk anim set, Bond's drops, lands as runway-style female NPC loops.
		# Override shared SLOT_IDLE/SLOT_WALK so feminine NPCs use these instead.
		SLOT_IDLE:            "peasant_female/idle.glb",          # Catwalk Idle Twist R
		SLOT_WALK:            "peasant_female/walk.glb",          # Catwalk Walk Forward 02
		&"walk_turn":         "peasant_female/walk_turn.glb",     # Catwalk Walk Forward Arc 90R
		&"talk":              "peasant_female/talk.glb",
		&"carry_basket":      "peasant_female/carry_basket.glb",
	},
	&"ranger_npc": {
		&"talk":              "ranger_npc/talk.glb",
		&"point":             "ranger_npc/point_directions.glb",
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
