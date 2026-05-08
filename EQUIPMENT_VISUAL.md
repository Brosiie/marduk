# Marduk — Equipment Visual Map

Per-category mesh specs for the modeling pipeline. Each category lists:
- Authored item IDs (from `item_registry.gd`)
- Visual silhouette / theme per rarity tier
- Bone attachment (from `CHARACTER_DESIGN.md` § 6)
- Hand-pose required for the weapon (animation hookup)

When a Player equips an item, the system loads `assets/items/<category>/<item_id>.glb` and attaches it to the bone. Missing files fall back to the category placeholder.

---

## A — Weapons

### A1. SWORDS (1H)
Bone: `RightHand` · Pose: `sword_grip` · Trail anchor: `tip`

| ID | Rarity | Visual notes |
|---|---|---|
| `sword_iron` | BASIC | Plain crossguard, leather wrap, dull steel. |
| `sword_steel` | COMMON | Polished blade, brass pommel. |
| `sword_temple` | COMMON | Inscribed fuller, pale wood grip, monastic. |
| `sword_silver_edge` | RARE | Silver-etched edge, faint holy glow. |
| `sword_lapis` | RARE | Curved sabre, lapis-blue inlaid hilt, frost wisp. |
| `sword_pirate_kings` | VERY_RARE | Curved cutlass, brass guard, salt-pitted. |
| `sword_etemenanki` | VERY_RARE | Bone-edged longsword, shadow-wisp emission. |

### A2. GREATSWORDS (2H)
Bone: `RightHand` (shoulder rest) · Pose: `greatsword_rest`

| ID | Rarity | Visual notes |
|---|---|---|
| `greatsword_iron` | BASIC | Crude, two-hand grip, broad fuller. |
| `greatsword_butcher` | COMMON | Wider blade, blood-stain texture. |
| `greatsword_kingu_brand` | RARE | Ridged spine, ember-vein emission along the fuller. |
| `greatsword_ennum_lost` | VERY_RARE | Pale wraith-bone, faint shadow trail. |
| `greatsword_sun_edge` | VERY_RARE | Gold trim, sun-disc pommel, dawn aura. |

### A3. AXES (1H)
Bone: `RightHand` · Pose: `axe_grip`

| ID | Rarity | Visual notes |
|---|---|---|
| `axe_iron_hand` | BASIC | Wedge head, ash haft. |
| `axe_steel` | COMMON | Bearded blade, longer haft. |
| `axe_blood_iron` | RARE | Dark iron with red rivets. |
| `axe_steppe_skull` | RARE | Bone-haft wrapped in sinew, skull-knob pommel. |

### A4. GREATAXES (2H)
Bone: `RightHand` · Pose: `greataxe_rest`

| ID | Rarity | Visual notes |
|---|---|---|
| `greataxe_iron` | BASIC | Single-bit, heavy crescent. |
| `greataxe_steppe` | COMMON | Twin-bit, twisted-iron haft. |
| `greataxe_throat_eater` | RARE | Serrated edge, blood-channel grooves. |
| `greataxe_hassu_kin` | VERY_RARE | Crescent-and-spike, dark obsidian inlay. |

### A5. BLUDGEONS (1H — maces)
Bone: `RightHand` · Pose: `mace_grip`

| ID | Rarity | Visual notes |
|---|---|---|
| `mace_iron` | BASIC | Round flanged head. |
| `mace_flanged` | COMMON | Eight-flange star-head. |
| `mace_inquisitor` | RARE | Brass-bound shaft, holy-script inscription. |
| `mace_pillar_fragment` | VERY_RARE | Stone head from a shattered Edict pillar, faint runes. |

### A6. GREAT BLUDGEONS (2H — mauls)
Bone: `RightHand` · Pose: `maul_rest`

