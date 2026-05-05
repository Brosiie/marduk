# The Ronin's Breathing Styles — Design + Implementation

This document maps Marduk's 49 Ronin breathing forms to their Demon Slayer
inspirations and specifies the animation, VFX, audio, and combat-state
implementation for each. The 49 forms already live in
`scripts/skills/breathing_registry.gd`. This document explains *why* they
exist as they do and *how* they should look in motion.

## Source material

Demon Slayer (Kimetsu no Yaiba) defines breathing as a stamina-cycling
combat technique that lets humans match the speed and strength of
demons. Each style has a canonical number of forms and a fighting
philosophy:

| Anime style | Forms | Practitioner | Philosophy |
|-------------|-------|--------------|------------|
| Water       | 11    | Tanjiro / Giyu | Adapt, flow, parry |
| Flame       | 9     | Rengoku       | Aggression, burn DoT |
| Mist        | 7     | Muichiro      | Deception, illusion strikes |
| Thunder     | 7 (Zenitsu = 1) | Zenitsu | One mastered form, godspeed |
| Stone       | 5     | Gyomei        | Heavy, defensive, slow |
| Wind        | 9     | Sanemi        | Spinning, multi-target |
| Sun (Hinokami Kagura) | 13 | Tanjiro (true form) | Origin of all styles |

Marduk normalizes these to **7 forms × 7 styles = 49 forms**. Each style
reads as its anime counterpart, but the seventh form of every style is
a unique-to-Marduk capstone.

## Why 49 / 7×7?

- Mirrors the Demon Slayer "form count varies per style" structure
  while keeping the skill tree symmetric.
- The 7-form ladder maps cleanly onto a 7-tier skill tree branch:
  one form per tier, one branch per style.
- Sun Breathing is gated behind mastering the 6 prerequisite styles
  (canon: Sun is the original, all others derived from it). In
  Marduk this makes Sun the *endgame* style.

## Form-by-form mapping

For each form: anime reference -> Marduk implementation -> animation
slot in `assets/animations/classes/ronin/<id>.fbx` -> trail VFX color
+ shape -> hit-feel notes.

---

### Water Breathing — flow, parry, sustain

| # | Marduk name | Anime ref | Mixamo anim | Trail VFX | Combat feel |
|---|-------------|-----------|-------------|-----------|-------------|
| 1 | River Cleave | Water Surface Slash (1st) | Sword Slash (single horizontal arc) | Wide blue arc 130° | Foundation slash. Forgiving, fast recovery. |
| 2 | Wheel of the Stream | Water Wheel (2nd) | Spin Attack | Spinning blue ring AOE | Spin around player, melee radius, free combo opener. |
| 3 | Dance of the Tide | Flowing Dance (3rd) | Sword Run Slash | Curving blue trail | Dash-then-slash. Closes a 5m gap. |
| 4 | Striking Current | Striking Tide (4th) | Sword Stab | Linear blue thrust line | Forward thrust. Pierces 30% armor. |
| 5 | Calm After Storm | Dead Calm (11th) | Sword Parry | Faint blue ring expanding | Active parry stance. Successful parry refunds stance + heals 8% HP. |
| 6 | Whirlpool | (custom, Marduk-only) | Spin Attack (longer) | Massive blue spiral, 6m | Pulls enemies in 6m, AOE damage. |
| 7 | Constant Flow | Constant Flux (10th) | Charging Sword Combo | Cyan-blue continuous flurry | Channeled 3-second blade flurry. Vulnerable to interrupt. Capstone. |

**Key signature:** every Water form has a circular or wave-motion blade
arc. The trail color shifts deeper blue from form 1 (sky blue) to form 7
(cyan-white) as the form unlocks more advanced techniques.

---

### Flame Breathing — aggression, burn DoT, momentum

