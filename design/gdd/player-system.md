# Player System

> **Status**: Needs Revision (revision-1 — addresses /design-review CONCERNS verdict: 1 BLOCKER + 3 RECOMMENDED + 4 NICE-TO-HAVE closed; awaiting re-review)
> **Author**: claude (revision-1 by claude after independent /design-review found XP formula divergence + 8 cross-doc signal-name mismatches with Combat GDD)
> **Last Updated**: 2026-05-25 (revision-1)
> **Implements Pillar**: Pillar 1 (清晰的生存压力 — Player is the survival subject), Pillar 2 (自动战斗与有意义的构筑选择 — Player owns the human-driven half of the input contract), Pillar 4 (数据驱动迭代 — Player stats are Resource-tuned via CharacterBase)
> **TR Coverage**: TR-core-001 (manual movement), TR-stack-001 (Godot+GDScript stack)

## Overview

The Player System owns the human-controlled avatar: movement, health, experience, level progression, weapon ownership, and the upgrade application pipeline. It is **the scene-and-runtime layer**; identity, base stats, and class-specific traits live one layer above in `CharacterBase` (a Resource-as-Node pattern). When a character is selected (修行者, 孙悟空, etc.), `CharacterBase` overrides Player's base values; when an upgrade is applied at level-up, Player mutates its own state in response to an `upgrade_applied` event.

Player is the **most central single-system node in the scene tree**: it owns the camera, the HP bar, six weapon child nodes (Talisman, FlyingSword, ThunderLaw, BaguaArray, ExplosiveTalisman, MountainSeal), the CharacterBase data node, and emits five signals that downstream systems (HUD, Run State, Experience, Combat, Pickup) subscribe to.

Reference ADRs: ADR-0001 (Godot 4.x + GDScript) constrains the implementation language; ADR-0003 (Sun Wukong active skills) defines the `ActiveSkillCharacter` subclass exception to the auto-battle contract.

## Player Fantasy

Movement is the only verb the player owns continuously. Everything else — attacks, pickups, level-up offers — happens *to* or *for* the player as consequences of moving well.

> "I'm a 修行者 wading into a tide of妖物. My talismans fire on their own; my survival is whether I read the field fast enough. Every step is a small decision — chase the experience orb that just dropped, kite the Bagua Array around an elite, dart through a burn patch to reach the镇妖碑 before it expires. I never press an attack button. I press a direction key, and either my构筑 carries me through or it doesn't."

When the Player System works invisibly, the player feels:
- **Sovereignty over space**: at 180 px/s base speed, the player can outrun any normal enemy and most elites. Positioning is the primary skill expression.
- **Weight of progression**: each level-up moment is a deliberate pause where the build becomes more *theirs*. The upgrade choice fires `upgrade_applied(upgrade_id)`, mutating Player state in a way the next 30 seconds will reveal.
- **Honest pain**: when HP drops, it drops because of an enemy contact the player could (in principle) have avoided. There is no "ghost damage." The HP bar is contract-grade truth.

Anti-fantasy: the player should never feel like they are *operating* the Player System. The system is a body, not a vehicle.

## Detailed Rules

### Core Rules

1. **Player movement is manual, vector-based, normalized to base speed.** Input combines `move_up/down/left/right` (set in `project.godot` Input Map per TR-core-001) into a `Vector2`. The vector is normalized, scaled by `move_speed × speed_multiplier`, applied as `velocity` on the underlying `CharacterBody2D`, and resolved via `move_and_slide()` per frame.

2. **Player owns its HP write.** Per Combat GDD Core Rule 3, only Player may decrement its own HP. Public entry point: `take_damage(amount: float) -> void`. Combat layer requests; Player applies. After applying, Player emits `health_changed(current_hp, max_hp)`.

3. **HP reaching 0 triggers death lifecycle.** Player emits `died()` and `health_changed(0, max_hp)` in the same frame, then enters a terminal `DEFEATED` state per Combat GDD Core Rule 4. There is no revive path in v0.4 (out of scope; see Open Questions).

4. **Player is the upgrade application sink.** When the Level Up panel returns a choice, the panel calls Player's internal upgrade application; Player mutates its own state (e.g. raise `xp_gain_multiplier`, raise `pickup_radius_bonus`, or push a per-weapon upgrade message to the relevant child weapon node). Player emits `upgrade_applied(upgrade_id: StringName)` so analytics and HUD can observe.

5. **CharacterBase overrides Player base stats at character selection.** When the character-select panel resolves a choice, the chosen `CharacterBase` Resource is attached as a child Node under Player. Its `max_health`, `move_speed`, `pickup_radius`, `initial_weapon_id`, and `element` fields **replace** Player's hard-coded defaults. Without a CharacterBase attached, Player uses the defaults (used in dev / debug only — production scenes must wire a CharacterBase).

6. **Weapons live as Player's child nodes.** Six weapon scenes (Talisman, FlyingSword, ThunderLaw, BaguaArray, ExplosiveTalisman, MountainSeal) are pre-instantiated under Player. At character selection time, all weapons start *disabled* except those listed in `initial_weapon_id`. Per-weapon `unlock` upgrades (e.g. `UPGRADE_UNLOCK_FLYING_SWORD`) enable additional weapons during the run.

7. **Upgrade pool is filtered by current character's weapons** (per TR-wpn-003 and 04_SKILL_DESIGN §9). Weapon-specific upgrade IDs (e.g. `UPGRADE_TALISMAN_DAMAGE`) only appear in the level-up choice pool if the relevant weapon is currently equipped or unlocked.

