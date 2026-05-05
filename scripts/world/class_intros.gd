extends RefCounted
class_name ClassIntros

# Maps class -> starter zone -> mini-boss -> convergence trigger.
#
# Each class begins in their unique intro zone (level 1-5). The mini-boss is the
# climax of the prologue. On its kill the player is at level ~5 and the convergence
# trigger sends them to Ashurim where they meet the other classes for the first time.

const INTRO_BY_CLASS := {
	&"berserker":            { "zone": &"ash_step_camp",   "mini_boss": &"raid_captain",       "title": "The Last of Ash-Step" },
	&"assassin":             { "zone": &"whisper_shrine",  "mini_boss": &"corrupt_master",     "title": "The Master's Lie" },
	&"ronin":                { "zone": &"sword_vow_ruins", "mini_boss": &"usurper_enforcer",   "title": "Sword Without Lord" },
	&"ranger":               { "zone": &"greenheart_glade","mini_boss": &"glade_terror",       "title": "The Spawn That Came Through" },
	&"mage":                 { "zone": &"inkstone_tower",  "mini_boss": &"tower_warden",       "title": "Pages and Ash" },
	&"chaos_druid":          { "zone": &"coven_glen",      "mini_boss": &"inquisitor_prime",   "title": "The Coven Burned" },
	&"paladin_guardian":     { "zone": &"sunsworn_chapel", "mini_boss": &"siege_master",       "title": "The Chapel Stood" },
	&"paladin_lightbringer": { "zone": &"sunsworn_chapel", "mini_boss": &"siege_master",       "title": "The Chapel Wept" },
	&"demon":                { "zone": &"pyre_ascent",     "mini_boss": &"self_that_said_yes", "title": "The Self That Said Yes" },
}

const ASHURIM_FLAG := &"reached_ashurim"
const CYCLE_BOSS_DEFEAT_PREFIX := "miniboss_"

static func intro_zone_for(class_id: StringName) -> StringName:
	var entry: Dictionary = INTRO_BY_CLASS.get(class_id, {})
	return entry.get("zone", &"")

static func mini_boss_for(class_id: StringName) -> StringName:
	var entry: Dictionary = INTRO_BY_CLASS.get(class_id, {})
	return entry.get("mini_boss", &"")

static func intro_title_for(class_id: StringName) -> String:
	var entry: Dictionary = INTRO_BY_CLASS.get(class_id, {})
	return entry.get("title", "")

# Mini-boss death wires here. Sets the run flag and triggers Ashurim convergence.
static func on_mini_boss_defeated(class_id: StringName) -> void:
	var boss_id: StringName = mini_boss_for(class_id)
	if boss_id != &"":
		SaveFlags.set_run(StringName("%s%s" % [CYCLE_BOSS_DEFEAT_PREFIX, boss_id]), true)
	# Mark prologue done; ZoneLoader / cutscene controller listens for this
	SaveFlags.set_run(&"prologue_complete", true)

static func has_completed_prologue() -> bool:
	return SaveFlags.has_run(&"prologue_complete")

static func ashurim_unlocked() -> bool:
	return has_completed_prologue() or SaveFlags.has_run(ASHURIM_FLAG)
