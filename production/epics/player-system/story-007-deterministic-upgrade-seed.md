# Story 007: Deterministic Upgrade Seed (Replay)

> **Epic**: Player System | **Status**: Ready | **Layer**: Core | **Type**: Logic | **Estimate**: S (1 hour)
> **Manifest Version**: 2026-05-25.1 | **Last Updated**: 2026-05-27

## Context

**GDD**: `design/gdd/player-system.md`
**Requirement**: TR-core-001 (deterministic upgrade replay for /balance-check + QA repro)
**ADR Governing Implementation**: ADR-0001. **Engine**: Godot 4.6 | **Risk**: LOW.

---

## Acceptance Criteria

- [ ] **AC-15**: Two runs with same `upgrade_random_seed = 2401`, same XP cadence, same weapon-unlock pattern → both reach L2 → identical 3 upgrade choices in same order

## Implementation Notes

```gdscript
@export var upgrade_random_seed: int = 2401  # dev default; production randomizes per-run

var _upgrade_rng: RandomNumberGenerator

func _ready() -> void:
    _upgrade_rng = RandomNumberGenerator.new()
    _upgrade_rng.seed = upgrade_random_seed

func _get_random_upgrade_options(count: int = 3) -> Array[StringName]:
    var pool := _get_upgrade_pool()
    # Fisher-Yates with deterministic RNG
    for i in range(pool.size() - 1, 0, -1):
        var j: int = _upgrade_rng.randi_range(0, i)
        var temp = pool[i]
        pool[i] = pool[j]
        pool[j] = temp
    return pool.slice(0, mini(count, pool.size()))
```

**Critical**: use a dedicated `RandomNumberGenerator` (not `randi()` global) — Godot's global RNG is shared with other systems and would break determinism.

## Out of Scope
- Pool generation (Story 006)
- Upgrade application (Story 005)
- Production seed source (TBD — `Time.get_unix_time_from_system()` or per-run user input)

## QA Test Cases

**AC-15**: Replay determinism
- Given: Two Player instances both with `upgrade_random_seed = 2401`; both pools have identical contents (same weapon unlock state)
- When: Both call `_get_random_upgrade_options(3)` at the same simulated level (L1→L2 transition)
- Then: Both return the SAME 3 upgrade_ids in the SAME order
- Edge: Different seeds → different orders (negative test); same seed but different unlock state → different pool → different first-3 (but still deterministic within each run)

## Test Evidence
**Required**: `tests/unit/player/upgrade_seed_test.gd` — must exist and pass
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Story 006 (pool generation)
- Unlocks: /balance-check determinism support