| ID | Rarity | Visual notes |
|---|---|---|
| `maul_iron` / `hammer_iron` | BASIC | Block head, iron-bound. |
| `maul_warhammer` / `hammer_iron` | COMMON | Spike-back, longer handle. |
| `maul_mountain_splitter` | RARE | Ridged stone head wrapped in iron bands. |
| `maul_adad_lesser` | VERY_RARE | Storm-rune head, lightning crackle on swing. |
| `hammer_lightbringers_mace` | RARE | Sun-disc head, gold trim. |
| `hammer_sun_brand` | VERY_RARE | Burning sun-head, ember trail. |
| `hammer_crown_warhammer` | VERY_RARE | Royal heraldry inlay, jeweled pommel. |

### A7. STAVES (2H — caster + druid)
Bone: `RightHand` (vertical) · Pose: `staff_rest`

| ID | Rarity | Visual notes |
|---|---|---|
| `staff_apprentice` | BASIC | Plain wood, simple crystal cap. |
| `staff_inkstone` | COMMON | Ink-black wood, scroll-binding wrap. |
| `staff_lapis_drowned` | RARE | Coral-encrusted, water orb at the cap. |
| `staff_druid_thorn` | RARE | Gnarled root, antler-fork cap, vine wrap. |
| `staff_pillar_thread` | VERY_RARE | Pillar-stone fragments threaded with gold wire, rune glow. |

### A8. WANDS (1H — caster)
Bone: `RightHand` · Pose: `wand_grip`

| ID | Rarity | Visual notes |
|---|---|---|
| `wand_apprentice` | BASIC | Carved bone with a quartz tip. |
| `wand_burning_finger` | COMMON | Charred wood, ember tip. |
| `wand_lightning_call` | RARE | Brass coil, jagged crystal tip. |
| `wand_void_finger` | VERY_RARE | Black metal, pulsing void-eye tip. |

### A9. KATANAS (1H — Ronin signature)
Bone: `RightHand` · Pose: `katana_grip` · Sheathe anchor: `Hips_left`

| ID | Rarity | Visual notes |
|---|---|---|
| `katana_temple` | BASIC | Plain ito wrap, silver fittings. |
| `katana_water_disciple` | COMMON | Cobalt-blue ito, water-wave hamon. |
| `katana_kazat_iron` | RARE | Bronze fittings, dull blade, weighty. |
| `katana_flame_disciple` | RARE | Orange ito, ember hamon, fire trail. |
| `katana_thunder_disciple` | RARE | Yellow ito, lightning-jagged hamon. |
| `katana_breathing_master` | VERY_RARE | White-and-gold ito, every-style aura. |

### A10. NODACHI (2H katana)
Bone: `RightHand` (shoulder rest) · Pose: `nodachi_rest`

| ID | Rarity | Visual notes |
|---|---|---|
| `nodachi_temple` | COMMON | Long basic blade, simple hilt. |
| `nodachi_constant_flow` | RARE | Flowing-water hamon, persistent trail. |
| `nodachi_storm_walker` | VERY_RARE | Crackling lightning at the tip, dark blade. |

### A11. DAGGERS (1H — Assassin signature)
Bone: `RightHand` (reverse grip default) · Pose: `dagger_reverse`

| ID | Rarity | Visual notes |
|---|---|---|
| `dagger_iron` | BASIC | Stub blade, leather wrap. |
| `dagger_thieves_kitchen` | COMMON | Curved kitchen-knife look, charcoal-stained. |
| `dagger_whisper_initiate` | RARE | Long thin blade, oiled-black, silent. |
| `dagger_five_mouth_pup` | VERY_RARE | Five-tongued blade fork, demon-aspect. |

### A12. BOWS (2H — Ranger signature)
Bone: `LeftHand` (held), `RightHand` (draw) · Pose: `bow_draw`

| ID | Rarity | Visual notes |
|---|---|---|
| `bow_short` | BASIC | Single-curve hunting bow. |
| `bow_long` | COMMON | Tall longbow, leather grip. |
| `bow_storm` | RARE | Recurve, brass tips, faint lightning. |
| `bow_glade_widow` | VERY_RARE | Ornate recurve, woven-vine grip, leaf-emission arrows. |

### A13. CROSSBOWS (2H)
Bone: `LeftHand` (cradle), `RightHand` (trigger) · Pose: `crossbow_aim`

