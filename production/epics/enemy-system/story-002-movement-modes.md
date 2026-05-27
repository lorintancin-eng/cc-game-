# Story 002: Movement Modes (CHASE + WAVE_CHASE)

> **Epic**: Enemy System | **Status**: Ready | **Layer**: Core | **Type**: Logic | **Estimate**: M

## Context

**GDD**: `design/gdd/enemy-system.md` (r1) | **Requirement**: TR-enemy-001
**ADR**: ADR-0001 | **Risk**: LOW

## Acceptance Criteria

- [ ] **AC-05**: Enemy with `movement_mode = CHASE` → velocity = direction-to-player × move_speed (straight line)
- [ ] **AC-06**: Enemy with `movement_mode = WAVE_CHASE` (e.g. Ghost Flame) → velocity = chase + perpendicular sine offset based on `wave_amplitude, wave_frequency, wave_phase`
- [ ] **AC-07**: Both modes use `move_and_slide()` for collision

## Implementation Notes

Per GDD Detailed Rules + entities.yaml ghost_flame:
```gdscript
enum MovementMode { CHASE, WAVE_CHASE }

func _physics_process(delta: float) -> void:
    if _is_dead or _player == null:
        return
    var chase_direction := global_position.direction_to(_player.global_position)
    if movement_mode == MovementMode.CHASE:
        velocity = chase_direction * move_speed
    elif movement_mode == MovementMode.WAVE_CHASE:
        _movement_time += delta
        var perpendicular := Vector2(-chase_direction.y, chase_direction.x)
        var offset := perpendicular * sin(_movement_time * wave_frequency + wave_phase) * wave_amplitude
        velocity = (chase_direction * move_speed) + offset
    move_and_slide()
```

## QA Test Cases

**AC-05**: CHASE direct line
- Given: Enemy with `movement_mode = CHASE, move_speed = 90`; Player at (100, 0); Enemy at (0, 0)
- When: 1 second of `_physics_process` at 60 FPS
- Then: Enemy position has advanced ~90 px toward (100, 0) (within frame discretization tolerance)

**AC-06**: WAVE_CHASE sinusoidal offset
- Given: Ghost Flame archetype (`wave_amplitude = 30, wave_frequency = 4.0, wave_phase = 0`)
- When: Multiple frames simulated
- Then: Enemy oscillates perpendicular to chase vector with peak offset ≈ 30 px AND period = 2π/4 ≈ 1.57s

**AC-07**: Collision sliding
- Given: Enemy chasing player through a wall
- When: Enemy hits wall
- Then: Enemy slides along wall (move_and_slide engine behavior)

## Test Evidence
`tests/unit/enemy/movement_modes_test.gd`

## Dependencies
- Depends on: Story 001
