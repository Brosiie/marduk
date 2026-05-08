# Demon Visual Transformation — Design Spec

**Status:** Pending Bond review. **Do not implement until approved.**

This is the design proposal for how Demon-class characters look when the Demon class is unlocked (post-Lucifer). It elaborates on CHARACTER_DESIGN.md § 1 row 5 and replaces the open question with a fully-specified system Bond can approve, modify, or reject.

---

## 1. Lore Foundation

The Demon class lore (from `class_registry.gd`):

> What walks back through Lucifer's gate is no longer mortal. They fight free of mana, paid only in blood. By day they are half-strength and never heal on their own. By night they are stronger than they were before the fall, and the world bleeds toward them.

The visual must communicate three things at a glance:
1. **Loss** — the player sees their old self fading
2. **Power** — the player sees what the deal got them
3. **Cost** — the body is paying for what the soul earned

---

## 2. Core Principle: Transformation, Not Replacement

The Demon character is **the same person** the player rolled before Lucifer. Their face, race, gender, hair color, scars — all of that **persists underneath** the demonic features. Players see their old self peeking through the corruption. This is intentional: the horror is recognising who you were.

This rules out the "fresh character creation for Demon class" path. Instead:

- Demon character creation **starts from a prior character on the same save**
- Player picks which of their previous characters they want to "become Demon"
- That character's appearance is loaded as the base
- Demon overlay system layers transformation on top

If the player has no prior characters (e.g. they imported a save or this is a fresh slot reaching Demon via party inheritance), they get a **fallback creation flow**: pick a race + gender + face, then the Demon overlay applies.

---

## 3. The Transformation Layers

Eight independent visual systems stack on top of the base appearance. Each is a slider or toggle in the Demon character creator (a one-time creator, run on Demon unlock; choices baked at confirm).

### Layer 1 — Horns (REQUIRED, 5 presets)

Permanent. Visible in cutscenes and Ashurim (helms can clip through).

