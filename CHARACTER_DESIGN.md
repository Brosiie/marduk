# Marduk — Character Design Master Spec

This is the design framework for every playable character, every weapon, every armor piece, every cosmetic option in the game. It's the source of truth for the modeling pipeline, the customization system, and the loot/drop maps.

---

## 1. Core Identity Decisions

These are foundational calls that ripple through everything else. Bond locked them 2026-05-08.

| Decision | Resolution |
|---|---|
| Race system | **5 races** mapped to Marduk's geographic regions (see § 2.5). Humans-adjacent ethnographic types, NOT Tolkien fantasy races. Demon = corrupted whatever-race, Druid forms = magical shapeshifts overlaying race. |
| Gender choice per class | **Male + Female** for every class. Both gender meshes ship per class (existing Mixamo meshes become the male OR female default per class; alternate gender mesh is a Phase 2 deliverable). Gender does NOT affect stats. Some cosmetics are gender-locked (beards male-only, certain hairstyles). |
| Customization depth | Preset-driven. **5 face presets, 8 hair styles, 6 hair colors, 5 skin tones (race-gated), 3 body types per gender.** Tighter than ESO sliders, looser than Diablo 4. |
| Transmog (glamour) | Yes. Unlocked at character level 10 via the Ashurim "Wardrobe-Master" NPC. Pay coin to apply any unlocked item's appearance over an equipped item. |
| Dye system | Yes, but limited. 12 dye colors per armor slot, applied at the same vendor as transmog. Some legendary items have a fixed scheme that resists dye. |
| Hide-headgear toggle | Yes, default on (helms hide automatically in cutscenes and Ashurim). |
| Cosmetic-only items | Yes. Achievement-locked appearances + prestige-tier-locked cosmetics drop from end-game sources. No stat impact. |
| Sun Breathing inheritance | Sun Breathing class **inherits** the originating Ronin character's race, gender, face, hair. Gi swaps to white-and-gold; sun-disc mempo permanent. Player can opt to re-create at unlock if they want a fresh look. |
| Demon visual transformation | **Pending Bond review.** Full spec in [DEMON_VISUAL_TRANSFORMATION.md](DEMON_VISUAL_TRANSFORMATION.md). Do not implement until approved. |
| Underwear / paper-doll base | Class-themed loincloth + chest-wrap; never fully nude. |

---

## 2. The Nine Playable Classes — Visual Identity

Each class has a single-sentence silhouette read, a primary color motif, weapon affinity, and armor philosophy. The character creator and equipment authoring all flow from these.

### Berserker
- **Silhouette:** Topless or fur-shoulder, two-handed weapon over the shoulder, war-paint on the chest. Reads as RAGE from across the screen.
- **Color motif:** Bone white + blood red + soot black.
- **Weapon affinity:** GREATAXE (signature), GREAT_BLUDGEON, GREATSWORD. Off-class fallback: AXE.
- **Armor:** PLATE (cap), but the look is exposed-skin even in plate — pauldrons, bracers, belt, no chest.
- **Customization tone:** scars are common, beards encouraged, war-paint a separate slot.

### Assassin
- **Silhouette:** Hood up, daggers reverse-grip, low crouch. Reads as PREDATOR.
- **Color motif:** Charcoal + venom green + brushed brass.
- **Weapon affinity:** DAGGER (signature, dual-wield by Phase 3), THROWING_KNIVES, SHURIKEN. Off-class: SWORD.
- **Armor:** LEATHER (cap). Hood is a permanent fixture; transmogging it off costs cosmetic coin.
- **Customization tone:** masks (cloth, brass, leather) are a separate cosmetic slot.

### Ronin
- **Silhouette:** Iai stance, single katana at the hip, hakama, half-tied topknot. Reads as DISCIPLINE.
- **Color motif:** Cobalt blue (Water) + bone + steel grey. Style-mastery shifts the trim color (Flame = orange, Thunder = yellow, etc.).
- **Weapon affinity:** KATANA (signature), NODACHI. Off-class: SWORD, POLEARM.
- **Armor:** LEATHER (cap). Ronin armor reads as Edo-period gi + brigandine, not full plate.
- **Customization tone:** topknots, mempo (face guards), and breath-trail color (cosmetic) tied to mastered style.

