# ADR-0007: Combat Damage Pipeline & HP Ownership

## Status
Accepted (2026-06-04 — independent /architecture-review verdict CONCERNS: architecture substantively passes; Core damage contract is ADR-covered and green-tested in `tests/unit/combat/*`. Broken WeaponBase ref fixed 0010→0011.)

## Date
2026-06-04

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Scripting / Combat |
| **Knowledge Risk** | LOW (formalizes as-built, unit-tested code; no new post-cutoff API) |
| **References Consulted** | `design/gdd/combat-system.md` (rev-6), `docs/architecture/control-manifest.md`, `tests/unit/combat/{hp_application,damage_tuple,aggregate_ceiling}_test.gd`; `/architecture-review` (2026-06-04, godot-specialist pass) |
| **Post-Cutoff APIs Used** | None. Typed signals + `maxf`/`minf` (4.0+). |
| **Verification Required** | None new — the contract is already covered by `tests/unit/combat/*` (hp application, damage tuple, aggregate ceiling). This ADR documents what those green tests assert. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Godot 4 + GDScript, signal architecture) |
| **Enables** | ADR-0011 (WeaponBase, pending), ADR-0012 (Status Effects, pending), ADR-0006 (Element System — fills the reserved pipeline slots), Combat Feedback / Boss / Enemy ADRs |
| **Blocks** | Weapon, Status Effects, Combat Feedback epics (they implement against this contract) |
| **Ordering Note** | This is the Core bottleneck (7 downstream systems). Resolves control-manifest conflicts C-1 / C-3 (see Consequences). Brownfield: code + tests already exist; this ADR retro-formalizes them. |

## Context

### Problem Statement
Combat is the central damage layer (7 downstream dependents) yet has **no governing ADR** — the only Core system at the project's highest fan-out with zero architectural formalization (`/architecture-review` 2026-06-04, FAIL driver). Worse, the **control-manifest contradicts the as-built, tested reality** on two load-bearing points (conflicts C-1 and C-3 below): a programmer reading the manifest would build the *wrong* damage-delivery and signal model. This ADR locks the real contract that `design/gdd/combat-system.md` (rev-6) specifies and `tests/unit/combat/*` already validate.

### Constraints
- Godot 4.6 / GDScript; signal-based architecture (ADR-0001).
- Brownfield: the pipeline is implemented and unit-tested (v0.1–v0.4). This ADR must document as-built, not redesign.
- Must preserve the reserved `element_modifier` / `crit_multiplier` slots (filled by ADR-0006) and the `MAX_FINAL_DAMAGE_PER_HIT = 200` clamp (combat rev-6).
- Performance: aggregate incoming-DPS ceiling must hold at 84-enemy swarms (TR-core-005; see ADR-0008 for the perf budget).

### Requirements
- Every damage exchange uses one tuple shape and one HP-ownership rule.
- Downstream systems (Status Effects, Combat Feedback, Experience, Boss, HUD, Run State) observe damage/death via signals, not by reaching into weapons or enemies.
- Player survivability is bounded by an aggregate-DPS ceiling, not per-attacker linear scaling.

## Decision

### 1. Damage tuple (the unit of all combat exchange)
Every damage event is `(source, target, amount, damage_type, source_kind)`:
- `damage_type ∈ {DIRECT, TICK, EXPLOSION, BURN}` (BURN = Formula 5, **not yet implemented** — combat rev-6 B-15).
- `source_kind ∈ {WEAPON, ENEMY, ENVIRONMENT}` — enforces the friendly-fire exemption (WEAPON/ALLY never damage the player; ENVIRONMENT can, e.g. a burn patch).

### 2. HP ownership — TARGET owns and mutates its own HP (resolves C-1)
**The delivery mechanism is a direct method call, not a signal.** A weapon (or enemy) calls `target.take_damage(amount, damage_type, source_kind, source)`. **Only the target's own script decrements its own HP.** After applying, the target emits its target-side signal (`health_changed` for Player, `damage_taken` for Enemy). `damage_dealt` is an **after-the-fact notification**, NOT the mechanism by which damage is applied.

