# ADR-0009: Targeting Service & Single-Frame Enemy Cache

## Status
Accepted (2026-06-04 — independent /architecture-review verdict CONCERNS: architecture substantively passes. Broken WeaponBase ref fixed 0010→0011. Targeting cache remains a Stage-2 perf prerequisite.)

## Date
2026-06-04

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Scripting / Performance |
| **Knowledge Risk** | MEDIUM (perf-critical; no new post-cutoff API — `get_nodes_in_group`, groups, `Node2D.global_position` all stable) |
| **References Consulted** | `design/gdd/targeting-system.md`, `weapon-system.md`, `enemy-system.md`; `docs/architecture/control-manifest.md` (C-2); `/architecture-review` godot-specialist pass (2026-06-04) |
| **Post-Cutoff APIs Used** | None. |
| **Verification Required** | At 84 enemies, total per-frame `get_nodes_in_group("enemies")` calls = **1** (the cache rebuild), not 20+. Confirm in the Stage-2 perf profile (shared gate with ADR-0008). |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0007 (Combat — targets are enemies), ADR-0008 (Enemy — the things being targeted), ADR-0001 |
| **Enables** | ADR-0011 (WeaponBase, pending — reads the service), the Stage-2 84-enemy perf budget (ADR-0008 §5b) |
| **Blocks** | Weapon epic; Stage-2 ship (perf prerequisite) |
| **Ordering Note** | The cache is a **hard Stage-2 prerequisite** (ADR-0008 §5b), not "future refactor." Resolves control-manifest conflict C-2. |

## Context

