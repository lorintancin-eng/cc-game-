# Combat System

> **Status**: In Design (revision-6 — /design-review MAJOR REVISION NEEDED addressed: 15 blockers resolved in-doc. Group A docs fixed (survival budget / AC stale values / Audio rate / DPS guardrail), Formula 1 `MAX_FINAL_DAMAGE_PER_HIT=200` clamp, aggregate ceiling → damage-tier selection, died/burn aligned to as-built, code deviations → OQ-7 backlog. Pending independent re-review. Prior: revision-5 D-B1 ×2.0 at HP=100.)
> **Author**: claude (revision-5 by claude — /propagate-design-change D-B1 OQ-5 closure, 2026-05-27)
> **Last Updated**: 2026-05-27 (revision-5)
> **Implements Pillar**: Pillar 1 (清晰的生存压力), Pillar 2 (自动战斗与有意义的构筑选择), Pillar 4 (数据驱动迭代)
> **TR Coverage**: TR-core-001, TR-core-005, TR-wpn-001, TR-wpn-002, TR-enemy-002

## Overview

Combat is the central data + signal layer that mediates every damage exchange in MythSurvivor. It is **infrastructure-shaped**, not a feature in itself: weapons declare damage intent, the Combat layer applies it to targets that have HP, and the layer emits the events (`damage_dealt`, `health_changed`, `damage_taken`, `died`) that downstream systems (Experience, Combat Feedback, Boss System, HUD) consume. Without Combat, weapons cannot affect enemies and enemies cannot affect the player — but players never "use" Combat directly; they use weapons and feel its effects through the **pressure curve** this layer enforces.

Reference ADRs: ADR-0001 (Godot 4.x + GDScript) constrains the implementation language and the signal-based architecture this system uses.

## Player Fantasy

Combat is **indirect** — players don't think about "the combat system," they think about *being under threat and pushing back*. The fantasy this layer enables:

> "I'm a 修行者 hunted by neon-cold spirits. My talismans and spells fire automatically — my job is to read the battlefield, choose where to stand, and trust that my构筑 is doing its work. Every hit on me costs me time; every kill of mine earns me 修为. The system gets out of my way and lets me feel the pressure curve build."

When Combat works invisibly, the player feels:
- **Tension**: each enemy carries a real threat (damage values matter, HP bars matter), but the game never one-shots them without warning
- **Power**: their构筑 turns into a visible damage stream that scales with升级
- **Clarity**: a hit is unambiguous — the enemy flashes, takes the value, dies on schedule
- **Fairness**: when surrounded by 8 enemies, Combat's aggregate DPS ceiling means the player still has a window to break out — not a 0.4-second wipe

When Combat fails (silent hits, ghost damage, dropped events, frame-rate-dependent burn), the player feels cheated. The system's success is measured by the *absence* of confusion and the *presence* of a readable pressure ramp.

## Pressure Curve (Design Targets)

This is the **design contract** the rest of the document implements. All formulas, tuning knobs, and acceptance criteria below must produce gameplay that satisfies this curve.

### Player Survival Budget

- **Player base HP**: **100** (matches `Player.tscn` and 修行者 `CharacterBase` `max_health` — per Player GDD revision-2, finalized). Combat GDD revision-4 propagated this from the original placeholder value of 30; all hits-to-die and reaction-window computations below are recomputed against HP=100.
- **Player MUST survive at least these scenarios at 60 FPS**:
  - Stationary in a single Paper Doll's contact for **8.5 seconds** before death (`damage = 10, damage_interval = 0.85` → ~11.76 dps × 8.5s ≈ 100 damage; 10 hits) — matches the Per-Phase table below
  - Surrounded by 4 simultaneous Paper Dolls for at least **2.13 seconds** before death (4 × 11.76 dps = 47.06 aggregate; HP 100 / 47.06 ≈ 2.13 s)
  - Surrounded by 8+ simultaneous Paper Dolls: aggregate DPS does **not** scale linearly past 4 attackers (Core Rule 8); the player still has **≥2.0s reaction window** — the same 2.13s as the 4-attacker case
- **Design note (OQ-5 closed by revision-5)**: HP=100 with the revision-5 ×2.0 damage values gives a 4-Paper-Doll survival window of **2.13 s** (vs ~0.64 s had HP stayed at 30). revision-5 executed path (a) of the former OQ-5 — enemy `damage` was tuned upward ×2.0 across all 7 `.tres` files — so the pressure curve now matches the Per-Phase table. Path (b) (lowering base HP toward 50-60) remains a possible future balance lever but is not active.

### Per-Phase TTK Budget (player vs. typical encounter)

Each phase's "hits-to-die" is computed against Player HP=100 and the dominant enemy of that phase. Use this as the **design target**: a sustained encounter in this phase should kill the player in roughly the listed hit count if they stand still.

| Phase | Time | Dominant enemy | hits-to-die @ HP=100 | Design intent |
|---|---|---|---|---|
| Familiarisation | 0:00 - 1:00 | Paper Doll (**dmg=10** r5) | **10 hits (8.5 s @ 0.85 interval)** | Player learns controls; single enemy is dangerous but survivable |
| First Pressure | 1:00 - 2:00 | Wandering Soul (**dmg=16** r5) | **~6 hits (5.0 s @ 0.8 interval)** | First time HP feels genuinely endangered — survive, don't linger |
| Risk/Reward | 2:00 - 3:00 | Stone Golem (**dmg=24** r5) | **~4 hits (4.2 s @ 1.0 interval)** | Demon seal decision matters because 4 contacts kills in ~1-2s |
| Elite Pressure | 3:00 - 4:30 | Shanxiao Elite (**dmg=30** r5) | **~3 hits (2.7 s @ 0.9 interval)** | Build matters; positioning matters — Elite is a clear kill threat |
| Boss Window | 4:30 - 5:00 | Mixed elite + filler | 3-4 hits depending on enemy | Player should be near-max equipped |
| Boss Fight | 5:00+ | Famine Beast (**dmg=36** r5) | **~3 hits (2.4 s @ 0.85 interval)** — 100 / 36 = 2.78 hits | Boss is the dominant threat; MUST dodge, cannot soak — Enrage at 30% HP is reachable |

> **revision-5 note (D-B1 OQ-5 closure)**: All damage values in this table are the post-path-(a) values (×2.0 multiplier applied to all 7 enemy `.tres` files). The survival windows at HP=100 now compress to ~2-10 hits-to-die, restoring meaningful pressure at each phase while retaining the HP=100 baseline. The aggregate DPS ceiling (MAX_CONTACT_ATTACKERS=4) remains the survival safety net. Playtest calibration may tune individual values up or down; the ×2.0 multiplier is the starting point, not the final answer.

### Per-Tier Enemy TTK Budget (weapon DPS targets)

Assuming the player has the v0.4 baseline build (Talisman + Flying Sword + 1-2 upgrades) at the time of encounter:

| Enemy tier | Example | Target TTK | Hits at base build DPS (~25 dps single-target) |
|---|---|---|---|
| Filler | Paper Doll (max_hp=14) | 0.4 - 0.7s | 1-2 hits |
| Normal | Wandering Soul / Fox Spirit / Ghost Flame (max_hp=18-24) | 0.7 - 1.2s | 2-4 hits |
| Tank | Stone Golem (max_hp=70) | 2.5 - 3.5s | 6-10 hits |
| Elite | Shanxiao Elite (max_hp=110) | 3.5 - 5.0s | 10-15 hits |
| Boss | Famine Beast (max_hp=360) | 12 - 18s | 35-45 hits |

### Incoming DPS Targets by Phase (player-side aggregate)

| Phase | Target incoming aggregate DPS | Notes |
|---|---|---|
| 0:00 - 1:00 | **0 - 24 dps** | At most 1-2 Paper Dolls; 1×10/0.85 = 11.8 dps, 2×=23.5 dps (with ceiling) |
| 1:00 - 2:00 | **12 - 40 dps** | First clustering; 2 Wandering Souls = 40 dps; start dodging |
| 2:00 - 3:00 | **24 - 72 dps** | Demon seal pressure; 3 Stone Golems = 72 dps → survival ~1.4s standing still |
| 3:00 - 4:30 | **40 - 80 dps** | Elite pressure; 2 Shanxiao × 33 dps each → DEADLY if caught stationary |
| 4:30 - 5:00 | **50 - 100 dps** | Pre-Boss peak density with elite + filler mix |
| Boss | **42 - 90 dps** | Boss = 36/0.85 ≈ 42 dps + summons; ceiling prevents ≥100 dps sustained |

> **revision-5 note**: DPS targets updated to reflect ×2.0 damage multiplier across all archetypes. Aggregate DPS ceiling (MAX_CONTACT_ATTACKERS=4) remains the key safety mechanism — without it, late-phase contact pressure would be fatal in <0.5s. With it, the player always has at least ~1.0-2.0s to react and escape.

