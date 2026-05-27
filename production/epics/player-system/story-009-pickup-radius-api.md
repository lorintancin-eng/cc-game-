# Story 009: Pickup Radius API (get_pickup_radius_bonus)

> **Epic**: Player System | **Status**: Ready | **Layer**: Core | **Type**: Logic | **Estimate**: S (1 hour)
> **Manifest Version**: 2026-05-25.1 | **Last Updated**: 2026-05-27

## Context

**GDD**: `design/gdd/player-system.md` + `design/gdd/pickup-system.md`
**Requirement**: TR-core-003 (Pickup auto-collect within radius — Player exposes bonus)
**ADR Governing Implementation**: ADR-0001. **Engine**: Godot 4.6 | **Risk**: LOW.

**Control Manifest Rules**: Player publishes state; UI/Pickup subscribes.

---

## Acceptance Criteria

- [ ] **AC-18**: Player with `CharacterBase.pickup_radius = 50, pickup_radius_bonus = 20` → `Player.get_pickup_radius_bonus()` returns `20` (bonus only — Pickup System reads base radius from CharacterBase separately per FT-12 contract)

## Implementation Notes

Per Player GDD Formula 5:
```gdscript
@export var pickup_radius_bonus: float = 0.0

func get_pickup_radius_bonus() -> float:
    return maxf(pickup_radius_bonus, 0.0)  # clamp at 0 — no negative reach
```

**Note on radius split** (per C-W06 cross-doc warning from /review-all-gdds 2026-05-27):
- Player GDD Formula 5: `effective_pickup_radius = CharacterBase.pickup_radius (50 default) + pickup_radius_bonus`
- Experience GDD Formula 2: `effective_radius = orb.pickup_radius (34) + max(player.get_pickup_radius_bonus(), 0)`
- The two GDDs reference different base values. This story implements ONLY the bonus API exposed by Player. Pickup System (Pickup epic) resolves the base-radius source on the consumer side per OQ-2 in those GDDs.

## Out of Scope
- Pickup System detection / collection logic (Pickup epic)
- Experience orb attraction (Experience epic)
- C-W06 radius reconciliation (cross-doc OQ — separate decision)

## QA Test Cases

**AC-18**: Bonus-only return
- Given: Player with `pickup_radius_bonus = 20.0`
- When: `Player.get_pickup_radius_bonus()` called
- Then: Returns 20.0 (NOT 70.0 — does NOT include base radius)
- Edge: bonus = 0 (default) → returns 0; bonus = -5 (defensive) → clamped to 0 (no negative reach); upgrade applied 5 times (cap) → bonus = 0 + 5×20 = 100 (max stack per Level Up Pool r2)

## Test Evidence
**Required**: `tests/unit/player/pickup_radius_api_test.gd` — must exist and pass
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Story 001 (Player base)
- Unlocks: Pickup epic consumer
