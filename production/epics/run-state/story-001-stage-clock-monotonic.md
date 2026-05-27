# Story 001: Stage Clock + Monotonic Progression

> **Epic**: Run State | **Status**: Ready | **Layer**: Foundation | **Type**: Logic | **Estimate**: S
> **Manifest Version**: 2026-05-25.1 | **Last Updated**: 2026-05-27

## Context

**GDD**: `design/gdd/run-state.md` (r2 after C-B1 reframing) | **Requirement**: TR-core-002
**ADR**: ADR-0001 | **Risk**: LOW

**Note (C-B1 resolution)**: Run State GDD is the lifecycle view; Stage Director GDD is canonical implementation. Both describe the SAME StageDirector node. Story implements the StageDirector node clock per Stage Director GDD's contracts.

## Acceptance Criteria

- [ ] **AC-01**: Stage starts → `elapsed_time = 0.0` AND `stage_time_changed(0.0, 300.0)` emits at `_ready()`
- [ ] **AC-02**: Every frame (when not terminal) → `elapsed_time += delta` clamped to `stage_duration (300.0)` AND `stage_time_changed(elapsed_time, stage_duration)` emits
- [ ] **AC-03**: After `_is_stage_cleared` OR `_is_stage_failed` → `_process()` early-returns; no further `stage_time_changed` emits

## Implementation Notes

Per Stage Director GDD Formula 1:
```gdscript
class_name StageDirector extends Node

signal stage_time_changed(elapsed_time: float, stage_duration: float)

const MIN_STAGE_DURATION: float = 1.0

@export var stage_duration: float = 300.0  # 5 minutes

var elapsed_time: float = 0.0
var _is_stage_cleared: bool = false
var _is_stage_failed: bool = false

func _ready() -> void:
    stage_duration = maxf(stage_duration, MIN_STAGE_DURATION)
    stage_time_changed.emit(elapsed_time, stage_duration)

func _process(delta: float) -> void:
    if _is_stage_cleared or _is_stage_failed: return
    elapsed_time = minf(elapsed_time + delta, stage_duration)
    stage_time_changed.emit(elapsed_time, stage_duration)
```

## QA Test Cases

**AC-01**: Initial emit
- Given: StageDirector instantiated in Main scene
- When: `_ready()` runs
- Then: `elapsed_time == 0.0` AND `stage_time_changed.emit(0.0, 300.0)` called once

**AC-02**: Monotonic clock
- Given: StageDirector active for 1 second at 60 FPS
- Then: `elapsed_time ≈ 1.0` (within frame discretization)

**AC-03**: Terminal early-return
- Given: `_is_stage_failed = true`
- When: `_process(0.016)` runs
- Then: `elapsed_time` UNCHANGED AND `stage_time_changed` NOT emit

## Test Evidence
`tests/unit/run-state/stage_clock_test.gd`

## Dependencies
- None — foundation story