| Preset | Look | Lore reference |
|---|---|---|
| **Ember Spurs** | Two short forward-curved horns, ember-vein at the base | Newly fallen, smallest brand |
| **Ram Curls** | Curled-back ram horns | Common Demon stock |
| **Ibex Ridges** | Tall ridged spirals | Wound-Marked Demons (the Wound takes its share) |
| **Bull Spread** | Wide forward bull horns | Ash-Born Demons (steppe blood doesn't surrender) |
| **Demon Crown** | Six-point crown of horns around the brow | Reserved unlock — appears only after Demon prestige tier 3 |

Horn material: matte volcanic black with ember-vein emission (intensity scales with current Blood pool — full Blood = horns visibly glow).

### Layer 2 — Eyes (REQUIRED, 3 colors + glow toggle)

Eyes change color irreversibly. Player picks one:

- **Arterial Red** (default) — most aggressive read
- **Coal Black with gold iris** — predatory; subtle
- **Burning Gold** — fanatic; reserved for players who killed Lucifer without dying themselves

Glow toggle: on/off. When on, eyes emit at intensity matching Blood pool. When off, eyes are still the chosen color but unlit.

### Layer 3 — Skin & Corruption Veins (REQUIRED, intensity slider 0-3)

The base skin tone (race-determined) is preserved but **shifts undertone toward grey/red**. On top of that, ember-glowing veins trace from horn-base down the face, neck, and arms.

| Intensity | Look |
|---|---|
| 0 (Veiled) | Subtle grey shift, faint vein outlines, easy to mistake for human at a glance |
| 1 (Touched) | Visible undertone shift, vein lines glow when in combat |
| 2 (Marked) | Permanent vein glow, skin reads clearly demonic |
| 3 (Burning) | Skin radiates heat-shimmer, vein glow lights nearby surfaces |

Slider position is a player choice — some want subtlety, some want maximum corruption. The Blood pool's combat-time pulse rides on top of the chosen baseline.

### Layer 4 — Lower Body (REQUIRED, 3 presets)

The legs change. Player picks:

- **Clawed Bare Feet** — human-shaped feet with elongated black claws; shoes/boots clip-fit around them
- **Hooves** — full transformation to cloven hooves; boots/sabatons cannot equip (visual swap to greaves-only)
- **Burnt Soles** — feet stay human-shape but are permanently charred/blackened; default if player doesn't want a visible change

### Layer 5 — Wings (OPTIONAL, toggleable, 4 presets + off)

Wings only manifest when the **Wings of Lucifer** ability fires (existing Demon ability), or when the cosmetic toggle is set to "always visible." Player picks the wing style at creation:

- **Off** — no wings visible outside of ability cast
- **Bat-wing** — leathery, demon-classic
- **Burnt-feather** — Lucifer-aspect, charred angel wings
- **Smoke-wing** — particle-only, no mesh, just an emanation
- **Ember-wing** — bone-frame with fire feathers

Wings are large and clip-prone. Default off; advanced players can enable.

### Layer 6 — Tail (OPTIONAL, 3 presets + off)

- **Off** — no tail
- **Whip-tail** — long thin black, animated
- **Spaded tail** — classical demon spade-tip
- **Bone-tail** — vertebrae-visible, sharp tip

Tail does NOT collide with hitboxes (visual only).

### Layer 7 — Teeth (TOGGLE)

Sharpened canines visible when the character speaks/snarls. On by default.

### Layer 8 — Gate-Scars (REQUIRED placement, intensity 0-3)

Permanent burn marks from passing through Lucifer's gate. Always present (intensity > 0); the question is severity.

- **Across the throat** (always present, varying severity) — the gate's first cut
- **Across the back** (always present) — the wings' tearing-out point, even if wings are off
- **Across the dominant hand** (always present) — what held the killing blade

Severity slider applies the burn-glow intensity and scar prominence.

---

## 4. Class Identity Layered Underneath

The Demon transformation does NOT erase the prior class's silhouette. A Demon-Ronin still:
- Wears Ronin gi-style armor (now bone-fused into the skin)
- Wields katana (now blackened-with-ember-veins variant)
- Uses Water Form animations (now with red-and-black breath trails instead of cobalt)

A Demon-Mage still:
- Wears robes (now charred-edged)
- Uses staff (now ember-cracked)
- Casts spells (now with corruption-aspect VFX overlay)

Each class gets a **demon-overlay material set** that re-tints the existing armor/weapon visuals. This avoids having to re-author every armor piece for the Demon class — we re-skin them at runtime via material override.

---

## 5. Armor Behavior Under Demon

Armor pieces equip and function normally, but visuals shift:

| Material | Pre-Demon look | Post-Demon look |
|---|---|---|
| CLOTH | Robes, soft fabric | Charred-edge robes, embers visible at hems |
| LEATHER | Tan/brown leather | Blackened, ash-rubbed leather |
| MAIL | Steel rings | Ashen-grey rings, oxidised |
| PLATE | Polished steel | Dark iron with ember-vein etching |

Helms specifically: when a helm equips on a Demon, the horns either:
- Clip through (Ember Spurs / Ram Curls — designed to fit)
- Force the helm off (Ibex Ridges / Bull Spread / Demon Crown — too large)

UI tells the player at the equip screen whether the helm will be visible.

---

## 6. Day/Night Visual Reinforcement

The class lore makes day/night a core mechanic. Visuals reinforce:

- **Daytime:** corruption veins dim to baseline, eye glow off, skin tone shifts toward "more human" — visual signal of weakened state
- **Nighttime:** veins pulse, eye glow at full intensity, skin tone shifts more demonic, faint smoke-particle emanation from horns

Implementation note: this is a single shader parameter (`time_of_day` 0..1) that drives all the demon-tint shaders. The WorldClock autoload already pushes time-of-day; we just hook the shader to it.

---

## 7. Implementation Plan (only after Bond approves)

Once approved, the implementation order:

1. **CharacterAppearance Resource extension** — add `demon_overlay: DemonOverlay` sub-resource (null for non-Demons)
2. **DemonOverlay Resource** — fields for all 8 layers above (horn_preset, eye_color, eye_glow, vein_intensity, leg_style, wing_preset, tail_preset, teeth_sharp, gate_scar_intensity)
3. **DemonOverlayApplier** — node that takes a base CharacterAppearance + DemonOverlay and produces the runtime visual
4. **Material library** — `assets/materials/demon/` with the demon-tint variants for cloth/leather/mail/plate
5. **Horn meshes** — 5 horn presets in `assets/items/demon/horns/`
6. **Wing meshes** — 4 wing presets in `assets/items/demon/wings/` (smoke-wing is particle-only, no mesh)
7. **Tail meshes** — 3 tail presets in `assets/items/demon/tails/`
8. **Demon character creator UI** — one-time flow on Demon unlock, prior-character selector + overlay configurator
9. **Day/night shader hookup** — feed WorldClock into the demon-tint shader's time_of_day parameter
10. **Helm-fit metadata** — flag every helm Item with `demon_horn_compatibility: int` (which horn presets it fits)

---

## 8. Bond's Review Checklist

Mark each item below to approve, modify, or reject:

- [ ] **Core principle (§ 2):** Demon = transformation of prior character, not fresh creation
- [ ] **Layer 1 horns (§ 3.1):** 5 presets, prestige-locked Demon Crown
- [ ] **Layer 2 eyes (§ 3.2):** 3 colors + glow toggle, gold reserved for no-death Lucifer kills
- [ ] **Layer 3 skin & veins (§ 3.3):** 4-step intensity slider, glow scales with Blood pool
- [ ] **Layer 4 lower body (§ 3.4):** clawed feet / hooves / burnt soles
- [ ] **Layer 5 wings (§ 3.5):** off-by-default, 4 presets + off
- [ ] **Layer 6 tail (§ 3.6):** off-by-default, 3 presets + off
- [ ] **Layer 7 teeth (§ 3.7):** sharpened canines toggle on by default
- [ ] **Layer 8 gate-scars (§ 3.8):** always present, intensity slider, three required placements
- [ ] **Class identity preservation (§ 4):** Demon-Ronin still uses Water Forms, just with corruption VFX
- [ ] **Armor re-skin via material override (§ 5):** no need to re-author every armor piece
- [ ] **Day/night visual reinforcement (§ 6):** shader-driven, single time_of_day parameter
- [ ] **Implementation plan order (§ 7):** OK to proceed in this sequence?

**Open questions for Bond:**

1. Should the player be able to **re-customize** the Demon overlay later (e.g. via a vendor in Ashurim), or is it locked at unlock?
2. For the **prestige-locked Demon Crown** (horn preset 5): tier 3 is roughly 50+ hours of late-game grind. Is that the right gate, or should it unlock earlier?
3. Does the **Burning Gold eye color** (no-death Lucifer kill) feel right, or should it be a different mechanic (e.g., killed Lucifer in under 10 minutes)?
4. **Scope check:** are 8 transformation layers too many? Could collapse to 5 (horns / eyes / skin / lower body / scars; drop wings/tail/teeth as not-shippable).
5. Should Demon **NPCs and bosses** (Lucifer himself, future Demon-faction antagonists) use the same transformation system, or are they bespoke?

---

## 9. Cross-Reference With Existing Demon Mechanics

Audited 2026-05-08 against `class_registry.gd::_register_demon`, `player.gd::_kit_demon` + Demon constants, and `skill_tree_factory.gd::build_demon_tree`. Visuals must align with these locked systems.

### 9.1 Class Stats & Resource (locked — class_registry.gd lines 318-352)

```
base_hp 130, base_mana 0          → no mana visuals (no blue resource bar)
base_str 15, dex 13, int 15, vit 12 → balanced melee+caster physique
primary str, spell int            → both physical and magical attack visuals valid
armor 7, mr 7                     → mid-armor visual
resource_mechanic = "blood"       → red resource bar, fills on kill
resource_max = 100, regen 0       → never auto-regenerates
max_armor_type = PLATE            → can wear plate, but plate skins demonically (see § 5)
unlocked_by_default = false       → gated by &"demon_class_unlocked" save flag
```

### 9.2 Day/Night Damage System (locked — player.gd lines 64-70)

```
DEMON_DAY_DMG_MULT   = 0.80    → -20% damage by day
DEMON_NIGHT_DMG_MULT = 1.20    → +20% damage by night
DEMON_NIGHT_HP_REGEN = 4.0     → +4 HP/sec at night only
DEMON_LIFESTEAL_PCT  = 0.05    → 5% of all damage dealt heals
DEMON_BLOOD_PER_KILL = 5.0     → +5 Blood per mob kill
DEMON_BLOOD_PER_BOSS = 25.0    → +25 Blood per boss kill
DEMON_KILL_HEAL_PCT  = 0.05    → +5% max HP heal per kill
```

**Visual reinforcement (REQUIRED):**

| Game state | Visual cue |
|---|---|
| Day | Vein glow dims to 30% of baseline · eye glow fades · skin tone shifts toward chosen race baseline · subtle posture droop (anim layer) |
| Night | Vein glow at 100% of baseline · eye glow at 100% · skin shifts grey/red · faint smoke-particle from horns · posture upright |
| Blood pool 0-25 | Baseline veins, no extra effects |
| Blood pool 26-50 | Veins gain pulse animation (slow heartbeat rhythm) |
| Blood pool 51-75 | Pulse rhythm speeds up · faint blood-mist around weapon-hand |
| Blood pool 76-99 | Heavy aura, blood-mist trails movement |
| Blood pool = 100 (cap) | Eyes blaze, full-body emission peak, weapon drips visible blood particles |
| Lifesteal proc | Brief red-mist tendril from target to player (every hit, low intensity) |
| Kill-heal proc | Single red-light flash absorbed into chest |

The Blood pool already drives `demon_damage_multiplier()`: `1.0 + min(1.0, blood/100)`. The visual intensity rides the same curve so what the player SEES matches what the formula DOES.

### 9.3 Q/E/R/F Kit (locked — player.gd lines 1486-1493)

| Slot | Ability | Existing element | Visual implication |
|---|---|---|---|
| Q | `claw_rake` (38 dmg, bleed) | SHADOW | Visible CLAWS on hand are required (Layer 4 lower-body has claws; need claws on hands too) |
| E | `hellfire_burst` (70 dmg AoE) | FIRE | Hands ignite during cast; flame radius from caster |
| R | `soul_drain` (55 dmg, 25% lifesteal) | SHADOW | Heavy red-mist tendril, longer than passive lifesteal proc |
| F | `demon_form` "Demon Unleashed" (+35% dmg, 6s buff) | SHADOW | **Temporary visual escalation** — see § 9.4 |

**Layer 4 amendment needed:** Add hand-claws as a paired choice with foot style. The current spec only addresses feet (claws/hooves/burnt soles). Hands need matching treatment because Claw Rake is the Q slot. Recommend: hand-claw style follows foot-claw style (all-claws set or no-claws set).

### 9.4 The "Demon Unleashed" Buff and the Cosmetic Wings

`demon_form` (F-slot) is a temporary 6-second +35% damage buff. **Bond's review needed:** I originally referenced "Wings of Lucifer" in this doc — that ability does NOT exist in the kit. The actual ability is the simpler `demon_form` buff.

Two paths to reconcile:

**Path A (recommended): Demon Unleashed = visual escalation**
- During the 6 seconds of `demon_form`, the player's existing Demon visuals max out:
  - Vein glow at 100% regardless of Blood pool
  - Eyes at maximum brightness with red lens-flare
  - Smoke-and-ember aura around the body
  - **Wings manifest** (if the player chose a wing preset other than "Off") for the buff duration only
  - Tail intensifies (whip animation on the tail mesh)
- After 6 seconds, visuals snap back to baseline
- This makes the F-slot a real transformation moment without needing a new ability

**Path B: rename to "Wings of Lucifer" and rebuild the ability**
- Replace `demon_form` with a wings-themed ability: short flight burst, cone of fire
- Wings are core to the ability rather than a cosmetic toggle
- More work but makes the wings system first-class

I recommend Path A. It respects the existing kit + skill tree and keeps the cosmetic system as the source of customization. Wings stay player-choice but get a real moment of glory when Demon Unleashed fires.

### 9.5 Skill Tree Paths and Cosmetic Markers (49 nodes — skill_tree_factory.gd lines 607-674)

Seven paths exist; each is a distinct demonic specialization. Optional design call: add **path-specific cosmetic markers** that appear as the player invests into a path. Visible to other players in multiplayer; reads as "this is what I am."

| Path | Theme | Cosmetic marker proposal |
|---|---|---|
| LEGION | Pet summons | Faint chains visible at the wrists (one chain link added per node spent in path) |
| HUNGER | Lifesteal | Mouth of the throat-scar opens slightly, blood-tooth visible (intensity scales with investment) |
| DAMNATION | Curses | Curse-runes etched into the cheek and forearm (max 3 visible runes at full investment) |
| ABYSS | Void magic | Eye-glow gains void-distortion shimmer; Dark Step ability leaves shadow-outline on cast |
| NIGHTBORN | Night-only buffs | Permanent moon-glyph on the brow (visible only at night when path is invested) |
| INFERNAL | Fire/sulfur | Body-of-Embers passive (path tier 6) starts smoking permanently; each ember-node adds one fire-mote orbiting the player |
| WRATH | Blood scaling | The Lucifer's Heir capstone (path tier 7) crowns the player with the Demon Crown horn preset for free, even pre-prestige |

These would be **earned** cosmetic adds, not character-creator choices. The player's build choices visibly mark them. Bond — interesting or feature creep?

### 9.6 Class Lock & Prior-Character Inheritance

The Demon class is gated by `unlock_save_flag = &"demon_class_unlocked"`. The unlock fires when the player kills Lucifer (anywhere on the save, any character).

For visual inheritance (§ 2 of this doc), implementation needs:

1. **Save-level character roster** — track all characters on the save, even retired ones, so Demon creation can pick from them
2. **Appearance archive** — when a character dies/retires/prestiges, archive their CharacterAppearance Resource so it's available for future Demon overlay
3. **First-Demon-on-this-save tutorial** — pop-up when entering Demon creator: "Pick the soul that walked Lucifer's gate"
4. **Fallback if no eligible characters exist** — fresh creation flow with full race/gender/face options before applying the Demon overlay

---

## 10. Updated Layer Summary (with mechanic alignment)

| Layer | Originally proposed | After mechanic audit |
|---|---|---|
| 1. Horns | 5 presets, prestige-locked Demon Crown | Unchanged. Horn glow scales with Blood pool (§ 9.2). |
| 2. Eyes | 3 colors + glow toggle | Unchanged. Glow intensity = Blood pool curve (§ 9.2). |
| 3. Skin & veins | 4-step intensity slider | Unchanged. Vein pulse rhythm = Blood pool curve (§ 9.2). Day/night also drives baseline (§ 9.2). |
| 4. Lower body | Claws/hooves/burnt | **AMENDED** — add paired hand-claw choice (§ 9.3). Claw Rake Q-slot needs visible claws. |
| 5. Wings | Off-by-default + 4 presets | Unchanged BUT — wings now manifest during Demon Unleashed buff (§ 9.4). Always-on toggle is for players who want them visible outside the buff. |
| 6. Tail | Off-by-default + 3 presets | Unchanged. Tail intensifies during Demon Unleashed (§ 9.4). |
| 7. Teeth | Sharpened canines toggle | Unchanged. |
| 8. Gate-scars | Always-on, intensity slider | Unchanged. The throat-scar opens slightly per HUNGER path investment (§ 9.5) — optional. |

**New optional system (§ 9.5):** path-specific cosmetic markers. Bond's call whether to ship.

---

## 11. Updated Bond Review Checklist

Replaces § 8. Mark each item to approve, modify, or reject:

- [ ] **Core principle (§ 2):** Demon = transformation of prior character, not fresh creation
- [ ] **8 transformation layers (§ 3):** as listed, with § 10 amendments
- [ ] **Class identity preservation (§ 4):** Demon-Ronin still uses Water Forms with corruption VFX
- [ ] **Armor re-skin via material override (§ 5):** no re-authoring per piece
- [ ] **Day/night visual reinforcement (§ 6 + § 9.2):** shader-driven, single time_of_day parameter
- [ ] **Implementation plan order (§ 7):** OK to proceed in this sequence?
- [ ] **§ 9.2 visual cues for day/night and Blood pool:** all required additions accepted?
- [ ] **§ 9.3 hand-claws amendment:** add hand claws paired with foot choice?
- [ ] **§ 9.4 Path A (Demon Unleashed = visual escalation, wings manifest during buff):** OR Path B (replace demon_form ability with new Wings of Lucifer ability)?
- [ ] **§ 9.5 path-specific cosmetic markers:** ship as a feature, or skip as feature creep?
- [ ] **§ 9.6 prior-character inheritance:** require it as the default, or allow fresh-creation as a first-class option?
- [ ] **§ 10 layer amendments:** all accepted?

**Implementation gate:** I will not write any Demon visual code until you mark the above and reply.

---

# Tier 2 — Creative Expansions

The above is the foundational system. This section pushes harder. Mark each idea SHIP / SKIP / DEFER. They stack on top of the foundational system; none require it to change.

---

## 12. Per-Prior-Class Demon Variants

The corruption respects what the soul *was*. A Demon-Berserker doesn't look like a Demon-Mage; the demonic transformation expresses through whatever you trained your body to do in life. Each prior class gets a unique demonic signature on top of the base 8-layer system.

| Pre-Lucifer Class | Demon Signature | Visual |
|---|---|---|
| **Berserker** | Bone-Spike Eruption | Spikes erupt from shoulders, elbows, spine. Permanent battle-stance. Veins are RED-glowing instead of ember. |
| **Assassin** | Shadow-Limbs | Forearms and lower legs dissolve into living shadow that re-forms when struck. Hood is now part of the body, never removable. |
| **Ronin** | Bone-Katana Soul | The katana's blade reshapes into curved bone with ember-veins along the spine. Mempo grows into the face — permanent half-mask of bone, mouth visible. Breath trails are red-and-black instead of cobalt. |
| **Ranger** | Antler-Crown + Bone-Bow | Antlers (separate from horn slot — these are permanent, no preset choice) crown the brow. Bow becomes living-bone shape; arrows materialize from the player's own ribcage. |
| **Mage** | Third Eye + Spirit-Robes | A third eye opens permanently on the forehead, gold and unblinking. Robes become composed of bound spirits whose faces occasionally surface and scream. |
| **Chaos Druid** | Wound Ascendant | The Wound corruption fully takes over. Antlers extend dramatically. Skin develops permanent vine-veins (not the ember kind — actual living vines that twitch). The character becomes a moving piece of the Wound. |
| **Paladin Guardian** | Inverted Halo + Shroud | Tabard becomes a black shroud that floats slightly off the body. Halo above the head inverts into a crown of thorns dripping black blood. Shield permanently scarred with the inverted Crown sigil. |
| **Paladin Lightbringer** | Black Sun | The sun motif on the chestplate turns BLACK. A small black sun orbits behind the character's head replacing the original gold halo. Hair turns ash-white permanently. |

**Implementation:** each prior-class signature is a class-specific cosmetic overlay layered on top of the base 8 layers. Stored as `DemonClassSignature` Resource per prior class. Activated automatically based on the inherited character's class_id.

**Why this is huge:** every Demon character looks distinct based on their soul-history. Players can read each other's pre-Lucifer class at a glance in PvP and parties. Demon-Ronin players become a recognizable archetype.

---

## 13. Ascendance Progression — The Transformation Deepens

The 8-layer character creator captures the player's CHOICES at unlock. But the Demon body keeps changing as the player levels their Demon character. **Ascendance** is the slow visible escalation of the corruption.

| Demon level | Visible change |
|---|---|
| 1 (unlock) | Player's chosen settings, baseline intensity |
| 10 | Vein system visibly expands — new veins trace down the legs |
| 20 | Eye glow brightens by one step (independent of the chosen baseline) |
| 30 | Horn-base gains permanent ember-glow even at 0 Blood |
| 40 | Tail manifests automatically (overrides "Off" choice — the body grows what it needs) |
| 50 | Skin tone shifts permanently one step toward "Burning" (independent of baseline slider) |
| 60 | Wings manifest occasionally during combat (1-2 second flickers) |
| 70 | Permanent black aura around the feet — looks like the floor is dying |
| 80 | Eyes can no longer be set to "off" — always glow |
| 90 | Voice deepens one octave (audio system) |
| 100 (cap) | Capstone Ascendance: the player chooses ONE of three apex visual modes, locked forever:  a) **Crowned** — Demon Crown horn preset locked on, regardless of prior choice. b) **Wing-Bound** — wings are always-out, even when not in combat. c) **Heart of Fire** — chest plate shows a visible glowing heart through the armor; +5% lifesteal permanent (mechanical bonus tied to cosmetic choice). |