**Aggregate DPS ceiling at any time**: ~50 dps. Combat enforces this via Core Rule 8 (max 4 simultaneous contact attackers). Without the ceiling, 8+ enemies of similar damage = 47+ dps and an HP=100 player dies in ~2.1 seconds — still a failure of the Familiarisation budget (which expects no death risk in minute 1) but less spectacularly fast than the HP=30 scenario originally documented (where uncapped contact killed in ~0.6s). The ceiling remains the correct mitigation regardless of which HP value the project ships at.

### Validation

These targets are **playtest-validated through `/playtest-report` runs**. Initial values are the design intent for v0.4 QA; expect adjustment after first playtest pass. The `damage_interval`, `max_hp`, and `damage` columns of `.tres` files are the tuning surface that enforces this curve — `/balance-check` should flag any value that violates a budget.

## Detailed Rules

### Core Rules

1. **Damage flows in one direction per exchange.** Either a weapon damages an enemy, or an enemy damages the player. **Friendly fire does not exist** — an explosion sourced from a weapon never damages the player or other allies, even within `explosion_radius`. Source-target classification (`weapon` / `enemy` / `environment`) is part of the damage tuple.

2. **Every damage event is a `(source, target, amount, damage_type, source_kind)` tuple.** No implicit damage, no shared mutable state — damage is data passing through signals.
   - `source`: the originating node (weapon instance, enemy instance, burn-patch instance)
   - `target`: the receiving node (enemy or player)
   - `amount`: float ≥ 0
   - `damage_type`: enum `{ DIRECT, TICK, EXPLOSION, BURN }` (status effects extend via separate enums in FT-10)
   - `source_kind`: enum `{ WEAPON, ENEMY, ENVIRONMENT }` (enforces friendly-fire rule from Core Rule 1)

3. **HP is mutable, owned by the target.** Only the target's own script may decrement its own HP in response to a damage event. Other systems request damage; the target applies it. **The target emits `health_changed(current, max)` after applying.**

4. **Death has two lifecycle phases.** When HP reaches 0:
   - **Data-death** (within 1 frame): target transitions to `DYING` state, `died(enemy_payload)` signal emits exactly once (see Core Rule 6 for guard), `last_hp = 0` locks.
   - **Visual-death** (asynchronous, ≤ 0.5s): dissolve animation plays, then `queue_free()`. Combat does not wait — downstream systems (XP spawn, victory trigger) react to `died` immediately.

5. **All damage values are configurable per Resource (`.tres`).** No hardcoded damage in `.gd` files except minimum-value safety floors. Tuning is data-driven (TR-data-001 + Pillar 4).

6. **DYING targets are inert to further damage events.** Once a target enters `DYING`, additional damage events targeting it are dropped silently (no HP change, no second `died` emit, no flash, no death VFX). This is enforced by a state guard, not by the damage formula. Without this guard, multi-hit frames could emit `died` twice, double-spawning XP orbs or double-triggering the Boss victory state.

7. **Zero-damage events still fire signals but do not reset throttles.** A `damage_amount = 0` event fires `damage_dealt(...)` (downstream systems may want to log it for status effect application), but it does **not** reset `last_hit_time` on the throttle (so a 0-damage debuff probe does not block real damage for the next throttle window).

8. **Aggregate DPS ceiling: max 4 simultaneous contact attackers against the player.** When more than 4 enemies are in contact with the player at the same time, only the **4 highest-damage** contact attackers participate in damage events; the lower-damage surplus queues but applies no damage until a slot frees. This caps theoretical incoming DPS and enforces the Pressure Curve §Player Survival Budget. **The 4-attacker selection is by damage tier — sort `(damage DESC, spawn_id ASC)` per Formula 7 (Blocker-2/5), NOT contact recency.** The earlier "most-recently-entered" rule was an anti-soak exploit: a player could run through cheap filler to cycle Elites / Boss-summons OUT of the slot and dodge their damage. Damage-tier priority guarantees the 4 most dangerous attackers always count; the `spawn_id` tiebreak makes same-frame wave spawns deterministic.

9. **Damage interval is per-enemy and per-target, not global.** Two different enemies hitting the player have independent `last_hit_time` counters. Two enemies of the same archetype (e.g., two Paper Dolls) each have their own throttle.

### Damage Types

Four damage types are supported. Every weapon and every environmental hazard must declare which type it produces. Status effects extend this via FT-10 Status Effects (separate GDD).

| Type | Field(s) | Time profile | Throttle? | Example weapon |
|---|---|---|---|---|
| **direct** | `damage` | One-shot on hit | Subject to enemy's `damage_interval` if target is player | Flying Sword, Talisman, Explosive Talisman impact (direct component) |
| **tick** | `damage` + `tick_rate` | Repeated at `tick_rate` while target is in zone | Per-zone, not per-target | Bagua Array (`tick_rate = 0.65s` default) |
| **explosion** | `explosion_damage` + `explosion_radius` | One-shot on impact, hits all in radius | None (single instant) | Explosive Talisman impact, Mountain Seal impact |
| **burn** | `burn_dps` + `burn_duration` | **Fixed-step tick at `BURN_TICK_INTERVAL = 0.1s`** | Per-burn-zone, accumulator-based | Thunder Strike (ground after-effect) |

**Damage type pipeline ordering** — every damage event passes through this pipeline:

```
raw_damage
    → × source_modifier   (weapon upgrades, e.g. damage_multiplier from level-up pool)
    → × crit_multiplier    [OQ-2 placeholder; default 1.0 until Active Skills GDD lands]
    → × element_modifier   [OQ-4 placeholder; default 1.0 until Elements GDD lands]
    → × pierce_falloff     (only for piercing projectiles; see Formula 6)
    → final_damage
    → applied via Formula 1 (clamped, never negative)
```

The placeholders `crit_multiplier` and `element_modifier` are **reserved slots in the pipeline** — both default to 1.0 and have no effect today, but the pipeline order is locked so that future GDDs (Active Skills, Elements) can amend their multipliers without rewriting Formula 1.

### States and Transitions

Combat has no global state machine — it is event-driven. Each *participant* (weapon, enemy, player) has its own state.

#### Weapon state

| State | Transition trigger | Next state |
|---|---|---|
| `IDLE` (cooldown_remaining > 0) | `delta` elapses in `_process`, cooldown reaches 0 | `READY` |
| `READY` (cooldown_remaining == 0) | `_try_attack()` returns true | `IDLE` (cooldown_remaining := cooldown) |
| `READY` | `_try_attack()` returns false (no valid target) | `READY` (retry next frame) |

#### Enemy combat state