### Ranger
- **Silhouette:** Hood (lighter than Assassin), bow drawn, quiver visible at hip. Reads as PRECISION.
- **Color motif:** Forest green + fawn brown + bronze.
- **Weapon affinity:** BOW (signature), CROSSBOW, THROWING_KNIVES. Off-class: DAGGER, SWORD.
- **Armor:** LEATHER (cap). Wears a half-cape over one shoulder where the bow sits.
- **Customization tone:** war-paint on cheekbones, animal-bone trinkets, hair often braided.

### Mage
- **Silhouette:** Robe to the floor, staff vertical, hood OR diadem, sleeves bell-cut. Reads as ARCANE.
- **Color motif:** Royal purple + arcane teal + silver. Diverges per spell school: pyromancer = scarlet, cryomancer = ice white, stormcaller = brass-and-gold.
- **Weapon affinity:** STAFF (signature), WAND. Off-class: DAGGER (utility only).
- **Armor:** CLOTH (cap). Robes hide leg geometry below the knee.
- **Customization tone:** runic forearm tattoos, glowing-eye toggle (off by default), focus-crystal jewelry.

### Chaos Druid
- **Silhouette:** Antlers or wreath, asymmetric layered furs, totem on belt, barefoot or wrapped. Reads as WILD.
- **Color motif:** Moss green + bog brown + bone + the Wound's sickly violet (corruption indicator).
- **Weapon affinity:** STAFF (signature, gnarled wood), POLEARM, FIST. Off-class: SCYTHE.
- **Armor:** LEATHER (cap). Furs and bones layered over wrappings; never plate.
- **Customization tone:** body paint (woad/ash), beast-skull headdresses (cosmetic), shapeshift form is its own pseudo-customization (Wolf/Bear/Raven/Serpent appearance presets).

### Paladin Guardian
- **Silhouette:** Tower shield, one-handed mace or sword, full plate with tabard, helm closed. Reads as BULWARK.
- **Color motif:** White + sun-gold + steel.
- **Weapon affinity:** BLUDGEON (signature), SWORD. Off-class: GREAT_BLUDGEON, POLEARM. Always paired with SHIELD.
- **Armor:** PLATE (cap). Tabard is a separate cosmetic layer (faction sigils unlock as you progress).
- **Customization tone:** beard styles formal, helm permanently visible by default (toggleable).

### Paladin Lightbringer
- **Silhouette:** Mid-armor, two-handed maul or polearm, sun motif on chestplate, hair often loose. Reads as RIGHTEOUS FURY.
- **Color motif:** Cream + dawn-pink + brass.
- **Weapon affinity:** GREAT_BLUDGEON (signature), POLEARM. Off-class: BLUDGEON.
- **Armor:** MAIL (cap). More mobile silhouette than Guardian; cape rather than tabard.
- **Customization tone:** sun-tattoos on the cheek, hair styled long-and-loose by default, Holy element auras tied to Sun Breathing once unlocked.

### Demon (LOCKED — post-Lucifer)
- **Silhouette:** Hooves or clawed bare feet, horns, tattered bone-armor, weapon dripping blood. Reads as FALLEN.
- **Color motif:** Volcanic black + ember orange + arterial red.
- **Weapon affinity:** Any (Demon learns whatever the player carried in life). Default: SCYTHE or GREATSWORD.
- **Armor:** PLATE (cap). Demon armor is grown rather than worn — bone-plates fused into skin. Visual transformation on every armor swap (the same iron helm looks darker/sharper on a Demon).
- **Customization tone:** horn shape (5 presets), wing toggle (Wings of Lucifer ability cosmetic), eye color (red/black/gold), corruption-veins overlay intensity slider.

### Sun Breathing Class (LOCKED — post-Tiamat + 2 styles + lvl 18)
- **Silhouette:** Open-chested gi, single katana, sun-disc mempo on the brow. Reads as DAWN.
- **Color motif:** White + gold + ember.
- **Weapon affinity:** KATANA only. Cannot equip non-katana mainhand.
- **Armor:** LEATHER (cap). Same gi-style as Ronin but always white-and-gold trimmed.
- **Customization tone:** inherits Ronin customization; gains a permanent dawn-aura that pulses on combat.

---

## 2.5 The Five Races

