"""
Marduk — procedural placeholder mesh generator.

Run inside Blender's Scripting workspace, or headless:
    blender --background --python generate_placeholders.py

Generates one .glb per item category with rarity-tinted materials.
Output: ~/marduk/blender/exports/<category>/<item_id>.glb

This is Tier 1 of the asset pipeline (see CHARACTER_DESIGN.md § 5).
Hand-modeled hero assets replace these in Tier 2.
"""

import bpy
import bmesh
import os
import math
from mathutils import Vector

# -----------------------------------------------------------------------------
# Paths
# -----------------------------------------------------------------------------
HOME = os.path.expanduser("~")
EXPORT_ROOT = os.path.join(HOME, "marduk", "blender", "exports")

# -----------------------------------------------------------------------------
# Rarity color table (matches Item.rarity_color() in GDScript)
# -----------------------------------------------------------------------------
RARITY_COLORS = {
    "JUNK":      (0.45, 0.45, 0.45, 1.0),
    "BASIC":     (0.65, 0.65, 0.65, 1.0),
    "COMMON":    (0.30, 0.85, 0.30, 1.0),
    "RARE":      (0.30, 0.55, 1.00, 1.0),
    "VERY_RARE": (0.70, 0.30, 1.00, 1.0),
    "LEGENDARY": (1.00, 0.78, 0.20, 1.0),
    "HEAVEN":    (1.00, 1.00, 1.00, 1.0),
}

EMISSION_BY_RARITY = {
    "JUNK": 0.0, "BASIC": 0.0, "COMMON": 0.0,
    "RARE": 0.4, "VERY_RARE": 0.8, "LEGENDARY": 1.5, "HEAVEN": 3.0,
}

