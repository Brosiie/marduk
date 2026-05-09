extends Resource
class_name Mob

# A non-boss enemy. Lives as data; spawning instantiates an EnemyBase scene
# and applies these stats. ~60 of these spread across zones, each carrying
# enough lore that a player who reads ALL the codex entries learns the world.

enum Role { GRUNT, ARCHER, CASTER, ELITE, RUSHER, SUPPORT, SUMMONER, SCOUT, TANK }
enum Tag { HUMAN, DEMON, UNDEAD, BEAST, SPAWN, CONSTRUCT, SPIRIT, INSECT }

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var lore: String = ""

@export_group("Role and Tags")
@export var role: Role = Role.GRUNT
@export var tags: Array[int] = []  # values from Tag enum

@export_group("Zone")
@export var home_zone: StringName = &""
@export var min_level: int = 1
@export var max_level: int = 5
@export var spawn_weight: float = 1.0  # for encounter table rolls

@export_group("Stats (base; level scales linearly)")
@export var base_hp: float = 60.0
@export var base_damage: float = 10.0
@export var base_armor: float = 4.0
@export var move_speed: float = 3.5
@export var attack_range: float = 1.8
@export var detect_radius: float = 9.0
@export var xp_reward: int = 25
@export var attack_cooldown: float = 1.6

@export_group("Loot")
@export var loot_table_id: StringName = &""
@export var unique_drop_id: StringName = &""
@export var unique_drop_chance: float = 0.0
