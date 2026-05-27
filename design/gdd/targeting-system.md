# Targeting System

> **Status**: Designed (revision-0, awaiting independent /design-review)
> **Author**: claude (reverse-documented from per-weapon `_find_nearest_enemy()` / `_find_nearest_targets()` patterns across 5 weapon scripts + Combat GDD's "Targeting" reference)
> **Last Updated**: 2026-05-25
> **Implements Pillar**: Pillar 2 (auto-battle — Targeting decides what gets attacked without player input)
> **TR Coverage**: (none direct — Targeting is implementation infrastructure under Combat)
> **Layer**: Core (depends on Player position, Enemy nodes)

## Overview

The Targeting System decides **which enemies a weapon will attack this frame**. It exposes two query primitives that every weapon needs: "give me the nearest enemy within range" (single-target weapons) and "give me the K nearest enemies within range" (multi-target weapons). Radius-based weapons (Bagua Array) don't use Targeting — they apply damage to all enemies inside their radius without explicit selection.

**Important honest-status finding (revision-0 reverse-doc audit, 2026-05-25)**: There is **no centralized Targeting service** in the v0.4 code. Each of the 4 single-target weapons (`talisman_weapon.gd`, `flying_sword_weapon.gd`, `explosive_talisman_weapon.gd`, `mountain_seal_weapon.gd`) re-implements `_find_nearest_enemy()` as a 20-line copy. `thunder_law_weapon.gd` re-implements a 32-line `_find_nearest_targets()` for K-nearest. **This GDD's design intent is the eventual contract** — a `Targeting` singleton or static class that exposes `find_nearest(origin, range)` and `find_nearest_k(origin, range, k)` — but the v0.4 code has not yet been refactored to that abstraction.

This is **OK** for v0.4 — the duplication works correctly. The GDD locks the *contract* so when refactor time comes, the API surface is pre-agreed.

Reference ADRs: ADR-0001 (Godot 4.x + GDScript — `get_tree().get_nodes_in_group()` is the engine primitive).

## Player Fantasy

Targeting is **completely invisible** to players. They never think "the target was selected by Algorithm X." They see:
- The flying sword hits **the closest enemy** that's threatening them (not a random one across the screen)
- Thunder Law strikes **multiple enemies in a tight cluster** (the most-densely-packed area)
- Their构筑 feels intentional, not random — weapons "know what to attack"

Anti-fantasy: a weapon firing at an empty space because the targeted enemy died half a frame ago, or attacking an enemy across the map while the player is being mobbed locally — both targeting bugs that destroy the auto-battle trust.

## Detailed Rules

### Core Rules

1. **Targeting is per-weapon-invocation, not persistent.** Each frame a weapon is ready to fire, it queries Targeting freshly. There is no "targeted enemy" stored across frames. This is by design — enemies die, move, and spawn fast enough that a stale target reference would be a bug source.

2. **The enemies pool is the Godot scene-tree group `"enemies"`.** Every Enemy node MUST be in this group (Enemy.tscn declares `groups=["enemies"]` at scene level). Targeting uses `get_tree().get_nodes_in_group("enemies")` — engine-provided, O(N) where N = enemies in group.

3. **Targeting filters out dead/dying nodes.** Per the contract, before considering an enemy a valid target, Targeting must verify:
   - `enemy is Node2D` (type guard)
   - `enemy.has_method("take_damage")` (Combat-API conformance)
   - `not enemy.is_queued_for_deletion()` (per Combat GDD Core Rule 6 — DYING enemies are inert; Targeting must not select them)

4. **Distance comparison uses squared distance** (`distance_squared_to`), NOT `distance_to`. This avoids per-comparison `sqrt()` cost. Range comparisons are done as `distance_squared > range²` to maintain correctness without taking the square root.

5. **Origin point for targeting queries is the weapon's `global_position`**, NOT Player's `global_position`. Most weapons are children of Player so the two are nearly identical, but multi-projectile weapons or spawned-projectiles use their own `global_position` for accurate range checks.

6. **Range is per-weapon, sourced from `WeaponBase.attack_range` (`.tres` or scene-embedded)**. Per Combat GDD Core Rule 4 (data-driven tuning), this value is configurable; per Combat GDD Tuning Knobs, design-safe range is 50 – 600 px (clamped lower bound `MIN_ATTACK_RANGE = 1.0`).

7. **K-nearest selection uses sorted insertion** (Thunder Law pattern). For `K` targets, maintain a sorted-by-distance array of size ≤ K; insert each candidate at the correct position; pop the back if size exceeds K. O(N×K) worst case — acceptable for K ≤ 8 and N ≤ 100.

### Two Query Primitives (Contract)

#### Primitive 1: `find_nearest(origin: Vector2, range: float) -> Node2D`

Returns the single closest enemy within `range` of `origin`. Returns `null` if no valid enemy is in range.

**Current implementation**: duplicated 4× across `talisman_weapon.gd:19`, `flying_sword_weapon.gd:20`, `explosive_talisman_weapon.gd:22`, `mountain_seal_weapon.gd:31`. All four are byte-identical in algorithm — only the call site differs.

#### Primitive 2: `find_nearest_k(origin: Vector2, range: float, k: int) -> Array[Node2D]`

Returns up to K closest enemies within `range`, sorted nearest-to-farthest. Returns empty array if no valid enemies in range.

**Current implementation**: `thunder_law_weapon.gd:38-70` (the only K-nearest weapon in v0.4).

### What Targeting Does NOT Provide

- **Predictive targeting** (leading the target): no v0.4 weapon predicts enemy future position. The projectile fires at the target's *current* position; if the enemy moves before the projectile arrives, it may miss.
- **Threat-based targeting** (highest-DPS enemy first): no priority queue beyond nearest. A Stone Golem with 70 HP is targeted the same as a Paper Doll with 14 HP — only distance matters.
- **Line-of-sight targeting**: no obstacle / wall checking. v0.4 is an open arena, so LOS doesn't matter; would be a future concern for indoor levels.
- **Persistent target**: as Rule 1 — each frame re-queries; no "keep firing at this enemy until it dies."
- **Radius-based selection** (Bagua Array): the Bagua's `_apply_radius_damage()` doesn't use Targeting — it iterates `get_tree().get_nodes_in_group("enemies")` directly and applies damage to all in radius. This is intentional (every enemy in radius is hit, not just one). Targeting's contract is only for **selected targets**.

## Formulas

### Formula 1: Nearest-enemy selection

For a weapon at `origin` with `range` r:

```
nearest = null
nearest_d2 = r * r          # squared range — avoid sqrt
for enemy in all_enemies_in_group:
    if not valid_target(enemy):
        continue
    d2 = origin.distance_squared_to(enemy.global_position)
    if d2 > nearest_d2:
        continue
    nearest = enemy
    nearest_d2 = d2
return nearest               # null if none in range
```

**Variables:**

| Variable | Type | Range | Description |
|---|---|---|---|
| `origin` | Vector2 | world coordinates | Weapon's global position |
| `range` | float | 50 – 600 (Combat GDD safe) | Per-weapon attack range |
| `enemy.global_position` | Vector2 | world coordinates | Enemy's position |
| `d2` | float | 0 – ∞ | Squared distance (skip sqrt) |
| `valid_target` | bool | — | `is Node2D AND has_method("take_damage") AND not is_queued_for_deletion()` |

**Output Range:** `null` (no enemy in range) OR a single Node2D reference. **Never** returns a DYING enemy (per Core Rule 3 + Combat GDD Core Rule 6).

**Cost:** O(N) where N = enemies in group. For v0.4 target of 100 enemies, ~100 squared-distance comparisons per weapon per frame. With 4 weapons firing at base cadence (~0.8s cooldown), this is ~500 ops/sec per weapon = ~2000 ops/sec total. Negligible vs frame budget (16.67ms allows ~10^7 simple ops at 60 FPS).

### Formula 2: K-nearest-enemies selection (sorted insertion)

For K targets:

```
targets = []                 # sorted nearest-to-farthest
d2s = []                     # parallel array of distances²
for enemy in all_enemies_in_group:
    if not valid_target(enemy):
        continue
    d2 = origin.distance_squared_to(enemy.global_position)
    if d2 > range * range:
        continue
    # Sorted insert
    insert_idx = d2s.size()
    for i in range(d2s.size()):
        if d2 < d2s[i]:
            insert_idx = i
            break
    targets.insert(insert_idx, enemy)
    d2s.insert(insert_idx, d2)
    if targets.size() > k:
        targets.pop_back()
        d2s.pop_back()
return targets
```

**Variables:** as Formula 1, plus `k` (int, 1 – 8 per Combat GDD Thunder target_count tuning).

**Cost:** O(N × K) worst case. For N=100, K=8: ~800 ops per Thunder Law fire (every 0.9s default). Still negligible.

### Formula 3: Distance-squared optimization

Why squared distance, not actual distance:

```
# Correct:        d  >  range     ←  involves expensive sqrt
# Equivalent:     d² >  range²   ←  no sqrt, identical truth value
```

For a 100-enemy scan, this saves ~100 sqrt() calls per Targeting query — measurable but not critical at v0.4 scale; matters more when N pushes 500+.

## Edge Cases

- **If `get_tree().get_nodes_in_group("enemies")` returns empty** (run start, between waves): `find_nearest` returns `null`. Weapons gracefully no-op via `if target == null: return false` (see flying_sword_weapon.gd:23-24).
- **If an enemy was just queue_free'd this frame but is still in the group**: the `is_queued_for_deletion()` guard catches it. Without this guard, Combat would attempt damage on a freed node — crash class.
- **If an enemy doesn't implement `take_damage`**: filtered out by Core Rule 3's `has_method` guard. This is defensive — currently all Enemy variants do implement `take_damage`, but the guard protects against a future class hierarchy change.
- **If two enemies are at exactly the same position**: tiebreak is the group iteration order from `get_tree().get_nodes_in_group()`, which is deterministic per scene tree state but not designer-specified. AC notes this is acceptable.
- **If `range` is 0**: squared range is 0, so only enemies at exactly the same position would match (which is virtually never). Effectively no target found — weapon no-ops. AC verifies this.
- **If `range` is negative** (impossible per `MIN_ATTACK_RANGE = 1.0` clamp but defensively): squared range is positive, distances are positive — comparison still works but the floor of 1.0 prevents the case anyway.
- **If a weapon fires every frame because cooldown is `MIN_COOLDOWN = 0.05s`** (20 Hz): targeting queries also run at 20 Hz per weapon. Negligible cost even at 8 weapons × 20 = 160 queries/sec.
- **If 500+ enemies are in the group** (way beyond design target): each Targeting query iterates 500 elements. Still <16ms at 60 FPS, but starts showing in profiler. Future optimization (OQ-2): use spatial partitioning (quadtree / grid) when N > 200.
- **If the targeted enemy dies between Targeting selecting it and the projectile reaching it**: the projectile's hit-detection (Combat GDD Edge Cases — "If a weapon fires and the projectile expires before reaching target") handles this — no damage, weapon already on cooldown.

## Dependencies

| Dependency | Type | Direction | Interface |
|---|---|---|---|
| **Enemy** (C-04, Approved) | Hard | Targeting depends on Enemy | Enemy nodes MUST be in scene-tree group `"enemies"`; MUST implement `take_damage(amount)` |
| **Godot 4.6 engine** | Hard | (implicit) | Provides `get_tree().get_nodes_in_group()`, `distance_squared_to()`, `is_queued_for_deletion()` |
| **Combat** (C-03, Approved) | Hard | Targeting is consumed by Combat | Weapons use Targeting to select targets before applying Combat damage tuples |

**Downstream consumers:**

| Consumer | Status | Interface |
|---|---|---|
| **talisman_weapon, flying_sword_weapon, explosive_talisman_weapon, mountain_seal_weapon** (4 weapons) | ✅ Currently consume `find_nearest` pattern (duplicated) | Each calls own `_find_nearest_enemy()` (same algorithm) |
| **thunder_law_weapon** | ✅ Currently consumes `find_nearest_k` pattern (sole implementation) | Calls own `_find_nearest_targets()` |
| **bagua_array_weapon** | ✗ Does NOT use Targeting (radius-based, hits all in range) | Bypasses; iterates group directly in `_apply_radius_damage()` |
| **Future weapon variants (Sun Wukong skills, future characters)** | ⏳ Will consume contract via the refactored service (when extracted) | Currently each new weapon would duplicate the pattern — not ideal |

**Bidirectional check:**
- Combat GDD lists "Targeting | Hard | Combat depends on" at line 386 ✅
- Enemy GDD must mention Targeting reads from `"enemies"` group ⏳ (verify in next /consistency-check)
- Weapon System GDD (future, FT-03) will be the primary consumer; must specify "uses Targeting primitives"

## Tuning Knobs

| Knob | Owner | Design-safe range | Default | Effect at extremes |
|---|---|---|---|---|
| `WeaponBase.attack_range` (per weapon) | Combat GDD owns this knob | 50 – 600 px | varies per weapon | <50 = melee-only; >600 = trivialises positioning. Combat GDD §Tuning Knobs is authoritative. |
| `target_count` (multi-target weapons only) | Thunder Law `.tres` | 1 – 8 | 1 (default) | >8 = visual chaos, perf rises. Combat GDD §Tuning Knobs |
| Group name `"enemies"` | Enemy.tscn scene | locked string | "enemies" | Renaming breaks all Targeting queries. Treat as engine-side constant, NOT designer-tunable. |
| Spatial partitioning threshold (future) | OQ-2 | TBD | n/a (linear scan today) | When N > threshold, switch to quadtree. To be set after profiling. |

This GDD does NOT introduce new tuning knobs — the `range` and `K` knobs are owned by Combat GDD's WeaponBase tuning. Targeting just consumes them.

## Acceptance Criteria

### AC group: Single-target selection (Formula 1)

**AC-01** **GIVEN** a weapon at world position (0, 0) with `attack_range = 100`, and 3 enemies at world positions (50, 0), (60, 0), (200, 0), **WHEN** `_find_nearest_enemy()` is called, **THEN** the returned target is the enemy at (50, 0) (closest), AND the enemy at (200, 0) is filtered out as out-of-range.

**AC-02** **GIVEN** a weapon at (0, 0) with `attack_range = 100`, and a single enemy at (50, 0) that has `is_queued_for_deletion() == true`, **WHEN** `_find_nearest_enemy()` is called, **THEN** the returned target is `null` (queue-free guard from Core Rule 3).

**AC-03** **GIVEN** a weapon at (0, 0) with `attack_range = 50`, and an enemy at (60, 0) (out of range), **WHEN** `_find_nearest_enemy()` is called, **THEN** the returned target is `null`.

**AC-04** **GIVEN** zero enemies in the scene-tree group `"enemies"`, **WHEN** any weapon's `_find_nearest_enemy()` is called, **THEN** the returned target is `null` AND no error fires.

### AC group: K-nearest selection (Formula 2)

**AC-05** **GIVEN** a Thunder Law weapon at (0, 0) with `attack_range = 200, target_count = 3`, and 5 enemies at (50, 0), (100, 0), (150, 0), (180, 0), (300, 0), **WHEN** `_find_nearest_targets()` is called, **THEN** the returned array is `[enemy(50,0), enemy(100,0), enemy(150,0)]` (3 closest in range; enemy(180,0) is in range but pushed out by K-limit; enemy(300,0) is out of range).

**AC-06** **GIVEN** Thunder Law with `target_count = 5` and only 3 enemies in range, **WHEN** `_find_nearest_targets()` is called, **THEN** the returned array has size 3 (not padded with nulls; size <= K, not == K).

### AC group: Type guards and Combat-API conformance

**AC-07** **GIVEN** the scene tree group `"enemies"` contains a node that is NOT a `Node2D`, **WHEN** `_find_nearest_enemy()` is called, **THEN** that node is silently skipped (no crash, no warning) per Core Rule 3's `enemy is Node2D` guard.

**AC-08** **GIVEN** a node in group `"enemies"` that does NOT implement `take_damage`, **WHEN** `_find_nearest_enemy()` is called, **THEN** that node is silently skipped per Core Rule 3's `has_method` guard.

### AC group: Distance-squared optimization (Formula 3)

**AC-09** **GIVEN** the targeting algorithm, **WHEN** the implementation is grep'd, **THEN** `distance_squared_to` is used (not `distance_to`) AND range comparisons use `range * range` (not `sqrt(d_squared) > range`). Validates the Formula 3 optimization is in place.

### AC group: Tiebreak determinism

**AC-10** **GIVEN** two enemies at exactly the same `global_position`, both in range, **WHEN** `_find_nearest_enemy()` is called, **THEN** the returned target is the one that appears first in `get_tree().get_nodes_in_group("enemies")` iteration order (deterministic per scene state, but not designer-specified). Acceptable tiebreak for v0.4.

## Open Questions

- **OQ-1** (Centralize Targeting as a service — tech debt): The 4 single-target weapons re-implement `_find_nearest_enemy()` as identical 20-line copies; Thunder Law has its own K-nearest. This violates DRY and increases the risk of inconsistent behavior across weapons (someone fixes a bug in one but not the others). **Resolution candidate**: extract a `Targeting` singleton (AutoLoad) with `find_nearest(origin, range)` and `find_nearest_k(origin, range, k)` methods; refactor all 5 weapons to call it. **Owner**: lead-programmer + systems-designer. **Target**: Weapon System GDD (FT-03) authoring will be the natural fold-in point — refactor Targeting and Weapon System in the same sprint. **Estimated cost**: 1-2 hours refactor + regression test pass.
- **OQ-2** (Spatial partitioning for >200 enemies): linear scan O(N) is fine at v0.4's 100-enemy target, but if future expansions push N higher (Boss summons, large levels), a quadtree or grid would reduce per-query cost from O(N) to O(log N) or O(1) per cell. **Resolution candidate**: profile first; defer until `/perf-profile` shows Targeting in the top 5 hot-paths. **Owner**: performance-analyst. **Target**: Polish phase.
- **OQ-3** (Predictive targeting for fast-moving enemies): currently a projectile fires at the target's current position. For Fox Spirit (`move_speed = 132 px/s`) at high range, the enemy may move out of the projectile's path before impact. Should Targeting compute an intercept point? **Resolution candidate**: too complex for MVP; revisit if playtest shows "Flying Sword feels inconsistent vs Fox Spirit." **Owner**: systems-designer + qa-lead. **Target**: post-v0.4 playtest report.
- **OQ-4** (Threat-priority targeting): "always attack nearest" is the simplest policy; alternatives include "attack lowest-HP first" (kill weak enemies quickly), "attack highest-DPS-threat first" (kill priority enemies). **Resolution candidate**: defer until upgrade pool offers a "Tactical Targeting" upgrade that re-prioritizes; design intent: keep MVP simple, complexity is upgrade content. **Owner**: game-designer. **Target**: post-v0.5 (after Elements GDD).
- **OQ-5** (Line-of-sight for future indoor levels): v0.4 is open arena; future cave / temple levels may have walls. Should Targeting respect LOS? **Resolution candidate**: yes, but only when first wall-based level is designed. Use raycast against collision layer "obstacles". **Owner**: level-designer + systems-designer. **Target**: Level Design GDD updates for first wall-containing level.

---

## Registry Updates Recorded

This GDD adds no new entries to `design/registry/entities.yaml` — Targeting is implementation infrastructure under Combat, not a content-bearing system. The `"enemies"` group name is a project-level constant defined by Enemy.tscn (canonical owner) and consumed here (constant-style usage; could be registered as a constant in `entities.yaml` if cross-system value-consistency matters).

**Cross-doc consistency**:
- Combat GDD line 386 "Targeting | Hard | Combat depends on | `find_nearest(position, range)` and `find_in_radius(position, radius)`" ✅ (note: Combat says `find_in_radius` — that's the Bagua's radius pattern, which this GDD calls out as NOT using Targeting service; should reconcile in future revision)
- Enemy GDD (Approved) — verify Enemy.tscn declares `groups=["enemies"]` ✅ (confirmed in scene)
- Player GDD line 271 "Targeting (C-05) | Hard | Combat depends on | `find_nearest(position, range)` and `find_in_radius(position, radius)`" — same as Combat reference ✅

## Revision Log

| Revision | Date | Trigger | Summary |
|---|---|---|---|
| 0 | 2026-05-25 | Initial reverse-doc by /design-system | First pass authored from per-weapon targeting patterns: 4× `_find_nearest_enemy()` (talisman/flying_sword/explosive_talisman/mountain_seal) + 1× `_find_nearest_targets()` (thunder_law) + 1× non-targeting radius pattern (bagua_array). 8 required CCGS sections + Open Questions + Registry Updates. **Honest finding**: no centralized Targeting service exists in v0.4 — code is duplicated across 4 weapons. OQ-1 tracks the refactor; the GDD's contract is the eventual service API. 10 ACs cover single-target, K-nearest, type guards, distance² optimization, tiebreak determinism. |