| ID | Rarity | Visual notes |
|---|---|---|
| `crossbow_simple` | BASIC | Wooden stock, iron prod. |
| `crossbow_repeater` | COMMON | Top-magazine repeater. |
| `crossbow_inquisitor` | RARE | Brass fittings, holy-text engraving. |

### A14. THROWING KNIVES (consumable)
Bone: `RightHand` (held), spawn projectile mesh per throw · Pose: `throw`

| ID | Rarity | Visual notes |
|---|---|---|
| `throwing_iron` | BASIC | Stub flat blades. |
| `throwing_serrated` | COMMON | Saw-toothed edge. |
| `throwing_silver` | RARE | Silver-edged, anti-shadow. |
| `throwing_master` | VERY_RARE | Black, serrated, bound in pairs. |

### A15. SHURIKEN (consumable)
Same as throwing knives, four-pointed star mesh.

| ID | Rarity | Visual notes |
|---|---|---|
| `shuriken_iron` | BASIC | Plain four-point. |
| `shuriken_lightning` | RARE | Brass, crackling. |
| `shuriken_poisoned` | RARE | Green-tipped points. |

### A16. POLEARMS (2H)
Bone: `RightHand` (haft) · Pose: `polearm_rest`

| ID | Rarity | Visual notes |
|---|---|---|
| `polearm_spear` | BASIC | Leaf-blade, ash haft. |
| `polearm_glaive` | COMMON | Wide curved blade. |
| `polearm_thorn_pike` | RARE | Barbed head, thorn-vine wrap. |
| `polearm_kingu_lesser` | VERY_RARE | Forked-tongue blade, scaled haft. |

### A17. SCYTHES (2H)
Bone: `RightHand` (haft) · Pose: `scythe_rest`

| ID | Rarity | Visual notes |
|---|---|---|
| `scythe_field` | BASIC | Wood haft, simple curved blade. |
| `scythe_blood_cradle` | RARE | Red-iron blade, drip-channel. |
| `scythe_lucifer_pup` | VERY_RARE | Black blade, ember-vein, demon-aspect. |

### A18. FIST WEAPONS (1H, both hands)
Bone: `LeftHand` + `RightHand` (always paired) · Pose: `fists`

| ID | Rarity | Visual notes |
|---|---|---|
| `fist_iron` | BASIC | Iron knuckles. |
| `fist_serpent_scale` | RARE | Scale-plated grip, fang spurs. |

### A19. WHIPS (1H)
Bone: `RightHand` (handle, coil mesh trails) · Pose: `whip_grip`

| ID | Rarity | Visual notes |
|---|---|---|
| `whip_leather` | BASIC | Plain braided leather. |
| `whip_inquisitor` | RARE | Steel-tipped barbs every meter. |

---

## B — Off-Hand Items

### B1. SHIELDS
Bone: `LeftHand` · Pose: `shield_block`

| ID | Rarity | Visual notes |
|---|---|---|
| `shield_buckler` | BASIC | Small round, iron rim. |
| `shield_kite` | COMMON | Tall kite, leather-bound. |
| `shield_tower` | RARE | Full body, painted heraldry. |
| `shield_paladin_kite` | RARE | Sun-disc center, gold edging. |
| `shield_dawn_bulwark` | VERY_RARE | Glowing sun motif, dawn aura. |
| `shield_pillar_disc` | VERY_RARE | Stone disc with rune glow. |

### B2. BOOKS / TOMES (caster off-hand)
Bone: `LeftHand` · Pose: `book_open`

| ID | Rarity | Visual notes |
|---|---|---|
| `book_apprentice` | BASIC | Leather, ribbon marker. |
| `book_burning_pages` | RARE | Edges always smoldering. |
| `book_asaridu_left` | VERY_RARE | Ink-black cover, glyphs floating off the page. |
| `tome_focus_clear` | COMMON | Crystal sphere on a leather mount. |
| `tome_lapis_orb` | RARE | Floating lapis orb, no physical book. |