> **This directly corrects control-manifest C-1**, which states damage is "applied via the `damage_dealt` signal, no direct cross-system calls." That is wrong: the tested code uses direct `take_damage()` calls with target-owned HP. The manifest must be reworded (see Migration Plan).

### 3. Signal contracts (resolves C-3)
Four signals, exact payloads:
```gdscript
# Source-side notification — fires for ALL damage events, incl. amount==0 probes:
signal damage_dealt(payload: { source: Node, target: Node, amount: float,
                               damage_type: DamageType, source_kind: SourceKind })
# Target-side, Enemy — fires only when amount > 0 (HP-bar / flash trigger):
signal damage_taken(current_hp: float, max_hp: float, last_damage_amount: float)
# Target-side, Player — Player OWNS this (Core Rule 3):
signal health_changed(current_hp: float, max_hp: float)
# Death — node form (as-built; Dictionary payload is the target refactor, combat rev-6 B-14):
signal died(enemy: Enemy)   # carries the node; consumers read enemy.position/xp_drop_value/is_boss
```
> **This corrects control-manifest C-3**, which lists a 2-field `damage_dealt(amount, target)`. The real contract is the 5-field payload above. Two signals exist by design: `damage_dealt` (source-side, every attempt, for Status Effects/analytics) and `damage_taken` (target-side, real HP change only, for flash/HP-bar).

### 4. Damage pipeline (Formula 1)
`final_damage = min(raw × source_modifier × crit_multiplier × element_modifier × pierce_falloff, MAX_FINAL_DAMAGE_PER_HIT)`; `new_hp = max(0, current_hp − final_damage)`.
- `MAX_FINAL_DAMAGE_PER_HIT = 200` (combat rev-6 B-3 clamp).
- `element_modifier` (ADR-0006 `ElementMatchup`) and `crit_multiplier` (ADR-0006 `maxf(fire_eyes, ore_crit)`) fill the reserved slots — pipeline shape is fixed so those ADRs amend multipliers without rewriting Formula 1.

### 5. Aggregate DPS ceiling
`MAX_CONTACT_ATTACKERS = 4`; when >4 enemies contact the player, only the **4 highest-damage** apply this frame (tiebreak `damage DESC, spawn_id ASC` — combat rev-6 B-2/B-5). Caps incoming DPS so a swarm cannot 0.4s-wipe the player. Per-enemy throttle (`damage_interval`, Formula 4) is independent and always applies.

### 6. Death lifecycle
HP→0 ⇒ **data-death** (transition to `DYING`, emit `died` once, lock `last_hp=0`) ⇒ **visual-death** (VFX, ≤0.5s, owned by VFX/Combat Feedback). A `DYING` guard drops further damage events to the same target (no double-`died`, no double-XP).

### Key Interfaces
```gdscript
# On every damageable target (Enemy, Player):
func take_damage(amount: float, damage_type: int = DIRECT,
                 source_kind: int = WEAPON, source: Node = null) -> void
# Target decrements own HP, clamps, emits its target-side signal, and (via Combat) emits damage_dealt.
enum DamageType { DIRECT, TICK, EXPLOSION, BURN }
enum SourceKind { WEAPON, ENEMY, ENVIRONMENT }
const MAX_FINAL_DAMAGE_PER_HIT: float = 200.0
const MAX_CONTACT_ATTACKERS: int = 4
```

## Alternatives Considered

