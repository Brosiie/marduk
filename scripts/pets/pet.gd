extends Resource
class_name Pet

# A non-combat companion. Most pets are purely cosmetic. The Yak is the singular
# exception: while a Yak is summoned, the player AND every party member gains
# +30 inventory bag slots while in range of the carrier.
#
# Pay-to-play. One free starter pet at level 3.

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var lore: String = ""
@export var icon: Texture2D
@export var mesh_scene: PackedScene

@export_group("Mechanics")
@export var inventory_bonus: int = 0       # Yak-only: +30
@export var party_share_radius: float = 30.0  # how far the bonus extends to party
@export var follow_distance: float = 2.5
@export var allowed_in_dungeons: bool = true   # Yak yes; cosmetics yes
@export var allowed_in_pvp: bool = true

@export_group("Pricing")
@export var price_usd: float = 2.99
@export var is_starter_free: bool = false

@export_group("Cosmetic")
@export var idle_animation: StringName = &"idle"
@export var follow_animation: StringName = &"walk"
@export var bark_sound_id: StringName = &""
