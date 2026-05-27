# Story 003: Demon Seal Spawn + Pressure Mode

> **Epic**: Run State | **Status**: Ready | **Layer**: Foundation | **Type**: Integration | **Estimate**: M

## Context

**GDD**: `design/gdd/run-state.md` + `design/gdd/demon-seal.md` (r1)
**Requirement**: TR-core-006 (Demon seal 8s seal process with risk events)
**ADR**: ADR-0001 | **Risk**: MEDIUM (multi-system: Stage Director ↔ Demon Seal ↔ Spawner + OQ-4 known defect tracked)

## Acceptance Criteria

- [ ] **AC-07**: At `elapsed_time = 120.0` → DemonSeal instantiated at random angle, distance 200-280 px from Player → `demon_seal_spawned(seal)` emit (one-shot)
- [ ] **AC-08**: Player enters seal → `_set_demon_seal_pressure_active(true)` → next `_apply_current_wave_config(force_apply=true)` applies multipliers (interval × 0.65, max + 6)
- [ ] **AC-09**: Player exits OR seal completes → `_set_demon_seal_pressure_active(false)` → next config re-applies WITHOUT multipliers
- [ ] **AC-10**: Seal completes → 8 ExperienceOrbs spawn in 54-px ring at seal position (each `xp_value = 6.0`); seal `queue_free`'d AND `demon_seal_completed(seal)` emits

## Implementation Notes

Per Run State GDD Rule 6 + Demon Seal GDD r1:
```gdscript
signal demon_seal_spawned(seal)
signal demon_seal_progress_changed(progress, required, is_sealing)
signal demon_seal_completed(seal)

@export var demon_seal_spawn_time: float = 120.0
@export var demon_seal_min_spawn_distance: float = 200.0
@export var demon_seal_max_spawn_distance: float = 280.0
@export var demon_seal_pressure_interval_multiplier: float = 0.65
@export var demon_seal_pressure_max_enemy_bonus: int = 6
@export var demon_seal_reward_orb_count: int = 8
@export var demon_seal_reward_orb_xp: float = 6.0
@export var demon_seal_reward_orb_radius: float = 54.0

var _is_demon_seal_pressure_active: bool = false
var _demon_seal_spawned: bool = false

func _process(delta: float) -> void:
    # ... clock code from Story 001 ...
    if not _demon_seal_spawned and elapsed_time >= demon_seal_spawn_time:
        _spawn_demon_seal()

func _spawn_demon_seal() -> void:
    _demon_seal_spawned = true
    var seal = demon_seal_scene.instantiate()
    var angle := randf() * TAU
    var distance := randf_range(demon_seal_min_spawn_distance, demon_seal_max_spawn_distance)
    seal.global_position = _player.global_position + Vector2.RIGHT.rotated(angle) * distance
    get_tree().current_scene.add_child(seal)
    seal.seal_progress_changed.connect(_on_demon_seal_progress_changed)
    seal.seal_completed.connect(_on_demon_seal_completed)
    demon_seal_spawned.emit(seal)

func _on_demon_seal_progress_changed(progress, required, is_sealing) -> void:
    if _is_stage_failed or _is_stage_cleared: return  # OQ-4 partial fix
    _set_demon_seal_pressure_active(is_sealing)
    demon_seal_progress_changed.emit(progress, required, is_sealing)

func _on_demon_seal_completed(seal) -> void:
    if _is_stage_failed or _is_stage_cleared: return  # OQ-4 full fix per /review-all-gdds C-B1 mirror
    _set_demon_seal_pressure_active(false)
    for i in demon_seal_reward_orb_count:
        var orb = experience_orb_scene.instantiate()
        var ring_angle := TAU * float(i) / float(demon_seal_reward_orb_count)
        orb.global_position = seal.global_position + Vector2.RIGHT.rotated(ring_angle) * demon_seal_reward_orb_radius
        orb.xp_value = demon_seal_reward_orb_xp
        get_tree().current_scene.add_child(orb)
    demon_seal_completed.emit(seal)

func _set_demon_seal_pressure_active(active: bool) -> void:
    if _is_demon_seal_pressure_active == active: return
    _is_demon_seal_pressure_active = active
    _apply_current_wave_config(true)
```

**OQ-4 closure** (per /review-all-gdds + S1/S3 scenario walkthroughs): the `if _is_stage_failed or _is_stage_cleared: return` guard at top of `_on_demon_seal_completed` prevents the 8-XP-orbs-spawn-around-corpse defect that Demon Seal GDD r1 tracked.

## QA Test Cases

**AC-07**: Seal spawn at 2:00
- Given: StageDirector with `_demon_seal_spawned = false`
- When: `elapsed_time` crosses 120.0
- Then: DemonSeal instance added to scene tree AND position is at random angle, distance ∈ [200, 280] from Player AND `demon_seal_spawned.emit(seal)` called once

**AC-08**: Pressure activation
- Given: Seal active; Player enters seal radius (`seal_progress_changed(0.5, 8.0, true)`)
- When: `_on_demon_seal_progress_changed` runs
- Then: `_is_demon_seal_pressure_active == true` AND `apply_wave_config` called with interval × 0.65 AND max + 6

**AC-09**: Pressure deactivation
- Given: Pressure active; Player exits seal (`seal_progress_changed(2.0, 8.0, false)`)
- When: Handler runs
- Then: `_is_demon_seal_pressure_active == false` AND next `apply_wave_config` uses BASE interval/max (no multipliers)

**AC-10**: Reward orbs on completion
- Given: Seal completes (`seal_completed(seal)`)
- When: `_on_demon_seal_completed` fires AND NOT (`_is_stage_failed` OR `_is_stage_cleared`)
- Then: 8 orbs spawned in 54-px ring AND each `xp_value == 6.0` AND `demon_seal_completed` emits
- Edge (OQ-4 closure): If `_is_stage_failed = true` (player died first) OR `_is_stage_cleared = true` (Boss died first) → handler early-returns, NO orbs spawn (closes the defect)

## Test Evidence
`tests/integration/run-state/demon_seal_test.gd`

## Dependencies
- Depends on: Story 001, 002
- Cross-coordinates: Demon Seal GDD r1 (seal Area2D itself), Experience epic (orb)