| # | Marduk name | Anime ref | Mixamo anim | Trail VFX | Combat feel |
|---|-------------|-----------|-------------|-----------|-------------|
| 1 | First Pyre | Unknowing Fire (1st) | Sword Slash | Orange forward arc | Upward slash + 8 dmg/s burn for 3s. |
| 2 | Rising Inferno | Rising Scorching Sun (2nd) | Jump Attack | Vertical orange trail | Leap from above + slam-strike. |
| 3 | Blazing Cosmos | Blazing Universe (3rd) | Sword Run Slash | Orange wide-cone trail | Wide horizontal cleave. Trail burns enemies who cross it. |
| 4 | Bloom of Flame | Blooming Flame Undulation (4th) | Spin Attack | Orange double-spiral | Two rotations. Hits twice. |
| 5 | Tiger of Embers | Flame Tiger (5th) | Sword Run Slash | Long orange dash trail | Dash leaves a 4-second fire trail. |
| 6 | Pyre's Edge | Pyre Storm (custom) | Charging Sword | Orange charged thrust line | 1s windup, 8m line ignite. |
| 7 | Crimson Suffering Sun | Rengoku (9th) | Charging Sword Combo | Massive crimson cone | Capstone: 12s scorching DoT, ignites the ground. |

**Key signature:** every Flame form lights the trail on fire. Colors range
from orange (early forms) to deep crimson (form 7). Fire trails on the
ground are persistent particle effects with damage zones.

---

### Mist Breathing — illusion, single-target burst, teleport-strike

| # | Marduk name | Anime ref | Mixamo anim | Trail VFX | Combat feel |
|---|-------------|-----------|-------------|-----------|-------------|
| 1 | Low Cloud, Distant Haze | Low Clouds, Distant Haze (1st) | Quick Sword Slash | White plume + brief teleport flash | 4m blink + slash. |
| 2 | Eight-Layered Mist | Eight-Layered Mist (2nd) | Sword Combo Attack 02 | 8 phantom strikes radiating | 8 rapid stabs on a single target. |
| 3 | Scattering Mist Splash | Scattering Mist Splash (3rd) | Spin Attack | White cloud burst | Cone in front + brief blind on hit (-50% accuracy). |
| 4 | Shifting Flow Slash | Shifting Flow Slash (4th) | Sword Riposte | Subtle white trail | Feint then strike. Auto-crit if used 0.5s after dodge. |
| 5 | Sea of Clouds and Haze | Sea of Clouds and Haze (5th) | Casting Spell Above | White cloud ring expanding | 5m AOE blind cloud, 4s duration. |
| 6 | Lunar Dispersion Mist | Lunar Dispersing Mist (6th) | Vanish | Slow white dissolution | 2s invisibility. Next hit while invisible auto-crits. |
| 7 | Obscuring Clouds | Obscuring Clouds (7th) | Charging Sword Combo | Blinding white pillar around player | Capstone: 5s invisibility + auto-crit + 200% damage on next hit. |

**Key signature:** every Mist form involves visual misdirection — phantom
strikes, brief invisibility, blind on hit. Trail color stays pale white
across all forms; what changes is the *pattern* of strikes (single,
multi, scattered, full-screen).

---

### Thunder Breathing — single high-speed strike, godspeed

| # | Marduk name | Anime ref | Mixamo anim | Trail VFX | Combat feel |
|---|-------------|-----------|-------------|-----------|-------------|
| 1 | Thunderclap and Flash | Thunder Clap and Flash (1st) | Quick Sword Slash | Tight yellow streak | Instant 6m dash strike. Tight perfect window. |
| 2 | Rice Spirit | Rice Spirit (2nd) | Spin Attack | Yellow disc around player | Spinning blade strike, up to 5 enemies. |
| 3 | Thunder Swarm | Thunder Swarm (3rd) | Air Slash | Branching yellow chains | Chain lightning, 4 enemies, 60% damage per chain. |
| 4 | Distant Thunder | Distant Thunder (4th) | Casting Spell Above | Delayed yellow shockwave | 0.8s delayed shockwave. Anticipation play. |
| 5 | Heat Lightning | Heat Lightning (5th) | Sword Stab | Long yellow line | Pierces all enemies in 12m line. |
| 6 | Rumble and Flash | Rumble and Flash (6th) | Sword Combo | Three short yellow dashes | Zigzag, 3 hits, 3 positions. |
| 7 | Flaming Thunder God | Honoikazuchi no Kami (6th canon, 7th here) | Charging Sword Combo | All-yellow flash, 7 chained strikes | Capstone: 7 enemies hit in 0.4s. |