8. **`upgrade_random_seed` makes upgrade-pool offerings deterministic per run.** Two runs starting with the same seed see identical level-up offer sequences. The seed is exported as `2401` by default; production uses a per-run random seed. This determinism enables /balance-check replay and QA repro.

9. **Player emits four progression signals at distinct moments**:
   - `health_changed(current, max)` — every HP mutation, including overheal and zero-clamp
   - `experience_changed(current_xp, xp_to_next_level, level)` — every XP gain, including over-cap (XP rolls into next level)
   - `level_reached(level)` — at level threshold crossing, before the Level Up panel pauses the run
   - `upgrade_applied(upgrade_id)` — after the player picks an upgrade and Player has finished mutating its state

### States and Transitions

Player has no global state machine — it is signal-driven. Each subsystem has its own state, summarised below:

#### Player movement state

| State | Transition trigger | Next state |
|---|---|---|
| `IDLE` (zero input vector) | input vector becomes non-zero | `MOVING` |
| `MOVING` (input vector non-zero) | input vector returns to zero | `IDLE` |
| `IDLE` or `MOVING` | `set_invincible(true)` called (debug / cheats) | unchanged (movement loop unaffected; takes_damage becomes no-op) |
| any | `defeated` emit | `DEFEATED` (terminal — Run State takes over) |

#### Player HP state

| State | Transition trigger | Next state |
|---|---|---|
| `ALIVE` (current_hp > 0) | `take_damage(amount)` with hp - amount > 0 | `ALIVE` (HP mutated, `health_changed` emit) |
| `ALIVE` | `take_damage(amount)` with hp - amount ≤ 0 | `DEFEATED` (HP clamps to 0, `health_changed(0, max)` + `died()` emit) |
| `DEFEATED` | terminal — no transition out | (Run State owns the lifecycle from here) |

#### Player progression state

| State | Transition trigger | Next state |
|---|---|---|
| `LEVEL_N_GAINING_XP` (xp < xp_to_next_level) | `gain_experience(amount)` with current_xp + amount < xp_to_next_level | same level (xp updated) |
| `LEVEL_N_GAINING_XP` | `gain_experience(amount)` with current_xp + amount ≥ xp_to_next_level | `LEVEL_N+1_GAINING_XP` + `level_reached(N+1)` emit + Level Up panel opens |
| `LEVEL_UP_PAUSED` (Level Up panel open) | player selects an upgrade choice | `LEVEL_N+1_GAINING_XP` + `upgrade_applied(id)` emit + panel closes + run resumes |

### Interactions with Other Systems

| System | Direction | Interface |
|---|---|---|
| **Input** (F-01) | Input → Player | Player reads `move_up/down/left/right` action states each `_physics_process()` |
| **Run State** (F-03) | Player → Run State | `died()` signal initiates run-end. Run State pauses Player input during pre-Boss warning / Level Up panel. |
| **Camera** (C-02) | Camera depends on Player | Camera is a child node of Player; transforms inherit. No data flow. |
| **Combat** (C-03) | Combat → Player | Combat calls `Player.take_damage(amount)` with the damage tuple per Combat GDD Core Rule 2. Player emits `health_changed` per Combat GDD Core Rule 3. |
| **CharacterBase** (FT-06 instance) | CharacterBase → Player | At spawn, Player reads `CharacterBase.max_health`, `move_speed`, `pickup_radius`, `initial_weapon_id`, `element` and overrides defaults. |
| **Weapon System** (FT-03) | Player owns weapons | Six weapon nodes are children of Player; weapons read Player position for spawn anchor; weapons receive upgrade messages from Player after `upgrade_applied`. |
| **Experience & Progression** (FT-04) | XP → Player | Pickup System calls `Player.gain_experience(amount)`. Player handles level-up internally. |
| **Level Up & Upgrade Pool** (FT-05) | Player ↔ Pool | Player opens the Level Up panel on `level_reached`; panel returns chosen upgrade id; Player applies and emits `upgrade_applied`. |
| **Pickup System** (FT-12) | Pickup → Player | Pickup System reads `Player.get_pickup_radius_bonus()` to scale its detection radius; reads Player position as origin. |
| **HUD** (P-01) | Player → HUD | HUD subscribes to `health_changed`, `experience_changed`, `level_reached`, `upgrade_applied`. **Player owns these signals — per Combat GDD Core Rule 3.** |
| **Active Skills** (FT-07, Sun Wukong only) | Player ↔ ActiveSkillCharacter | When the selected CharacterBase is `ActiveSkillCharacter` subclass, Player routes 1/2/3/4 key input into `cast_skill(slot)`. See ADR-0003 + SUN_WUKONG_V2_DESIGN. |

`health_changed`, `died`, `experience_changed`, `level_reached`, `upgrade_applied` are owned by Player. Player is the authoritative source for player-side state.

## Formulas

### Formula 1: Movement velocity

```
input_vec   = Vector2(
    Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
    Input.get_action_strength("move_down")  - Input.get_action_strength("move_up")
)
direction   = input_vec.normalized() if input_vec.length() > 0 else Vector2.ZERO
velocity    = direction × move_speed × speed_multiplier
move_and_slide()
```

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| `input_vec` | i | Vector2 | each axis in [-1, 1] (analog stick range) | Raw input from action states |
| `direction` | d̂ | Vector2 | unit vector or zero | Normalized direction (prevents diagonal speed boost) |
| `move_speed` | s | float | 50 – 400 (design-safe) / 0 – ∞ (no clamp) | Base speed in px/s |
| `speed_multiplier` | m | float | 0.5 – 3.0 (design-safe) / 0 – ∞ | Buff hook (e.g. from upgrades, status effects) |
| `velocity` | v | Vector2 | bounded by s × m | Applied to CharacterBody2D before `move_and_slide()` |