### Problem Statement
Targeting is a Core service (weapons pick targets through it) with **no governing ADR**. Two problems compound: (1) the shared service **does not exist yet** — each of the 5 nearest-targeting weapons carries its own copy of `_find_nearest_enemy()` and calls `get_nodes_in_group("enemies")` itself; (2) at the Stage-2 84-enemy swarm, that is **20+ full scene-tree group scans per frame** — a direct violation of `technical-preferences.md` ("avoid expensive scene-tree searches during combat") and the dominant avoidable cost in the swarm-perf risk (ADR-0008 R-1). Meanwhile the control-manifest already *asserts* weapons use a shared Targeting service (conflict C-2: the manifest describes a service that isn't built).

### Constraints
- 60 FPS at 84 enemies (TR-core-005); the per-frame scan count must collapse to 1.
- Brownfield: weapons currently self-iterate; the refactor must not change targeting *behavior* (nearest-enemy selection), only centralize + cache it.
- Bagua Array intentionally bypasses targeting (radius aura hits all in range) — must remain a sanctioned exception.

### Requirements
- One service exposing `find_nearest` and `find_in_radius`.
- The enemy list is scanned **once per physics frame**, cached, and reused by all callers.
- Deterministic tiebreak for equidistant enemies (replay/test-safe).

## Decision

### 1. A single `Targeting` service (Player-scoped node, not autoload)
A `Node` child of Player owning the per-frame enemy cache and exposing:
```gdscript
func find_nearest(from: Vector2, max_range: float) -> Node2D        # nearest enemy within range, or null
func find_k_nearest(from: Vector2, max_range: float, k: int) -> Array[Node2D]   # Thunder Law multi-target
func find_in_radius(from: Vector2, radius: float) -> Array[Node2D]  # area queries
```
Equidistant tiebreak: lower `spawn_id` wins (deterministic). Per-Player node (not autoload) — it serves this run's weapons and resets with the run; consistent with ComboManager (ADR-0006) and the no-gameplay-singleton rule.

### 2. Single-frame cache (the perf core)
The service rebuilds its enemy list **at most once per physics frame**, guarded by a dirty flag:
- `get_nodes_in_group("enemies")` runs once when the cache is dirty; results cached for the rest of the frame.
- Cache invalidated (dirty=true) on enemy **spawn** and **despawn** (the spawner / enemy `_die()` flips the flag), and at the start of each physics frame.
- All weapons call `find_*` which read the cache — **zero weapons call `get_nodes_in_group` directly.**
- Optionally store cached enemy positions to avoid repeated `global_position` reads in the same frame.

### 3. Targeting bypass for radius weapons (sanctioned)
Bagua Array (and future pure-aura weapons) do **not** use `find_nearest` — they apply to all enemies in their radius. They still read the **cache** (`find_in_radius`) rather than scanning the tree themselves, so they too contribute zero extra scans.

### Key Interfaces
```gdscript
# Targeting (child of Player)
func find_nearest(from: Vector2, max_range: float) -> Node2D
func find_k_nearest(from: Vector2, max_range: float, k: int) -> Array[Node2D]
func find_in_radius(from: Vector2, radius: float) -> Array[Node2D]
func mark_dirty() -> void        # called by spawner on spawn, enemy on despawn
# Internal: _rebuild_cache() runs once/frame max when _dirty
```

## Alternatives Considered

### Alternative 1: Keep per-weapon self-iteration (status quo)
- **Cons**: 20+ tree scans/frame at 84 enemies; duplicated `_find_nearest_enemy()` across 5 weapons; the documented swarm-perf risk.
- **Rejection**: This is exactly the cost the Stage-2 budget cannot afford; centralizing is the single biggest win (ADR-0008 §5b).

### Alternative 2: Physics-overlap targeting (Area2D per weapon)
- **Description**: Each weapon uses an `Area2D` range and reads overlapping bodies.
- **Pros**: No group scan; engine broadphase does the work.
- **Cons**: More `Area2D` nodes (already a swarm cost); per-weapon range areas duplicate work the cache does once; harder to get deterministic nearest tiebreak.
- **Rejection**: A single shared cache beats N per-weapon areas for *nearest* queries. (Area-overlap remains the right tool for contact damage, ADR-0007 — different purpose.)

### Alternative 3: Autoload Targeting
- **Cons**: Holds per-run state (the cache, the enemy set) that resets each run; targeting is run-scoped gameplay support.
- **Rejection**: Per-Player node matches the run lifecycle.

## Consequences

### Positive
- Per-frame enemy scans collapse from 20+ to 1 — the dominant avoidable swarm cost is gone (unblocks ADR-0008 R-1).
- One targeting implementation (kills the 5 duplicated `_find_nearest_enemy()` copies, TR tech debt).
- Deterministic tiebreak makes targeting replay/test-safe.

### Negative
- Cache-invalidation correctness becomes load-bearing: a missed `mark_dirty()` on spawn/despawn yields stale targets for one frame. Mitigated by also rebuilding at frame start.

### Risks
- **R-1 stale cache**: if an enemy dies mid-frame after the cache is built, `find_*` may return a dying node. Callers must null-check / `is_instance_valid()` (the enemy is freed end-of-frame; reads in the same frame are safe but the node may be `DYING`). Document in the weapon contract (ADR-0010).
- **R-2 behavior drift**: centralizing must preserve the exact nearest-selection the 5 weapons had. Covered by porting their logic verbatim into `find_nearest` + a regression test.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| targeting-system.md | `find_nearest` / `find_in_radius` service | §Decision 1 |
| targeting-system.md | per-weapon `_find_nearest_enemy()` copies = tech debt → centralize | §Decision 1/2 (one impl) |
| weapon-system.md | Bagua Array bypasses targeting (radius) | §Decision 3 (sanctioned, reads cache) |
| stage-2-enemies.md / TR-core-005 | 84 enemies at 60 FPS | §Decision 2 (1 scan/frame) |
| control-manifest C-2 | "weapons use shared Targeting service" | §Decision 1 makes the asserted service real |

## Performance Implications
- **CPU**: one `get_nodes_in_group` + one list build per physics frame, vs 20+ today. `find_nearest` is an O(n) scan of the cached list per call — acceptable at n≤84; if profiling flags it, a spatial bucket can be added later (not needed at this scale).
- **Memory**: one cached `Array[Node2D]` (+ optional positions) per frame — negligible.
- **Draw calls**: N/A (logic only).

## Migration Plan
1. Add the `Targeting` node under Player; implement `find_nearest`/`find_k_nearest`/`find_in_radius` + the dirty-flag cache.
2. Replace each weapon's `_find_nearest_enemy()` with a `Targeting.find_nearest(...)` call (behavior-preserving).
3. Spawner calls `Targeting.mark_dirty()` on spawn; enemy `_die()` marks dirty on despawn (coordinate with combat OQ-7 B-13 which also edits `_die()`).
4. control-manifest C-2: change the Targeting assertion to reflect reality — it was `[PLANNED]` (service didn't exist); after this ADR + migration it becomes the enforced rule. Until migration lands, mark the manifest line `[PLANNED — pre-Stage-2]` so `/story-done` doesn't fail existing self-iterating weapons.

## Validation Criteria
- Unit: `find_nearest` returns the correct nearest enemy + deterministic tiebreak; `find_in_radius` returns all in range; cache rebuilds exactly once per frame (instrument the scan count).
- **Perf gate (shared with ADR-0008)**: at 84 enemies, group-scan count per frame == 1; Stage-2 sustains 60 FPS.

## Related Decisions
- ADR-0007 (Combat). ADR-0008 (Enemy/Spawning — §5b names this cache a hard prerequisite). ADR-0011 (WeaponBase, pending — consumes `find_*`). control-manifest C-2.
- `targeting-system.md`, `weapon-system.md`. TR-core-005.
