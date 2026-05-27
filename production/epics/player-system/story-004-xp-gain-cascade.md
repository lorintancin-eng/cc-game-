# Story 004: XP Gain + Multi-Level Cascade + DEFEATED Suppression

> **Epic**: Player System | **Status**: Ready | **Layer**: Core | **Type**: Logic | **Estimate**: M (2-3 hours)
> **Manifest Version**: 2026-05-25.1 | **Last Updated**: 2026-05-27

## Context

**GDD**: `design/gdd/player-system.md`
**Requirement**: TR-core-001 (XP progression)
**ADR Governing Implementation**: ADR-0001. **Engine**: Godot 4.6 | **Risk**: LOW.

**Control Manifest Rules (Core Layer)**: Typed signal payloads required.

---

## Acceptance Criteria

- [ ] **AC-10**: Player at L1, `xp_gain_multiplier = 2.0`, `gain_experience(10)` → `effective_amount = 20` AND `current_xp = 2.0` AND `level_reached(2)` emit (effective 20 > threshold 18)
- [ ] **AC-11**: Player at L5, `current_xp = 0`, `gain_experience(150)` → `level_reached(6)` AND `level_reached(7)` emit in order AND Level Up panel queue has 2 pending offers
- [ ] **AC-12**: Player in DEFEATED state (`_is_dead = true`), `gain_experience(50)` → early-returns (`player.gd:140-141`); `current_xp` unchanged AND NO signals fire AND score screen sees pre-death XP
- [ ] **AC-20**: Any XP gain event → `experience_changed` payload exactly `(current_xp: float, xp_to_next_level: float, level: int)` with `current_xp < xp_to_next_level`

## Implementation Notes

Per Player GDD Formula 4 + Edge Case (DEFEATED):
```gdscript
signal experience_changed(current_xp: float, xp_to_next_level: float, level: int)
signal level_reached(level: int)

@export var xp_gain_multiplier: float = 1.0

var current_xp: float = 0.0
var level: int = 1

func gain_experience(amount: float) -> void:
    if _is_dead or amount <= 0.0: return       # AC-12: DEFEATED-state early-return
    var effective_amount := amount * xp_gain_multiplier
    current_xp += effective_amount
    while current_xp >= xp_to_next_level(level):
        current_xp -= xp_to_next_level(level)
        level += 1
        level_reached.emit(level)                # AC-11: per-level emit during cascade
    experience_changed.emit(current_xp, xp_to_next_level(level), level)
```

**Multi-level cascade rule**: Level Up panel handles queue draining (see Level Up Pool epic) — Player just emits `level_reached` per crossed threshold.

## Out of Scope
- XP curve math itself (Story 003 — this story consumes that formula)
- Level Up panel UI / queue management (Level Up Pool epic)
- XP orb pickup (Experience epic — calls gain_experience)

## QA Test Cases

**AC-10**: XP multiplier
- Given: Player `level = 1, current_xp = 0, xp_gain_multiplier = 2.0`
- When: `gain_experience(10.0)`
- Then: `effective_amount = 20.0`; `current_xp = 2.0` (20 consumed = 18 threshold + 2 carry); `level == 2`; `level_reached.emit(2)`
- Edge: multiplier = 0 → no XP gained (early-return on `amount <= 0` after multiplication? — defensive: skip multiplier-zeroes); multiplier negative → defensive clamp at 0

**AC-11**: Multi-level cascade
- Given: Player `level = 5, current_xp = 0`; thresholds L5→L6=88, L6→L7=119, L7→L8=159
- When: `gain_experience(150)` (effective 150 with multiplier=1.0)
- Then: 150 - 88 = 62 carries to L6; 62 < 119 → stops at L6 with current_xp = 62; `level_reached(6)` emit ONCE; `experience_changed(62.0, 119.0, 6)` final emit
- **Worked example with multiplier**: gain_experience(150) with xp_gain_multiplier=2.0 → effective 300 → 300-88=212 → 212-119=93 → 93 < 159 → stops at L7 with 93 XP; `level_reached(6)` AND `level_reached(7)` emit (2 signals)
- Edge: Multiple cascades produce queue in Level Up panel (out of scope here)

**AC-12**: DEFEATED state suppresses XP
- Given: Player `_is_dead = true, current_xp = 23` (from before death)
- When: Player dies and a Boss kill grants 100 XP via `gain_experience(100)`
- Then: Function early-returns at line 140-141 AND `current_xp` stays 23 AND NO `experience_changed` emit AND NO `level_reached` emit AND score screen reads 23 XP (not 23 + 100)
- Edge: gain_experience(-5) → also early-returns (amount <= 0 condition); is_invincible during gain_experience → does NOT bypass (only HP-side cheat)

**AC-20**: Signal payload contract
- Given: Any successful XP gain
- When: `experience_changed` emits
- Then: Payload is `(current_xp: float, xp_to_next_level: float, level: int)` in order AND `current_xp < xp_to_next_level` (because level-up consumes threshold first)

## Test Evidence
**Required**: `tests/unit/player/xp_gain_cascade_test.gd` — must exist and pass
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Story 002 (`_is_dead` flag), Story 003 (xp_to_next_level formula)
- Unlocks: Level Up Pool epic stories