Marduk is a Mesopotamian-mythic setting (Marduk vs Tiamat is straight from the Enuma Elish). Races are ethnographic types from the world's regions, not high-fantasy peoples. They are all human-or-near-human. Demon-class characters keep their pre-Lucifer race underneath the corruption (see DEMON_VISUAL_TRANSFORMATION.md).

Each race has:
- **Geographic origin** (which region/zone produced them)
- **Visual signature** (height, build, skin palette, face cast)
- **Stat lean** (small ±1 to ±2 nudge — never dominant; class drives the build)
- **Default class affinity** (which class lore-fits — visual suggestion in creator, NOT a gate)
- **Cultural cosmetics** (race-specific tattoos, jewelry, hair traditions)

All races can play all classes. Picking against the affinity is allowed and lore-supported (a Mountain-Forged Mage exists, just rarer in the world).

---

### Race 1 — Anunnaki-Blooded
*Babilim-born, the bloodline of the old kings. The Crown's nobility; the Inkstone temple's scholars.*

| Property | Value |
|---|---|
| Geographic origin | Babilim, the Iron Crown court, the Inkstone Sanctum |
| Height | 1.05× baseline (tallest race, but elegant rather than imposing) |
| Build | Slender, long-limbed, fine-boned |
| Skin palette | Pale gold to alabaster (5 tones, all warm-undertoned) |
| Hair | Black, dark brown, occasional silver-blonde (rare) |
| Eye colors | Hazel, amber, dark grey |
| Face cast | High cheekbones, straight noses, narrow chins |
| Stat lean | +1 Intellect, +1 Dexterity, -1 Strength |
| Class affinity | Mage, Paladin Lightbringer, Assassin |
| Cultural cosmetics | Kohl-lined eyes, gold forehead bindi, ear-lobe weights, calligraphy tattoos on the forearm |
| Voice tone | Measured, formal, the language of decree |

---

### Race 2 — Ash-Born
*Steppe people from the volcanic plains east of the Bone Mountains. Berserker country.*

| Property | Value |
|---|---|
| Geographic origin | The ash-steppes, the broken east |
| Height | 1.0× baseline |
| Build | Broad-shouldered, dense muscle, scar-prone |
| Skin palette | Olive-tan to weathered bronze (5 tones, neutral undertone) |
| Hair | Black, deep brown, often shaved at the sides; clan braids common |
| Eye colors | Black, brown, grey-flecked |
| Face cast | Wide jaw, broken-nose tradition (cultural; warriors break their own at coming-of-age) |
| Stat lean | +2 Strength, +1 Vitality, -1 Intellect |
| Class affinity | Berserker, Paladin Guardian, Demon (post-unlock) |
| Cultural cosmetics | Soot war-paint (5 patterns), ritual scarring on chest/arms, bone-and-tooth jewelry, beard-braiding for males |
| Voice tone | Low, clipped, syllables hammered |

---

### Race 3 — Reed-Walker
*Marsh nomads of the Reed Wastes; coastal salt-cracked traders of Lapis Bay. Two flavors of the same root stock.*

| Property | Value |
|---|---|
| Geographic origin | Reed Wastes, Lapis Bay, the deltas |
| Height | 0.98× baseline |
| Build | Lean, wiry, salt-weathered |
| Skin palette | Sun-darkened brown to deep umber (5 tones, cool undertone from sea-air) |
| Hair | Black to dark brown, often salt-bleached at the ends; long-and-loose tradition |
| Eye colors | Dark brown, hazel-green, rare sea-grey |
| Face cast | Sharp angular features, wind-narrowed eyes |
| Stat lean | +2 Dexterity, +1 Vitality, -1 Strength |
| Class affinity | Ronin, Ranger, Assassin, Sun Breathing |
| Cultural cosmetics | Reed-fiber bracelets, fish-scale beadwork, blue dye line under the eyes (sea-charm), shell-disc earrings |
| Voice tone | Carried, sing-song cadence, vowel-stretched |

---

### Race 4 — Mountain-Forged
*Smith-clans and miners from the Bone Mountains. Short, dense, beard-heavy. They built the Edict pillars before the Crown took credit.*