| State | Transition trigger | Next state |
|---|---|---|
| `ALIVE` (hp > 0) | damage event, hp - amount > 0 | `ALIVE` (hp updated, `damage_taken(current, max)` emit, flash effect 0.1s) |
| `ALIVE` | damage event, hp - amount ≤ 0 | `DYING` (within 1 frame) |
| `DYING` | enter `DYING` | `died(enemy_payload)` emits **exactly once** (Core Rule 6 guard) |
| `DYING` | additional damage event | (no-op — event silently dropped) |
| `DYING` | dissolve animation completes (≤ 0.5s) | (node `queue_free()`'d) |

Elite enemies apply HP and damage multipliers on spawn (`iron_bones` = HP × 1.45, `swift` = speed × 1.3 — see Enemy GDD when written). Multipliers do not change Combat behaviour, only base values.

#### Player combat state

| State | Transition trigger | Next state |
|---|---|---|
| `ACTIVE` (hp > 0) | damage event from any enemy (subject to enemy's `damage_interval`, subject to Core Rule 8 ceiling) | `ACTIVE` if hp > 0 (`health_changed(current, max)` emit), else `DEFEATED` |
| `DEFEATED` | (`died()` emit — terminal — Run State system handles run end. **Signal name: `died` — matches `scripts/player/player.gd:4`. revision-3 of this GDD propagated from `defeated()` (stale) to `died()` (code-true) per Player GDD revision-1 reconciliation.**) | — |

### Interactions with Other Systems

| System | Direction | Interface |
|---|---|---|
| **Resource Data Framework** | Combat consumes | Reads weapon `.tres` and enemy `.tres` for damage / hp / cooldown values |
| **Targeting** | Combat depends on | Weapons call `Targeting.find_nearest(position, range)` to pick a target; Combat receives the chosen target via `_try_attack()` |
| **Weapon System** | Weapon → Combat | Each weapon subclass overrides `_try_attack()`; on success, calls into target with damage payload (Core Rule 2 tuple) |
| **Enemy** | Combat ↔ Enemy | Enemy decrements own HP in response to damage event; Enemy emits `damage_taken(current, max)` (HP bar trigger) and `died(enemy_payload)` |
| **Player** | Combat ↔ Player | Player decrements own HP; Player emits `health_changed(current, max)` (HUD trigger) and `died()` (Run State trigger). **Player owns the `health_changed` signal — per Core Rule 3** |
| **Status Effects** (FT-10) | Combat dispatches into | When damage_type is `TICK` or `BURN`, Combat may also notify Status Effects to create a stack on the target (separate GDD) |
| **Experience & Progression** | Enemy → Experience | On `died(enemy_payload)`, Experience reads `payload.position` for orb spawn and `payload.xp_value` for amount |
| **Combat Feedback (P-03)** | Combat events trigger | Combat Feedback subscribes to `damage_taken` (flash), `died` (death VFX), `health_changed` (low-HP heartbeat). **Minimum flash interval recommendation**: 0.05s between consecutive flashes on the same target (prevents strobe at high DPS) |
| **HUD** | Player → HUD | HUD subscribes to `health_changed(current, max)` on Player node and `level_changed` on Experience for live updates |
| **Run State** | Combat → Run State | `died()` and `Boss died()` are the two signals Run State observes for run-ending transitions |

`died` signal payload contract (Core Rule 4):
```
died(payload: {
    enemy: Enemy node reference,
    position: Vector2,              # for XP orb spawn anchor
    xp_drop_value: float,           # for Experience to award (0 for Boss)
    archetype_name: String,         # for analytics and damage attribution
    is_boss: bool                   # for Run State victory branch
})
```

> **⚠️ AS-BUILT (v0.4) — Blocker-14 resolution (GDD documents the code reality)**: the shipped code emits **`signal died(enemy: Enemy)`** — it passes the Enemy **node directly**, NOT the 5-field Dictionary above. XP orbs are spawned **inside `enemy._die()` BEFORE the signal fires**, not by an Experience subscriber reacting to `died`. Consumers read what they need off the node (`enemy.global_position`, `enemy.xp_drop_value`, `enemy.is_boss`). **Implement against the node form** — a programmer coding to the Dictionary will hit a null-access crash. The Dictionary payload above is the **target refactor contract** (cleaner decoupling: Experience reacts to the signal instead of `_die()` doing the spawn), tracked as Blocker-14 in the backlog OQ below. AC-18 / AC-02 assert the *behavior* (single emit, `is_boss` branch, no-XP-for-Boss) which is already green via node fields; only the Dictionary *shape* is target-state.

`damage_taken` signal payload contract (Enemy):
```
damage_taken(current_hp: float, max_hp: float, last_damage_amount: float)
```

`health_changed` signal payload contract (Player):
```
health_changed(current_hp: float, max_hp: float)
```

`damage_dealt` signal payload contract (source-side — fires for ALL damage events including zero-amount probes, unlike `damage_taken` which only fires when amount > 0):
```
damage_dealt(payload: {
    source: Node,             # weapon / enemy / environment node that originated the event
    target: Node,             # the receiving node (enemy or player)
    amount: float,            # may be 0 (status-only probe)
    damage_type: DamageType,  # DIRECT | TICK | EXPLOSION | BURN
    source_kind: SourceKind   # WEAPON | ENEMY | ENVIRONMENT (enforces Core Rule 1 friendly-fire exemption)
})
```

**Why two signals (`damage_dealt` source-side AND `damage_taken` target-side)**: source-side signal lets Status Effects (FT-10), analytics, and damage attribution observe every damage attempt (including zero-amount status-only probes); target-side signal is the HP-bar / flash trigger that fires only on actual HP change. Without `damage_dealt`, downstream consumers would have to subscribe to every weapon's internal hit event, breaking encapsulation.

## Formulas

### Formula 1: Damage application

Applied every time a weapon hits an enemy or an enemy hits the player. **All multiplier modifiers run before this step (see Damage type pipeline ordering above).**

`new_hp = max(0, current_hp - final_damage)`

where `final_damage = min(raw_damage × source_modifier × crit_multiplier × element_modifier × pierce_falloff, MAX_FINAL_DAMAGE_PER_HIT)`.

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| `current_hp` | hp₀ | float | 0.0 – max_hp | Target HP before damage |
| `raw_damage` | r | float | 0.0 – 200.0 | Base damage from weapon `.tres` (or enemy `.tres` for enemy→player) |
| `source_modifier` | m_s | float | 0.5 – 5.0 | From level-up pool stacked multipliers (Level Up GDD) |
| `crit_multiplier` | m_c | float | **1.0 (default)**, 火眼金睛: 1.2 | OQ-2 placeholder; reserved for Active Skills GDD |
| `element_modifier` | m_e | float | **1.0 (default)**, ±0.3 / -0.2 | OQ-4 placeholder; reserved for Elements GDD (v0.5+) |
| `pierce_falloff` | f_p | float | 1.0 (only for piercing projectiles, see Formula 6) | Default 1.0 |
| `final_damage` | d | float | 0.0 – `MAX_FINAL_DAMAGE_PER_HIT` (200) | The clamped, final value applied — hard-capped per the clamp below |
| `MAX_FINAL_DAMAGE_PER_HIT` | d_max | float constant | **200** | Hard per-hit damage ceiling (Blocker-3). Engine constant, NOT a `.tres` tuning surface — change via ADR |
| `new_hp` | hp₁ | float | 0.0 – max_hp | Target HP after damage. HP can never go negative. |

**Output Range:** 0.0 to `max_hp`. Overkill is not stored.
**Example:** A 修行者 with `current_hp = 28.0` is hit by a Stone Golem for `raw_damage = 24.0` (all modifiers default 1.0) → `final_damage = 24.0` → `new_hp = max(0, 28 - 24) = 4.0`. (Stone Golem damage revised D-B1 ×2.0, 2026-05-27: was 12.0)

**Per-hit clamp (Blocker-3 resolution)**: `MAX_FINAL_DAMAGE_PER_HIT = 200` caps every single damage application. Rationale: without it, a maxed build at `source_modifier = 5.0` with the now-active `element_modifier = 1.3` (Five Phases 相克) and `crit_multiplier = 1.5` (Five Phases 矿脉精粹, resolved by `max()` vs 火眼金睛) reaches `raw × 5 × 1.5 × 1.3` — at `raw = 200` that is 1950, a one-shot on a 360-HP Boss. A normal build (`raw = 8 × 5 × 1.5 × 1.3 ≈ 78`) sits far below 200, so the clamp only catches `.tres` typos and runaway outliers, never legitimate scaling. Boss minimum TTK is preserved: 360 HP / 200 ≥ 2 hits even at the cap. Five Phases' 燎原 burst (`0.5 × killing_blow`) inherits this protection indirectly — its source killing-blow is already clamped, so burst ≤ 100.

### Formula 2: Single-target weapon theoretical DPS

For a non-piercing weapon with damage `d` and cooldown `c`:

`dps = d / max(MIN_COOLDOWN, c)`

(Clamp is **inside** the formula — designers can request cooldown < 0.05s but the effective firing rate caps at 20 Hz.)

**Variables:**

| Variable | Symbol | Type | Design-safe range | Clamp-enforced range | Description |
|---|---|---|---|---|---|
| `d` | damage | float | 1 – 200 | 0 – ∞ (no upper clamp) | Per-hit damage |
| `c` | cooldown | float | 0.1 – 3.0 | 0.05 – ∞ (`MIN_COOLDOWN = 0.05`) | Seconds between attacks |

**Output Range:** 0 to ~4000 DPS (extreme: 200 / 0.05). Real builds stay under ~200 DPS single-target before mid-game upgrades.
**Example:** Flying Sword (d=14, c=0.8) → 17.5 dps single-target.

### Formula 3: Multi-target weapon effective DPS

For radius / tick / multi-target weapons (Bagua Array, Thunder Law radius):

`total_effective_dps = (d × hits_per_tick) / max(MIN_TICK_RATE, tick_rate)`
`per_enemy_dps = d / max(MIN_TICK_RATE, tick_rate)` (each enemy in radius takes this DPS)

The first formula is the observation; the second is the design target.

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| `d` | damage | float | 1 – 50 per-tick (multi-target damage is typically lower than single-target) | Per-tick damage |
| `hits_per_tick` | n | int | 0 – MAX_HITS_PER_TICK (default 20, see Tuning Knobs) | Enemies caught per tick. Capped to prevent runaway DPS in dense swarms |
| `tick_rate` | tick_rate | float | 0.2 – 1.5 (design-safe) / 0.05 – ∞ (clamp `MIN_TICK_RATE = 0.05`) | Seconds between damage ticks |

**Output Range:**
- `per_enemy_dps`: 0 – 1000 dps per enemy (extreme: d=50, tick_rate=0.05); practical: 5 – 30 dps per enemy
- `total_effective_dps`: scales linearly with `hits_per_tick` up to the cap

**Per-enemy DPS guardrail (N-2)**: any weapon `.tres` whose `per_enemy_dps = d / max(MIN_TICK_RATE, tick_rate)` exceeds **100** triggers an engine `push_warning()` at load — mirroring the `Enemy.max_hp > 10000` N-1 guardrail in the Tuning Knobs table. At the legal extreme (d=50, tick_rate=0.05) the formula yields **1000 dps per enemy** — enough to one-tick the Boss. The guardrail does NOT clamp (a designer may intentionally exceed it for a special weapon) but forces an explicit acknowledgement so a typo in a `.tres` cannot silently ship a one-tick weapon. Recommended ceiling 100; revise via the same ADR path as `MIN_TICK_RATE`.

**Example:** Bagua Array (d=4, tick_rate=0.65) hitting 10 enemies → `per_enemy = 4 / 0.65 ≈ 6.15 dps`; `total = 6.15 × 10 = 61.5 dps total`.

### Formula 4: Damage interval throttle (enemy → player)

A single enemy can only damage the player once per `damage_interval` seconds.

`can_hit = (current_time - last_hit_time) ≥ damage_interval`

**Initialization rule:** On enemy spawn, `last_hit_time` is initialized to `current_time - damage_interval` — meaning the enemy **can** hit the player immediately on first contact (no grace period). This is intentional: spawn-into-player scenarios should not have invisible armor on the spawning enemy. If a grace period is needed (e.g. for telegraph-based Boss attacks), the spawning system is responsible for delaying the contact check.

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| `current_time` | t | float | run elapsed seconds | Current time |
| `last_hit_time` | t₀ | float | run elapsed seconds | Last successful hit. Initialized to `t - damage_interval` on spawn. |
| `damage_interval` | Δ | float | 0.4 – 1.5 (design-safe) / 0.1 – ∞ (clamp `MIN_DAMAGE_INTERVAL = 0.1`) | Per-enemy throttle |

**Output Range:** boolean.
**Example:** Wandering Soul (`damage_interval = 0.8`) spawns at t=10.0, immediately makes contact → `can_hit = (10 - 9.2 ≥ 0.8) = true`. Hits, then `last_hit_time = 10.0`. Next legal hit at t=10.8.

### Formula 5: Burn damage (fixed-step accumulator)

> **⚠️ NOT IMPLEMENTED (v0.4) — Blocker-15 (scope gap)**: this formula is fully specified but **not built**. `thunder_strike.gd` is cosmetic-only (visual fade, 0.32s lifetime) — no `Area2D`, no accumulator, no `take_damage` calls. **AC-15 / AC-16 / AC-17 are RED** and cannot pass until burn is implemented. Burn is a *current-tier* damage type per this GDD (not a future feature), so this is a delivery gap tracked in the backlog OQ below. The spec that follows is the implementation target. **Five Phases note**: the 燎原 (Wildfire) combo spawns a fire *burst* (instantaneous EXPLOSION-type, per Five Phases Formula 4), which is a DIFFERENT mechanic from this burn accumulator — 燎原 does not depend on Formula 5 being implemented.

Burn damage is **decoupled from frame rate**. Each burn zone maintains its own time accumulator and ticks at a fixed interval, regardless of `_process` frequency.

```
on _process(delta):
    accumulator += delta
    while accumulator >= BURN_TICK_INTERVAL:
        if target in zone:
            apply_damage(burn_dps × BURN_TICK_INTERVAL, type=BURN)
        accumulator -= BURN_TICK_INTERVAL
    burn_lifetime_remaining -= delta
    if burn_lifetime_remaining ≤ 0:
        zone.queue_free()
```

`BURN_TICK_INTERVAL = 0.1` (constant). Burn lifetime is independent of tick count.

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| `burn_dps` | dps | float | 1 – 30 | Burn damage per second |
| `BURN_TICK_INTERVAL` | δ | constant | 0.1 (fixed) | Tick interval (NOT a tuning knob) |
| `damage_per_tick` | d_t | float | 0.1 – 3.0 (= dps × δ) | Damage applied per tick |
| `burn_duration` | T | float | 0.5 – 10.0 | Total burn lifetime in seconds |

**Output Range:** total damage per target standing in zone for full duration = `dps × T` (deterministic, frame-rate-independent).
**Example:** Thunder Strike burn patch (dps=6, T=2.0). Player in zone the full 2s → 12 damage total, applied as 20 ticks of 0.6 damage at 0.1s intervals. Player in zone for 0.5s → 6 damage total (10 ticks). At 30 FPS or with a 200ms frame hitch, the result is identical (extra ticks queue in the accumulator and fire when delta arrives, never doubling or skipping).

### Formula 6: Pierce damage falloff

For piercing projectiles, each hit consumes one `pierce_count`. The pierced damage is **full damage** per hit (no falloff in v0.4 baseline):

`damage_per_pierce_hit = raw_damage × source_modifier × crit_multiplier × element_modifier`
`pierce_falloff = 1.0` (constant placeholder)

If a future weapon design needs reduced damage on subsequent pierces, the `pierce_falloff` slot in the Formula 1 pipeline is reserved; replace 1.0 with a function of pierce index (e.g. `0.8^(index - 1)`).

**Boundary case:** `pierce_count = 0` means the projectile hits **exactly one** enemy and is destroyed (`pierce_count` is the number of *additional* pierces beyond the first hit; 0 = no piercing). `pierce_count = 1` means the projectile hits the first enemy AND one more.

### Formula 7: Aggregate DPS ceiling enforcement

When more than 4 enemies are in contact with the player simultaneously:

```
# Active slot = the 4 HIGHEST-DAMAGE attackers (Blocker-2 resolution).
# Removes the anti-soak exploit: a player could run through cheap filler to
# cycle Elites / Boss-summons OUT of the damage slot. Damage-tier priority
# means the 4 most dangerous attackers always occupy the slot.
contact_attackers = sort_by(enemies_touching_player,
                            key = (damage DESC, spawn_id ASC))  # deterministic tiebreak (Blocker-5)
active_attackers = contact_attackers[0:4]  # 4 most dangerous
queued_attackers = contact_attackers[4:]   # lower-damage surplus — no damage this frame

for enemy in active_attackers:
    if enemy.can_hit (Formula 4):
        apply_damage_to_player(enemy.damage, type=DIRECT, source_kind=ENEMY)
        enemy.last_hit_time = current_time

for enemy in queued_attackers:
    # No damage applied. Their last_hit_time is NOT updated — they remain ready
    # to deal damage on the next frame they're in the active slot.
```

**N-4 explicit behavior — all active attackers on cooldown**: If every enemy in `active_attackers` has `can_hit = false` (their per-enemy `last_hit_time` not yet ready), zero damage applies this frame **even though queued attackers exist**. Formula 4 (throttle) always takes precedence over slot availability — the ceiling caps maximum DPS but does not bypass per-enemy throttles. Queued attackers do NOT "fill in" for throttled active ones in the same frame; they wait for the next frame when active slot rotation may pick them up.

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| `MAX_CONTACT_ATTACKERS` | k | int constant | **4** | Hard cap, not a tuning knob |
| `contact_attackers` | C | list of Enemy | length 0 – ∞ | All enemies currently overlapping the player's contact box |
| `active_attackers` | A | list of Enemy | length 0 – min(4, len(C)) | Slice that may apply damage this frame |

**Output:** at most `MAX_CONTACT_ATTACKERS × (1 / average_damage_interval)` hits-per-second land on the player.
**Example (homogeneous):** 8 Paper Dolls in contact (each `damage = 10, damage_interval = 0.85`, revision-5 ×2.0). Without Formula 7: 8 × (10/0.85) ≈ 94 dps. With Formula 7: 4 × (10/0.85) ≈ 47 dps. At Player HP=100: without ceiling survival ≈ 100/94 ≈ **1.06s**; with ceiling ≈ 100/47 ≈ **2.13s** — matches §Survival Budget (4-Paper-Doll: 2.13s).

**Example (heterogeneous — the anti-soak fix):** 5 Paper Dolls (`damage = 10`) + 3 Shanxiao Elites (`damage = 30`) all in contact. Damage-tier selection puts the **3 Elites + 1 Paper Doll** in the active slot (NOT 4 Paper Dolls), so the player cannot body-block Elite damage with cheap filler. Incoming ≈ 3×(30/0.9) + 1×(10/0.85) ≈ 100 + 11.8 ≈ 112 dps — the dangerous attackers are always counted. (Under the old "most-recently-entered" rule, a player could run through the Elites last so they got evicted by fresh filler contact — the exploit Blocker-2 removes.)

## Edge Cases

- **If `final_damage == 0`** (multiplier or raw value zeroed): damage signal still fires (`damage_dealt(...)`) for downstream observers (e.g. status effects), but `new_hp` is unchanged. **No flash, no death, and `last_hit_time` on the throttle is NOT reset** (per Core Rule 7).
- **If `final_damage > current_hp`**: damage caps at `current_hp` (overkill is not stored). Death triggers normally via the data-death → visual-death lifecycle (Core Rule 4).
- **If multiple damage events target the same enemy in the same frame, and the first kills it**: the first transitions the enemy to `DYING`; the second is silently dropped per Core Rule 6 (no `died` re-emit, no double XP). The implementation uses a `is_dying` flag checked at the start of damage application.
- **If a weapon fires and the projectile expires before reaching target**: no damage applied. The weapon is back on cooldown regardless — the cost is the cooldown, not the hit.
- **If `cooldown < MIN_COOLDOWN` (0.05s) is set via tuning**: clamped to 0.05s. No console error. Designers can request fast firing rate but not infinite (Formula 2 enforces this in the formula itself).
- **If `damage_interval < MIN_DAMAGE_INTERVAL` (0.1s)**: clamped to 0.1s. Even the fastest enemy cannot frame-rate-deadlock the player.
- **If an explosion (`source_kind = WEAPON`) overlaps the player**: player takes 0 damage. Friendly fire does not exist (Core Rule 1). Other allies (future summoned units, hair clones) are also exempt.
- **If a `burn` ground patch (`source_kind = ENVIRONMENT`)** is on the player's path: damage applies at fixed-step ticks (Formula 5). The patch belongs to no source — it is environmental — so it can damage the player AND enemies if both are in range. Friendly-fire exemption applies only to `source_kind = WEAPON` and `source_kind = ALLY` (future).
- **If `xp_drop_value = 0` (Boss case)**: enemy still emits `died(payload)`, but `Experience` system spawns no XP orb (consumer-side filter on `payload.xp_drop_value > 0`). Boss death additionally sets `payload.is_boss = true` for Run State victory branch.
- **If `pierce_count = 0`**: projectile hits exactly 1 enemy, destroys self. `pierce_count = 3`: hits up to 4 enemies (initial + 3 pierces).
- **If two different enemies hit the player in the same frame, both within their own `damage_interval` budget**: both apply damage (in arrival order from the physics broadphase). They are independent per Core Rule 9. Aggregate ceiling (Core Rule 8) still applies — the active slot holds the 4 **highest-damage** attackers; any lower-damage surplus is queued (no damage this frame) per Formula 7's damage-tier selection (Blocker-2).
- **If burn `burn_duration` expires while target is still in zone**: zone removes itself (`queue_free`), no further ticks. Target may freely move through the now-clear area.
- **If two `enemies_touching_player` cross the 4-slot boundary with equal `damage`**: the tiebreak is `spawn_id ASC` (earlier-spawned wins the slot) — deterministic and replay-safe per Formula 7 damage-tier selection (Blocker-2/5; OQ-6 resolved). Same-frame wave spawns no longer depend on physics-broadphase order.
- **If an enemy dies while occupying a contact-attacker slot (Blocker-13)**: `enemy._die()` MUST disable its `DamageArea` collision shape BEFORE `queue_free()` / emitting `died`. Otherwise the corpse still occupies a contact-attacker entry during the 1-frame `queue_free()` deferral, silently dropping the effective `MAX_CONTACT_ATTACKERS` below 4 — a live threat gets starved by a dead body. Code fix tracked in OQ-7 backlog.
- **If the player's HP is restored above 0 after `DEFEATED` (e.g. by some future revival mechanic)**: the `DEFEATED` state is terminal in v0.4. No transition out. Reviving requires a separate `revive(hp)` API that bypasses this state machine — out of scope until Run State GDD addresses it.

## Dependencies

| Dependency | Type | Direction | Interface |
|---|---|---|---|
| **Resource Data Framework** | Hard | Combat depends on | `.tres` Resource subclasses for weapon and enemy stats |
| **Targeting** | Hard | Combat depends on | `find_nearest(position, range)` and `find_in_radius(position, radius)` |
| **Weapon System** | Hard | Combat is the contract for | All weapons implement `WeaponBase._try_attack()` and emit a `(source, target, amount, damage_type, source_kind)` tuple on successful hit |
| **Enemy** | Hard | Bidirectional | Enemy owns its HP; Combat sends damage events; Enemy emits `damage_taken(current, max, last)` and `died(payload)` |
| **Player** | Hard | Bidirectional | Player owns its HP; Combat sends damage events; Player emits `health_changed(current, max)` and `died()` |
| **Status Effects (FT-10)** | Soft | Combat dispatches into | When damage_type is `TICK` or `BURN`, Combat may notify Status Effects (separate GDD) |
| **Experience & Progression** | Soft | Combat events trigger | On `died(payload)`, Experience spawns XP orb using `payload.position` and `payload.xp_drop_value` |
| **Combat Feedback (P-03)** | Soft | Combat events trigger | Subscribes to `damage_taken`, `died`, `health_changed`. Hand-off note: enforce minimum 0.05s between consecutive flashes on the same target |
| **HUD** | Soft | Combat events trigger | Subscribes to player `health_changed(current, max)` |
| **Run State** | Soft | Combat events trigger | Subscribes to `died()` (run-end via death) and Boss `died(payload.is_boss)` (run-end via victory) |

**Bidirectional check (per design-docs rule)**:
- Enemy GDD must list "depends on Combat" in its Dependencies. ⏳ (will be enforced when Enemy GDD is written)
- Weapon System GDD must list "depends on Combat" in its Dependencies. ⏳ (same)
- Player GDD must list "depends on Combat" in its Dependencies. ⏳
- Experience & Progression GDD must list "soft-depends on Combat (for `died` event)" ⏳
- Run State GDD must list "soft-depends on Combat (for `defeated` and Boss `died` events)" ⏳

## Tuning Knobs

All combat values are tuned via Resource (`.tres`) files. No `.gd` code change needed for balance passes. Constants like `MIN_COOLDOWN`, `BURN_TICK_INTERVAL`, `MAX_CONTACT_ATTACKERS` are **engine-side constants** — not per-build `.tres` tuning surfaces and not editable by content designers. Values may be revised post-playtest through an ADR amendment (see OQ-5); changing them requires a code change + ADR record, not just a Resource edit.

| Knob | Owner | Design-safe range | Clamp range | Effect at extremes |
|---|---|---|---|---|
| `WeaponBase.damage` | Per-weapon `.tres` | 1 – 200 | 0 – ∞ | <1 = useless; >200 = trivialises mid-game enemies |
| `WeaponBase.cooldown` | Per-weapon `.tres` | 0.1 – 3.0 | 0.05 – ∞ (`MIN_COOLDOWN = 0.05`) | <0.1 = clamped; >3.0 = feels lifeless |
| `WeaponBase.projectile_speed` | Per-weapon `.tres` | 100 – 800 | 0 – ∞ | <100 = miss everything; >800 = invisible bullets |
| `WeaponBase.attack_range` | Per-weapon `.tres` | 50 – 600 | 1.0 – ∞ (`MIN_ATTACK_RANGE = 1`) | <50 = melee-tight; >600 = trivialises spacing |
| `WeaponBase.projectile_lifetime` | Per-weapon `.tres` | 0.3 – 5.0 | 0.05 – ∞ (`MIN_PROJECTILE_LIFETIME = 0.05`) | <0.3 = explodes in face; >5.0 = perf cost (orphan projectiles) |
| `Enemy.damage` | Per-enemy `.tres` | 3 – 30 | 0 – ∞ | <3 = trivial; >30 = unfair without构筑 |
| `Enemy.damage_interval` | Per-enemy `.tres` | 0.4 – 1.5 | 0.1 – ∞ (`MIN_DAMAGE_INTERVAL = 0.1`) | <0.4 = punishingly fast; >1.5 = enemy feels harmless |
| `Enemy.max_hp` | Per-enemy `.tres` | 5 – 500 (Boss exception 5000) | 1 – 10000 (engine `push_warning()` if exceeded, except Boss category) | <5 = popcorn; >500 = boring tank; >10000 = bug suspected, warning fires (N-1 guardrail) |
| `BaguaArrayWeapon.tick_rate` | Bagua `.tres` | **0.6 – 1.5 (recommended); 0.2 – 0.6 requires systems-designer review** | 0.05 – ∞ (`MIN_TICK_RATE = 0.05`) | <0.6 = mechanically dominant over `damage_interval` (see Interaction Warnings); >1.5 = feels dead |
| `BaguaArrayWeapon.radius` | Bagua `.tres` | 40 – 180 | 1 – ∞ (`MIN_RADIUS = 1`) | <40 = no value; >180 = trivialises positioning |
| `ThunderLawWeapon.target_count` | Thunder `.tres` | 1 – 8 | 1 – ∞ | >8 = visual chaos, perf concerns |
| `ThunderLawWeapon.radius` | Thunder `.tres` | 40 – 180 | 1 – ∞ | Same as Bagua radius |
| `ThunderLawWeapon.burn_dps` | Thunder `.tres` | 1 – 30 | 0 – ∞ | Burn DPS, applied via Formula 5 |
| `ThunderLawWeapon.burn_duration` | Thunder `.tres` | 0.5 – 10.0 | 0 – ∞ | Burn lifetime in seconds |
| `FlyingSwordWeapon.pierce_count` | Flying Sword `.tres` | 0 – 8 | 0 – ∞ (int) | >8 = single-shot wipes everything |
| `FlyingSwordWeapon.projectile_count` | Flying Sword `.tres` | 1 – 8 | 1 – ∞ | >8 = visual chaos |
| `ExplosiveTalismanWeapon.explosion_damage` | Explosive `.tres` | 5 – 80 | 0 – ∞ | <5 = ignored; >80 = AoE wipe-button |
| `ExplosiveTalismanWeapon.explosion_radius` | Explosive `.tres` | 30 – 150 | 1 – ∞ | Same shape as other radius knobs |
| `Elite multipliers` (iron_bones HP × 1.45, swift speed × 1.3) | Per-archetype `.tres` | 1.0 – 2.0 | 0 – ∞ | >2.0 = elite becomes mini-Boss without Boss treatment |
| `MAX_HITS_PER_TICK` | Engine constant (NOT in `.tres`) | **20** | — | Caps Formula 3 hits_per_tick. Raise only if perf profiling allows. |

**Run-arc worked example (representative DPS by minute, single-target Flying Sword + Bagua build)**:

| Time | Single-target DPS (Formula 2) | Multi-target per-enemy DPS (Formula 3) | Aggregate vs. 6-enemy cluster |
|---|---|---|---|
| 0:00 (base) | Flying Sword 14/0.8 = 17.5 + Bagua 4/0.65 = 6.2 → ~23.7 | Bagua 6.2 per enemy | Bagua hits 6 = 37.2; plus Flying Sword 17.5 = 54.7 |
| 2:00 (+2 升级) | 17.5 × 1.3 + 6.2 × 1.2 = 22.75 + 7.44 = 30.2 | 7.44 per enemy | 6 × 7.44 + 22.75 = 67.4 |
| 4:00 (+5 升级) | 17.5 × 1.7 + 6.2 × 1.5 = 29.75 + 9.3 = 39.0 | 9.3 per enemy | 6 × 9.3 + 29.75 = 85.6 |
| Boss (5:00+) | 17.5 × 2.0 + 6.2 × 1.8 = 35.0 + 11.2 = 46.2 single + AoE bonus | — | Boss DPS = 46.2 vs. Famine Beast 360 HP → ~7.8s (within 12-18s budget — acceptable, build dependent) |

These numbers feed into the Pressure Curve §Per-Tier Enemy TTK Budget. `/balance-check` should flag any `.tres` value that produces TTKs outside the budget.

**Interaction warnings**:
- Lowering `cooldown` while keeping `damage` high → exponential DPS growth. Pair these in tuning passes.
- Increasing `attack_range` and `projectile_speed` simultaneously trivialises kiting. Tune them as a pair.
- `tick_rate` lower than the average enemy `damage_interval` makes tick weapons mechanically dominant. Keep them in the same order of magnitude (0.6 – 0.9s).
- Stacked `source_modifier` from level-up pool can push `final_damage` past the design-safe range. `/balance-check` should flag any build path that exceeds 5.0× cumulative damage multiplier.

## Visual/Audio Requirements

Combat is **infrastructure** — most visuals come from FT-10 Status Effects, P-03 Combat Feedback, PL-02 VFX, and PL-01 Audio. Combat itself only defines the visual contract:

- **Hit confirmation**: a 0.1-second white flash on the target sprite. Owned by Combat Feedback GDD; Combat dispatches `damage_taken(...)` signal that Combat Feedback subscribes to. **Minimum interval between consecutive flashes on the same target: 0.05s** (prevents strobe at high DPS — accessibility consideration, see future Accessibility GDD).
- **Data-death timing**: `died(payload)` fires within 1 frame of HP reaching 0.
- **Visual-death timing**: dissolve animation plays for **up to 0.5s** before `queue_free()`. Death VFX (particle burst + sprite fade) owned by VFX GDD. Combat does not control timing — VFX GDD is authoritative.
- **Damage number floaters** (optional, v0.4+): on hit, show numeric damage value briefly. Per [07_VISUAL_STYLE_GUIDE](style/07_VISUAL_STYLE_GUIDE.md) 暗黑志怪 palette — off-white with thin red glow on crits (NOT modern game blue/yellow). Subscribes to `damage_taken` signal.
- **Color-blind toggle hook** (N-2 — Accessibility GDD): the red-glow-on-white crit indicator can be hard to distinguish for deuteranopic players (~5% of males). Reserve a `crit_indicator_palette: enum {DEFAULT, COLORBLIND_SAFE}` setting; default is DEFAULT. When the Accessibility GDD lands, COLORBLIND_SAFE will swap red glow for a high-contrast shape modifier (e.g. underline, bold weight, or icon prefix). Combat itself does not implement the palette — it only reserves the toggle field in player settings.

📌 **Asset Spec** — Visual/Audio requirements above are infrastructure-light. When Combat Feedback GDD or VFX GDD is written, run `/asset-spec system:combat-feedback` to produce per-asset specs.

**Audio handoff to Audio GDD**:
- Every hit must have a short SFX cue (≤ 0.15s), distinct per weapon
- Worst-case hit event rate to plan for: **400 events / second** from a single area weapon (Bagua Array at `MIN_TICK_RATE = 0.05s` = 20 ticks/sec × `MAX_HITS_PER_TICK = 20` = 400). Two simultaneous area weapons (e.g. Bagua + a 燎原-fed Fire build per Five Phases) can exceed **800 events/sec**. Audio system MUST coalesce / pool aggressively to avoid CPU spikes. (Corrects the earlier 160/sec estimate, which under-counted by ~2.5×.)
- Burn ticks at 0.1s intervals — Audio should NOT play a cue every tick; cue once on burn start, ambient loop while burn lifetime > 0.

## UI Requirements

Combat exposes UI surfaces consumed by HUD and per-target overlays:

1. **Player HP bar** (HUD): subscribes to **Player node's** `health_changed(current_hp, max_hp)` — per Core Rule 3, Player owns this signal. Updates instantly (≤50ms after signal). When `current_hp < 0.25 × max_hp`, HUD may layer a low-HP heartbeat effect (specified in HUD UX spec).
2. **Enemy HP bars** (per-enemy overlay): subscribes to **Enemy node's** `damage_taken(current_hp, max_hp, last_damage)`. **Trigger rule: HP bar is hidden until first `damage_taken` emission**, then visible until enemy `queue_free()`. Without `damage_taken`, the HP bar has no event to render against — Core Rule 2's tuple contract carries this signal.
3. **Damage number floaters** (optional): subscribes to `damage_taken`; reads `last_damage_amount`.
4. **Game-over flow trigger**: subscribes to Player's `died()` — see Run State GDD for the full transition contract (fade, score, restart prompt).

📌 **UX Flag — Combat System**: HUD HP bar + on-screen damage feedback + game-over transition are UI surfaces. In Phase 4 (Pre-Production), run `/ux-design` for:
- `design/ux/hud.md` (HP bar + run timer + XP bar)
- `design/ux/damage-numbers.md` (if floaters are kept for v0.4)
- `design/ux/game-over.md` (defeated-to-restart flow)
**before** writing epics that touch this UI.

## Acceptance Criteria

Numbered for traceability into `/create-stories`. **AC-21 and AC-22 are reserved placeholders** — they specify contracts that will activate when downstream GDDs (Active Skills, VFX) land. Implementations should treat them as design intent today and test targets tomorrow.

### AC group: Core damage application (Core Rule 1, 3)

**AC-01** **GIVEN** a 修行者 with `current_hp = 100` (`max_hp = 100`), **WHEN** a Wandering Soul with `damage = 16` (revision-5 ×2.0 value) hits, **THEN** Player's `current_hp` becomes 84 AND Player emits `health_changed(84, 100)` exactly once.

**AC-02** **GIVEN** an enemy with `max_hp = 14` (Paper Doll), **WHEN** total damage applied across any number of events reaches exactly 14, **THEN** Enemy emits `damage_taken(0, 14, ...)` AND transitions to `DYING` AND emits `died(payload)` exactly once — all within 1 frame.

**AC-03** **GIVEN** a Paper Doll in `DYING` state, **WHEN** an additional damage event from any source targets it before `queue_free()` completes, **THEN** no `died` re-emits AND `current_hp` remains 0 AND no XP orb is spawned for the second event.

**AC-04** **GIVEN** an Explosive Talisman (`source_kind = WEAPON`) impacts at the player's exact position, **WHEN** the explosion fires, **THEN** Player takes 0 damage AND any enemies within `explosion_radius` take `explosion_damage` exactly once each.

**AC-05** **GIVEN** a damage event is processed, **WHEN** the event is dispatched, **THEN** the payload contains all five fields `(source, target, amount, damage_type, source_kind)` AND `damage_type ∈ {DIRECT, TICK, EXPLOSION, BURN}` AND `source_kind ∈ {WEAPON, ENEMY, ENVIRONMENT}`.

### AC group: Weapon mechanics (Formulas 2, 3, 6)

**AC-06** **GIVEN** a Flying Sword projectile with `pierce_count = 3`, **WHEN** it passes through 4 enemies sequentially, **THEN** enemies 1-4 take damage (initial + 3 pierces = 4 hits) AND the projectile is destroyed.

**AC-07** **GIVEN** a Flying Sword projectile with `pierce_count = 0`, **WHEN** it hits the first enemy, **THEN** that enemy takes damage AND the projectile is destroyed (no pierce-through).

**AC-08-deterministic-A** **GIVEN** a Bagua Array with `tick_rate = 0.65`, **WHEN** 5 enemies are inside the radius continuously for a 2.0s window, **THEN** each enemy receives **exactly 4 damage applications** (tick cadence 0.65s → 4 ticks in 2.0s). Assert by tick COUNT, not absolute timestamps: the first tick fires on the first `_process` after the enemies are in radius (Godot `_process` runs the frame *after* node entry, never at a literal spawn-instant `t = 0.0`). The existing `bagua_array_tick_test.gd` calls `_apply_radius_damage()` directly to stay frame-agnostic.

**AC-08-deterministic-B** **GIVEN** a Bagua Array with `tick_rate = 0.65`, **WHEN** 5 enemies enter the radius at `t = 0.0` and one enemy exits at `t = 1.0`, **THEN** that enemy receives exactly 2 damage applications (at `t = 0.0` and `t = 0.65`) AND the remaining 4 enemies receive 4.

**AC-09** **GIVEN** a weapon `.tres` with `cooldown = 0.01` (below `MIN_COOLDOWN`), **WHEN** the project loads and the weapon fires, **THEN** effective cooldown is `0.05` AND no console error AND `dps = damage / 0.05`.

### AC group: Enemy → player damage and throttling (Formulas 4, 7; Core Rules 8, 9)

**AC-10** **GIVEN** a Stone Golem (`damage = 24, damage_interval = 1.0`) spawns and immediately makes contact with the player at `t = 5.0`, **WHEN** the contact resolves, **THEN** the player takes 24 damage at `t = 5.0` (no spawn grace period — per Formula 4 initialization rule) AND `last_hit_time = 5.0`. (damage revised D-B1 ×2.0, 2026-05-27: was 12)

**AC-11** **GIVEN** a Stone Golem (`damage = 24, damage_interval = 1.0`) in contact with the player from `t = 0.0` to `t = 2.5`, **WHEN** the run progresses, **THEN** the player takes damage at exactly `t = 0.0, 1.0, 2.0` (3 hits) AND no per-frame damage. (damage revised D-B1 ×2.0, 2026-05-27: was 12)

**AC-12** **GIVEN** two different enemies (Stone Golem and Paper Doll) both in contact with the player and both having `last_hit_time` ready, **WHEN** the throttle check runs on the same frame, **THEN** the player takes both damage values independently (per Core Rule 9 — per-enemy throttle) AND each enemy updates its own `last_hit_time`.

**AC-13** (Integration-level — Area2D contact plumbing cannot be verified headlessly; the selection function alone is unit-testable as AC-13a) **GIVEN** 4 Shanxiao Elites (`damage = 30`) and 4 Paper Dolls (`damage = 10`) all in contact (8 > `MAX_CONTACT_ATTACKERS = 4`), **WHEN** the throttle resolves, **THEN** only the **4 highest-damage attackers (the 4 Elites)** apply damage this frame AND the 4 Paper Dolls' `last_hit_time` is **not** updated (Blocker-2 damage-tier selection; tiebreak `damage DESC, spawn_id ASC`).
- **AC-13a** (unit): `select_active_attackers([Elite×4, PaperDoll×4])` returns exactly the 4 Elites.
- **AC-13b** (integration + playtest sign-off): the Area2D wiring delivers damage only from those 4.

**AC-14** **GIVEN** the player at `current_hp = 5` and a Stone Golem in contact (`damage = 24`, revision-5 ×2.0 value), **WHEN** the next hit applies, **THEN** `current_hp = 0` (clamped, no negative) AND Player emits `health_changed(0, 100)` AND emits `died()` exactly once AND no further enemy damage events apply to the Player for the rest of the run. (Note: `max_hp = 100` per Player GDD revision-2 — Player.tscn ships at 100, not 30.)

### AC group: Burn (Formula 5)

**AC-15** **GIVEN** a Thunder Strike burn patch (`burn_dps = 6, burn_duration = 2.0, BURN_TICK_INTERVAL = 0.1`), **WHEN** the player remains in the zone for the full 2.0s duration, **THEN** the player takes exactly 20 ticks of 0.6 damage = 12 total damage (within ±0.05 floating-point tolerance).

**AC-16** **GIVEN** the same burn patch, **WHEN** the run is executed at 30 FPS instead of 60 FPS, **THEN** the player still takes exactly 20 ticks of 0.6 damage over the same 2.0s (frame-rate independent — Formula 5).

**AC-17** **GIVEN** a Thunder Strike burn patch with `burn_duration = 2.0`, **WHEN** 2.0 seconds elapse since the patch spawned, **THEN** the patch is removed (`queue_free`) AND any subsequent player presence at that location takes no damage.

### AC group: Boss and victory (Core Rule 4)

**AC-18** **GIVEN** a Famine Beast Boss (`max_hp = 360, xp_drop_value = 0, is_boss = true`), **WHEN** total weapon damage of 360 has been applied, **THEN** Boss emits `died(payload)` exactly once AND `payload.is_boss = true` AND `Experience` system spawns NO XP orb AND `Run State` receives the victory transition trigger.

### AC group: Zero / boundary cases

**AC-19** **GIVEN** an enemy at `current_hp = 24`, **WHEN** a `damage_amount = 0` event fires (e.g. from a status-only probe), **THEN** `current_hp` stays at 24 AND no flash, no death, no `damage_taken` emit (HP bar does NOT show) AND `last_hit_time` on the throttle is NOT reset.

**AC-20** **GIVEN** an enemy at `current_hp = 5`, **WHEN** a damage event with `amount = 999` arrives, **THEN** `current_hp = 0` (clamped, not -994) AND `died` fires AND no second `died` emits.

### AC group: Reserved placeholders (activate when downstream GDDs land)

**AC-21** (reserved — activates when Active Skills GDD lands; defends Damage Type Pipeline Ordering): **GIVEN** `raw_damage = 10` AND `source_modifier = 1.5` AND `crit_multiplier = 1.2` AND `element_modifier = 1.0` AND `pierce_falloff = 1.0`, **WHEN** the damage is applied, **THEN** `final_damage = 10 × 1.5 × 1.2 = 18.0` (NOT 10 × 1.2 × 1.5 — order is `raw → source_mod → crit → element → pierce`, and order matters when multipliers are introduced in a non-commutative future formula like `floor()` or saturating arithmetic). Implementation note: this AC is a no-op today (all reserved multipliers default to 1.0), but Active Skills GDD must keep it green when 火眼金睛's `crit_multiplier = 1.2` lands.

**AC-22** (reserved — activates when Combat Feedback / VFX GDDs land; defends Visual-Death Timing budget) — **Integration-level test** (NOT unit: `queue_free()` is deferred and needs the scene tree to tick): **GIVEN** an enemy that emits `died(payload)`, **WHEN** the test does `await get_tree().create_timer(0.5).timeout`, **THEN** `is_instance_valid(enemy_node) == false` (the node has been freed). **Failure mode if violated**: enemy lingers in tree indefinitely → memory leak during long Boss fights with summons; `damage_taken` signals leak to stale listeners. **Ownership**: VFX GDD owns the 0.5s budget; Combat validates the upper bound via this AC. Classify under `tests/integration/`, not `tests/unit/`; pairs with a playtest sign-off.

## Open Questions

- **OQ-1** (Combat Feedback overlap): Should `damage_amount = 0` events still trigger the white-flash effect? Per AC-19 the current spec is **no**, but a "tap-to-debuff" weapon could need it. **Owner**: systems-designer + ux-designer. **Target resolution**: before Combat Feedback GDD is finalised.
- **OQ-2** (Crit support): The current pipeline reserves a `crit_multiplier` slot (default 1.0). Future weapon designs (especially 孙悟空's 火眼金睛 +20% vs. elite/Boss) need this. Decision: is crit weapon-side, target-side, or a separate modifier pipeline? **Owner**: systems-designer. **Target resolution**: when Active Skills GDD is written.
- **OQ-3** (Status pipeline boundary): When a Bagua Array tick applies, does the target get a status stack (currently no)? If we want chained effects (tick → burn → explosion), we need clearer Status Effects integration. **Owner**: systems-designer. **Target resolution**: when Status Effects (FT-10) GDD is written.
- **OQ-4** (五行 / Elements scaling): The `element_modifier` slot in the pipeline is reserved (default 1.0). 03_CORE §9 element table specifies ±30% / -20% modifiers. Decision: pre-clamp or post-clamp? **Resolution: pre-clamp** (modifier applies in the multiplier chain before Formula 1's `max(0, …)` clamp). This is now locked. **Owner**: systems-designer. **Target full implementation**: Elements GDD (v0.5+).
- **OQ-5** ✅ **RESOLVED in revision-5 (D-B1 from /review-all-gdds 2026-05-27)** — **Path (a) selected**: Player HP stays at 100; all 7 enemy archetype `.tres` `damage` fields multiplied ×2.0. Per-Phase TTK Budget and Incoming DPS Targets in §Pressure Curve updated to reflect new values. The ×2.0 multiplier is a **starting calibration point** — `/balance-check` post-playtest may nudge individual enemy values up or down independently. `MAX_CONTACT_ATTACKERS = 4` ceiling remains correct and does not need revision; with ×2 damage it actually becomes MORE important (without it, late-phase contact is instantly lethal). If playtest shows the game is still too easy, candidate follow-up tuning: raise damage_interval ceiling (allow faster attacks), OR reduce `MAX_CONTACT_ATTACKERS` to 3, OR apply path (b) (lower HP) as an additional tuning axis. **Owner**: game-designer + qa-lead. **Resolution date**: 2026-05-27.
- **OQ-6 (RESOLVED 2026-06-03 — Blocker-2/5)**: aggregate-ceiling selection is now **damage-tier priority** with a deterministic tiebreak `(damage DESC, spawn_id ASC)` — see Formula 7. Same-frame contact entry no longer depends on physics-broadphase order; the monotonic `spawn_id` guarantees replay determinism. No longer deferred.
- **OQ-7 (Code-fix backlog — Blocker-11/12/13/14/15 from /design-review 2026-06-03)**: five as-built code deviations for the implementation pipeline (the GDD is now aligned to as-built reality; these are code tasks, not design changes):
  - **Blocker-11**: Formula 7 ceiling enforcement is O(n² log n)/frame (`sort_custom` inside a per-enemy `is_contact_attacker_allowed`). Refactor to cache the sorted allowed-set once per frame (dirty flag on register/unregister contact attacker).
  - **Blocker-12**: `weapon_base.gd` resets cooldown unconditionally — check the `_try_attack()` return value and reset cooldown only on `true` (else weapons waste cooldown cycles when no target is in range).
  - **Blocker-13**: `enemy._die()` must disable its `DamageArea` collision before `queue_free()` (see Edge Cases — a corpse holds a contact slot for 1 frame).
  - **Blocker-14**: `died` emits a node, not the Dictionary payload (GDD now documents the as-built node form; the Dictionary is the target refactor).
  - **Blocker-15**: Formula 5 burn is not implemented (`thunder_strike.gd` is cosmetic-only); AC-15/16/17 are RED until built.
  **Owner**: gameplay-programmer / lead-programmer. **Target**: v0.5 implementation sprint.

---

## Registry Updates Recorded

This GDD references the following entities/constants that exist in `design/registry/entities.yaml`:

- 7 enemies (`paper_doll`, `wandering_soul`, `fox_spirit`, `ghost_flame`, `stone_golem`, `shanxiao_elite`, `famine_beast`) — `referenced_by` array includes `design/gdd/combat-system.md`
- `target_framerate = 60` — `referenced_by` includes this GDD
- 4 formulas registered: `damage_application_formula` (now Formula 1, extended), `weapon_dps_formula` (Formula 2, clamp-embedded), `multi_target_effective_dps` (Formula 3, capped), `damage_interval_throttle` (Formula 4, init-rule clarified)
- 3 new formulas added in revision-1: `burn_fixed_step_formula` (Formula 5), `pierce_damage_formula` (Formula 6), `aggregate_dps_ceiling_formula` (Formula 7)
- 1 new constant added in revision-1: `max_contact_attackers = 4` (engine constant, not designer-tunable)
- **revision-2 additions** (no new registry entries — all changes are wording / AC placeholder / formula clarification within combat-system.md itself). Notable additions to flag for future GDDs:
  - `damage_dealt` signal payload (5 fields) — Status Effects / Analytics / damage-attribution consumers must use this contract
  - `crit_indicator_palette` enum (DEFAULT / COLORBLIND_SAFE) — Accessibility GDD will define when authored
  - AC-21 + AC-22 reserved placeholders — Active Skills and VFX GDD authors must keep these green

**Cross-doc consistency**: All numeric values referenced (enemy HP / damage / damage_interval, weapon damage / cooldown, etc.) match the values in `.tres` files and `entities.yaml`. No conflicts surfaced.

## Revision Log

| Revision | Date | Trigger | Summary |
|---|---|---|---|
| 0 | 2026-05-25 | Initial reverse-doc | First pass authored by /design-system based on existing v0.4-pre-qa code |
| 1 | 2026-05-25 | /design-review verdict: MAJOR REVISION NEEDED | Added Pressure Curve §, Core Rules 6/7/8/9, Formula 5/6/7, AC-01 through AC-20 (10 new ACs), explicit signal payload contracts, friendly-fire `source_kind` field, fixed-step burn, aggregate DPS ceiling, OQ-5/6 added. Section "Detailed Design" renamed to "Detailed Rules" for grep tooling. |
| 2 | 2026-05-25 | /design-review verdict: CONCERNS (independent subagent re-review) | **B-1 closed**: added `damage_dealt` source-side payload contract (5 fields) alongside existing `damage_taken` / `died` / `health_changed` — unblocks Status Effects (FT-10) integration. **R-1 closed**: tightened "engine-side constants" wording to clarify post-playtest ADR-amendment path. **R-2 closed**: added AC-21 reserved placeholder defending damage type pipeline ordering (activates when Active Skills GDD lands). **R-3 closed**: added AC-22 reserved placeholder defending visual-death ≤ 0.5s budget (activates when VFX GDD lands). **R-4 closed**: BaguaArray `tick_rate` design-safe range tightened to 0.6-1.5 (recommended) with 0.2-0.6 flagged as needing systems-designer review. **N-1 closed**: `Enemy.max_hp` clamp range now 1-10000 with `push_warning()` above 10000 (Boss category exempt). **N-2 closed**: added color-blind toggle hook (`crit_indicator_palette` enum) for Accessibility GDD. **N-3 closed**: OQ-5 expanded to include Player HP coupling and `/propagate-design-change` instruction. **N-4 closed**: Formula 7 explicit behavior for all-active-attackers-on-cooldown scenario. |
| 3 | 2026-05-25 | Player GDD /design-review finding R-1 (cross-doc signal name mismatch) | Propagated 8 instances of `defeated()` to `died()` to match code (`scripts/player/player.gd:4` declares `signal died`, emits `died.emit()` at line 205). Status: APPROVED unchanged — no design changes, only a name correction. |
| 4 | 2026-05-25 | Player GDD revision-2 OQ-1 resolution (Combat HP=30 assumption vs code HP=100) | Propagated Player base HP from placeholder 30 to code-true 100 throughout §Pressure Curve §Survival Budget and §Per-Phase TTK Budget. Recomputed: single-Paper-Doll survival 2.5s → 17.0s; 4-attacker survival 1.5s → 4.25s; per-phase hits-to-die roughly tripled across the board (Familiarisation 6+ → 20; Boss 1-2 → 6). AC-14 `health_changed(0, 30)` → `health_changed(0, 100)`. OQ-5 expanded with two balance paths (raise enemy damage OR lower Player HP). Aggregate ceiling failure mode reworded (~0.6s → ~2.1s without ceiling). Status: APPROVED unchanged — data propagation only, no design contracts changed. |
| 5 | 2026-05-27 | D-B1 from /review-all-gdds (OQ-5 path (a)) | All 7 enemy archetype `.tres` `damage` fields multiplied ×2.0 to restore pressure at HP=100. §Pressure Curve Per-Phase TTK Budget + Incoming DPS Targets recomputed; OQ-5 closed. (Logged retroactively — the header was marked revision-5 but this table row was missing.) |
| 6 | 2026-06-03 | /design-review verdict: MAJOR REVISION NEEDED (15 blockers, 5-agent panel) | **Group A docs fixed**: B-1 §Survival Budget damage=5→10 (8.5s single / 2.13s 4-doll, removed all pre-rev5 figures) + Formula 7 worked example; B-4 Formula 3 per-enemy DPS guardrail N-2 (>100 → `push_warning`); B-6 AC-01 dmg 8→16; B-7 AC-14 dmg 12→24; B-8 AC-08 removed false `t=0.0` anchor → tick-count; B-9 AC-22 → `is_instance_valid`+`await`, Integration-level; B-10 Audio 160→400 events/s (+800 multi-weapon). **Design decisions**: B-3 Formula 1 `MAX_FINAL_DAMAGE_PER_HIT = 200` clamp (guards Five Phases 相克 ×1.3 + 矿脉 crit ×1.5 stacking from one-shotting Boss); B-2/B-5 aggregate ceiling → **damage-tier selection** `(damage DESC, spawn_id ASC)` across Core Rule 8 + Formula 7 + AC-13 (split 13a unit / 13b integration) + OQ-6 resolved. **As-built aligned**: B-14 `died` documents node form (Dictionary = target refactor); B-15 Formula 5 burn marked NOT IMPLEMENTED. **Code backlog**: B-11/12/13/14/15 → new OQ-7 for the implementation pipeline. Verdict status: blockers addressed in-doc; pending independent re-review. |
