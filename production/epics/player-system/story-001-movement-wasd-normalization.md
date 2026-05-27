# Story 001: Player Movement (WASD + Normalization)

> **Epic**: Player System | **Status**: Ready | **Layer**: Core | **Type**: Logic | **Estimate**: S (1-2 hours)
> **Manifest Version**: 2026-05-25.1 | **Last Updated**: 2026-05-27

## Context

**GDD**: `design/gdd/player-system.md`
**Requirement**: `TR-core-001` (manual movement)
**ADR Governing Implementation**: ADR-0001 (Godot 4.x + GDScript). **Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Use `Input.get_action_strength()` (analog-safe); `CharacterBody2D.move_and_slide()` for collision sliding.

**Control Manifest Rules (Core Layer)**:
- Required: Player movement uses `move_up/down/left/right` Input actions (no hardcoded keys)
- Forbidden: `Input.is_action_pressed()` polling in `_process()` for one-shot events — use `_input(event)` instead (this story uses continuous polling in `_physics_process` which IS the correct pattern for movement)

---

## Acceptance Criteria

- [ ] **AC-01**: `move_speed = 180, speed_multiplier = 1.0`, `move_right` held 1.0s → x-displacement = 180 px (±5 px tolerance)
- [ ] **AC-02**: Same defaults, `move_up + move_right` held 1.0s → magnitude = 180 px (NOT 254 px — normalization prevents diagonal speed boost)
- [ ] **AC-03**: Player against collision boundary → slides along wall via `move_and_slide()` (engine-provided)

## Implementation Notes

Per Combat GDD Formula 1:
```gdscript
func _physics_process(delta: float) -> void:
    if _is_dead: return
    var input_vec := Vector2(
        Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
        Input.get_action_strength("move_down")  - Input.get_action_strength("move_up")
    )
    var direction := input_vec.normalized() if input_vec.length() > 0 else Vector2.ZERO
    velocity = direction * move_speed * speed_multiplier
    move_and_slide()
```
**Critical**: `.normalized()` MUST run before scaling — prevents diagonal speed bug (1.414× boost).

## Out of Scope

- Camera follow (Camera epic — child node inheritance handles it automatically)
- `speed_multiplier` from status effects (Status Effects epic)
- DEFEATED state lock (Story 002)

## QA Test Cases

**AC-01**: Pure-axis movement
- Given: Player at (0,0); `move_speed = 180`; mock `Input.get_action_strength("move_right") = 1.0`, others = 0
- When: 60 `_physics_process` ticks at 1/60s delta (1.0s)
- Then: `position.x ≈ 180.0` (±5 px) AND `position.y == 0`
- Edge cases: speed_multiplier = 0 → no movement; analog stick value = 0.5 → half speed

**AC-02**: Diagonal normalization
- Given: Player at (0,0); both `move_right` and `move_up` strength = 1.0
- When: 60 ticks (1.0s)
- Then: `position.length() ≈ 180.0` (NOT 254.5); position is approximately (127.3, -127.3)
- Edge cases: All 4 directions held simultaneously → input_vec = (0,0) → no movement

**AC-03**: Wall collision slide
- Given: Player at (50, 0); wall at x=100 (StaticBody2D); `move_right` held
- When: Player advances into wall, then `move_up` added
- Then: Player stops at x=100 (wall blocks) but slides up the wall when up added (move_and_slide handles)
- Edge cases: Two walls forming corner → player stops; smooth wall → slides

## Test Evidence

**Required**: `tests/unit/player/movement_test.gd` — must exist and pass.
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Input epic (action map must be defined)
- Unlocks: All other Player stories (movement is foundational behavior)
