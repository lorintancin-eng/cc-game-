# Story 006: Run-End Signals (stage_cleared + stage_failed)

> **Epic**: Run State | **Status**: Ready | **Layer**: Foundation | **Type**: Logic | **Estimate**: S

## Context

**GDD**: `design/gdd/run-state.md` | **Requirement**: TR-run-001 + TR-enemy-003
**ADR**: ADR-0001 | **Risk**: LOW

## Acceptance Criteria

- [ ] **AC-16**: Boss `died` signal received → `_is_stage_cleared = true` AND `stage_cleared(elapsed_time)` emits ONCE AND `EnemySpawner.set_spawning_enabled(false)` called
- [ ] **AC-17**: Player `died` signal received → `_is_stage_failed = true` AND `stage_failed(elapsed_time)` emits ONCE AND demon seal pressure released
- [ ] **AC-18**: Both signals are terminal — `_process` early-returns after either fires (per Story 001 AC-03)
- [ ] **AC-19**: If Player dies on same frame as Boss → `stage_failed` wins (terminal-flag guard prevents double-fire)

## Implementation Notes

```gdscript
signal stage_cleared(elapsed_time: float)
signal stage_failed(elapsed_time: float)

func _ready() -> void:
    # ... existing setup ...
    _player.died.connect(_on_player_died)

func _on_boss_died(payload) -> void:
    if not payload.is_boss: return  # safety guard
    if _is_stage_failed: return     # AC-19: stage_failed wins race
    if _is_stage_cleared: return    # already cleared
    _is_stage_cleared = true
    stage_cleared.emit(elapsed_time)
    enemy_spawner.set_spawning_enabled(false)

func _on_player_died() -> void:
    if _is_stage_cleared: return    # already won
    if _is_stage_failed: return     # double-fire guard
    _is_stage_failed = true
    _set_demon_seal_pressure_active(false)
    stage_failed.emit(elapsed_time)
```

## QA Test Cases

**AC-16**: Boss death → stage_cleared
- Given: StageDirector with `_is_stage_cleared = false, _is_stage_failed = false`
- When: Boss `died.emit({is_boss: true, ...})` fires
- Then: `_is_stage_cleared == true` AND `stage_cleared.emit(elapsed_time)` once AND `enemy_spawner.set_spawning_enabled(false)` called

**AC-17**: Player death → stage_failed
- Given: Same initial state
- When: Player `died.emit()` fires
- Then: `_is_stage_failed == true` AND `stage_failed.emit(elapsed_time)` once AND `_is_demon_seal_pressure_active = false`

**AC-18**: Terminal early-return (mirror of Story 001 AC-03)
- Given: `_is_stage_failed = true`
- When: `_process(0.016)` runs
- Then: `elapsed_time` UNCHANGED AND no clock signals fire

**AC-19**: Race condition — stage_failed wins
- Given: Both Player and Boss die on same frame
- When: `_on_player_died()` AND `_on_boss_died()` both invoked (any order)
- Then: First to fire sets its terminal flag; second fires sees the flag → early-returns; only one of `stage_cleared` OR `stage_failed` emits

## Test Evidence
`tests/unit/run-state/run_end_signals_test.gd`

## Dependencies
- Depends on: Story 001 (terminal-flag guards)
- Cross-coordinates: Combat epic Story 010 (Boss died signal source); Player epic Story 002 (Player died signal source)