| Property | Value |
|---|---|
| Geographic origin | Bone Mountains, the deep forge-cities |
| Height | 0.85× baseline (shortest race, distinctly different proportions) |
| Build | Stocky, broad-chested, thick-limbed |
| Skin palette | Pale-cream to ruddy-tan (5 tones, soot-shadowed near the jaw and palms) |
| Hair | Reddish-brown to coal-black; thick beards mandatory cultural for males, plait-braids for females |
| Eye colors | Steel grey, deep blue, dark brown |
| Face cast | Wide nose, heavy brow, square jaw |
| Stat lean | +2 Vitality, +1 Strength, -1 Dexterity |
| Class affinity | Berserker, Paladin Guardian, Mage (rune-smiths), Chaos Druid |
| Cultural cosmetics | Forge-burn scars (decorative, etched in apprentice trials), iron beard-rings (male) or hair-rings (female), pillar-stone amulets |
| Voice tone | Deep, gravelly, words land like hammer-strikes |

---

### Race 5 — Wound-Marked
*Frontier folk born in the Verdant Wound — the corruption-blighted greenlands where the world bleeds chaos. Druid country.*

| Property | Value |
|---|---|
| Geographic origin | The Verdant Wound, the corruption-frontier villages |
| Height | 1.02× baseline (slightly tall, but gaunt) |
| Build | Hollow-cheeked, long-limbed, vine-rooted bone structure |
| Skin palette | Pale ash-grey with faint green undertone, to bog-pale (5 tones, all unhealthy-undertoned) |
| Hair | Moss green, ash-white, deep black, occasional vine-purple (Wound-touched) |
| Eye colors | Pale green, milk-white (Wound-touched), dark brown |
| Face cast | Hollow temples, long noses, thin lips, sometimes asymmetric (Wound-touched mutation) |
| Stat lean | +1 Intellect, +1 Dexterity, -1 Vitality |
| Class affinity | Chaos Druid, Mage (corruption school), Demon (post-unlock — already half-touched) |
| Cultural cosmetics | Woad body-paint (vine and antler patterns), bone-thorn piercings, antler hair-pins, scar-rune brands earned during the "Wound Survival" right-of-passage |
| Voice tone | Quiet, breathy, half-whispered |

---

### Race & Class — Default Pairings (visual suggestions, not gates)

The character creator highlights the lore-fit race for each class. Players can override; off-fit choices unlock cosmetic dialogue from NPCs ("You're far from the Bone Mountains, smith.").

| Class | Default Race | Why |
|---|---|---|
| Berserker | Ash-Born | Steppe country, ritual scarring, rage culture |
| Assassin | Reed-Walker | Coastal smuggler stock, lithe build, salt-cracked silence |
| Ronin | Reed-Walker | Six Breaths temple is on the Lapis Bay coast |
| Ranger | Reed-Walker | Wastes-and-coast nomads, bow tradition |
| Mage | Anunnaki-Blooded | Inkstone Sanctum scholars, court-trained |
| Chaos Druid | Wound-Marked | Born in the Wound, half-corrupted from infancy |
| Paladin Guardian | Anunnaki-Blooded | Crown's holy order, court-knight tradition |
| Paladin Lightbringer | Anunnaki-Blooded | Sun-cult priesthood, often noble-born |
| Demon (post-Lucifer) | (inherits prior race) | See DEMON_VISUAL_TRANSFORMATION.md |
| Sun Breather (post-Tiamat) | (inherits prior Ronin race) | Sun is a Ronin progression, never a fresh roll |

---

## 3. Customization System Spec

**File:** `scripts/player/character_appearance.gd` (Resource subclass — **TO BUILD**)