**Output Range:** velocity magnitude is 0 (stationary) to `move_speed × speed_multiplier` (max sprint). At base values (180 × 1.0 = 180 px/s), a full screen (1280 px wide) takes ~7 seconds to cross corner-to-corner.

**Example:** 修行者 with `move_speed = 180, speed_multiplier = 1.0`, holding W+D (up + right) → `input_vec = (1, -1)` → `direction = (0.707, -0.707)` → `velocity = (127.3, -127.3)` (magnitude 180, NOT 254 — normalization prevents the classic diagonal-speed bug).

### Formula 2: HP application

Delegated to Combat GDD Formula 1. Player's `take_damage(amount)` is the **entry point**:

```
on take_damage(amount):
    if is_invincible: return                   # cheat / debug bypass
    current_hp = max(0, current_hp - amount)   # Combat Formula 1
    health_changed.emit(current_hp, max_hp)
    if current_hp == 0:
        died.emit()
        # Player enters DEFEATED state; Run State observes died signal
```

Player does NOT independently calculate damage — it receives a pre-resolved `amount` from Combat. The formula here is the **mutation + signal emission**, not the damage calculation.

### Formula 3: XP-to-next-level curve (recursive, `ceilf`-clamped)

The XP threshold for the next level is computed **recursively from the previous threshold**, NOT as a closed-form `f(level)`. Each step is clamped via `ceilf` and a strict-monotonic floor:

```
xp_threshold(1) = initial_xp_to_next_level   # base case: 18.0 default
xp_threshold(L) = ceil(max(
    xp_threshold(L-1) × max(μ, 1.0) + max(δ, 0.0),    # main computation
    xp_threshold(L-1) + 1.0                            # strict-monotonic floor
))                                                      # for L ≥ 2
```

Two safeguards inside the formula:
- `max(μ, 1.0)` prevents accidental level-down (if `xp_growth_multiplier` is set < 1.0, growth defaults to flat-only)
- `max(threshold, previous + 1)` ensures monotonic increase even when μ ≈ 1.0 and δ = 0

The `ceilf` rounds up each step, which **accumulates** across many levels — this is intentional (designers see whole-XP values, no fractional displays).

**Why recursive, not closed-form**: every `ceilf` truncation propagates, so the actual values cannot be computed from a closed-form `f(level)` without simulating the recursion. Any documentation that uses the closed-form will be wrong by L=2 (1 XP off) and significantly off by L=10 (40+ XP off).

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| `level` | L | int | 1 – 50 (expected MVP cap) | Current level (starts at 1) |
| `initial_xp_to_next_level` | x₀ | float | 10 – 30 (design-safe) | XP for level 1 → 2 (base case) |
| `xp_growth_multiplier` | μ | float | 1.10 – 1.40 (design-safe); clamped to `max(μ, 1.0)` inside formula | Exponential growth per level |
| `xp_growth_flat` | δ | float | 0 – 15 (design-safe); clamped to `max(δ, 0)` inside formula | Additive growth per level |

**Default values (in code, verified):** x₀ = 18.0, μ = 1.28, δ = 6.0.

**Output Range (computed by simulation against the actual code path):**

| L→L+1 | Threshold (XP) | Computation |
|---|---|---|
| 1 → 2 | 18 | base case |
| 2 → 3 | 30 | ceil(max(18 × 1.28 + 6, 19)) = ceil(29.04) = 30 |
| 3 → 4 | 45 | ceil(max(30 × 1.28 + 6, 31)) = ceil(44.4) = 45 |
| 4 → 5 | 64 | ceil(max(45 × 1.28 + 6, 46)) = ceil(63.6) = 64 |
| 5 → 6 | 88 | ceil(max(64 × 1.28 + 6, 65)) = ceil(87.92) = 88 |
| 6 → 7 | 119 | ceil(max(88 × 1.28 + 6, 89)) = ceil(118.64) = 119 |
| 7 → 8 | 159 | ceil(max(119 × 1.28 + 6, 120)) = ceil(158.32) = 159 |
| 8 → 9 | 210 | ceil(max(159 × 1.28 + 6, 160)) = ceil(209.52) = 210 |
| 9 → 10 | 275 | ceil(max(210 × 1.28 + 6, 211)) = ceil(274.8) = 275 |
| 10 → 11 | 358 | ceil(max(275 × 1.28 + 6, 276)) = ceil(358.0) = 358 |
| ≈ 20 → 21 | ≈ 4000 | recursive — ceil accumulation makes precise value path-dependent on prior states |

**Example:** Killing a Wandering Soul drops 5.5 XP (per entities.yaml). Level 1 → 2 requires 18 / 5.5 ≈ 3.3 Wandering Souls. Level 5 → 6 requires 88 / 5.5 ≈ 16 Wandering Souls (with Talisman + Flying Sword build at v0.4 baseline, this takes ~40-60 seconds mid-game).

> **revision-1 note (B-1 fix)**: revision-0 documented a closed-form `xp_to_next_level(level) = x0 × μ^(L-1) + δ × (L-1)` which is mathematically inconsistent with the shipping code's recursive `ceilf` implementation. Differences grow fast: closed-form predicted L5→6 = 73.4, actual is 88; closed-form predicted L10→11 = 250, actual is 358 (a 43% under-estimate). All AC values, worked examples, and the entities.yaml registry entry have been recomputed against the actual code path.