# -----------------------------------------------------------------------------
# Item catalog — extracted from item_registry.gd (see EQUIPMENT_VISUAL.md)
# Format: { item_id: ("category", "rarity", optional_kwargs) }
# -----------------------------------------------------------------------------
CATALOG = {
    # Swords
    "sword_iron":         ("swords", "BASIC"),
    "sword_steel":        ("swords", "COMMON"),
    "sword_temple":       ("swords", "COMMON"),
    "sword_silver_edge":  ("swords", "RARE"),
    "sword_lapis":        ("swords", "RARE"),
    "sword_pirate_kings": ("swords", "VERY_RARE"),
    "sword_etemenanki":   ("swords", "VERY_RARE"),

    # Greatswords
    "greatsword_iron":      ("greatswords", "BASIC"),
    "greatsword_butcher":   ("greatswords", "COMMON"),
    "greatsword_kingu_brand":("greatswords", "RARE"),
    "greatsword_ennum_lost":("greatswords", "VERY_RARE"),
    "greatsword_sun_edge":  ("greatswords", "VERY_RARE"),

    # Axes
    "axe_iron_hand":  ("axes", "BASIC"),
    "axe_steel":      ("axes", "COMMON"),
    "axe_blood_iron": ("axes", "RARE"),
    "axe_steppe_skull":("axes", "RARE"),

    # Greataxes
    "greataxe_iron":         ("greataxes", "BASIC"),
    "greataxe_steppe":       ("greataxes", "COMMON"),
    "greataxe_throat_eater": ("greataxes", "RARE"),
    "greataxe_hassu_kin":    ("greataxes", "VERY_RARE"),

    # Bludgeons
    "mace_iron":             ("bludgeons", "BASIC"),
    "mace_flanged":          ("bludgeons", "COMMON"),
    "mace_inquisitor":       ("bludgeons", "RARE"),
    "mace_pillar_fragment":  ("bludgeons", "VERY_RARE"),

    # Great bludgeons
    "maul_iron":          ("great_bludgeons", "BASIC"),
    "maul_warhammer":     ("great_bludgeons", "COMMON"),
    "maul_mountain_splitter":("great_bludgeons", "RARE"),
    "maul_adad_lesser":   ("great_bludgeons", "VERY_RARE"),
    "hammer_iron":        ("great_bludgeons", "BASIC"),
    "hammer_lightbringers_mace":("great_bludgeons", "RARE"),
    "hammer_sun_brand":   ("great_bludgeons", "VERY_RARE"),
    "hammer_crown_warhammer":("great_bludgeons", "VERY_RARE"),

    # Staves
    "staff_apprentice":    ("staves", "BASIC"),
    "staff_inkstone":      ("staves", "COMMON"),
    "staff_lapis_drowned": ("staves", "RARE"),
    "staff_druid_thorn":   ("staves", "RARE"),
    "staff_pillar_thread": ("staves", "VERY_RARE"),

    # Wands
    "wand_apprentice":     ("wands", "BASIC"),
    "wand_burning_finger": ("wands", "COMMON"),
    "wand_lightning_call": ("wands", "RARE"),
    "wand_void_finger":    ("wands", "VERY_RARE"),

    # Katanas
    "katana_temple":            ("katanas", "BASIC"),
    "katana_water_disciple":    ("katanas", "COMMON"),
    "katana_kazat_iron":        ("katanas", "RARE"),
    "katana_flame_disciple":    ("katanas", "RARE"),
    "katana_thunder_disciple":  ("katanas", "RARE"),
    "katana_breathing_master":  ("katanas", "VERY_RARE"),

    # Nodachi
    "nodachi_temple":        ("nodachi", "COMMON"),
    "nodachi_constant_flow": ("nodachi", "RARE"),
    "nodachi_storm_walker":  ("nodachi", "VERY_RARE"),

    # Daggers
    "dagger_iron":            ("daggers", "BASIC"),
    "dagger_thieves_kitchen": ("daggers", "COMMON"),
    "dagger_whisper_initiate":("daggers", "RARE"),
    "dagger_five_mouth_pup":  ("daggers", "VERY_RARE"),

    # Bows
    "bow_short":       ("bows", "BASIC"),
    "bow_long":        ("bows", "COMMON"),
    "bow_storm":       ("bows", "RARE"),
    "bow_glade_widow": ("bows", "VERY_RARE"),

    # Crossbows
    "crossbow_simple":     ("crossbows", "BASIC"),
    "crossbow_repeater":   ("crossbows", "COMMON"),
    "crossbow_inquisitor": ("crossbows", "RARE"),

    # Throwing knives
    "throwing_iron":     ("throwing", "BASIC"),
    "throwing_serrated": ("throwing", "COMMON"),
    "throwing_silver":   ("throwing", "RARE"),
    "throwing_master":   ("throwing", "VERY_RARE"),

    # Shuriken
    "shuriken_iron":      ("shuriken", "BASIC"),
    "shuriken_lightning": ("shuriken", "RARE"),
    "shuriken_poisoned":  ("shuriken", "RARE"),

    # Polearms
    "polearm_spear":         ("polearms", "BASIC"),
    "polearm_glaive":        ("polearms", "COMMON"),
    "polearm_thorn_pike":    ("polearms", "RARE"),
    "polearm_kingu_lesser":  ("polearms", "VERY_RARE"),

    # Scythes
    "scythe_field":        ("scythes", "BASIC"),
    "scythe_blood_cradle": ("scythes", "RARE"),
    "scythe_lucifer_pup":  ("scythes", "VERY_RARE"),

    # Fists
    "fist_iron":         ("fists", "BASIC"),
    "fist_serpent_scale":("fists", "RARE"),

    # Whips
    "whip_leather":    ("whips", "BASIC"),
    "whip_inquisitor": ("whips", "RARE"),

    # Shields
    "shield_buckler":      ("shields", "BASIC"),
    "shield_kite":         ("shields", "COMMON"),
    "shield_tower":        ("shields", "RARE"),
    "shield_paladin_kite": ("shields", "RARE"),
    "shield_dawn_bulwark": ("shields", "VERY_RARE"),
    "shield_pillar_disc":  ("shields", "VERY_RARE"),

    # Books / Tomes
    "book_apprentice":     ("books", "BASIC"),
    "book_burning_pages":  ("books", "RARE"),
    "book_asaridu_left":   ("books", "VERY_RARE"),
    "tome_focus_clear":    ("tomes", "COMMON"),
    "tome_lapis_orb":      ("tomes", "RARE"),

    # Quivers
    "quiver_leather":     ("quivers", "COMMON"),
    "quiver_glade_widow": ("quivers", "VERY_RARE"),

    # Totems
    "totem_bone":        ("totems", "COMMON"),
    "totem_dragon_pup":  ("totems", "VERY_RARE"),

    # Helms
    "helm_leather":            ("helms", "BASIC"),
    "helm_iron":               ("helms", "COMMON"),
    "helm_circlet_apprentice": ("helms", "COMMON"),
    "helm_steppe_skull":       ("helms", "RARE"),
    "helm_inquisitor_hood":    ("helms", "RARE"),
    "helm_paladin_great":      ("helms", "RARE"),
    "helm_pillar_diadem":      ("helms", "VERY_RARE"),

    # Chests
    "chest_leather":          ("chests", "BASIC"),
    "chest_iron":             ("chests", "COMMON"),
    "chest_robe_apprentice":  ("chests", "COMMON"),
    "chest_water_disciple":   ("chests", "RARE"),
    "chest_kazat_iron_plate": ("chests", "RARE"),
    "chest_paladin_plate":    ("chests", "RARE"),
    "chest_lightbringer_mail":("chests", "RARE"),
    "chest_pillar_robe":      ("chests", "VERY_RARE"),

    # Legs
    "legs_leather_pants": ("legs", "BASIC"),
    "legs_iron_greaves":  ("legs", "COMMON"),
    "legs_hakama":        ("legs", "COMMON"),
    "legs_storm_walker":  ("legs", "RARE"),

    # Boots
    "boots_leather":    ("boots", "BASIC"),
    "boots_sabaton":    ("boots", "COMMON"),
    "boots_dancer":     ("boots", "RARE"),
    "boots_silent_step":("boots", "RARE"),

    # Gloves
    "gloves_leather":         ("gloves", "BASIC"),
    "gloves_iron_gauntlets":  ("gloves", "COMMON"),
    "gloves_archer":          ("gloves", "COMMON"),
    "gloves_burning_palm":    ("gloves", "VERY_RARE"),

    # Cloaks
    "cloak_traveler":    ("cloaks", "BASIC"),
    "cloak_mist_shroud": ("cloaks", "RARE"),
    "cloak_sun_bearer":  ("cloaks", "VERY_RARE"),

    # Belts
    "belt_leather":           ("belts", "BASIC"),
    "belt_war":               ("belts", "COMMON"),
    "belt_storm_girdle":      ("belts", "RARE"),
    "belt_pirate_kings_sash": ("belts", "VERY_RARE"),

    # Amulets
    "amulet_simple":      ("amulets", "BASIC"),
    "amulet_lapis_drop":  ("amulets", "RARE"),
    "amulet_sun_drop":    ("amulets", "RARE"),
    "amulet_storyteller": ("amulets", "VERY_RARE"),

    # Rings
    "ring_iron":             ("rings", "BASIC"),
    "ring_bronze_strength":  ("rings", "COMMON"),
    "ring_silver_dexterity": ("rings", "COMMON"),
    "ring_gold_intellect":   ("rings", "COMMON"),
    "ring_focus":            ("rings", "RARE"),
    "ring_blood":            ("rings", "RARE"),
    "ring_pillar_seal":      ("rings", "VERY_RARE"),
    "ring_kingu_marker":     ("rings", "VERY_RARE"),
}

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------
def clear_scene():
    """Wipe the current Blender scene to a clean slate."""
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    for mat in list(bpy.data.materials):
        bpy.data.materials.remove(mat)
    for mesh in list(bpy.data.meshes):
        bpy.data.meshes.remove(mesh)


