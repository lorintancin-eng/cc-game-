# Story 011: Reserved Placeholders + Performance Budget

> **Epic**: Combat System
> **Status**: Ready (partial — AC-21 + AC-22 are "no-op today, activate when downstream lands")
> **Layer**: Core
> **Type**: Integration
> **Estimate**: M (2-3 hours — perf budget verification is the bulk; reserved AC tests are 30 min)
> **Manifest Version**: 2026-05-25.1
> **Last Updated**: 2026-05-27

## Context

**GDD**: `design/gdd/combat-system.md`
**Requirement**: `TR-core-005` (60 FPS sustained @ 50-100 enemies), `TR-wpn-002` (damage type pipeline ordering)

**ADR Governing Implementation**: ADR-0001: Godot 4.x + GDScript
**ADR Decision Summary**: Performance budget per `.claude/docs/technical-preferences.md` §Performance Budgets — 60 FPS sustained, 16.67 ms frame budget; 30 FPS minimum for Boss-fight edge case.

**Engine**: Godot 4.6 | **Risk**: MEDIUM (perf testing requires representative scene load — Boss + summons + 100+ enemies + 200+ projectiles per Combat GDD Pillar 3 worst case)
**Engine Notes**: Use `Engine.get_frames_per_second()` for FPS sampling; capture `Engine.get_main_loop().root.get_tree().get_node_count_in_group("enemies")` for enemy count assertion.

**Control Manifest Rules (Core Layer)**:
- Guardrail: Performance budget 60 FPS sustained, 16.67 ms frame budget (per technical-preferences.md)
- Guardrail: Aggregate DPS ceiling (Story 008) is the primary protection against perf degradation under contact saturation

---

## Acceptance Criteria

*From GDD `design/gdd/combat-system.md` reserved placeholders + TR-core-005:*

- [ ] **AC-21** (no-op today; activates when Active Skills GDD lands): `raw_damage = 10, source_modifier = 1.5, crit_multiplier = 1.2, element_modifier = 1.0, pierce_falloff = 1.0` → `final_damage = 10 × 1.5 × 1.2 = 18.0` (NOT 10 × 1.2 × 1.5 — order is `raw → source_mod → crit → element → pierce`). Test must remain green when Active Skills' 火眼金睛 lands with `crit_multiplier = 1.2`.
- [ ] **AC-22** (no-op today; activates when VFX GDD lands): Enemy emits `died(payload)` at `t = X` → at `t = X + 0.5`, enemy node has been removed from scene tree (`queue_free()` completed). Per VFX GDD r1 contract: VFX subscribes, plays dissolve, calls `enemy.queue_free()` after ≤0.5s.
- [ ] **TR-core-005 perf budget**: Simulate Boss + 100 enemies + 200 projectiles for 5 seconds → average FPS ≥ 60 (or ≥ 30 in worst-case Boss-fight scenarios per technical-preferences.md)

---

## Implementation Notes

*Per Combat GDD AC-21 / AC-22 / OQ-5 + technical-preferences.md Performance Budgets:*

### AC-21 (damage pipeline order test)

Implement Formula 1 pipeline as discrete multiplication chain (NOT a generic `apply_all_modifiers(args[])` that loses order):

```gdscript
func compute_final_damage(raw: float, source_mod: float, crit: float, elem: float, pierce: float) -> float:
    # Pipeline order is LOCKED — non-commutative-safe ordering for future saturating-arithmetic math
    return raw * source_mod * crit * elem * pierce
```

For v0.4 baseline: `crit`, `elem`, `pierce` all default to 1.0 — the test passes trivially. When Active Skills GDD's 火眼金睛 lands with `crit = 1.2`, the test must still pass with the same formula (no reorder).

### AC-22 (visual-death timing)

Already partially implemented via Story 003 (enemy emits `died` but does NOT call queue_free). The VFX subscriber side will land with VFX GDD implementation. For now:

```gdscript
# Test stub VFX subscriber (lives in tests/helpers/, not production code):
class_name StubVFXSubscriber
extends Node

func _on_enemy_died(payload: Dictionary) -> void:
    var enemy = payload.enemy
    if is_instance_valid(enemy):
        await get_tree().create_timer(0.5).timeout
        if is_instance_valid(enemy):
            enemy.queue_free()
```