### Formula 4: XP gain with multiplier

```
on gain_experience(amount):
    effective_amount = amount × xp_gain_multiplier
    current_xp += effective_amount
    while current_xp >= xp_to_next_level(level):
        current_xp -= xp_to_next_level(level)
        level += 1
        level_reached.emit(level)
    experience_changed.emit(current_xp, xp_to_next_level(level), level)
```

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| `amount` | a | float | 0 – 100 | Raw XP from a pickup (per `xp_drop_value` on Enemy) |
| `xp_gain_multiplier` | g | float | 1.0 (default) – 3.0 (upgrade-stacked) | Player upgrade modifier |
| `effective_amount` | e | float | a × g | XP actually credited |

**Carry-over rule:** If a single `gain_experience` call would push the player through multiple levels (e.g. defeating a Boss late-game grants 100 XP at level 8 when only 30 are needed), the while-loop credits each level individually, emitting `level_reached` per level. Level Up panel **stacks** the offers — a 3-level jump produces 3 sequential panel openings.

### Formula 5: Pickup radius effective range

```
effective_pickup_radius = (CharacterBase.pickup_radius or default 50) + pickup_radius_bonus
```

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| `CharacterBase.pickup_radius` | r₀ | float | 30 – 120 (design-safe) | Per-character base from CharacterBase Resource |
| `pickup_radius_bonus` | b | float | 0 (default) – 100 (upgrade-stacked) | From Player upgrade pool |

**Output Range:** typically 50 – 150 px at MVP balance.

**Example:** 修行者 with CharacterBase.pickup_radius = 50 and Player.pickup_radius_bonus = 20 → effective radius = 70 px. XP orbs within 70 px of Player are auto-collected by the Pickup System (per TR-core-003 + Pickup GDD when written).

## Edge Cases

- **If `is_invincible == true`** (debug or cheat hook): `take_damage` returns immediately; no HP change, no signal emit. This is intentional for /soak-test runs and balance debug, but production builds should never see invincibility activated.
- **If `take_damage(0)`**: HP is unchanged. Per Combat GDD Core Rule 7, the source-side `damage_dealt` signal still fires from the source. Player's `health_changed` does NOT emit (no state change).
- **If `take_damage(amount)` with `amount > current_hp`**: HP clamps to 0 (overkill not stored). `died` fires exactly once. Subsequent `take_damage` calls in the same frame are silently dropped — Player is in `DEFEATED` state.
- **If two `take_damage` calls arrive in the same frame, both with `amount > 0`**: both are applied sequentially (HP decremented twice, `health_changed` emitted twice). If the first kills, the second is dropped per the DEFEATED-state rule above.
- **If `gain_experience` is called while `DEFEATED`**: XP is still credited internally (so post-death stats are accurate for the score screen), but `level_reached` is NOT emitted — Level Up panel cannot open during DEFEATED.
- **If `level_reached` fires while Level Up panel is already open** (multi-level XP carry-over): subsequent `level_reached` queues. After the player picks an upgrade for level N, the panel reopens for level N+1, etc., until the queue is empty.
- **If the player picks an upgrade for a weapon that gets later unlocked**: the upgrade is silently dropped (it has no target). This should be impossible if the upgrade pool filter (Core Rule 7) works correctly, but the application path tolerates it as a defensive guard.
- **If `pickup_radius_bonus` is set to a negative value via a future debuff**: effective radius is clamped to 0 (can't reach for orbs the player is standing on the edge of). No upgrade in v0.4 sets it negative.
- **If `set_speed_multiplier(0)` is called** (paralysis status effect): Player is unable to move but still takes damage and emits signals. This is the "immobilize" effect from `scripts/weapon/sun_wukong/immobilize.gd` applied to Player via friendly mechanics (currently unused — reserved for future).
- **If `set_damage_multiplier(value)` is called**: this modifies *outgoing* damage from Player's weapons (passed via the source_modifier slot in Combat Formula 1's pipeline). It does NOT affect *incoming* damage to Player. The name is slightly confusing — see Open Questions.
- **If no CharacterBase is attached to Player** (dev / debug scene): Player uses default exports (`max_hp = 100`, `move_speed = 180`, `pickup_radius` falls through to a hardcoded 50). Game is playable but no character identity is established. Production must wire a CharacterBase per character-select flow.
- **If `xp_growth_multiplier == 1.0`** (linear growth, debug case): the exponential component goes flat; XP-to-next-level grows purely additively. Each level takes `initial_xp_to_next_level + (level - 1) × xp_growth_flat` XP. Permitted as a debug curve, not a shipping value.

## Dependencies