def make_material(name, rarity):
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    color = RARITY_COLORS[rarity]
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Roughness"].default_value = 0.4
    bsdf.inputs["Metallic"].default_value = 0.7
    emission = EMISSION_BY_RARITY[rarity]
    if emission > 0:
        bsdf.inputs["Emission Color"].default_value = color
        bsdf.inputs["Emission Strength"].default_value = emission
    return mat


def add_object(obj_name, mesh):
    obj = bpy.data.objects.new(obj_name, mesh)
    bpy.context.collection.objects.link(obj)
    return obj


# -----------------------------------------------------------------------------
# Per-category mesh primitives
# -----------------------------------------------------------------------------
def build_sword(blade_len=0.9, blade_w=0.06, hilt_len=0.18):
    """1H sword: thin blade + crossguard + hilt + pommel."""
    bm = bmesh.new()
    # Blade — flat oblong
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=(blade_w, 0.015, blade_len), verts=bm.verts)
    bmesh.ops.translate(bm, vec=(0, 0, blade_len), verts=bm.verts)
    # Crossguard
    cguard_verts = bmesh.ops.create_cube(bm, size=1.0)["verts"]
    bmesh.ops.scale(bm, vec=(0.18, 0.04, 0.04), verts=cguard_verts)
    # Hilt
    hilt_verts = bmesh.ops.create_cube(bm, size=1.0)["verts"]
    bmesh.ops.scale(bm, vec=(0.04, 0.04, hilt_len), verts=hilt_verts)
    bmesh.ops.translate(bm, vec=(0, 0, -hilt_len), verts=hilt_verts)
    # Pommel
    pommel_verts = bmesh.ops.create_uvsphere(bm, u_segments=8, v_segments=6, radius=0.045)["verts"]
    bmesh.ops.translate(bm, vec=(0, 0, -hilt_len * 2), verts=pommel_verts)
    mesh = bpy.data.meshes.new("sword_mesh")
    bm.to_mesh(mesh)
    bm.free()
    return mesh