### B3. PARRYING DAGGERS
See A11 daggers. Same mesh family, smaller scale.

### B4. QUIVERS (Ranger)
Bone: `Spine2` (back-anchor, slung) · No pose change

| ID | Rarity | Visual notes |
|---|---|---|
| `quiver_leather` | COMMON | Plain leather tube, 12-arrow capacity visible. |
| `quiver_glade_widow` | VERY_RARE | Vine-wrapped, glowing-arrow heads visible. |

### B5. TOTEMS (Druid)
Bone: `Hips` (belt-clip) when carried · `LeftHand` when raised in cast

| ID | Rarity | Visual notes |
|---|---|---|
| `totem_bone` | COMMON | Carved bone, feathers, leather wrap. |
| `totem_dragon_pup` | VERY_RARE | Carved dragon coil, faint scale shimmer. |

---

## C — Armor Slots

### C1. HELMS
Bone: `Head` · Hide-toggle obeyed

| ID | Rarity | Visual notes |
|---|---|---|
| `helm_leather` | BASIC | Simple leather cap, chinstrap. |
| `helm_iron` | COMMON | Round nasal helm. |
| `helm_circlet_apprentice` | COMMON | Silver wire, single gem. |
| `helm_steppe_skull` | RARE | Carved animal skull worn as crown. |
| `helm_inquisitor_hood` | RARE | Black hood + brass mask underneath. |
| `helm_paladin_great` | RARE | Closed great-helm, slit visor, sun crest. |
| `helm_pillar_diadem` | VERY_RARE | Stone fragments suspended around the brow. |

### C2. CHESTS
Bone: `Spine2` (layered over base body)

| ID | Rarity | Visual notes |
|---|---|---|
| `chest_leather` | BASIC | Leather cuirass, belted. |
| `chest_iron` | COMMON | Iron brigandine, plate sections. |
| `chest_robe_apprentice` | COMMON | Cloth robe, pockets, sash. |
| `chest_water_disciple` | RARE | Cobalt gi, water-print sash. **Ronin only.** |
| `chest_kazat_iron_plate` | RARE | Heavy plate, dark iron, shoulder-spikes. |
| `chest_paladin_plate` | RARE | Tabard over plate, sun crest. |
| `chest_lightbringer_mail` | RARE | Mail with cape, sun-disc. |
| `chest_pillar_robe` | VERY_RARE | Robe woven with pillar-stone threads, gold trim, glowing sigils. |

### C3. LEGS
Bone: `Hips` (skirt or pants mesh)

| ID | Rarity | Visual notes |
|---|---|---|
| `legs_leather_pants` | BASIC | Plain leather. |
| `legs_iron_greaves` | COMMON | Iron greaves over chausses. |
| `legs_hakama` | COMMON | Black pleated hakama. **Ronin / Sun.** |
| `legs_storm_walker` | RARE | Lightning-runed greaves, faint glow. |

### C4. BOOTS
Bone: `LeftFoot` + `RightFoot` (mirrored)

| ID | Rarity | Visual notes |
|---|---|---|
| `boots_leather` | BASIC | Calf-high leather. |
| `boots_sabaton` | COMMON | Iron foot armor, plate joints. |
| `boots_dancer` | RARE | Soft leather, silent soles, no visible buckles. |
| `boots_silent_step` | RARE | Wrapped feet, dark cloth. **Assassin / Ronin.** |

### C5. GLOVES / GAUNTLETS
Bone: `LeftHand` + `RightHand` (under weapon mesh)

| ID | Rarity | Visual notes |
|---|---|---|
| `gloves_leather` | BASIC | Wrap-bound leather. |
| `gloves_iron_gauntlets` | COMMON | Articulated iron plates. |
| `gloves_archer` | COMMON | Three-finger archer's glove. |
| `gloves_burning_palm` | VERY_RARE | Black leather, ember-glowing palm runes. |

### C6. CLOAKS
Bone: `Spine2` (back-anchor, cloth physics)