**Why this is huge:** the player VISIBLY EARNS their final form. New players see veteran Demons and read instantly that they're a long way from the gate. Customization isn't just at-creation — it's a slow ceremony of becoming.

---

## 14. The Mortal Echo

The pre-Lucifer character isn't gone. They exist as a **ghostly companion** that occasionally manifests near the Demon character. Visible only to the Demon player and to other Demons.

**Behaviors:**
- Appears spontaneously at major story moments (entering Ashurim, killing a boss, dying)
- Speaks in their own voice — separate voice pack from the Demon's deepened voice
- Reacts to the player's choices: approves of mercy, recoils from cruelty
- Can be **invoked** once per day-cycle as a temporary buff: the Mortal Echo grants the player one of their old class's abilities for 30 seconds (e.g., a Demon-Ronin can cast Water Form 1 in pure-cobalt color, dealing the original physical damage instead of shadow). Cosmetically, the Demon briefly looks half-human during the channel.
- Has its OWN dialogue arc — the Echo has feelings about what happened. Late game, the Echo can either forgive the Demon (becomes a permanent passive ally, ghost-aura around the player) or denounce them (vanishes forever, removes the daily buff).

**Implementation:** `MortalEcho` resource attached to Demon characters. Stores the original `CharacterAppearance` separately. Renders as a translucent, desaturated ghost mesh using the original character meshes.