def build_greatsword():
    return build_sword(blade_len=1.4, blade_w=0.09, hilt_len=0.28)


def build_axe(head_w=0.28, head_h=0.24, haft_len=0.7):
    """1H axe: crescent head + haft."""
    bm = bmesh.new()
    # Head — wedge approximated by cube
    head = bmesh.ops.create_cube(bm, size=1.0)["verts"]
    bmesh.ops.scale(bm, vec=(head_w, 0.04, head_h), verts=head)
    bmesh.ops.translate(bm, vec=(head_w * 0.4, 0, haft_len * 0.85), verts=head)
    # Haft
    haft = bmesh.ops.create_cylinder(bm, segments=10, radius1=0.025, radius2=0.025, depth=haft_len)["verts"]
    bmesh.ops.translate(bm, vec=(0, 0, haft_len * 0.5), verts=haft)
    mesh = bpy.data.meshes.new("axe_mesh")
    bm.to_mesh(mesh)
    bm.free()
    return mesh


def build_greataxe():
    return build_axe(head_w=0.42, head_h=0.40, haft_len=1.3)


def build_bludgeon(head_r=0.10, haft_len=0.7):
    """Mace: round flanged head + haft."""
    bm = bmesh.new()
    head = bmesh.ops.create_uvsphere(bm, u_segments=10, v_segments=8, radius=head_r)["verts"]
    bmesh.ops.translate(bm, vec=(0, 0, haft_len), verts=head)
    haft = bmesh.ops.create_cylinder(bm, segments=10, radius1=0.025, radius2=0.025, depth=haft_len)["verts"]
    bmesh.ops.translate(bm, vec=(0, 0, haft_len * 0.5), verts=haft)
    mesh = bpy.data.meshes.new("bludgeon_mesh")
    bm.to_mesh(mesh)
    bm.free()
    return mesh


def build_great_bludgeon():
    return build_bludgeon(head_r=0.20, haft_len=1.4)


def build_staff(haft_len=1.6):
    """Staff: long shaft + crystal at top."""
    bm = bmesh.new()
    haft = bmesh.ops.create_cylinder(bm, segments=8, radius1=0.022, radius2=0.018, depth=haft_len)["verts"]
    bmesh.ops.translate(bm, vec=(0, 0, haft_len * 0.5), verts=haft)
    crystal = bmesh.ops.create_icosphere(bm, subdivisions=1, radius=0.07)["verts"]
    bmesh.ops.translate(bm, vec=(0, 0, haft_len + 0.05), verts=crystal)
    mesh = bpy.data.meshes.new("staff_mesh")
    bm.to_mesh(mesh)
    bm.free()
    return mesh


def build_wand(haft_len=0.4):
    bm = bmesh.new()
    shaft = bmesh.ops.create_cylinder(bm, segments=8, radius1=0.012, radius2=0.018, depth=haft_len)["verts"]
    bmesh.ops.translate(bm, vec=(0, 0, haft_len * 0.5), verts=shaft)
    tip = bmesh.ops.create_icosphere(bm, subdivisions=1, radius=0.035)["verts"]
    bmesh.ops.translate(bm, vec=(0, 0, haft_len + 0.02), verts=tip)
    mesh = bpy.data.meshes.new("wand_mesh")
    bm.to_mesh(mesh)
    bm.free()
    return mesh