```
# Identity
@export var class_id: StringName        # which class this appearance belongs to
@export var race_id: StringName         # &"anunnaki" / &"ash_born" / &"reed_walker" / &"mountain_forged" / &"wound_marked"
@export var gender: StringName          # &"male" or &"female"

# Body
@export var body_type: int              # 0..2 (lean / athletic / bulk; gender-aware presets)
@export var skin_tone: int              # 0..4 (gated by race palette)
@export var height_scale: float         # 1.0 default; race-driven baseline applied separately

# Face & hair
@export var face_preset: int            # 0..4 (gender + race aware preset library)
@export var hair_style: int             # 0..7 (gender + race aware library)
@export var hair_color: int             # 0..5 (race-gated: Wound-Marked unlocks moss green, etc.)
@export var eye_color: int              # 0..4 (race-gated)
@export var beard_style: int            # 0..4 (male only; 0 = clean shaven)

# Overlays
@export var scar_overlay: int           # 0..3 (0 = none)
@export var warpaint_overlay: int       # 0..6 (0 = none; class+race specific)
@export var cultural_marking: int       # 0..4 (race-specific tattoos / body paint / piercings)
@export var jewelry_set: int            # 0..3 (race-specific cosmetic chains/rings/etc, no stats)

# Audio
@export var voice_pack: int             # 0..3 (per gender; race-tinted accent)

# Class-specific toggles
@export var glow_eyes: bool             # Mage/Sun-Breather toggle (Demon glow handled separately, see Demon spec)
@export var aura_intensity: float       # 0..1 for classes that have an aura (Sun, late-game Demon)
```

**File:** `scripts/player/appearance_registry.gd` (Autoload — **TO BUILD**)
- All preset textures and meshes registered in one place.
- Provides `apply_appearance(player_node, appearance)` to swap meshes/materials at runtime.

**Character creator UI** (`scenes/menus/character_creator.tscn` — **TO BUILD**)
- Class select on the left, preview on the right, sliders/preset buttons in the middle.
- Live preview rotates with mouse drag.

---

## 4. Equipment Visual Map

Every Item.id needs:
1. A 3D mesh for the ground drop (`mesh_scene` field on Item).
2. An attached-to-character mesh (when equipped — visible on player).
3. An icon (32x32 or 64x64 inventory display).

The current `ItemPickup._path_for_item()` falls back to KayKit props by `weapon_type`. **For Phase 2+, every Item needs its own dedicated mesh.**

See `EQUIPMENT_VISUAL.md` for the full per-item map (organized by slot and tier).

---

## 5. Authoring Pipeline

### Tier 1 — Procedural Placeholders (THIS SESSION)
Blender Python script generates a primitive mesh per weapon type and armor slot, color-coded by rarity. Drops into `assets/items/placeholder/`. Every Item.id resolves to one of these via category.

### Tier 2 — Hand-modeled per class signature gear (Phase 2-3)
Bond models the 9 class signature weapons (one per class) + the 4 main armor pieces per class (helm, chest, legs, boots). 9 × 5 = 45 hero-tier assets.

### Tier 3 — Per-rarity variation (Phase 4-5)
Common/Rare/Very Rare/Legendary visual variants per slot. Each tier above Common adds emission, gem inlay, or ornamental detail.

### Tier 4 — Legendaries with unique mechanics (Phase 5)
Heaven katana, Tiamat's Crown, etc. — fully bespoke, animated, with particle effects.

---

## 6. Mesh Attachment Bone Map

The Mixamo skeleton uses standard bone names. We attach equipment to:

| Slot | Bone | Notes |
|---|---|---|
| WEAPON_MAIN | `RightHand` (or `mixamorig_RightHand`) | Mainhand grip |
| WEAPON_OFFHAND | `LeftHand` | Shield, off-dagger, focus |
| HEAD | `Head` | Helm/hood mesh attaches and rotates with head |
| CHEST | `Spine2` | Layered armor mesh that follows torso |
| LEGS | `Hips` | Legging mesh follows pelvis |
| FEET | `LeftFoot` + `RightFoot` | Two attachments, mirrored |
| HANDS | `LeftHand` + `RightHand` | Glove mesh layered, weapons go ON TOP |
| BACK | `Spine2` (back-anchor) | Cloak with cloth physics |
| BELT | `Hips` | Wraps belt mesh |
| RING_LEFT | `LeftHandIndex1` | Tiny mesh on finger; toggleable visibility |
| RING_RIGHT | `RightHandIndex1` | Same |
| AMULET | `Neck` | Small mesh at throat |
| CHARM | (no visual attach) | Pure stat item |

---

## 7. Drop Coverage Map

Every Item.id needs a designated source. Currently many items have `unique_drop_source` set; common items roll from `LootGenerator` against zone level. **Audit needed:** which items have NO source assigned and would never drop in normal play? See `EQUIPMENT_VISUAL.md` for the audit table.

---

## 8. Build Order for the Customization Feature