**Why this is huge:** turns a one-time creation choice into an ongoing emotional arc. The player's old self is a character in the game.

---

## 15. Demon Lifestyle Systems

Smaller systems that flavor the Demon experience.

### 15.1 Pact Marks
The Demon can make **pacts with NPCs** (replaces normal quest acceptance for some NPCs). Each pact carves a sigil somewhere on the Demon's body — chest, arm, neck, back. Visible cosmetic permanent change. The NPC who made the pact will recognize their sigil on sight when met later in the game.

- 12 NPCs across the world have pact dialogue
- Each pact = unique sigil mesh applied to the body
- Sigils are permanently visible — the character becomes a walking ledger of bargains
- Some NPCs will refuse to deal with a Demon who already bears too many pact-sigils ("You're already promised, devil.")

### 15.2 Echo Abilities
The Demon retains their pre-Lucifer abilities as **Echo Casts**. Bound to a modifier key (Shift + Q/E/R/F).

- Echo casts are FREE of Blood (Demon abilities are also free, so this is parity)
- Echo casts use HP instead — 5% of max HP per echo
- Echo casts deal the ORIGINAL element damage in shadow-aspect (Water Form 1 hits as Shadow with the cobalt VFX)
- Visual: the Demon briefly desaturates during the cast, the Mortal Echo's hands phase through to perform the strike

