# Story 002: HP Lifecycle (take_damage + DEFEATED + Signal Payloads)

> **Epic**: Player System | **Status**: Ready | **Layer**: Core | **Type**: Logic | **Estimate**: M (2-3 hours)
> **Manifest Version**: 2026-05-25.1 | **Last Updated**: 2026-05-27

## Context

**GDD**: `design/gdd/player-system.md`
**Requirement**: `TR-core-001` (Player as damage target — Combat-side already in Combat epic Story 002)
**ADR Governing Implementation**: ADR-0001. **Engine**: Godot 4.6 | **Risk**: LOW.

**Control Manifest Rules (Core Layer)**:
- Required: Combat damage applied via signals — never direct property writes
- Required: Player owns its HP write (per Combat GDD Core Rule 3)

---

## Acceptance Criteria

- [ ] **AC-04**: Player at `current_hp = 100`, `take_damage(8)` → `current_hp = 92` AND `health_changed(92, 100)` emits exactly once
- [ ] **AC-05**: Player at `current_hp = 5, is_invincible = false`, `take_damage(50)` → `current_hp = 0` AND `health_changed(0, 100)` emits AND `died()` emits (both same frame, in order)
- [ ] **AC-06**: Player in DEFEATED state (`_is_dead = true`), subsequent `take_damage(20)` → no further signals fire AND `current_hp` stays at 0
- [ ] **AC-07**: Player with `is_invincible = true`, `take_damage(50)` → no HP change AND no signals fire (cheat hook validation)
- [ ] **AC-08**: Player at `current_hp = 50`, `take_damage(0)` → `current_hp` unchanged AND no `health_changed` emit (Combat AC-19 mirror)
- [ ] **AC-19**: Any HP mutation event → `health_changed` payload exactly `(current_hp: float, max_hp: float)` in order, both ≥ 0

## Implementation Notes

Per Player GDD Core Rules 2 + 3 + Formula 2:
```gdscript
signal health_changed(current_hp: float, max_hp: float)
signal died

var current_hp: float = 100.0
var max_hp: float = 100.0
var is_invincible: bool = false
var _is_dead: bool = false

func take_damage(amount: float) -> void:
    if _is_dead: return                    # AC-06: DEFEATED is inert
    if is_invincible: return                # AC-07: cheat hook
    if amount <= 0.0: return                # AC-08: zero-damage no-op
    current_hp = maxf(current_hp - amount, 0.0)
    health_changed.emit(current_hp, max_hp)
    if current_hp == 0.0:
        _is_dead = true
        died.emit()
```

## Out of Scope
- XP gain suppression on DEFEATED (Story 004)
- VFX dissolve (VFX epic — Player does not queue_free per Combat GDD)
- Damage source-side tuple (Combat epic Story 001)

## QA Test Cases

**AC-04**: Standard HP decrement
- Given: Player `current_hp = 100, max_hp = 100, _is_dead = false`
- When: `take_damage(8.0)`
- Then: `current_hp == 92.0` AND `health_changed.emit(92.0, 100.0)` called once
- Edge: take_damage(100) → kills cleanly; take_damage(8.5) → fractional HP supported

**AC-05**: Death event sequence
- Given: Player `current_hp = 5, max_hp = 100`
- When: `take_damage(50.0)`
- Then: In order: `current_hp = 0` → `health_changed(0, 100)` emit → `_is_dead = true` → `died()` emit (same frame)
- Edge: take_damage(5) exactly → still triggers death; take_damage(999) overkill → still single `died` emit

**AC-06**: DEFEATED inert
- Given: Player in `_is_dead = true` state (after AC-05)
- When: `take_damage(20)` invoked subsequently
- Then: `current_hp` stays 0 AND `health_changed` NOT re-emit AND `died` NOT re-emit
- Edge: Multiple damage events on death frame — first triggers, rest dropped

**AC-07**: Invincibility bypass
- Given: Player `current_hp = 100, is_invincible = true`
- When: `take_damage(50)`
- Then: `current_hp == 100` (no change) AND no signal emit
- Edge: `is_invincible` toggled mid-damage → only events while true are bypassed

**AC-08**: Zero-damage no-op (Combat AC-19 mirror)
- Given: Player `current_hp = 50`
- When: `take_damage(0)` or `take_damage(-5)` (defensive)
- Then: `current_hp == 50` AND `health_changed` NOT emit
- Edge: Negative amount → defensive: NO healing (no `take_damage(-5)` heal exploit)

**AC-19**: Signal payload typing
- Given: Any `health_changed` emission from above tests
- When: Signal payload inspected
- Then: Exactly 2 args, both `float`, both ≥ 0, in order `(current_hp, max_hp)`

## Test Evidence
**Required**: `tests/unit/player/hp_lifecycle_test.gd` — must exist and pass
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Story 001 (Player CharacterBody2D foundation)
- Unlocks: Stories 003, 004 (XP/Level depend on `_is_dead` guard)
