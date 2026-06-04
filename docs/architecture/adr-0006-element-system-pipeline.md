# ADR-0006: Five Phases Element System — Pipeline & Combo Architecture

## Status
Accepted (2026-06-04 — independent /architecture-review verdict CONCERNS: architecture substantively passes; CombatEvents bus + ComboManager design validated by godot-specialist. Unblocks Five Phases stories.)

## Date
2026-06-04

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Scripting / Combat |
| **Knowledge Risk** | MEDIUM (4.4+ typed-`Dictionary` syntax; callable-only signal connections since 4.0 — both accounted for below) |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md`, `deprecated-apis.md`; ADR-0001; `control-manifest.md`; validated by `godot-specialist` (2026-06-04) |
| **Post-Cutoff APIs Used** | `Dictionary[String, int]` typed syntax (4.4+). `maxf()` (4.0+). No load-bearing post-cutoff-only API. |
| **Verification Required** | (1) `CombatEvents.enemy_killed` fires exactly once per death with correct element/damage/position; (2) ComboManager recompute fires only on inventory change, not per-frame; (3) crit `maxf()` resolution never exceeds 1.5; (4) frost-slow refresh-only under simultaneous multi-weapon hits. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Godot 4 + GDScript, signal architecture). Combat GDD's `element_modifier` slot (OQ-4, pre-clamp) is a prerequisite contract — already in `combat-system.md`. |
| **Enables** | Five Phases Synergy epic stories; future element-tagged content |
| **Blocks** | Five Phases Synergy epic — combo stories cannot start until this is Accepted |
| **Ordering Note** | Independent of ADR-0005 (Save/Load). Introduces a new `CombatEvents` autoload that future combat-broadcast features may reuse. |

## Context

### Problem Statement
The Five Phases Synergy System (`design/gdd/elements-five-phases.md`, revision-4) adds element tags, a 5×5 overcoming-cycle damage modifier, and **5 passive generating-cycle combos** that hook into combat, the player, weapons, and status effects. The GDD specifies *what* each combo does; this ADR locks *how* the system is wired into the existing node/signal architecture — specifically (a) where element state lives, (b) how combos activate and route their effects without per-frame polling, and (c) how 燎原 reacts to enemy deaths at 50-100-enemy scale without a per-enemy signal anti-pattern.

### Constraints
- Godot 4.6 / GDScript. No singletons for **gameplay logic** (`technical-preferences.md`). Composition + signals (`ARCHITECTURE.md`).
- Must use the reserved `element_modifier` and `crit_multiplier` slots in Combat Formula 1 (pre-clamp) — no changes to the damage pipeline shape.
- Must respect `MAX_FINAL_DAMAGE_PER_HIT = 200` (ADR-?? / Combat rev-6) — combo damage that goes through the pipeline is clamped.
- Test determinism required (no global `randf()`; seeded RNG).
- Performance: 50-100 enemies on screen; combo recompute must not be per-frame.

### Requirements
- `element_modifier` lookup returns {0.8, 1.0, 1.3} per the 相克 cycle (Five Phases Formula 1).
- 5 combos activate passively when `element_inventory` holds ≥1 of each element in a generating pair (Formula 2), recomputed on inventory change only.
- 燎原 chain-burst on Fire-weapon kills; 熔岩甲 shield + 春生 regen on Player; 矿脉精粹 pierce/crit on weapons; 寒露凝锋 frost-slow status on hits.
- crit_multiplier shared with Active Skills' 火眼金睛, resolved by max() (Formula 8).

## Decision

Four architectural pieces:

1. **`ElementMatchup` — stateless pure-function lookup (Combat module).**
   `ElementMatchup.modifier(src_element: String, tgt_element: String) -> float` returns {0.8, 1.0, 1.3} from the `favorable_set` algorithm (Five Phases Formula 1). No state, no node — a static utility. Combat calls it to fill the `element_modifier` slot in Formula 1. Lives in Combat because it is a damage modifier.

2. **`element_inventory` — owned by Player, typed.**
   `var element_inventory: Dictionary[String, int]` ({metal,wood,water,fire,earth → int}), **all 5 keys seeded at run-start in Player `_ready()`** (before any combo signal fires — see Risks R-2). Incremented on weapon-unlock / `upgrade_applied`. Player emits `element_inventory_changed(inventory: Dictionary)` after each change. **Typed `Dictionary[String, int]`** is mandatory — an untyped `Dictionary` makes `inventory[key] >= 1` a Variant compare, and a missing key returns `null` where `null >= 1` silently evaluates `false` (correctness trap).

3. **`ComboManager` — per-Player child node, signal-driven.**
   A `Node` child of Player (NOT an autoload, NOT a Resource). Responsibilities:
   - Connects to `Player.element_inventory_changed` (after run-init) → recomputes the active-combo set (Formula 2) + scaling (Formula 3). On a **newly** activated pair, emits `combo_activated(combo_id: String)`.
   - Holds the active-combo set + per-combo scaling values; exposes read accessors (`is_combo_active(id) -> bool`, `get_pierce_bonus() -> int`, `get_ore_crit_chance() -> float`, `get_shield_params()`, `get_regen_params()`, …).
   - It does **not** implement the 5 effects inline. Effect routing:
     | Combo | Mechanism |
     |---|---|
     | 燎原 | ComboManager connects to `CombatEvents.enemy_killed`; on Fire-source kill + combo active, spawns the burst (EXPLOSION-type, **bypasses Formula 1**, direct `take_damage` — see Risks R-4/OQ-7) |
     | 熔岩甲 / 春生 | Player reads ComboManager shield/regen accessors in its own `_process`/damage path |
     | 矿脉精粹 | Weapons read `get_pierce_bonus()` + crit chance; Combat applies crit via Formula 8 |
     | 寒露凝锋 | The weapon-hit path applies the `frost_slow` status (owned by Status Effects, refresh-only) |
   - Recompute is **event-driven only** — no `_process` polling.

4. **`CombatEvents` — autoload signal bus (NEW infrastructure).**
   A pure signal relay (zero gameplay logic, zero state) for broadcast combat events that would otherwise require per-instance connections. Declares:
   `signal enemy_killed(kill_data: EnemyKillData)` where `EnemyKillData extends RefCounted` carries **value data only** — `source_element: String`, `damage: float`, `position: Vector2` (NEVER the enemy Node reference — it is freed end-of-frame). Each enemy, on death, calls `CombatEvents.enemy_killed.emit(data)` **before** `queue_free()`. ComboManager connects **once** in `_ready()`.
   - **Why an autoload bus instead of per-enemy `died.connect()`**: at 50-100 enemies, per-enemy connection means 50-100 live connections, per-spawn connection bookkeeping, and dangling-callable hazards on `queue_free()`. A single bus connection eliminates all three. This is the godot-specialist-confirmed idiomatic pattern.
   - **Why an autoload is allowed here**: like `SaveService` (ADR-0005), `CombatEvents` holds **no gameplay logic** — it is a communication channel. The project's no-singleton rule targets logic-owning singletons. A stateless event bus is the sanctioned exception (`ARCHITECTURE.md` §信号与数据流规则). It is the second and—by intent—final infrastructure autoload of this design tier; new autoloads require their own ADR justification.

### Key Interfaces

```gdscript
# --- Combat module: stateless lookup ---
class_name ElementMatchup
static func modifier(src: String, tgt: String) -> float   # {0.8, 1.0, 1.3}