### Alternative 1: Signal-delivered damage (the manifest's model)
- **Description**: Weapons emit `damage_dealt`; targets subscribe and apply.
- **Cons**: Inverts ownership (a global listener applies damage to a target it doesn't own); ordering/race issues; harder to unit-test a single hit; contradicts the shipped, tested code.
- **Rejection Reason**: The as-built direct-call + target-owned-HP model is simpler, testable (it IS tested), and matches Core Rule 3. The manifest is the thing that is wrong, not the code.

### Alternative 2: Central CombatManager applies all damage
- **Description**: One node owns all HP and applies every hit.
- **Cons**: God-object; breaks the "target owns its HP" rule; a bottleneck at 84 enemies.
- **Rejection Reason**: Distributed target-owned HP scales and keeps responsibility local.

## Consequences

### Positive
- The 7 downstream systems get one stable contract (tuple + 4 signals + Formula 1) to build against.
- Resolves control-manifest conflicts C-1 (HP model) and C-3 (signal signature) — programmers stop getting misled.
- ADR-0006's element/crit slots and the rev-6 clamp are now anchored in an Accepted ADR.

### Negative
- The control-manifest must be edited (it currently states the wrong model) — a doc-correction cost, done in Migration Plan.
- `died(enemy)` node form (not Dictionary) is locked as as-built; the cleaner Dictionary payload is deferred (combat rev-6 B-14 / OQ-7).

### Risks
- **R-1**: Burn (`damage_type = BURN`, Formula 5) is specified but unimplemented (combat OQ-7 B-15); AC-15/16/17 are RED until built. Documented, not a contract change.
- **R-2**: `damage_dealt` fires on every event incl. `amount==0` probes — consumers (Status Effects) must handle zero-amount events (Core Rule 7).

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| combat-system.md | Core Rule 2: `(source,target,amount,damage_type,source_kind)` tuple | §Decision 1 |
| combat-system.md | Core Rule 3: target owns + mutates own HP; emits health_changed | §Decision 2 (resolves C-1) |
| combat-system.md | Formula 1 + `MAX_FINAL_DAMAGE_PER_HIT=200` | §Decision 4 |
| combat-system.md | Core Rule 8 / Formula 7: aggregate ceiling, damage-tier | §Decision 5 |
| combat-system.md | Core Rule 4/6: data-death → visual-death, DYING guard | §Decision 6 |
| combat-system.md | 4 signal payloads (damage_dealt 5-field, damage_taken, health_changed, died) | §Decision 3 (resolves C-3) |
| TR-wpn-002 | 4 damage types | §Decision 1 (BURN unimplemented) |

## Performance Implications
- **CPU**: Per-hit Formula 1 is a handful of float ops + one `minf`. Aggregate-ceiling selection sorts ≤contact-count attackers (see ADR-0008 R for the O(n²) fix, combat OQ-7 B-11). At 84 enemies the ceiling caps *incoming* work; outgoing weapon hits are bounded by weapon count.
- **Memory**: No per-hit allocation beyond the damage_dealt payload Dictionary (short-lived). Consider a tuple/struct if profiling flags GC churn.
- **Load/Network**: N/A.

## Migration Plan
Code exists and is tested — no code migration. **Doc corrections required** (this ADR makes them canonical; the manifest edits land in the same change-set):
- control-manifest C-1: reword "damage applied via `damage_dealt` signal, no direct calls" → "weapons call `target.take_damage()`; target owns/mutates HP; `damage_dealt` is an after-the-fact notification."
- control-manifest C-3: replace `damage_dealt(amount, target)` with the 5-field payload.
- (C-2 Targeting and C-4 .tres-waves are resolved by ADR-0008 / ADR-0004 respectively.)

## Validation Criteria
Already green: `tests/unit/combat/hp_application_test.gd` (Formula 1 + clamp + HP ownership), `damage_tuple_test.gd` (tuple + friendly-fire), `aggregate_ceiling_test.gd` (MAX_CONTACT_ATTACKERS selection — note: integration-level Area2D wiring per combat AC-13b needs playtest). New ACs only if the `died` Dictionary refactor (OQ-7 B-14) is undertaken.

## Related Decisions
- ADR-0001 (Godot 4 + GDScript). ADR-0006 (Element System — fills element/crit slots). ADR-0008 (Enemy/Spawning — perf budget, ceiling O(n²) fix). ADR-0011 (WeaponBase, pending). ADR-0012 (Status Effects, pending — consumes `damage_dealt`).
- `design/gdd/combat-system.md` rev-6. `control-manifest.md` (C-1/C-3 corrections). TR-wpn-002, TR-core-005.