1. **Author CHARACTER_DESIGN.md** ← THIS DOC (this session)
2. **Author EQUIPMENT_VISUAL.md** ← per-item mesh map (this session)
3. **Build placeholder meshes via Blender script** (this session)
4. **Build CharacterAppearance Resource + AppearanceRegistry** (next session)
5. **Build character creator UI scene** (next session)
6. **Wire appearance to player.gd `_attach_npc_mesh`-style hooks** (next session)
7. **Per-class signature weapon models in Blender** (Phase 2)
8. **Per-class armor sets** (Phase 2-3)
9. **Transmog + dye vendor in Ashurim** (Phase 3)
10. **Legendary unique-mesh authoring** (Phase 5)

---

## 8.4 The Heaven Rule (LOCKED 2026-05-08)

**Heaven does not bind to the fallen.** Demon-class characters cannot wield the Heaven katana. The class_restriction enforces this silently for non-Ronin classes; the Heaven Rule converts that silent reject into a meaningful one-way sacrifice for Demons.

### The Rule

When a Demon character attempts to **equip Heaven**:
1. The standard equip path detects Demon + Heaven mismatch
2. Instead of a silent reject, the Sacrifice Prompt fires
3. The player is given full information about what they will lose and what they may gain
4. They choose: **Walk Back** (sacrifice the Demon) or **Refuse** (keep the Demon, never wield Heaven)
5. The choice is **permanent**. The gate does not open twice.

### What "Walking Back" does