# --- Autoload: CombatEvents (pure relay, no logic, no state) ---
signal enemy_killed(kill_data: EnemyKillData)
# EnemyKillData extends RefCounted: source_element:String, damage:float, position:Vector2

# --- Player (owns element state) ---
var element_inventory: Dictionary[String, int]    # 5 keys, seeded in _ready()
signal element_inventory_changed(inventory: Dictionary)

# --- ComboManager (child of Player) ---
signal combo_activated(combo_id: String)
func is_combo_active(combo_id: String) -> bool
func get_pierce_bonus() -> int
func get_ore_crit_chance() -> float           # 0.0–0.10
func get_shield_params() -> Dictionary        # {max_hp, regen, grace}
func get_regen_params() -> Dictionary         # {hp_per_4s, xp_bonus}
var _rng: RandomNumberGenerator               # seeded; injected in tests

# --- Combat crit resolution (Formula 8, pull model) ---
# crit_multiplier = maxf(fire_eyes_modifier, ore_crit_roll)   # maxf, NOT max(Variant)
```

### Architecture Diagram

```
 Player ──owns──> element_inventory: Dictionary[String,int]
   │  emits element_inventory_changed
   └── ComboManager (child node, signal-driven)
         ├─ recompute active combos on inventory change (no polling)
         ├─ connects ONCE ──> CombatEvents.enemy_killed  ──(燎原)
         └─ exposes flags/accessors read by:
              Player (熔岩甲 shield / 春生 regen)
              Weapons (矿脉精粹 pierce + crit chance)
              weapon-hit path (寒露凝锋 → Status Effects frost_slow, refresh-only)

 Enemy._die() ──emit──> CombatEvents.enemy_killed(EnemyKillData{element,damage,pos})
                                            (value data only — node freed end-of-frame)

 Combat Formula 1: final = min(raw × source × maxf(fire_eyes, ore_crit) × ElementMatchup.modifier × pierce, 200)
