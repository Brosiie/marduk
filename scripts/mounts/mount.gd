extends Resource
class_name Mount

# A ground-only mount. Doubles movement speed (+100%). Cannot be used in combat
# or in dungeons (Bond's design: mounts are travel-tier convenience).
#
# Pay-to-play: each mount has a price_usd. Purchase routes through the Cloudflare
# /v1/store endpoint. Ownership stored as permanent SaveFlag `mount_owned_<id>`.
# Owned mounts persist forever, including across prestige cycles.

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var lore: String = ""
@export var icon: Texture2D
@export var mesh_scene: PackedScene

@export_group("Mechanics")
@export var move_speed_multiplier: float = 2.0     # +100% speed
@export var stamina_drain_per_sec: float = 0.0     # 0 = no upkeep
@export var allowed_in_dungeons: bool = false
@export var allowed_in_pvp: bool = false
@export var dismiss_on_combat: bool = true         # combat enters = mount despawns

@export_group("Pricing")
@export var price_usd: float = 4.99                # one-time purchase
@export var is_starter_free: bool = false          # one mount free at level 5

@export_group("Visual")
@export var preview_animation: StringName = &"mount_idle"
@export var summon_vfx_color: Color = Color.WHITE