def build_katana():
    """Katana: curved single-edge — approximated as slender slightly-bent oblong + tsuba + tsuka."""
    bm = bmesh.new()
    blade_len = 1.0
    # Blade slab
    blade = bmesh.ops.create_cube(bm, size=1.0)["verts"]
    bmesh.ops.scale(bm, vec=(0.04, 0.018, blade_len), verts=blade)
    bmesh.ops.translate(bm, vec=(0, 0, blade_len), verts=blade)
    # Tsuba (round guard)
    tsuba = bmesh.ops.create_cylinder(bm, segments=12, radius1=0.07, radius2=0.07, depth=0.014)["verts"]
    # Tsuka (handle wrap)
    tsuka = bmesh.ops.create_cube(bm, size=1.0)["verts"]
    bmesh.ops.scale(bm, vec=(0.03, 0.05, 0.20), verts=tsuka)
    bmesh.ops.translate(bm, vec=(0, 0, -0.20), verts=tsuka)
    mesh = bpy.data.meshes.new("katana_mesh")
    bm.to_mesh(mesh)
    bm.free()
    return mesh


def build_nodachi():
    bm = bmesh.new()
    blade_len = 1.5
    blade = bmesh.ops.create_cube(bm, size=1.0)["verts"]
    bmesh.ops.scale(bm, vec=(0.05, 0.020, blade_len), verts=blade)
    bmesh.ops.translate(bm, vec=(0, 0, blade_len), verts=blade)
    tsuba = bmesh.ops.create_cylinder(bm, segments=12, radius1=0.085, radius2=0.085, depth=0.016)["verts"]
    tsuka = bmesh.ops.create_cube(bm, size=1.0)["verts"]
    bmesh.ops.scale(bm, vec=(0.035, 0.06, 0.32), verts=tsuka)
    bmesh.ops.translate(bm, vec=(0, 0, -0.32), verts=tsuka)
    mesh = bpy.data.meshes.new("nodachi_mesh")
    bm.to_mesh(mesh)
    bm.free()
    return mesh


def build_dagger():
    return build_sword(blade_len=0.32, blade_w=0.04, hilt_len=0.10)