This rewards mastery of both the Demon kit AND the prior class kit. Mechanically deep.

### 15.3 Day of Reckoning
Once per real-world calendar day, the Demon character experiences a 30-second cinematic of their fall through the gate. Triggered by entering any Lodestone. Cannot be skipped on first viewing per save (subsequent days: skippable after 5 sec).

- Restores Blood to 100 instantly
- Restores HP to full
- Visual: 30 sec of slow-motion gate-walk, deep red haze, screams of fallen Anunnaki
- Mechanically: a daily reset for the Demon's resource economy
- Lore reinforcement: every day, the player reckons with what they did

### 15.4 The Crown of Names
At prestige tier 3 (when the Demon Crown horn preset unlocks), the player ALSO unlocks the **Crown of Names** — a one-time-per-prestige naming.

- The player types the name **Lucifer spoke when they crossed back through the gate**
- Up to 24 characters
- Engraved permanently on the horns themselves
- Visible to other players in PvP, parties, Ashurim social hub
- Format: "X-Who-Y" is the cultural pattern, but unenforced
- Examples: "Khalin-Who-Drinks-Pillars", "Sera-Who-Crowned-Tiamat", "The-Last-Cup-of-Iddinu"

Player-authored personalization that stays tied to the most exclusive cosmetic. This becomes legendary in the player community — when someone sees a Crowned Demon they get to read what made them.

