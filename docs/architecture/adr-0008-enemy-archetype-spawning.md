# ADR-0008: Enemy Archetype Schema, Spawning & Swarm Performance

## Status
Proposed

## Date
2026-06-04

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Scripting / Performance |
| **Knowledge Risk** | MEDIUM-HIGH (84-enemy swarm perf is a real GTX 1060 risk — escalated to HIGH by godot-specialist in `/architecture-review` 2026-06-04) |
| **References Consulted** | `design/gdd/enemy-system.md`, `enemy-spawning.md`, `stage-2-enemies.md`, `boss-system.md`; `docs/engine-reference/godot/`; `/architecture-review` godot-specialist pass (2026-06-04) |
| **Post-Cutoff APIs Used** | `VisibleOnScreenNotifier2D` (stable), `MultiMeshInstance2D` (optional health bars), `Dictionary[String,int]` typed (4.4+, for element). None load-bearing beyond stable APIs. |
| **Verification Required** | **Profile a 84-enemy Stage-2 wave on GTX-1060-class hardware** — sustained 60 FPS with culling + Targeting cache; confirm health-bar strategy holds. This is a BLOCKING perf gate before Stage-2 ships. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0007 (Combat — enemies are damage targets), ADR-0001 |
| **Enables** | Boss ADR (BossBase extends Enemy), ADR-0006 (element field on archetypes), Demon Seal / Stage Director spawning |
| **Blocks** | Enemy, Enemy-Spawning, Boss epics |
| **Ordering Note** | Carries the Stage-2 84-enemy performance budget — gates Targeting cache (ADR-0009) as a hard prerequisite, not "future work." |

## Context

### Problem Statement
The Enemy system (7 archetypes, 20-field schema, elite affixes) and Enemy-Spawning (timed waves, seeded RNG) have **no governing ADR** despite being a 6-downstream Core bottleneck. Critically, `/architecture-review` (godot-specialist) escalated the **2:00 Stage-2 wave of 84 enemies to HIGH performance risk** on GTX-1060-class hardware: 84× `CharacterBody2D + Area2D` plus per-enemy `Polygon2D` health bars plus 20+ per-frame `get_nodes_in_group("enemies")` scans is a real allocation/CPU storm. This ADR locks the archetype/spawning contract **and** the mandatory swarm-perf mitigations.

### Constraints
- 60 FPS sustained on GTX 1060 / RX 580 (TR-core-005); 30 FPS floor only in the Boss edge case.
- Data-driven archetypes (`.tres`) per Pillar 4 / ADR-0001.
- Brownfield: 7 archetypes + spawner implemented; stage data is a GDScript code-builder, not `.tres` (known ADR-0004 deferral, C-4).
- Must support the `element` field (ADR-0006) and the Merit difficulty multiplier (Merit GDD).

### Requirements
- One `EnemyArchetype` Resource schema; elites are affix-modified archetypes, not separate classes.
- Spawning is time-triggered + seeded-RNG deterministic (replay-safe).
- A 84-enemy wave sustains 60 FPS.

## Decision

### 1. `EnemyArchetype` Resource (20 fields, data-driven)
A single `Resource` (`.tres`) per archetype: `max_hp, damage, move_speed, damage_interval, xp_drop_value, archetype_name, is_boss, element` (+12 existing fields incl. movement mode, elite-affix flags, sprite refs). `element: String = "neutral"` (ADR-0006). Enemies load an archetype via `apply_archetype(arch)`; **no enemy stats are hardcoded** in `.gd`.

### 2. Elite affixes = archetype modifiers, not subclasses
`configure_elite(affix)` multiplies base archetype values: `iron_bones` → `max_hp ×1.45`; `swift` → `move_speed ×1.3`. Applied at spawn in `apply_archetype()`. Elites reuse the same Enemy class.

### 3. Run-difficulty multiplier hook (Merit)
At spawn, `max_hp` and `damage` are multiplied by the active `difficulty_multiplier` (1.0 normal / 1.3 Hard `天劫` / 1.6 Ascension `渡劫`, Merit GDD). Owned by the run-difficulty state; Enemy reads it in `apply_archetype()`. Stacks multiplicatively with elite affixes and per-stage remix scaling (ADR-0004).

### 4. Spawning — time-triggered + seeded RNG
The spawner is reconfigured per wave by Stage Director (ADR-0004) via `apply_wave_config(interval, max_enemies, archetype_pool, elite_chance)`. Spawn timing is a function of `elapsed_time` (not kill count); archetype/position selection uses a **seeded `RandomNumberGenerator`** (replay determinism, test determinism). `max_enemies` clamps concurrent count per wave.