def build_bow(arc=1.4):
    """Bow: simple curved arc — torus segment."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=0.04)  # tiny grip
    # Arms — two cylinders angled up/down
    upper = bmesh.ops.create_cylinder(bm, segments=8, radius1=0.018, radius2=0.005, depth=arc * 0.5)["verts"]
    bmesh.ops.rotate(bm, verts=upper, cent=(0, 0, 0),
                     matrix=bpy.data.objects.new("_t", None).rotation_euler.to_matrix())
    bmesh.ops.translate(bm, vec=(0, 0, arc * 0.25), verts=upper)
    lower = bmesh.ops.create_cylinder(bm, segments=8, radius1=0.018, radius2=0.005, depth=arc * 0.5)["verts"]
    bmesh.ops.translate(bm, vec=(0, 0, -arc * 0.25), verts=lower)
    mesh = bpy.data.meshes.new("bow_mesh")
    bm.to_mesh(mesh)
    bm.free()
    return mesh


def build_crossbow():
    bm = bmesh.new()
    stock = bmesh.ops.create_cube(bm, size=1.0)["verts"]
    bmesh.ops.scale(bm, vec=(0.06, 0.04, 0.5), verts=stock)
    prod = bmesh.ops.create_cube(bm, size=1.0)["verts"]
    bmesh.ops.scale(bm, vec=(0.5, 0.02, 0.04), verts=prod)
    bmesh.ops.translate(bm, vec=(0, 0, 0.22), verts=prod)
    mesh = bpy.data.meshes.new("crossbow_mesh")
    bm.to_mesh(mesh)
    bm.free()
    return mesh


def build_throwing():
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=(0.025, 0.008, 0.10), verts=bm.verts)
    mesh = bpy.data.meshes.new("throwing_mesh")
    bm.to_mesh(mesh)
    bm.free()
    return mesh


def build_shuriken():
    bm = bmesh.new()
    # Four arms — cross
    a = bmesh.ops.create_cube(bm, size=1.0)["verts"]
    bmesh.ops.scale(bm, vec=(0.10, 0.005, 0.02), verts=a)
    b = bmesh.ops.create_cube(bm, size=1.0)["verts"]
    bmesh.ops.scale(bm, vec=(0.02, 0.005, 0.10), verts=b)
    mesh = bpy.data.meshes.new("shuriken_mesh")
    bm.to_mesh(mesh)
    bm.free()
    return mesh


def build_polearm():
    bm = bmesh.new()
    haft = bmesh.ops.create_cylinder(bm, segments=8, radius1=0.022, radius2=0.022, depth=1.8)["verts"]
    bmesh.ops.translate(bm, vec=(0, 0, 0.9), verts=haft)
    head = bmesh.ops.create_cube(bm, size=1.0)["verts"]
    bmesh.ops.scale(bm, vec=(0.05, 0.03, 0.30), verts=head)
    bmesh.ops.translate(bm, vec=(0, 0, 1.95), verts=head)
    mesh = bpy.data.meshes.new("polearm_mesh")
    bm.to_mesh(mesh)
    bm.free()
    return mesh


def build_scythe():
    bm = bmesh.new()
    haft = bmesh.ops.create_cylinder(bm, segments=8, radius1=0.022, radius2=0.022, depth=1.5)["verts"]
    bmesh.ops.translate(bm, vec=(0, 0, 0.75), verts=haft)
    blade = bmesh.ops.create_cube(bm, size=1.0)["verts"]
    bmesh.ops.scale(bm, vec=(0.55, 0.02, 0.10), verts=blade)
    bmesh.ops.translate(bm, vec=(0.30, 0, 1.60), verts=blade)
    mesh = bpy.data.meshes.new("scythe_mesh")
    bm.to_mesh(mesh)
    bm.free()
    return mesh


def build_fist():
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=(0.10, 0.06, 0.10), verts=bm.verts)
    mesh = bpy.data.meshes.new("fist_mesh")
    bm.to_mesh(mesh)
    bm.free()
    return mesh


def build_whip():
    bm = bmesh.new()
    handle = bmesh.ops.create_cylinder(bm, segments=8, radius1=0.025, radius2=0.020, depth=0.25)["verts"]
    bmesh.ops.translate(bm, vec=(0, 0, 0.125), verts=handle)
    coil = bmesh.ops.create_uvsphere(bm, u_segments=8, v_segments=6, radius=0.10)["verts"]
    bmesh.ops.translate(bm, vec=(0, 0, 0.35), verts=coil)
    mesh = bpy.data.meshes.new("whip_mesh")
    bm.to_mesh(mesh)
    bm.free()
    return mesh


def build_shield():
    bm = bmesh.new()
    bmesh.ops.create_cylinder(bm, segments=24, radius1=0.40, radius2=0.40, depth=0.06)
    mesh = bpy.data.meshes.new("shield_mesh")
    bm.to_mesh(mesh)
    bm.free()
    return mesh


def build_book():
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=(0.20, 0.05, 0.28), verts=bm.verts)
    mesh = bpy.data.meshes.new("book_mesh")
    bm.to_mesh(mesh)
    bm.free()
    return mesh


def build_tome():
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=12, v_segments=10, radius=0.10)
    mesh = bpy.data.meshes.new("tome_mesh")
    bm.to_mesh(mesh)
    bm.free()
    return mesh


def build_quiver():
    bm = bmesh.new()
    bmesh.ops.create_cylinder(bm, segments=10, radius1=0.07, radius2=0.07, depth=0.45)
    mesh = bpy.data.meshes.new("quiver_mesh")
    bm.to_mesh(mesh)
    bm.free()
    return mesh


def build_totem():
    bm = bmesh.new()
    bmesh.ops.create_cylinder(bm, segments=8, radius1=0.05, radius2=0.07, depth=0.40)
    mesh = bpy.data.meshes.new("totem_mesh")
    bm.to_mesh(mesh)
    bm.free()
    return mesh


# Armor — placeholder volumes that approximate the slot's silhouette
def build_helm():
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=12, v_segments=8, radius=0.14)
    mesh = bpy.data.meshes.new("helm_mesh")
    bm.to_mesh(mesh)
    bm.free()
    return mesh


def build_chest():
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=(0.36, 0.20, 0.50), verts=bm.verts)
    mesh = bpy.data.meshes.new("chest_mesh")
    bm.to_mesh(mesh)
    bm.free()
    return mesh


def build_legs():
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=(0.30, 0.18, 0.50), verts=bm.verts)
    mesh = bpy.data.meshes.new("legs_mesh")
    bm.to_mesh(mesh)
    bm.free()
    return mesh


def build_boots():
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=(0.10, 0.10, 0.20), verts=bm.verts)
    mesh = bpy.data.meshes.new("boots_mesh")
    bm.to_mesh(mesh)
    bm.free()
    return mesh


def build_gloves():
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=(0.08, 0.06, 0.10), verts=bm.verts)
    mesh = bpy.data.meshes.new("gloves_mesh")
    bm.to_mesh(mesh)
    bm.free()
    return mesh


def build_cloak():
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=(0.36, 0.04, 0.65), verts=bm.verts)
    mesh = bpy.data.meshes.new("cloak_mesh")
    bm.to_mesh(mesh)
    bm.free()
    return mesh


def build_belt():
    bm = bmesh.new()
    bmesh.ops.create_cylinder(bm, segments=16, radius1=0.20, radius2=0.20, depth=0.06)
    mesh = bpy.data.meshes.new("belt_mesh")
    bm.to_mesh(mesh)
    bm.free()
    return mesh


def build_amulet():
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=10, v_segments=8, radius=0.04)
    mesh = bpy.data.meshes.new("amulet_mesh")
    bm.to_mesh(mesh)
    bm.free()
    return mesh


def build_ring():
    bm = bmesh.new()
    bmesh.ops.create_cylinder(bm, segments=16, radius1=0.025, radius2=0.025, depth=0.008)
    mesh = bpy.data.meshes.new("ring_mesh")
    bm.to_mesh(mesh)
    bm.free()
    return mesh


# -----------------------------------------------------------------------------
# Category dispatch table
# -----------------------------------------------------------------------------
BUILDERS = {
    "swords":          build_sword,
    "greatswords":     build_greatsword,
    "axes":            build_axe,
    "greataxes":       build_greataxe,
    "bludgeons":       build_bludgeon,
    "great_bludgeons": build_great_bludgeon,
    "staves":          build_staff,
    "wands":           build_wand,
    "katanas":         build_katana,
    "nodachi":         build_nodachi,
    "daggers":         build_dagger,
    "bows":            build_bow,
    "crossbows":       build_crossbow,
    "throwing":        build_throwing,
    "shuriken":        build_shuriken,
    "polearms":        build_polearm,
    "scythes":         build_scythe,
    "fists":           build_fist,
    "whips":           build_whip,
    "shields":         build_shield,
    "books":           build_book,
    "tomes":           build_tome,
    "quivers":         build_quiver,
    "totems":          build_totem,
    "helms":           build_helm,
    "chests":          build_chest,
    "legs":            build_legs,
    "boots":           build_boots,
    "gloves":          build_gloves,
    "cloaks":          build_cloak,
    "belts":           build_belt,
    "amulets":         build_amulet,
    "rings":           build_ring,
}

# -----------------------------------------------------------------------------
# Main pipeline
# -----------------------------------------------------------------------------
def export_one(item_id, category, rarity):
    builder = BUILDERS.get(category)
    if not builder:
        print(f"[skip] no builder for category {category}")
        return False
    clear_scene()
    mesh = builder()
    obj = add_object(item_id, mesh)
    mat = make_material(f"mat_{item_id}", rarity)
    obj.data.materials.append(mat)
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj

    out_dir = os.path.join(EXPORT_ROOT, category)
    os.makedirs(out_dir, exist_ok=True)
    out_path = os.path.join(out_dir, f"{item_id}.glb")
    bpy.ops.export_scene.gltf(
        filepath=out_path,
        export_format='GLB',
        use_selection=True,
        export_apply=True,
    )
    print(f"[ok] {category}/{item_id}.glb [{rarity}]")
    return True


def main():
    os.makedirs(EXPORT_ROOT, exist_ok=True)
    successes = 0
    failures = 0
    for item_id, spec in CATALOG.items():
        category, rarity = spec[0], spec[1]
        try:
            ok = export_one(item_id, category, rarity)
            if ok:
                successes += 1
            else:
                failures += 1
        except Exception as e:
            print(f"[ERR] {item_id}: {e}")
            failures += 1
    print("=" * 60)
    print(f"DONE — {successes} exported, {failures} failed")
    print(f"Output root: {EXPORT_ROOT}")


if __name__ == "__main__":
    main()