---

## 16. Faction Reactions to Demons

Existing factions in Marduk lore (Crown / Inquisition / Druids / Six Breaths / Black Sail). Each reacts to a Demon character differently. **Reputation system gates dialogue and vendor access** for Demon-class characters specifically.

| Faction | Reaction to Demons | Mechanical effect |
|---|---|---|
| **Iron Crown** | Hunt | Crown patrols are HOSTILE on sight. Crown vendors refuse all transactions. Crown-faction quests become impossible — they rebrand as "Hunt the Demon" quests issued AGAINST the player. |
| **Inquisition** | Capture | Inquisitors actively ambush the Demon in cities. Successful capture imprisons the player for in-game-day-rest of session (warp to cell, escape mini-quest). Inquisitor vendor will sell the Demon ANYTHING — at 5x markup, then immediately reports them. |
| **Druids of the Wound** | Welcome | Druid vendors give the Demon access to Wound-only items. Druid dialogue is warm — they recognize kin. Druid quests grant double reputation for Demons. |
| **Six Breaths** | Conflicted | Sun-aspected Sixth Breath master will REFUSE to teach Sun Breathing to a Demon (Sun Breathing class cannot be unlocked while in Demon form — only by reverting via prestige to a non-Demon character). Other Breaths neutral. |
| **Black Sail** | Profitable | Pirates will sell to anyone with coin. Black Sail captains specifically respect Demons ("Most committed deal I ever saw, devil. Welcome aboard."). Demons can join Black Sail crews for piracy quest line. |