| Dependency | Type | Direction | Interface |
|---|---|---|---|
| **Input** (F-01) | Hard | Player depends on | Reads `move_up/down/left/right` action states each `_physics_process()` |
| **Combat** (C-03) | Hard | Bidirectional | Combat calls `Player.take_damage(amount)`; Player emits `health_changed` + `died` |
| **CharacterBase** (FT-06 base class) | Hard | Player depends on | Reads `max_health`, `move_speed`, `pickup_radius`, `initial_weapon_id`, `element` at character spawn |
| **Resource Data Framework** (F-02) | Hard | Player depends on | CharacterBase is a Resource (.tres) per Pillar 4 |
| **Run State** (F-03) | Soft | Player → Run State | `died` signal initiates run-end transition |
| **Camera** (C-02) | Soft | Camera depends on Player | Camera is a child node; transform inheritance only |
| **Weapon System** (FT-03) | Soft | Player owns | Six weapon nodes are Player's children; weapons read Player position; weapons receive `upgrade_applied` payloads |
| **Experience & Progression** (FT-04) | Soft | Pickup → Player → Level Up | Pickup calls `gain_experience(amount)`; Player handles level-up internally |
| **Level Up & Upgrade Pool** (FT-05) | Soft | Player ↔ Pool | Player opens Level Up panel on `level_reached`; panel returns upgrade id; Player applies and mutates |
| **Pickup System** (FT-12) | Soft | Pickup depends on Player | Reads `get_pickup_radius_bonus()` and position |
| **HUD** (P-01) | Soft | Player → HUD | HUD subscribes to `health_changed`, `experience_changed`, `level_reached`, `upgrade_applied` |
| **Active Skills** (FT-07 — Sun Wukong only) | Soft | Player ↔ ActiveSkillCharacter | Routes 1/2/3/4 key input into `cast_skill(slot)` when CharacterBase is ActiveSkillCharacter subclass |

**Bidirectional check (per design-docs rule)**:
- Combat GDD must list "Bidirectional with Player" in its Dependencies. ✅ Combat GDD lines 397: "Player owns its HP; Combat sends damage events; Player emits `health_changed(current, max)` and `died()`". **(revision-1 reconciliation)**: Combat GDD originally used the signal name `defeated()` in 8 places; the code (`scripts/player/player.gd:4`) declares `signal died` and emits `died.emit()` (line 205). Combat GDD has been propagated to use `died()` consistently in this revision; this bidirectional check is now accurate.
- CharacterBase / Character System GDD must list "Player depends on CharacterBase for base stats" in its Dependencies. ⏳ (will be enforced when Character System GDD is written)
- All downstream soft-dependents (HUD, Run State, Pickup, Experience, Level Up) must list Player as their source. ⏳ (will be enforced when each GDD is written)

## Tuning Knobs

All Player values are tunable via:
- **Player.tscn exports** (per-scene defaults, dev / debug)
- **CharacterBase.tres** (per-character production values — overrides Player exports at character-select time)

| Knob | Owner | Design-safe range | Default | Effect at extremes |
|---|---|---|---|---|
| `Player.max_hp` (default) | Player.tscn | 30 – 200 | 100 | <30 = trivial-to-kill; >200 = trivializes mid-game enemies. (NOTE: Combat GDD §Pressure Curve assumes HP=30 as design intent; current 修行者 ships at 100 — see OQ-1 for propagation path.) |
| `Player.move_speed` (default) | Player.tscn | 100 – 300 | 180 | <100 = can't outrun Fox Spirit (132); >300 = trivializes positioning |
| `Player.initial_xp_to_next_level` | Player.tscn | 10 – 30 | 18.0 | <10 = level 1→2 in seconds; >30 = first upgrade feels late |
| `Player.xp_growth_multiplier` | Player.tscn | 1.10 – 1.40 | 1.28 | <1.10 = late game over-levels; >1.40 = leveling stalls hard |
| `Player.xp_growth_flat` | Player.tscn | 0 – 15 | 6.0 | <0 not allowed; >15 = early game stagnates |
| `Player.xp_gain_multiplier` | Player.tscn / upgrades | 1.0 – 3.0 | 1.0 | Upgrade stack ceiling; >3.0 trivializes XP economy |
| `Player.pickup_radius_bonus` | Player.tscn / upgrades | 0 – 100 | 0.0 | Upgrade stack ceiling; combined with CharacterBase 50 px base → max ~150 px |
| `Player.upgrade_random_seed` | Player.tscn (dev only) | any int | 2401 | Hardcoded for dev determinism; production overrides per-run |
| `CharacterBase.max_health` | CharacterBase.tres | 30 – 200 | 100 (修行者) | Overrides Player.max_hp at spawn |
| `CharacterBase.move_speed` | CharacterBase.tres | 100 – 300 | 180 (修行者 — overridden in Player.tscn from the class default of 200) | Overrides Player.move_speed |
| `CharacterBase.pickup_radius` | CharacterBase.tres | 30 – 120 | 50 (修行者) | Overrides Player default |
| `CharacterBase.element` | CharacterBase.tres | enum {neutral, **metal**, wood, water, fire, earth} | "neutral" | Reserved for 五行 GDD (v0.5+ per OQ-4 in Combat GDD). **Canonical English term is `metal` (not `gold`), matching `scripts/character/character_base.gd:79` doc-comment.** |

**Interaction warnings**:
- Lowering `Player.max_hp` while keeping enemy `damage` high → Pressure Curve becomes punishing fast. Pair these in tuning passes.
- `xp_growth_multiplier × xp_growth_flat` combination defines the pacing of the level-up cadence — adjust both together, not individually.
- `set_speed_multiplier(value)` is a runtime hook for buffs / debuffs; it stacks multiplicatively with `move_speed`, so a 0.5 multiplier on a 180 speed character produces 90 px/s (slower than every enemy except Stone Golem).

## Visual/Audio Requirements