**Key signature:** Thunder is **fast**. Every form has minimal cast time
(0.05s on the first form). Unlike Water (curves) or Flame (cones), all
Thunder trails are tight straight lines. Color stays bright yellow with
brief whitening on critical hits.

---

### Stone Breathing — slow, heavy, devastating, armor-piercing

| # | Marduk name | Anime ref | Mixamo anim | Trail VFX | Combat feel |
|---|-------------|-----------|-------------|-----------|-------------|
| 1 | Bedrock Strike | Serpentinite Bipolar (1st) | Heavy Sword Slash | Brown grounded arc | Dual chained strike, slow recovery. |
| 2 | Upper Smash | Upper Smash (2nd) | Great Sword Smash | Brown overhead trail | Overhead crusher. 1m radius. |
| 3 | Stone Skin | (custom defensive) | Sword And Shield Block | Faint brown aura | Self buff: -40% damage taken 6s. |
| 4 | Volcanic Rock | Volcanic Rock (3rd) | Stomping | Brown ground crack | Heavy single hit, ground-shake stagger. |
| 5 | Arcs of Justice | Arcs of Justice (5th canon, 5th here) | Charging Sword | Brown curved chain trail | Overhead axe slam. 4m AOE. |
| 6 | Rolling Boulder | (custom) | Running Slide | Brown rolling line | Charge attack, 8m, knockback all in path. |
| 7 | Mountain Beneath | (custom capstone) | Charging Sword Combo | Earth-quake AOE pulses | Capstone: massive earthquake, 12m radius, all enemies stagger. |

**Key signature:** Stone is **slow**. Every form has 0.5s+ cast time.
Trail color stays earthy brown. Forms feel grounded — the player's
camera shakes on connect, fragments fly off the ground, dust clouds
linger. Best for siege boss DPS.

---

### Wind Breathing — multi-directional spin, multi-hit

| # | Marduk name | Anime ref | Mixamo anim | Trail VFX | Combat feel |
|---|-------------|-----------|-------------|-----------|-------------|
| 1 | Dust Whirlwind Cutter | Dust Whirlwind Cutter (1st) | Spin Attack | Green spinning ring | Circular spin, 360° hit. |
| 2 | Claws of Purifying Wind | Claws of Purifying Wind (2nd) | Sword Combo Attack 02 | Green claw streaks | Slashing claws, 5 short slashes. |
| 3 | Clean Storm Wind Tree | Clean Storm Wind Tree (3rd) | Sword Slash 2 | Vertical green trails | Vertical multi-cut. Vertical 6m. |
| 4 | Rising Dust Storm | Rising Dust Storm (4th) | Jump Attack | Rising green vortex | Uplifting AOE, knocks enemies up. |
| 5 | Cold Mountain Wind | Cold Mountain Wind (5th) | Quick Sword Slash | Pale green chilling cut | Cut + 30% slow on hit, 4s. |
| 6 | Black Wind, Mountain Mist | Black Wind, Mountain Mist (6th) | Sword Combo | Dark green wide trail | Wide multi-target sweep. |
| 7 | Idaten Typhoon | Idaten Typhoon (9th canon, 7th here) | Charging Sword Combo | Massive green tornado | Capstone: godspeed sweeping finisher, hits everything in 8m. |

**Key signature:** Wind is **multi-hit**. Every form lands at least 3
distinct hits (visualized as repeated trail segments). Color stays
green, intensifying from pale jade (form 1) to dark forest green
(form 7).

---