**Visual reinforcement:** each faction has visible color/symbology. NPCs of each faction have distinct postures when the Demon enters their line of sight (Crown patrols go to weapons-drawn, Druids bow, Black Sail tip a flask).

**Why this is huge:** the visual transformation has REAL CONSEQUENCES. Walking into Babilim as a Demon is a different game than walking in as a Ronin.

---

## 17. Updated Bond Review Checklist (Tier 2)

Mark each Tier 2 idea **SHIP / SKIP / DEFER**:

- [ ] **§ 12** — Per-prior-class Demon variants (8 unique signatures)
- [ ] **§ 13** — Ascendance progression (visible escalation per Demon level)
- [ ] **§ 14** — The Mortal Echo (ghost-companion of pre-Lucifer self)
- [ ] **§ 15.1** — Pact Marks (sigils carved per NPC pact)
- [ ] **§ 15.2** — Echo Abilities (Shift+Q/E/R/F casts pre-Lucifer abilities at HP cost)
- [ ] **§ 15.3** — Day of Reckoning (daily lore-cinematic, Blood reset)
- [ ] **§ 15.4** — Crown of Names (player-authored prestige-tier-3 horn engraving)
- [ ] **§ 16** — Faction reactions to Demons (Crown hunts, Druids welcome, etc.)

**Note on scope:** Tier 2 ideas are systemically heavy. Estimate 2-4 weeks of dedicated dev per major item (§ 12, § 13, § 14, § 16 are big). § 15 sub-items are smaller (1-3 days each). Bond's call which to ship for v1 vs Phase 6+ DLC.

---

## 18. The Sacrifice Ritual — Walking Back Through Lucifer's Gate

**LOCKED 2026-05-08.** Bond's design call: Heaven cannot bind to Demons. A Demon attempting to wield Heaven is offered a one-way ritual to sacrifice the Demon and reclaim mortality. See also [CHARACTER_DESIGN.md § 8.4](CHARACTER_DESIGN.md).

### 18.1 Trigger

The Sacrifice is offered ONLY when:
- Player is currently a Demon-class character (`stats.class_def.class_id == &"demon"`)
- Player attempts to **equip** the Heaven katana (`item.id == &"heaven"`)

The trigger fires inside the Inventory equip flow, *before* the standard `class_restriction` reject. If the Demon refuses, the standard reject takes over (Heaven cannot equip; lore reason: it does not bind).

### 18.2 The Sacrifice Prompt

A modal dialog with full information disclosed upfront. No surprise costs.

```
╔══════════════════════════════════════════════════════════════════╗
║  HEAVEN DOES NOT BIND TO THE FALLEN                              ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                  ║
║  The katana lies still in your demon-hand. It will not warm      ║
║  to you.                                                         ║
║                                                                  ║
║  You may walk back through Lucifer's gate. Once.                 ║
║                                                                  ║
║  The Demon you became will dissolve. The soul you walked into    ║
║  Lucifer with will return.                                       ║
║                                                                  ║
║  You will be mortal again.                                       ║
║                                                                  ║
║  Your race, your face, the marks you bear from the fight to      ║
║  here — these stay. The horns, the veins, the hunger — these     ║
║  go.                                                             ║
║                                                                  ║
║  Pre-Lucifer class:  RONIN                                       ║
║  Heaven will bind:   YES                                         ║
║                                                                  ║
║  The gate does not open twice. Once chosen, this cannot be       ║
║  undone.                                                         ║
║                                                                  ║
║                                                                  ║
║   [ ACCEPT — WALK BACK ]      [ REFUSE — KEEP THE DEMON ]        ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
```

When the pre-Lucifer class is NOT Ronin, the prompt shows:
```
║  Pre-Lucifer class:  MAGE                                        ║
║  Heaven will bind:   NO — the sword remains Ronin-only           ║
║                                                                  ║
║  You will become mortal again, but Heaven will not bind to you.  ║
║  This is a sacrifice for the soul, not for the sword.            ║
```

The button labels stay the same. The information is fully disclosed.

### 18.3 What Happens On ACCEPT

The `SacrificeRitual.walk_back(player)` flow runs in this order:

1. **Lock the gate forever:** `SaveFlags.set_permanent_for_character(character_id, &"lucifer_walked_back", true)`
2. **Strip the Demon class:**
   - `stats.class_def = ClassRegistry.get_class_def(character_appearance.pre_lucifer_class_id)`
   - Wipe Demon skill tree progression: remove all `dm_*` skill node ids from `stats.unlocked_skill_node_ids`
   - Restore the pre-Lucifer skill tree progression (preserved on Demon creation in `character_appearance.pre_lucifer_skill_node_ids`)
