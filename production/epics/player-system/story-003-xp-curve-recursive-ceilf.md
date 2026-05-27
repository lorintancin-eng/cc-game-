# Story 003: XP Curve (Recursive Ceilf Formula 3)

> **Epic**: Player System | **Status**: Ready | **Layer**: Core | **Type**: Logic | **Estimate**: M (2-3 hours — recursive ceil accumulation is subtle)
> **Manifest Version**: 2026-05-25.1 | **Last Updated**: 2026-05-27

## Context

**GDD**: `design/gdd/player-system.md`
**Requirement**: TR-core-001 (XP progression — Player-owned)
**ADR Governing Implementation**: ADR-0001. **Engine**: Godot 4.6 | **Risk**: MEDIUM (formula NOT closed-form; recursive `ceilf` accumulation can drift if implemented as `f(level)` shortcut).
**Engine Notes**: Use `ceilf()` from Godot 4.x; do NOT use `pow()` for closed-form alternatives — recursion is required.

**Control Manifest Rules (Core Layer)**:
- Required: Typed GDScript throughout (function return types declared)

---

## Acceptance Criteria

- [ ] **AC-09**: Player at level 1, `current_xp = 0`, defaults (x₀=18, μ=1.28, δ=6) → `gain_experience(18)` → `level_reached(2)` emit AND `current_xp` rolls to 0 AND `experience_changed(0, 30, 2)` emit. **The threshold for L2→L3 is 30** (NOT 29.04 — Formula 3 applies ceilf to `18 × 1.28 + 6 = 29.04` → 30).

## Implementation Notes

Per Player GDD Formula 3 (recursive, ceilf-clamped):
```gdscript
@export var initial_xp_to_next_level: float = 18.0
@export var xp_growth_multiplier: float = 1.28
@export var xp_growth_flat: float = 6.0

func xp_to_next_level(level: int) -> float:
    var threshold := initial_xp_to_next_level  # base case L1→L2
    for L in range(2, level + 1):
        var main_calc := threshold * maxf(xp_growth_multiplier, 1.0) + maxf(xp_growth_flat, 0.0)
        var floor_calc := threshold + 1.0  # strict monotonic
        threshold = ceilf(maxf(main_calc, floor_calc))
    return threshold
```

**Why recursive (revision-1 B-1 fix)**: every `ceilf()` truncation accumulates. Closed-form `f(level) = x0 × μ^(L-1) + δ × (L-1)` is off by 1 XP at L=2 and 43% at L=10 (358 actual vs 250 closed-form).

**Verified expected values (from code path)**:
| L→L+1 | Threshold | Computation |
|---|---|---|
| 1→2 | 18 | base case |
| 2→3 | 30 | ceil(18×1.28 + 6) = ceil(29.04) = 30 |
| 3→4 | 45 | ceil(30×1.28 + 6) = ceil(44.4) = 45 |
| 5→6 | 88 | (chain) |
| 10→11 | 358 | (recursive accumulation) |

## Out of Scope

- XP gain mechanics + multi-level cascade (Story 004)
- DEFEATED-state suppression (Story 004 — moved there with carry-over logic)
- XP orb spawn on enemy death (Experience epic)

## QA Test Cases

**AC-09**: Level 1→2 with exactly-threshold XP
- Given: Player `level = 1, current_xp = 0`; defaults x₀=18, μ=1.28, δ=6
- When: `gain_experience(18.0)`
- Then: `level == 2` AND `current_xp == 0` (18 consumed) AND `level_reached.emit(2)` called once AND `experience_changed.emit(0.0, 30.0, 2)` emit
- Edge: gain_experience(17.99) → no level up, `experience_changed(17.99, 18.0, 1)`; gain_experience(36) → L2 (18 consumed) → L3 (30 needed); since 36-18=18 < 30, finishes at L2 with 18 XP

**Recursive ceil accumulation regression**:
- Given: Same defaults
- When: `xp_to_next_level(L)` called for L = 2, 3, 4, 5, 6, 7, 8, 9, 10, 11
- Then: Returns exactly [18, 30, 45, 64, 88, 119, 159, 210, 275, 358]
- Edge: μ = 1.0 (linear case) → growth purely additive (18, 24, 30, 36, ...); μ = 0.9 (negative growth) → clamped to 1.0 by `maxf(μ, 1.0)` so still positive

**Edge: strict-monotonic floor activation**
- Given: μ = 1.0, δ = 0 (no growth)
- When: `xp_to_next_level(2)` evaluates
- Then: `main_calc = 18.0 × 1.0 + 0 = 18.0`; `floor_calc = 18.0 + 1.0 = 19.0` → ceil(max(18, 19)) = 19 (floor activates)

## Test Evidence
**Required**: `tests/unit/player/xp_curve_test.gd` — must exist and pass
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Story 001 (Player base)
- Unlocks: Story 004 (gain_experience consumes this formula)