### Sun Breathing (Hinokami Kagura) — LOCKED endgame

Mastered only after the player has unlocked at least 2 prerequisite
styles to their 7th form (canon: Sun derived from all other styles, so
in Marduk you must first prove proficiency in 2 styles before Sun
unlocks). The `unlock_save_flag = sun_breathing_unlocked` permanent
flag persists across prestige.

| # | Marduk name | Anime ref | Mixamo anim | Trail VFX | Combat feel |
|---|-------------|-----------|-------------|-----------|-------------|
| 1 | Dance | Dance (1st Hinokami) | Sword Slash | Gold radiant arc | Opening sweep, baseline filler. |
| 2 | Clear Blue Sky | Clear Blue Sky (2nd) | Spin Attack | Wide gold horizontal arc | Wide arc swing. |
| 3 | Setting Sun Transformation | Setting Sun Transformation (3rd) | Sword Combo | Gold dawn-light trail | Triple hit, dawn imagery. |
| 4 | Solar Heat Haze | Solar Heat Haze (4th) | Casting Spell Above | Gold area scorch | Area scorch, 5m radius. |
| 5 | Burning Bones, Summer Sun | Burning Bones, Summer Sun (5th) | Sword Combo Attack 02 | Gold burning multi-strike | 7 burning strikes. |
| 6 | Fire Wheel | Fire Wheel (6th) | Spin Attack (heavy) | Gold rolling AOE wheel | Rolling AOE, knocks back. |
| 7 | Flame Dance | Flame Dance (7th canon) | Charging Sword Combo | Massive gold radiance + screen flash | Capstone of the entire class: all-in massive ultimate, 18s cooldown. |

**Key signature:** Sun is **golden and radiant**. Every form bathes the
arena in light. Sun forms are the only ones that emit a screen-wide
post-process flash on hit (BLOOM intensity ramps briefly). Form 7,
Flame Dance, freezes time for 0.4s as the strike lands — full Demon
Slayer Tanjiro vs Muzan finale energy.

## Implementation patterns

### Animation layering

Each form references `f.animation_name = StringName("breath_<style>_<n>")`.
The Mixamo .fbx for that name lives in `assets/animations/classes/ronin/`.
At spawn time, `AnimationLibraryLoader` merges the file under
`marduk/breath_<style>_<n>` on the player's `AnimationPlayer`. The
ability runner plays the merged clip when the form casts.

For tonight's playable demo, only forms 1-2 of each style ship with
hand-picked Mixamo source files (see `assets/animations/README.md`).
Higher forms reuse the closest cousin animation until dedicated
clips are downloaded.

### VFX trail layering

Every form casts a `BreathTrail` (`scripts/vfx/breath_trail.gd`)
parameterized by the style id (water/flame/mist/thunder/stone/wind/sun).
The trail's color, arc radius, thickness, and duration are read from
`BreathTrail.STYLES`. Form 7 capstones use a brighter, longer-lasting
trail variant.

For the FULL Demon Slayer feel, three additional VFX layers should be
added in a future polish pass:

1. **Particle sub-emitters** — water droplets, fire embers, lightning
   sparks, dust, mist particles, leaves. Spawn per-form from a
   `GPUParticles3D` child of the trail node.
2. **Camera shake** on form-7 hits — proportional to damage dealt. Hook
   `CameraRig.shake(magnitude, duration)`.
3. **Post-process flash** on Sun forms — `WorldEnvironment.adjustment_brightness`
   pulses to 1.4 then back over 0.2s.

### Combat state machine

Each form has a fixed three-state lifecycle:

```
windup  → execute  → recovery
```

- `cast_time` is the windup duration. During windup the player is
  `locked` (no movement) and visible as the chosen animation winds up.
- `execute` spawns the hitbox. Damage applies, VFX plays, audio cue
  fires.
- `recovery` is `f.miss_punishment_seconds` long if the strike misses
  every enemy in range, or zero if at least one enemy was hit. Encourages
  Souls-like commitment.