Player visual contract:
- **Body sprite**: currently a `Polygon2D` placeholder (see `scenes/player/Player.tscn`). Per 07_VISUAL_STYLE_GUIDE 暗黑志怪 palette, the production sprite will be a 修行者 silhouette (具体 art passes via /art-bible).
- **HealthBar overlay**: 36 × 5 px bar above the body. Two layers (Background + Fill `Polygon2D`s). Updates instantly on `health_changed` signal.
- **Low-HP visual cue** (UX-spec'd in HUD GDD): when `current_hp < 0.25 × max_hp`, HUD layers a heartbeat / vignette effect. Player doesn't render this directly — it emits the signal and trusts HUD.
- **Death animation**: per Combat GDD Core Rule 4, data-death is 1 frame; visual-death is `≤ 0.5s` dissolve owned by VFX GDD. Player's `died` signal is the trigger; VFX handles the rendering.

📌 **Asset Spec** — Once 07_VISUAL_STYLE_GUIDE is locked and an art-bible exists for 修行者 silhouette, run `/asset-spec system:player` to produce per-asset specs (body sprite, HealthBar texture if upgraded from Polygon2D, footstep VFX hook).

Audio handoff to Audio GDD:
- **Footstep cadence**: at base 180 px/s, a step ~ every 0.5s feels right. Audio GDD owns the actual cue.
- **Hit reaction grunt**: on `take_damage` with amount > some threshold (Audio GDD decides). Per the Combat Feedback minimum-flash-interval rule (0.05s), grunts also need coalescing — avoid playing on every tick of a multi-tick burn.
- **Level-up chime**: on `level_reached`. Owned by Audio.
- **Death sting**: on `died`. Owned by Audio.

## UI Requirements

Player exposes UI surfaces consumed by HUD and per-Player overlays:

1. **Player HP bar** (HUD): subscribes to `Player.health_changed(current_hp, max_hp)`. Updates instantly (≤ 50ms after signal). When `current_hp < 0.25 × max_hp`, HUD adds the low-HP heartbeat effect.
2. **Per-Player HealthBar** (above sprite, drawn by Player itself): the 36 × 5 px bar at scene-level. Always visible. Updates on `health_changed`.
3. **XP bar** (HUD): subscribes to `Player.experience_changed(current_xp, xp_to_next_level, level)`. Bar fills 0 → xp_to_next_level as XP accrues. Resets visually when level_reached fires.
4. **Level indicator** (HUD): subscribes to `Player.level_reached(level)`. Updates the "境界 N" display in the HUD's top-left.
5. **Upgrade chosen feedback** (HUD): subscribes to `Player.upgrade_applied(upgrade_id)`. Brief toast / icon in HUD acknowledging the choice.
6. **Game-over flow trigger** (Run State, not HUD directly): subscribes to `Player.died()`. See Run State GDD for transition contract.

📌 **UX Flag — Player System**: HUD HP bar / XP bar / Level indicator / upgrade toast are UI surfaces. In Phase 4 (Pre-Production), run `/ux-design` for `design/ux/hud.md` (which covers all these) **before** writing epics that touch this UI. See Combat GDD's UX Flag for the existing queued spec list.

## Acceptance Criteria

Numbered for traceability into `/create-stories`.

### AC group: Movement (Core Rule 1, Formula 1)

**AC-01** **GIVEN** Player with `move_speed = 180, speed_multiplier = 1.0`, **WHEN** input `move_right` is held for 1.0 second on a flat empty arena, **THEN** Player's position has advanced by 180 px on the x-axis (±5 px tolerance for frame-discretization).

**AC-02** **GIVEN** Player with same defaults, **WHEN** input `move_up` AND `move_right` are held simultaneously for 1.0 second, **THEN** Player's displacement magnitude is 180 px (NOT 254.5 px — Formula 1 normalization prevents diagonal speed boost).

**AC-03** **GIVEN** Player on a collision boundary, **WHEN** input pushes Player into the wall, **THEN** Player slides along the wall (via `move_and_slide()`) without stopping or jittering. (Engine-provided behavior; this AC verifies the wiring.)

### AC group: HP and damage (Core Rules 2, 3; Formula 2)

**AC-04** **GIVEN** Player with `current_hp = 100, max_hp = 100`, **WHEN** `take_damage(8)` is called, **THEN** `current_hp` becomes 92 AND `health_changed(92, 100)` is emitted exactly once.

**AC-05** **GIVEN** Player with `current_hp = 5, max_hp = 100, is_invincible = false`, **WHEN** `take_damage(50)` is called, **THEN** `current_hp` becomes 0 AND `health_changed(0, 100)` is emitted AND `died()` is emitted (both in the same frame, in that order).

**AC-06** **GIVEN** Player in `DEFEATED` state (`current_hp = 0` and `died` already fired), **WHEN** `take_damage(20)` is called subsequently, **THEN** no further `health_changed` or `died` signals fire AND `current_hp` remains 0.

**AC-07** **GIVEN** Player with `is_invincible = true`, **WHEN** `take_damage(50)` is called, **THEN** `current_hp` is unchanged AND no `health_changed` or `died` signal fires. (Cheat hook validation.)

**AC-08** **GIVEN** Player with `current_hp = 50`, **WHEN** `take_damage(0)` is called, **THEN** `current_hp` remains 50 AND no `health_changed` signal fires (no state change per Combat GDD Core Rule 7).

### AC group: XP and progression (Core Rule 4, Formulas 3 + 4)

**AC-09** **GIVEN** Player at level 1 with `current_xp = 0` and defaults (x₀=18, μ=1.28, δ=6), **WHEN** `gain_experience(18)` is called, **THEN** `level_reached(2)` is emitted AND `current_xp` rolls to 0 AND `experience_changed(0, 30, 2)` is emitted. (Note: 30 — not 29.04 — because Formula 3 applies `ceilf` to `18 × 1.28 + 6 = 29.04` per the recursive code path. revision-0 of this GDD asserted 29.04 from a now-corrected closed-form formula.)

**AC-10** **GIVEN** Player at level 1 with `xp_gain_multiplier = 2.0`, **WHEN** `gain_experience(10)` is called, **THEN** `effective_amount = 20` AND `current_xp` becomes 2.0 AND `level_reached(2)` is emitted (because effective 20 > threshold 18).

**AC-11** **GIVEN** Player at level 5 with `current_xp = 0`, **WHEN** `gain_experience(150)` is called (enough to skip multiple levels at this curve), **THEN** `level_reached` is emitted for level 6 AND level 7 (in that order) AND the Level Up panel queue contains two pending offers.

**AC-12** **GIVEN** Player in `DEFEATED` state, **WHEN** `gain_experience(50)` is called, **THEN** `current_xp` is credited internally for the score screen BUT no `level_reached` fires AND Level Up panel does not open.

### AC group: Upgrade application (Core Rules 4, 7, 8)

**AC-13** **GIVEN** Player with the Level Up panel returning `UPGRADE_TALISMAN_DAMAGE`, **WHEN** the upgrade is applied, **THEN** the Talisman child weapon node's `damage` field is incremented by **+10.0** (the v0.4 hardcoded delta in `_apply_upgrade` — see OQ-6 for tech-debt extraction to `.tres`) AND `upgrade_applied(UPGRADE_TALISMAN_DAMAGE)` is emitted exactly once.

**AC-14** **GIVEN** Player without `UPGRADE_UNLOCK_FLYING_SWORD` applied (Flying Sword still disabled), **WHEN** the upgrade pool is queried for choices, **THEN** `UPGRADE_FLYING_SWORD_DAMAGE` is NOT in the choice set (Core Rule 7 filter). Conversely, `UPGRADE_UNLOCK_FLYING_SWORD` IS in the set.

**AC-15** **GIVEN** Player with `upgrade_random_seed = 2401`, **WHEN** two runs are started from the same seed and gain XP at the same cadence, **THEN** the Level Up panel offers the same upgrade choices in the same order in both runs (determinism per Core Rule 8).

### AC group: Character base override (Core Rule 5)

**AC-16** **GIVEN** Player.tscn with default `max_hp = 100`, **WHEN** a CharacterBase Resource with `max_health = 80` is attached as a child node at character-select time, **THEN** Player's effective `max_hp` becomes 80 AND the first `health_changed` emit reports `(80, 80)`.

**AC-17** **GIVEN** Player with CharacterBase.initial_weapon_id = "talisman", **WHEN** the run starts, **THEN** the Talisman weapon child is enabled AND the other five weapon children (FlyingSword, ThunderLaw, BaguaArray, ExplosiveTalisman, MountainSeal) are disabled.

### AC group: Pickup radius (Formula 5)

**AC-18** **GIVEN** Player with CharacterBase.pickup_radius = 50 and `pickup_radius_bonus = 20`, **WHEN** Pickup System queries `Player.get_pickup_radius_bonus()`, **THEN** the returned value is 20 (the bonus only — base radius is read from CharacterBase by the Pickup System separately, per the FT-12 contract).

### AC group: Signal payload correctness

**AC-19** **GIVEN** any HP mutation event, **WHEN** `health_changed` emits, **THEN** the payload is exactly `(current_hp: float, max_hp: float)` in that order with both values ≥ 0.

**AC-20** **GIVEN** any XP gain event, **WHEN** `experience_changed` emits, **THEN** the payload is exactly `(current_xp: float, xp_to_next_level: float, level: int)` with `current_xp < xp_to_next_level` (since level-up consumes the threshold first).

## Open Questions

- **OQ-1** (HP discrepancy with Combat GDD Pressure Curve): Combat GDD §Pressure Curve §Survival Budget (lines 35-39) assumes `Player base HP = 30` and derives all TTK budgets from this. The actual shipping code value is **100** — a 233% divergence, well beyond Combat OQ-5's ±20% threshold. **Action required**: after this GDD is approved, run `/propagate-design-change design/gdd/player-system.md` against Combat GDD to recalibrate the Pressure Curve, OR make a deliberate balance decision to bring Player HP down toward 30 (would require a Player.tscn / CharacterBase.tres balance change). **Owner**: game-designer + systems-designer. **Target resolution**: before v0.4 playtest (this is a known dependency, not a discovered defect).
- **OQ-2** (`set_damage_multiplier` naming + wiring): the public method `set_damage_multiplier(value)` modifies *outgoing* damage from Player's weapons (per design intent; passed to weapons via the source_modifier slot in Combat Formula 1's pipeline). It does NOT affect *incoming* damage. The name is ambiguous. **Additional finding from /design-review (revision-1)**: the field `_damage_multiplier` is set by this method in `player.gd:835` but **not visibly read elsewhere in `player.gd`** — the connection to weapons happens through some other route (Weapon System pulls from Player? or the wiring is incomplete?). The GDD's claim that it's "passed via the source_modifier slot in Combat Formula 1's pipeline" is currently aspirational rather than wired-in. **Resolution candidate**: rename to `set_weapon_damage_multiplier` AND verify the actual wiring before Weapon System GDD is written. **Owner**: lead-programmer + systems-designer. **Target resolution**: before Weapon System GDD.
- **OQ-3** (Revive mechanic out of scope): Combat GDD edge case acknowledges that `DEFEATED` is terminal in v0.4 and any future revive mechanic requires a separate `revive(hp)` API bypassing the state machine. This GDD reaffirms: no revive in v0.4 Player. **Owner**: game-designer. **Target resolution**: if a revival upgrade or character trait is designed in a future version.
- **OQ-4** (Camera coupling): the Camera2D node is a child of Player, so transform inheritance handles the follow behavior. This is acceptable for MVP but may need a separate Camera GDD if features like screen shake, zoom transitions, or look-ahead are added. **Owner**: ux-designer. **Target resolution**: when /ux-design touches `design/ux/hud.md` or adds `design/ux/camera.md`.
- **OQ-5** (Six weapon nodes always pre-instantiated): Player.tscn has all six weapon children present at scene load time, even if only `initial_weapon_id` is enabled. This is the simplest pattern but means every Player instance carries node overhead for five disabled weapons. **Resolution candidate**: lazy-instantiation when `UPGRADE_UNLOCK_<weapon>` fires. **Owner**: performance-analyst + lead-programmer. **Target resolution**: after `/perf-profile` shows whether the overhead is measurable in the 50-100 enemy regime.
- **OQ-6** (Upgrade deltas hardcoded in `_apply_upgrade` match statement — tech debt vs. Pillar 4): The upgrade application path (`scripts/player/player.gd:710+` for TALISMAN_DAMAGE = +10.0; similar pattern for all 25+ upgrade IDs) hardcodes the delta values inside the match statement rather than reading them from a `.tres` Resource. AC-13 was originally worded "the upgrade's defined delta" implying data-driven, but the code is in-code constants. This violates Pillar 4 (数据驱动迭代) in spirit, though it works. **Resolution candidate**: extract upgrade definitions to `resources/upgrades/*.tres` (one file per upgrade or one master `.tres`). **Owner**: systems-designer + lead-programmer. **Target resolution**: when Level Up & Upgrade Pool GDD (FT-05) is written, OR as a sprint-1 refactor before any new upgrade is added. (Tracked as tech-debt — does not block current MVP since upgrades work; blocks Pillar-4 compliance.)
- **OQ-7** (XP formula recursion + `ceilf` accumulation): Formula 3 (revision-1) describes the recursive `ceilf` behavior accurately, but the cumulative rounding-up means actual values drift upward from any closed-form approximation (e.g., L10→11 = 358 actual vs. 250 closed-form prediction = 43% higher). This is acceptable for v0.4 — the curve "feels right" at default values per the macro-GDD 04_SKILL §9 — but `/balance-check` should validate the curve produces the desired session-length (5-6 levels per 5-minute run). **Resolution candidate**: if QA finds the level cadence too slow, lower `xp_growth_multiplier` from 1.28 to 1.22 (smaller exponential factor offsets the ceil accumulation). **Owner**: game-designer + qa-lead. **Target resolution**: after first v0.4 playtest report.

