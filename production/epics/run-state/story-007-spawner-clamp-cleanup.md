# Story 007: Spawner State Clamps + Cleanup

> **Epic**: Run State | **Status**: Ready | **Layer**: Foundation | **Type**: Logic | **Estimate**: S

## Context

**GDD**: `design/gdd/run-state.md` | **Requirement**: TR-core-002
**ADR**: ADR-0001 | **Risk**: LOW

## Acceptance Criteria

- [ ] **AC-20**: All stage parameter exports clamped in `_ready()`:
  - `stage_duration ≥ MIN_STAGE_DURATION (1.0s)`
  - `boss_warning_lead_time ∈ [0, stage_duration]`
  - `demon_seal_spawn_time ∈ [0, stage_duration]`
  - `boss_spawn_distance ≥ MIN_SPAWN_DISTANCE (80)`
- [ ] **AC-21**: `apply_wave_config` skipped while `_is_boss_spawned` (Boss phase locks spawner)
- [ ] **AC-22**: Empty wave pool → spawner falls back to default (defensive layer per Run State Edge Case)

## Implementation Notes

Per Run State GDD Rules 7 + 8 + Edge Cases:
```gdscript
const MIN_STAGE_DURATION: float = 1.0
const MIN_SPAWN_DISTANCE: float = 80.0

func _ready() -> void:
    stage_duration = maxf(stage_duration, MIN_STAGE_DURATION)
    boss_warning_lead_time = clampf(boss_warning_lead_time, 0.0, stage_duration)
    demon_seal_spawn_time = clampf(demon_seal_spawn_time, 0.0, stage_duration)
    boss_spawn_distance = maxf(boss_spawn_distance, MIN_SPAWN_DISTANCE)
    # ... other clamps ...

func _apply_current_wave_config(force_apply: bool = false) -> void:
    if _is_boss_spawned and not force_apply:
        return  # AC-21: Boss phase locks normal wave-config application
    # ... rest of method
```

## QA Test Cases

**AC-20**: Defensive clamps
- Given: StageDirector with `stage_duration = 0.0` (typo) in `.tscn` export
- When: `_ready()` runs
- Then: `stage_duration == 1.0` (clamped)
- Edge: All export values set to typo values → all clamped silently

**AC-21**: Boss phase spawner lock
- Given: `_is_boss_spawned = true`; phase boundary crossed at 300s+
- When: `_apply_current_wave_config()` invoked
- Then: Method early-returns; spawner config NOT changed (Boss-phase pressure clamp from Story 005 holds)

**AC-22**: Empty pool fallback
- Given: Wave config with empty `pool` array
- When: `apply_wave_config` called
- Then: Enemy Spawner uses its own internal default pool (defensive layer per Enemy Spawning GDD Edge Cases)

## Test Evidence
`tests/unit/run-state/clamps_cleanup_test.gd`

## Dependencies
- Depends on: Stories 001-005