### Stance + perfect window

Forms cost `stance_charge_cost` of the Ronin's stance pool (0-100, gained
from kills/parries). Spent stance accelerates the form's perfect window.

Forms with `perfect_window_seconds > 0.0` reward early presses:

- Press the form's hotkey within `perfect_window_seconds` of the previous
  Ronin form ending its execute phase.
- A perfect chain grants the next form `f.chain_bonus_mult` damage
  multiplier (typically 1.4-1.8).
- This is the "Tanjiro chains 4 forms in a row" feeling — reward the
  player who learns the rhythm.

### Chain predecessors

`f.chain_predecessor = &"<style>_<n-1>"` declares an "intended" prior
form. If the player casts the form within the perfect window AND the
prior form was the chain predecessor, the form gains the chain bonus
PLUS a small VFX upgrade — trail glows brighter, arc widens, particles
double.

### Damage type per style

| Style   | Damage type |
|---------|-------------|
| Water   | PHYSICAL    |
| Flame   | FIRE (2)    |
| Mist    | SHADOW (6)  |
| Thunder | LIGHTNING (4) |
| Stone   | PHYSICAL    |
| Wind    | PHYSICAL    |
| Sun     | HOLY (5)    |

This matters for resistances on bosses and undead. Sun's HOLY tag is
especially impactful against demons / undead in late-game encounters.

## Skill-tree progression

The Ronin's 49-node skill tree is laid out as **7 branches × 7 tiers**.
Each branch is one breathing style; each tier is one form within that
style. Spending a skill point on tier N unlocks form N for casting.

Tree gates:
- Form N requires form N-1 mastered (`prereq_form_id`).
- Sun branch requires `mastered_count >= 2` across other branches.
- Form 7 of any style is the branch capstone — costs 3 skill points
  instead of 1.

This means the canonical "ronin progression" is:
1. Pick a starter style (Water / Flame / Mist / Thunder / Stone / Wind).
2. Climb that branch tier by tier.
3. Diversify into a second style for combat versatility.
4. Once two styles are at form 7, Sun branch opens.
5. Climb Sun for the endgame ultimates.

Total skill points to fully master 1 style: 3 points × 1 capstone +
1 point × 6 lower forms = 9 points. To master all 7 styles: 63 points.
Player reaches level 100 with ~99 skill points (one per level past 1),
so a full master-everything build is theoretically attainable but
expensive — most players will specialize 2-3 styles.

## Audio cues per style

Until real .ogg files ship, `AudioBus.play_cue(...)` synthesizes
short procedural tones. Recommended cue assignments per style:

| Style   | Cue name | Pitch shift on form 7 |
|---------|----------|-----------------------|
| Water   | swing    | 1.4x (high, clean)    |
| Flame   | swing    | 0.85x (deeper roar)   |
| Mist    | button   | 0.95x (subtle)        |
| Thunder | crit     | 1.6x (bright crackle) |
| Stone   | death    | 0.7x (heavy thud)     |
| Wind    | swing    | 1.2x (whoosh)         |
| Sun     | level_up | 1.0x (arpeggio fanfare) |

When real audio lands, a sound designer should replace these procedural
cues 1:1 by mapping `AudioBus.play_cue(&"<style>_form_<n>", ...)` to
authored .ogg samples per form.

## Quick reference: which 4 forms ship with Q/W/E/R for tonight?

Player.gd's `_kit_ronin()` defaults to:

| Slot | Form ID         | Style   | Why this 4 |
|------|-----------------|---------|------------|
| Q    | iai_strike      | Water   | Fast filler, low cost, teaches the rhythm |
| W    | water_breath_1  | Water   | First breathing form, trail-VFX teaching moment |
| E    | thunder_breath_1| Thunder | High burst, demonstrates godspeed feel |
| R    | parry           | Water-5 | Defensive option, completes the loop |

Once the skill tree spends are wired (next pass), the player picks any
unlocked forms to bind to the four slots in real time.