---

## Registry Updates Recorded

This GDD references entities / constants in `design/registry/entities.yaml`:

- 7 enemies (referenced for movement / pickup / TTK calculations): `paper_doll`, `wandering_soul`, `fox_spirit`, `ghost_flame`, `stone_golem`, `shanxiao_elite`, `famine_beast` — `referenced_by` array should be appended with `design/gdd/player-system.md`
- `target_framerate = 60` — Player Formula 1 movement assumes per-frame physics tick at 60 FPS
- `stage_duration_seconds = 300` — Player's run lifetime is bounded by this constant

**New formula candidates to register** (to be added by `/consistency-check` or manually):
- `player_xp_curve` (Formula 3): exponential + additive growth
- `player_xp_gain` (Formula 4): with multiplier and carry-over
- `player_pickup_radius` (Formula 5): CharacterBase + bonus

**Cross-doc consistency**:
- Player.tscn `max_hp = 100` — **divergent** from Combat GDD Pressure Curve's `HP = 30` assumption (see OQ-1; propagation required)
- Player.tscn `move_speed = 180` — Fox Spirit's `move_speed = 132` < Player; Stone Golem's `move_speed = 54` << Player; Shanxiao Elite's `move_speed = 72` < Player. Player can always outrun all enemies, as designed.
- CharacterBase.max_health 100 (修行者 default) matches Player.tscn default — no override drift at MVP baseline.