```

## Alternatives Considered

### Alternative 1: 燎原 via per-enemy `died.connect()`
- **Description**: ComboManager connects to each spawned enemy's `died` signal.
- **Pros**: No new bus; direct.
- **Cons**: 50-100 live connections; per-spawn bookkeeping; dangling-callable hazard on `queue_free()`; reads a node that is freed end-of-frame.
- **Rejection Reason**: Textbook anti-pattern at this enemy count (godot-specialist). The `CombatEvents` bus is one connection with zero lifecycle risk.

### Alternative 2: ComboManager as autoload
- **Description**: A global combo manager.
- **Cons**: Holds per-run state (active combos, scaling) that must reset each run; that state belongs to the Player's lifetime; violates the no-gameplay-logic-singleton rule (combo activation IS gameplay logic).
- **Rejection Reason**: Per-Player child node matches the run lifecycle and keeps gameplay logic out of autoloads.

### Alternative 3: Push model for crit_multiplier (shared mutable slot)
- **Description**: 火眼金睛 and 矿脉精粹 each write the crit slot; last writer wins.
- **Cons**: Frame-order-dependent, non-deterministic when both write from different signal callbacks.
- **Rejection Reason**: `maxf()` pull at damage-calc time is order-independent and stateless (Formula 8).

## Consequences

### Positive
- Combo logic encapsulated in one per-Player node; effects routed via clean accessors/signals; no per-frame cost.
- `CombatEvents` bus scales to any enemy count and becomes reusable infrastructure for future broadcast combat events (damage dealt, status applied, …).
- Stateless `ElementMatchup` + pull-model crit are trivially unit-testable and deterministic (seeded RNG).

### Negative
- A second infrastructure autoload (`CombatEvents`) is introduced. Accepted as a stateless relay; must be guarded against accreting logic (registered as a forbidden pattern).
- 燎原's pipeline-bypass (direct `take_damage`, not through Formula 1) means it is **not** covered by the `MAX_FINAL_DAMAGE_PER_HIT` clamp — bounded instead by `WILDFIRE_MAX_CHAINS` and the 50%-of-killing-blow ratio (the killing blow itself is clamped, so burst ≤ 100). See Risks.

### Risks
- **R-1 EnemyKillData lifetime**: must carry value data only (element/damage/position), never the enemy Node — the node is freed end-of-frame after `queue_free()`.
- **R-2 Inventory init order (Core Rule 11)**: ComboManager must not connect to `element_inventory_changed` until Player has fully seeded the inventory in `_ready()` (incl. Merit Node 11 element bonus), or a combo could activate mid-init before the HUD exists. Use a `run_initialized` signal ComboManager awaits.
- **R-3 Frost-slow double-write**: simultaneous multi-weapon hits (Thunder Law multi-target + Flying Sword same frame) both invoke the slow path. Refresh-only semantics MUST be guarded **inside the Status Effects registry**, not in ComboManager — else two "apply slow" calls race. Cross-system contract with the Status Effects implementer.
- **R-4 / OQ-7 燎原 chain DPS ceiling**: chain burst (50% non-decaying, 3 chains) is unbounded by pack density; one kill in a 100-enemy cluster can cascade. **Blocking playtest gate** before shipping 燎原 — tune `WILDFIRE_MAX_CHAINS` / ratio against Combat's aggregate-DPS expectations.
- **R-5 Typed Dictionary**: `element_inventory` MUST be `Dictionary[String, int]` with all 5 keys initialized; untyped form risks `null >= 1` silent-false bugs.
- **R-6 Hot-path `maxf()`**: crit resolution uses `maxf(float,float)`, not `max(Variant,Variant)` — per-hit calc in 200-projectile scenarios.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| elements-five-phases.md | Formula 1: 相克 modifier {0.8,1.0,1.3} | `ElementMatchup.modifier()` stateless lookup in Combat |
| elements-five-phases.md | Core Rule 3/11: element_inventory, run-start seed | Player owns typed `Dictionary[String,int]`, seeded in `_ready()` |
| elements-five-phases.md | Formula 2: passive combo activation on inventory ≥1+1 | ComboManager recompute on `element_inventory_changed`, no polling |
| elements-five-phases.md | 燎原 chain burst on Fire-weapon kill | `CombatEvents.enemy_killed` bus + ComboManager handler; EXPLOSION-type, pipeline-bypass |
| elements-five-phases.md | Formula 8: crit_multiplier max() with 火眼金睛 | `maxf(fire_eyes, ore_crit)` pull model in Combat |
| elements-five-phases.md | 寒露凝锋 frost slow (refresh-only) | Routed to Status Effects registry; refresh guard owned there (R-3) |
| combat-system.md | element_modifier / crit_multiplier reserved slots (pre-clamp) | Filled by ElementMatchup + Formula 8; pipeline shape unchanged |

## Performance Implications
- **CPU**: Combo recompute fires only on inventory change (≈1×/level-up, ~10-15×/run) — negligible. `ElementMatchup.modifier` is a small set lookup per hit; `maxf` per hit is trivial. `CombatEvents` bus is one emit per enemy death (replaces per-enemy connection overhead).
- **Memory**: One ComboManager + one EnemyKillData RefCounted per death (GC'd). Negligible.
- **Load Time**: N/A.
- **Network**: N/A.

## Migration Plan
The `element_modifier` / `crit_multiplier` slots already exist (default 1.0) in Combat Formula 1 — no pipeline migration. New code: `ElementMatchup`, `CombatEvents` autoload, `ComboManager`, Player `element_inventory` + signal. Enemy `_die()` gains one `CombatEvents.enemy_killed.emit()` before `queue_free()` (coordinate with Combat Blocker-13/14 fix in OQ-7, which also touches `_die()`).

## Validation Criteria
- Unit: `ElementMatchup.modifier` returns correct value for all 25 ordered pairs (covers Five Phases AC-14b/c/d/e). ComboManager activates the right combos for given inventories (Formula 2). `maxf` crit never exceeds 1.5. Seeded-RNG crit roll is deterministic.
- Integration: `CombatEvents.enemy_killed` fires once per death with correct data; 燎原 burst triggers only on Fire-source kills with combo active; frost-slow refresh-only under simultaneous hits.
- Playtest gate: OQ-7 chain-kill cascade bounded (R-4).

## Related Decisions
- ADR-0001 (Godot 4 + GDScript signal architecture).
- ADR-0005 (Save/Load) — sibling v0.5 foundation ADR; same justified-autoload bar.
- `combat-system.md` (rev-6) — element_modifier/crit slots, MAX_FINAL_DAMAGE_PER_HIT clamp, OQ-7 backlog.
- `design/gdd/elements-five-phases.md` (revision-4) — source GDD.
- `design/gdd/status-effects.md` — frost_slow owner (refresh-only guard, R-3).
- TR registry: `TR-elem-*` domain (to be populated by `/architecture-review`).