Test asserts: at t=X+0.5 (±1 frame), enemy is no longer in scene tree.

### TR-core-005 (performance budget)

Build a test fixture scene:
- 1 Boss instance
- 100 Wandering Soul instances in random positions
- 200 active projectile instances (Talisman or Flying Sword)
- Run for 5 seconds (300 frames at 60 FPS target)
- Assert: average FPS ≥ 60 OR worst-frame time ≤ 33.3 ms (Boss-fight edge case)

Use `tests/integration/combat/perf_budget_test.gd` (GUT supports `before_each`/`after_each` for scene setup).

---

## Out of Scope

- Active Skills GDD implementation (separate epic — Story 011 only validates that Combat's pipeline order is preserved for it)
- VFX GDD implementation (separate epic — Story 011 only validates Combat's death-timing budget hook)
- D-B1 HP/damage balance decision (playtest in progress)

---

## QA Test Cases

**AC-21**: Damage pipeline order
- **Given**: `compute_final_damage(raw=10, source_mod=1.5, crit=1.2, elem=1.0, pierce=1.0)` (Active Skills 火眼金睛 future scenario)
- **When**: Formula 1 pipeline applies
- **Then**: Result is exactly `18.0` (= 10 × 1.5 × 1.2 × 1.0 × 1.0); NOT 18.0 reached via a different order that would matter under future non-commutative math (e.g. saturating clamp at 15 mid-pipeline)
- **Edge cases**: All multipliers = 1.0 (v0.4 baseline) → result equals raw; `raw = 0` → result = 0; negative multipliers (impossible from `.tres` validation but defensive) → defined behavior is multiplication-with-clamp

**AC-22**: Visual-death timing budget (with stub VFX subscriber)
- **Given**: Enemy at `current_hp = 5`; StubVFXSubscriber connected to `Enemy.died`
- **When**: `Enemy.take_damage(10)` fires at t=X
- **Then**: `died(payload)` emits within 1 frame of t=X AND enemy node IS still in scene tree at t=X+0.4 (within VFX dissolve window) AND enemy node IS NOT in scene tree at t=X+0.5+ε (queue_free completed)
- **Edge cases**: VFX subscriber never connected → enemy lingers forever (memory leak) → this AC failing in production means VFX wiring is broken; multiple subscribers → only one should call queue_free (use `is_instance_valid` guard)

**TR-core-005**: 60 FPS @ 100 enemies + 200 projectiles
- **Given**: Test scene with 1 Boss + 100 Wandering Souls in random positions within 1000px × 1000px area + 200 active Talisman projectiles
- **When**: Scene runs for 5 seconds (frame-by-frame `_physics_process` and `_process`)
- **Then**: Average FPS ≥ 60 (Engine.get_frames_per_second() averaged over 300 frames) OR worst-case 95th-percentile frame time ≤ 33.3 ms (Boss-fight edge case per technical-preferences.md "30 FPS minimum acceptable for Boss-fight edge case")
- **Edge cases**: Mid-range PC vs CI runner perf disparity → set CI threshold at 30 FPS sustained (not 60 — CI typically slower); manual playtest on target hardware (mid-range GTX 1060 / RX 580 class) must hit 60 FPS

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/unit/combat/damage_pipeline_order_test.gd` (AC-21)
- `tests/integration/combat/visual_death_timing_test.gd` (AC-22, with StubVFXSubscriber)
- `tests/integration/combat/perf_budget_test.gd` (TR-core-005)
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Stories 001-010 (this is the integration / perf-validation capstone for the Combat epic)
- Unlocks: `/gate-check pre-production` for Combat epic (Definition of Done validation)

---

## Notes

This is the **capstone story** for the Combat epic — closing it requires the entire epic's logic to be in place. AC-21 and AC-22 are explicitly reserved ACs that "activate" when downstream Active Skills / VFX GDDs are implemented; they are tested today using default values + stub subscribers but their full validation deepens as those epics ship.

The performance budget (TR-core-005) is the engineering quality gate: if this fails, the project cannot ship at 60 FPS and either (a) GDExtension is needed for hot paths (per ADR-0001 §Performance Implications re-evaluation triggers), OR (b) the entity counts in `design/gdd/03_CORE_GAMEPLAY.md` §13 must be revised down.