### 5. **Swarm performance budget (BLOCKING for Stage-2)** — the headline of this ADR
At up to ~84 concurrent enemies, the following are **required**, not optional:
- **5a. Off-screen culling**: each enemy carries a `VisibleOnScreenNotifier2D`; off-screen enemies suspend non-essential per-frame work (health-bar redraw, animation) — they still move/spawn but skip rendering-side updates.
- **5b. Targeting cache (hard dependency on ADR-0009)**: the 20+ per-frame `get_nodes_in_group("enemies")` scans collapse into **one cached enemy list per physics frame** (dirty-flagged on spawn/despawn). Weapons read the cache, not the tree. This is the single biggest win and is a Stage-2 prerequisite.
- **5c. Aggregate-ceiling O(n²) fix (combat OQ-7 B-11)**: the contact-attacker selection must cache its sorted set once per frame, not `sort_custom` per-enemy-per-frame.
- **5d. Health-bar strategy**: per-enemy `Polygon2D` bars at 84× are a draw-call/alloc risk. Default mitigation: only draw a bar when the enemy is damaged AND on-screen (culled bars don't redraw). If profiling still fails, escalate to a single `MultiMeshInstance2D` for all health bars (one draw call). Decision deferred to the perf-gate profile (Verification Required).
- **5e. Simple collision shapes** (circles/capsules) during combat (control-manifest).

## Alternatives Considered

### Alternative 1: One Enemy class per archetype (subclassing)
- **Cons**: 7+ near-identical scripts; elites would multiply the count; balance edits touch code not data.
- **Rejection**: Data-driven single class + `.tres` archetypes is the shipped, Pillar-4-compliant model.

### Alternative 2: Defer swarm perf to "optimize later"
- **Cons**: The review proved 84 enemies is a *current* Stage-2 content reality, not hypothetical. Shipping without culling/cache risks sub-60-FPS on target hardware.
- **Rejection**: Perf mitigations are promoted to BLOCKING prerequisites with a profile gate.

## Consequences

### Positive
- One schema + affix model; balance stays in `.tres`. Spawning is deterministic (replay/test-safe). The 84-enemy risk has a concrete, gated mitigation plan.
- Locks the `element` field and difficulty hook that ADR-0006 / Merit depend on.

### Negative
- The Targeting cache (ADR-0009) becomes a hard Stage-2 prerequisite, not future work — pulls that ADR earlier.
- A perf-profile gate is added to the Stage-2 critical path.

### Risks
- **R-1 (HIGH) 84-enemy frame budget**: even with culling + cache, GTX-1060 60 FPS is unproven until profiled. The Verification gate is mandatory; MultiMesh health bars are the escalation lever.
- **R-2 stage-data not `.tres` (C-4)**: waves are a GDScript code-builder, violating "no hardcoded waves." Accepted as ADR-0004 deferral; a migration AC is tracked there.
- **R-3 element coverage**: archetypes default `neutral`; ADR-0006 anti-dormancy floor requires both Bosses + ≥4 Stage-1 enemies non-neutral (already assigned).

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| enemy-system.md | TR-enemy-001: 20-field archetype schema, data-driven | §Decision 1 |
| enemy-system.md | Elite affixes (iron_bones, swift) | §Decision 2 |
| enemy-system.md / merit-system.md | difficulty_multiplier at spawn | §Decision 3 |
| enemy-spawning.md | timed spawn + seeded RNG + apply_wave_config | §Decision 4 |
| stage-2-enemies.md | 2:00 wave max_enemies=84 sustains 60 FPS | §Decision 5 (BLOCKING perf budget) |
| elements-five-phases.md | element field per archetype | §Decision 1 (ADR-0006) |
| TR-core-005 | 60 FPS on mid-range PC | §Decision 5 + Verification gate |

## Performance Implications
- **CPU**: Culling suspends off-screen per-frame work; Targeting cache removes 20+ tree scans/frame; ceiling O(n²)→O(n log n) once/frame. Net: the dominant per-frame costs at 84 enemies are addressed.
- **Memory**: 84× (CharacterBody2D + Area2D + sprite) is the floor; health bars are the swing factor (per-node Polygon2D vs one MultiMesh). Within the 1 GB ceiling but profile-confirm.
- **Draw calls**: health-bar strategy is the main lever (84 bars → potentially 1 via MultiMesh). Keep steady-state combat ≤2000 draw calls (technical-preferences).

## Migration Plan
Brownfield: archetypes + spawner exist. New work: add `VisibleOnScreenNotifier2D` culling (5a), consume the Targeting cache (5b, ADR-0009), apply the ceiling O(n²) fix (5c, combat OQ-7 B-11), and gate Stage-2 on the perf profile (Verification). Health-bar MultiMesh only if the profile demands it.

## Validation Criteria
- Unit: `apply_archetype` loads all 20 fields; `configure_elite` applies affix multipliers; difficulty multiplier stacks correctly; seeded-RNG spawn is deterministic.
- **Perf gate (BLOCKING)**: 84-enemy Stage-2 wave sustains 60 FPS on GTX-1060-class hardware with culling + Targeting cache; draw calls ≤2000; memory <1 GB.

## Related Decisions
- ADR-0007 (Combat — damage targets, aggregate ceiling). ADR-0009 (Targeting cache — hard prerequisite for 5b). ADR-0004 (Stage/wave config; C-4 .tres deferral). ADR-0006 (element field). Boss ADR (BossBase extends Enemy). Merit GDD (difficulty multiplier).
- `enemy-system.md`, `enemy-spawning.md`, `stage-2-enemies.md`. TR-enemy-001/003, TR-core-005.
