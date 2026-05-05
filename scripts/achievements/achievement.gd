extends Resource
class_name Achievement

# A player accomplishment. Carries trigger conditions, rewards, and lore flavor.
# Achievements never reset (permanent flag). They survive prestige.

enum Category {
	COMBAT,         # boss kills, mob kills, no-hit fights
	EXPLORATION,    # zones discovered, ruins examined, secrets found
	PROFESSIONS,    # smithing/mining/etc maxed
	STORY,          # quest completions, faction allegiances
	FEATS,          # speed runs, no-damage fights, prestige depth
	COLLECTION,     # rare drops, set completion
	META            # play time, cycle counter, collection mastery
}

enum TriggerKind {
	BOSS_DEFEATED,            # data: boss_id
	BOSS_DEFEATED_NO_HIT,     # data: boss_id
	BOSS_DEFEATED_UNDER_TIME, # data: { boss_id, seconds }
	BOSS_DEFEATED_AT_LEVEL,   # data: { boss_id, max_level }
	KILL_COUNT,               # data: { tag, count }; tag like "demon", "any"
	PROFESSION_MAXED,         # data: profession_id
	ALL_PROFESSIONS_MAXED,
	ZONE_DISCOVERED,          # data: zone_id
	ALL_ZONES_DISCOVERED,
	LANDMARK_EXAMINED,        # data: landmark_id
	QUEST_COMPLETED,          # data: quest_id
	PRESTIGE_REACHED,         # data: cycle_n
	ITEM_OBTAINED,            # data: item_id (Heaven, legendaries)
	CLASS_LEVEL_REACHED,      # data: { class_id, level }
	ALL_BREATHING_FORMS,      # Ronin: master all 49 breathing forms
	ALL_MAGE_SPELLS,          # Mage: unlock all 49 spells
	HIDDEN                    # tracked manually by gameplay code
}

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var category: Category = Category.COMBAT
@export var trigger: TriggerKind = TriggerKind.BOSS_DEFEATED
@export var trigger_data: Dictionary = {}
@export var hidden_until_unlocked: bool = false  # easter egg achievements

@export_group("Reward")
@export var awards_title_id: StringName = &""   # the Title to unlock
@export var xp_reward: int = 0
@export var gold_reward: int = 0
@export var skill_point_reward: int = 0
@export var item_reward_id: StringName = &""

@export_group("Lore")
@export_multiline var unlock_flavor: String = ""  # shown in popup when earned

func is_combat_feat() -> bool:
	return trigger in [
		TriggerKind.BOSS_DEFEATED_NO_HIT,
		TriggerKind.BOSS_DEFEATED_UNDER_TIME,
		TriggerKind.BOSS_DEFEATED_AT_LEVEL,
		TriggerKind.ALL_BREATHING_FORMS,
		TriggerKind.ALL_MAGE_SPELLS,
	]