| ID | Rarity | Visual notes |
|---|---|---|
| `cloak_traveler` | BASIC | Plain wool, hood up. |
| `cloak_mist_shroud` | RARE | Pale grey, mist particle trail. |
| `cloak_sun_bearer` | VERY_RARE | White, gold-trim, dawn-aura. |

### C7. BELTS
Bone: `Hips`

| ID | Rarity | Visual notes |
|---|---|---|
| `belt_leather` | BASIC | Plain. |
| `belt_war` | COMMON | Studded, with hanging straps. |
| `belt_storm_girdle` | RARE | Brass-buckle, lightning rune, faint crackle. |
| `belt_pirate_kings_sash` | VERY_RARE | Red silk sash, gold buckles, knife-loops. |

### C8. AMULETS
Bone: `Neck`

| ID | Rarity | Visual notes |
|---|---|---|
| `amulet_simple` | BASIC | Wooden disc on cord. |
| `amulet_lapis_drop` | RARE | Lapis stone in silver setting. |
| `amulet_sun_drop` | RARE | Gold sun-disc. |
| `amulet_storyteller` | VERY_RARE | Closed eye carved in obsidian, faint pulse. |

### C9. RINGS
Bone: `LeftHandIndex1` / `RightHandIndex1`

| ID | Rarity | Visual notes |
|---|---|---|
| `ring_iron` | BASIC | Plain iron band. |
| `ring_bronze_strength` | COMMON | Engraved bronze, strength glyph. |
| `ring_silver_dexterity` | COMMON | Silver, dexterity glyph. |
| `ring_gold_intellect` | COMMON | Gold, intellect glyph. |
| `ring_focus` | RARE | Gem-set, faint mana-glow. |
| `ring_blood` | RARE | Red gem, slow pulse. |
| `ring_pillar_seal` | VERY_RARE | Stone-set, gold runic band. |
| `ring_kingu_marker` | VERY_RARE | Black band, ember inlay. |

### C10. CHARMS
No visual attachment (stat-only). Inventory icon required.

| ID | Rarity | Visual notes |
|---|---|---|
| `charm_traveler` | BASIC | Wooden token icon. |
| `charm_breathing_stone` | RARE | Smooth river stone icon, water-rune. |
| `charm_inkstone_seal` | RARE | Black wax seal icon. |
| `charm_oath_locket` | RARE | Brass locket icon. |
| `charm_sanctum_petal` | VERY_RARE | Pressed white petal icon. |
| `charm_sun_phylactery` | VERY_RARE | Gold scroll-tube icon. |

---

## D — Consumables

Potions and surge items. Single mesh family: small bottle, color per type.

| Color | Items |
|---|---|
| Red (HP) | `potion_hp_lesser/minor/greater/major/supreme/surge`, `surge_hp` |
| Blue (Mana) | `potion_mana_lesser/minor/greater/major/surge`, `surge_mana` |
| Green (Stamina) | `potion_stamina_minor/surge`, `surge_stamina` |
| Gold (Champion) | `potion_champions_draught` |

Bottle silhouette varies by tier: lesser = plain vial, minor = corked flask, greater = labeled bottle, major = sealed wax-top, supreme = ornate gold-rim.

---

## E — Authoring Priority Order

Cut by impact-on-Phase-1-demo. Highest impact first.

1. **`katana_kazat_iron`** — bronze katana drop from Kazat (Phase 1 demo loot)
2. **`katana_water_disciple`** — Ronin starter weapon
3. **`chest_water_disciple`** + **`legs_hakama`** — Ronin starter outfit
4. **All 9 class-default weapons** (one per class)
5. **All 9 class-starter chests** (one per class)
6. **Rest of Common-tier items** for the loot pool
7. **All Rare-tier items** with class-restriction
8. **Very Rare and Legendary items** with bespoke meshes

---

## F — Drop Source Audit

**TODO:** for each item, confirm a drop source exists. Items with `unique_drop_source = &"..."` are explicit. Common items roll via `LootGenerator` against zone level. Need to enumerate which items have NO source and would be unobtainable in normal play. To be done in a follow-up audit pass.