3. **Strip the Demon visual overlay:**
   - `character_appearance.demon_overlay = null`
   - Re-apply appearance via `AppearanceRegistry.apply(player, character_appearance)` to remove horns, eyes, veins, claws, etc.
   - Add the permanent **white sacrifice scar** as a special CombatScar (location=&"chest", element=HOLY, intensity=0.6, is_boss_scar=true so it persists)
4. **Refund Demon-only items:**
   - Iterate inventory; any item with `class_restriction = [&"demon"]` becomes "Inheritance Trinkets" (renamed, lore-only, no stats)
5. **Award the title:** `TitleRegistry.award(player, &"the_mortal_returned")`
6. **Re-emit class_changed signal** so HUD and ability bar refresh
7. **Trigger the cinematic** (Tier 2): 8-second slow-motion of the gate-walk, this time outbound. Camera follows the demonic features dissolving off the player.
8. **Auto-equip Heaven** if the new class is Ronin (the sacrifice was for the sword)
9. **NPC reactions update:** Storyteller and Inkstone Sage gain new dialogue lines (see § 18.6)

### 18.4 What Happens On REFUSE

- Dialog closes
- Heaven attempts standard equip, fails on `class_restriction` check, returns to inventory (it's `auto_returns_to_inventory = true`)
- Player retains Demon class, Heaven sits inert in inventory
- The prompt **can be re-attempted** later by trying to equip Heaven again — the sacrifice is one-way, but the prompt to accept it is not. Player can wait, think, come back.

### 18.5 New Permanent Save Flag

`lucifer_walked_back` (per-character bool):
- Set true on Sacrifice ACCEPT
- Locks Demon class for that character forever (cannot become Demon again on this character)
- Surfaced to NPCs and the Codex
- Visible in character paper-doll UI

### 18.6 NPC Reactions

The Storyteller and Inkstone Sage gain new opening lines for `lucifer_walked_back == true` characters.

**Storyteller** (Ashurim):
> "You came back. I've seen people make a lot of choices in this hall. That one I respect more than most. The sword has decided you. It doesn't decide many."

**Inkstone Sage:**
> "I knew you when you had a different name. You took it back. Most don't. Sit. Let me see what's left of you."

These replace the standard Demon class greetings and become the permanent opening for these characters.

### 18.7 Title: The Mortal Returned

A new TitleRegistry entry: `&"the_mortal_returned"`.
- Display name: "The Mortal Returned"
- Display variant: "Twice-Walker"
- Visible in character paper-doll, party screens, PvP tags
- **Cosmetic only** (no stat bonus) — the sacrifice itself was the reward
- Locked to characters with `lucifer_walked_back == true`

### 18.8 The White Sacrifice Scar

A bespoke `CombatScar` instance, manually inserted via `ScarManager`:
- `scar_id = &"sacrifice_scar"`
- `location = &"chest"`
- `element = 5` (HOLY — gold-edged)
- `intensity = 0.6`
- `is_boss_scar = true` (never fades)
- `source_id = &"lucifer_gate_walked_back"`
- `source_display_name = "Lucifer's Gate, walked back"`

This is the visible permanent mark of the sacrifice. Other players can see it. Combined with the **Mortal Returned** title, the character carries the choice publicly.

### 18.9 Edge Cases

- **What if the character has no pre_lucifer_class_id set?** (e.g., test characters, save-data corruption) — Default to Ronin (the only class that can wield Heaven post-walk-back). Log a warning.
- **What if the player tries to sacrifice with a non-Ronin pre-Lucifer class?** Prompt makes it clear Heaven won't bind. They can still go through with it — they're choosing mortality, not the sword.
- **Multiplayer party Demon-Ronin:** the Sacrifice fires only on the player who attempted equip. Party members see a notification and a ritual visual but their characters are unaffected.
- **Heaven dropped while Sacrifice prompt open:** Heaven is `auto_returns_to_inventory = true` — it cannot be lost during the prompt.
- **Demon picks up Heaven from a chest/loot, doesn't try to equip:** sacrifice not triggered. Heaven sits in their bag, glowing, waiting. When they finally try to equip, it fires.

### 18.10 Implementation Order

When Bond approves the broader Demon spec, the Sacrifice Ritual implements alongside:
1. **Add `pre_lucifer_class_id` and `pre_lucifer_skill_node_ids` to CharacterAppearance** (foundational, ships immediately even before Demon spec approval since it's a benign addition)
2. **Build `SacrificeRitual` utility** (`scripts/player/sacrifice_ritual.gd`)
3. **Add equip-flow detection in Inventory** — emit `sacrifice_required(item, player)` signal
4. **Build `SacrificePrompt` controller + scene** (`scripts/ui/dialogs/sacrifice_prompt.gd`, `scenes/ui/dialogs/sacrifice_prompt.tscn`)
5. **Add `the_mortal_returned` title in TitleRegistry**
6. **Add walked-back NPC opening lines** to InkstoneSage and StorytellerNPC
7. **Tier 2:** Sacrifice cinematic (8-second gate-walk-out)
8. **Tier 2:** Mortal Echo merger animation (when § 14 ships)