## Revision Log

| Revision | Date | Trigger | Summary |
|---|---|---|---|
| 0 | 2026-05-25 | Initial reverse-doc by /design-system | First pass authored from `scripts/player/player.gd` + `scripts/character/character_base.gd` + Player.tscn + 02_CHARACTER_DESIGN + Combat GDD contracts. 8 required sections + Visual/Audio + UI Requirements + Open Questions + Registry Updates. Notable: OQ-1 flags HP discrepancy with Combat GDD (100 vs 30 — 233% divergence requires propagation). |
| 1 | 2026-05-25 | /design-review verdict: CONCERNS (independent design-reviewer subagent) | **B-1 closed**: Formula 3 rewritten to match actual recursive-ceilf code path (was incorrectly a closed-form approximation, off by 43% at L10). Worked example table, AC-09 value (29.04 → 30), and entities.yaml expression all updated. **R-1 closed**: Combat GDD `defeated()` signal name (8 occurrences) propagated to `died()` to match `scripts/player/player.gd:4` `signal died`. Player GDD bidirectional check note updated. **R-2 closed**: CharacterBase.move_speed default corrected (200 class-default vs 180 Player.tscn override). **R-3 closed**: `element` enum value renamed `gold → metal` to match `character_base.gd:79`. **N-1 closed**: max_hp parenthetical reworded (was confusing). **N-2 closed**: OQ-2 expanded to flag `_damage_multiplier` un-read field. **N-3 closed**: AC-13 updated to reflect hardcoded +10.0 delta; OQ-6 added for tech-debt extraction. **N-4 closed**: OQ-7 added tracking XP formula recursion `/balance-check` follow-up. |