If the player accepts the sacrifice:
- The Demon class is **permanently locked** for this character (cannot become Demon again)
- The pre-Lucifer class is **restored** (whichever soul the player walked into Lucifer's gate as — see [DEMON_VISUAL_TRANSFORMATION.md § 2](DEMON_VISUAL_TRANSFORMATION.md))
- The pre-Lucifer skill tree is **restored** (preserved when the player became Demon)
- All Demon abilities, the Demon Q/E/R/F kit, the 49-node Demon skill tree progression are **stripped**
- The Demon visual overlay is **removed** (horns dissolve, veins fade, hooves/claws revert to mortal feet, eye glow off)
- The character is now mortal again
- **Save flag** `lucifer_walked_back: true` is set permanently on this character
- The character earns the title **"The Mortal Returned"** (or **"Twice-Walker"** — display variant)
- A faint white scar remains across the chest where the corruption used to live (cosmetic, permanent)

### What is preserved

The walk-back doesn't erase the character's history. These persist:
- Race, gender, face, body — everything that was them before Lucifer
- Combat scars (boss scars never fully heal)
- Tattoo glyphs (already-inscribed marks stay)
- Pact marks (the Demon made those promises; mortality doesn't break them)
- Inventory (except Demon-only items, which become uncarriable)
- XP and level
- Achievements
- The Mortal Echo NPC (§ 14 of Demon spec) — they merge with the player on this event; the Echo dialogue arc closes
- The Heaven katana — if the pre-Lucifer class was Ronin, Heaven now binds to them

### What is NOT regained by the sacrifice

If the pre-Lucifer class was **NOT Ronin**, the player walks back to a mortal Mage / Berserker / Druid / etc. — **Heaven still does not bind to them** (it remains Ronin-only). The sacrifice prompt makes this explicit upfront. Players who go through with it for a non-Ronin pre-Lucifer class do so for the lore choice, not the weapon.

### Why this is the right rule

- **Lore-aligned:** Heaven is the divine antithesis of Demonhood. The sword choosing a corrupted wielder breaks the entire mythology of the game.
- **Player agency with weight:** the choice is meaningful. Demon power is real (49-node tree, +200% damage at full Blood, lifesteal, day/night swing). Sacrificing it for Heaven means weighing decades of investment.
- **Inheritance pays off:** the prior-class choice at Demon creation now matters mechanically. A Demon-Ronin can pursue this arc; a Demon-Mage cannot reach Heaven through this path.
- **One-way doors are powerful storytelling:** "the gate does not open twice" is a phrase players will remember.

See [DEMON_VISUAL_TRANSFORMATION.md § 18](DEMON_VISUAL_TRANSFORMATION.md) for the technical Sacrifice Ritual spec.

---

## 8.5 Living Character Systems (Tier 2 — creative ideas)

The foundation systems above cover the basics: races, classes, customization, equipment. Tier 2 is what makes the character a *living artifact*. Every system here turns playtime into visible character history. Mark each SHIP / SKIP / DEFER.

These apply to **all classes**, not just Demon. The Demon-specific additions are in [DEMON_VISUAL_TRANSFORMATION.md § 12-16](DEMON_VISUAL_TRANSFORMATION.md).

---

### 8.5.1 Combat Scars
The character body shows what hit it. Hits that took ≥ 25% of max HP in a single blow leave a visible scar. Scars heal slowly over real time but persist if the player doesn't naturally regenerate.

- **Boss scars never fully heal** — they fade to silver lines but stay. A maxed character is visibly mapped with their kill list.
- Scars respect the originating element: fire scars are charred, frost scars are frostbitten-pale, shadow scars are ink-black, holy scars are gold-edged.
- Cosmetic-only. Players who hate the look can disable in Settings > Display > "Show Combat Scars: Off."
- Implementation: `ScarRegistry` tracks `(location, intensity, element, source_id)` per scar. Up to 16 visible at once, oldest fade first beyond that.

### 8.5.2 Tattoo Glyphs (the Codex of Marks)
First-time boss kills earn a **Glyph** — a unique geometric mark associated with that boss's identity. Glyphs can be **inscribed** as tattoos at any Inkstone Sanctum vendor.

- Each glyph is a small mesh + emission texture
- Costs gold + a token from that boss's drop table
- Tattoo location is player-choice (chest, back, arm, neck, leg, face)
- Inscribed glyphs grant a tiny stat bonus (+0.5% vs that boss's faction)
- Stack: a player can be covered in a sleeve of glyphs that tells their kill story
- PvP / party visibility: hovering over another player shows their glyph list as a tooltip

**This is huge for community.** Veterans become walking museums. New players learn the bestiary by reading vets' bodies.

### 8.5.3 Race-Specific Earned Cosmetics
Each race has a cultural progression that visually rewards engagement with race-themed content.

| Race | Earned cosmetic | Earned by |
|---|---|---|
| **Anunnaki-Blooded** | Royal Bearing — silver thread accents on hair, gold lining on robes, posture upright in idle anim | Complete Crown court quest line; +intimidation in noble dialogue |
| **Ash-Born** | Ritual Scars — visible scarification adds new patterns each major boss kill | Defeat 3 main-tier bosses on this character |
| **Reed-Walker** | Salt-Crust Accents — sea-air weathered face, fish-scale beadwork in hair | 50+ hours played in coastal/marsh zones |
| **Mountain-Forged** | Forge-Burn Brands — decorative burns in geometric pattern | Craft 50+ items at the smith |
| **Wound-Marked** | Wound Ascendance — gradual mutation: longer fingers, deeper green tint, visible vine-veins; mechanical: +5% nature damage at full mutation | Spend 100+ hours in Verdant Wound zones; STAGES (4) so the player chooses how deep to go |

**Wound-Marked is the spicy one.** The player visibly degrades as they engage with the corruption. Cool — but maybe gated by a "Stop Mutating" toggle so players who hit a stage they like can lock there.

### 8.5.4 Soul-Binding
Players can **soul-bind** a single weapon and a single armor piece. Bound items become PART of the character.

- Bound weapon's grip protrudes from the character's bare forearm bone when "sheathed" — like the weapon is fused into the body
- Bound armor never visually unequips — the character cannot be naked over that slot, even when transmogged
- Bound items: cannot be dropped, cannot be lost, scale with character level (auto-upgrade item_level to match player_level)
- Bond cost: sacrifice 5 other items of the same slot type at an altar in Ashurim. The sacrificed items become part of the bound item's lore-text (etched into the binding)
- Cannot un-bind without prestige

**Lore weight:** the character chose what they wanted to *be*. The bound katana is no longer a tool — it's an organ.

### 8.5.5 Apothecary Saturation
Drinking potions over time changes appearance. Each potion type has a saturation track (0-1000 lifetime drinks).

| Potion type | Saturation cosmetic |
|---|---|
| HP potions | Skin reddens slightly, blood-vessel glow at full saturation |
| Mana potions | Skin pales toward blue, faint mana-mist at fingertips |
| Stamina potions | Hair becomes wild-and-windswept, eyes brighten green |
| Champion's Draught (rare gold potion) | Hair gains gold streaks, golden glow under skin at full saturation |

Each saturation hits its visual peak at 1000 drinks — a 100+ hour commitment. Stacks: a player who drinks heavily of mana AND stamina shows blue-green hybrid features.

**Cosmetic-only, but reads as identity.** Players who heavily potion-stack become visibly potion-saturated. New players see a glowing-blue Mage and know they've been at the cauldron a long time.

### 8.5.6 Time-of-Creation Gifts
Characters created during specific in-game calendar events get permanent appearance gifts unique to that day. The events tie to the real-world date (server-time aware).

| Event | Date-window | Gift |
|---|---|---|
| **Eclipse Day** | Real-world solar eclipse OR in-game Eclipse Festival (anniversary of game launch) | Character has a permanent dim crescent halo above their head |
| **Blood Moon** | Real-world lunar eclipse OR monthly in-game Blood Moon | Character has perma-red eye-glow option (free, no Demon required) |
| **Sun Festival** | Real-world summer solstice | Permanent gold dawn-aura at sunrise in-game |
| **Dark Solstice** | Real-world winter solstice | Permanent shadow-trail at sunset in-game |
| **Founding Day** | Real-world game launch anniversary | Permanent founder's mark sigil on the chest, displays creation year |

**Why this is huge:** characters are timestamps. Year-1 founders are visibly recognizable to year-5 players. Real-world calendar engagement.

### 8.5.7 Shadow History
The character's **Death Replay** system already exists in code (the Souls-style "you died" replay). Tier 2 extension: every death is recorded as a **Shadow Memory** — a phantom of the killing blow can be summoned at the death-marker location.

- Up to 10 Shadow Memories stored per character
- Replay is visible to other players who walk near the marker — a 2-second ghost loop of how the character died
- Inscribe a Shadow Memory as a permanent tattoo to record the cause-of-death visually

Death becomes a feature instead of a punishment. The world fills with player-generated ghost-loops. Veterans walking past their old death sites see their younger selves get killed.

### 8.5.8 The Inkstone Codex (NPC system)
There's an NPC at the Inkstone Sanctum — **The Inkstone Sage** — who chronicles the player's character.

- Visit any time
- Sage describes the character's life in prose: "I see fifty-seven kills, twelve scars, a vow to Belitu, the salt of the Bay on your skin, and a blade you have made part of yourself."
- Description regenerates each visit — reflects current state
- Can be **transcribed** to in-game journal: a paper-doll image of the character + the prose, exportable as a screenshot
- Implementation: SQL-like query against the character's full state, fed into a description template

**Lore-flavored character sheet.** Players love their stats described in-character. This is a big retention hook.

---

### Implementation Order for Tier 2 (priority)

If shipping any of these, suggested order:

1. **Combat Scars** — small system, big visual payoff, infrastructure exists
2. **Tattoo Glyphs** — community-positive, fits existing Codex registry
3. **Soul-Binding** — moderate scope, fits existing Inventory + transmog systems
4. **Race-Specific Earned Cosmetics** — moderate scope, requires per-race meshes
5. **Inkstone Sage NPC** — small scope, BIG personality
6. **Apothecary Saturation** — slow burn, stacks with combat scars
7. **Shadow History** — fits existing death replay, light extension
8. **Time-of-Creation Gifts** — minimal code (calendar check + flag), high meta-engagement

---

## 9. Open Design Calls — Status

| # | Call | Status (locked 2026-05-08 by Bond) |
|---|---|---|
| 1 | Race system | **5 races** — see § 2.5 |
| 2 | Gender per class | **Male + Female, every class**, no stat impact |
| 3 | Customization depth | **Preset-driven** — see § 3 |
| 4 | Transmog economy | **Coin-via-vendor at lvl 10**, with achievement-unlocked appearances layered on top |
| 5 | Demon visual transformation | **PENDING REVIEW** — full spec at [DEMON_VISUAL_TRANSFORMATION.md](DEMON_VISUAL_TRANSFORMATION.md). Do not implement until Bond signs off. |
| 6 | Sun Breathing inheritance | **Inherits Ronin appearance**, gi-swap to white-and-gold, optional re-creation |
| 7 | Cosmetic-only items | **Yes** — achievement and prestige-tier sources |
