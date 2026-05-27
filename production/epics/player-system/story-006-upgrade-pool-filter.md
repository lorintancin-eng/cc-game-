# Story 006: Upgrade Pool Filter (Weapon-Conditional + Stack-Cap)

> **Epic**: Player System | **Status**: Ready | **Layer**: Core | **Type**: Logic | **Estimate**: S (1-2 hours)
> **Manifest Version**: 2026-05-25.1 | **Last Updated**: 2026-05-27

## Context

**GDD**: `design/gdd/player-system.md` + `design/gdd/level-up-pool.md` (r2)
**Requirement**: TR-wpn-003 (Upgrade pool filtered by character/weapon state)
**ADR Governing Implementation**: ADR-0001. **Engine**: Godot 4.6 | **Risk**: LOW.

---

## Acceptance Criteria

- [ ] **AC-14**: Player without `UPGRADE_UNLOCK_FLYING_SWORD` applied (FlyingSword disabled) → pool query → `UPGRADE_FLYING_SWORD_DAMAGE` NOT in choice set AND `UPGRADE_UNLOCK_FLYING_SWORD` IS in choice set
- [ ] **Stack-cap filter** (per Level Up Pool r2 Rule 6): upgrades where `_upgrade_pick_count[id] >= max_stacks` are NOT in choice set

## Implementation Notes

Per Player GDD Core Rules 7 + Level Up Pool r2:
```gdscript
func _get_upgrade_pool() -> Array[StringName]:
    var pool: Array[StringName] = []

    # Always-present: 4 Player attribute upgrades + 4 Talisman upgrades (Talisman starts unlocked)
    pool.append_array([
        &"UPGRADE_MAX_HP", &"UPGRADE_MOVE_SPEED", &"UPGRADE_PICKUP_RADIUS", &"UPGRADE_XP_GAIN",
        &"UPGRADE_TALISMAN_DAMAGE", &"UPGRADE_TALISMAN_COOLDOWN", &"UPGRADE_TALISMAN_COUNT", &"UPGRADE_TALISMAN_PIERCE"
    ])

    # Weapon-conditional: only add weapon's upgrades if weapon is unlocked
    if $FlyingSwordWeapon._unlocked:
        pool.append_array([
            &"UPGRADE_FLYING_SWORD_DAMAGE", &"UPGRADE_FLYING_SWORD_COOLDOWN",
            &"UPGRADE_FLYING_SWORD_PIERCE", &"UPGRADE_FLYING_SWORD_COUNT"
        ])
    else:
        pool.append(&"UPGRADE_UNLOCK_FLYING_SWORD")  # unlock available only when locked

    # ... same pattern for ThunderLaw, BaguaArray, ExplosiveTalisman, MountainSeal

    # Stack-cap filter (Level Up Pool r2 Rule 6 enforcement)
    pool = pool.filter(func(upgrade_id: StringName) -> bool:
        var pick_count: int = _upgrade_pick_count.get(upgrade_id, 0)
        var max_stacks := _get_max_stacks(upgrade_id)
        return pick_count < max_stacks
    )

    return pool

func _get_random_upgrade_options(count: int = 3) -> Array[StringName]:
    var pool := _get_upgrade_pool()
    pool.shuffle()  # Fisher-Yates (Godot built-in)
    return pool.slice(0, mini(count, pool.size()))
```

## Out of Scope
- Fisher-Yates seed determinism (Story 007)
- Upgrade application itself (Story 005)
- Level Up panel UI (Level Up Pool epic)

## QA Test Cases

**AC-14**: Pool filter — locked weapon
- Given: Player with `$FlyingSwordWeapon._unlocked = false`
- When: `_get_upgrade_pool()` runs
- Then: Returned array CONTAINS `UPGRADE_UNLOCK_FLYING_SWORD` AND does NOT contain any of `UPGRADE_FLYING_SWORD_DAMAGE / COOLDOWN / PIERCE / COUNT`
- Edge: All 5 weapons locked → pool has 4 unlock upgrades + 8 base upgrades (12 total); all 5 weapons unlocked → 20 upgrade entries (4 per × 5 weapons + 8 always-present)

**Pool filter — unlocked weapon adds upgrades**:
- Given: Player with `$FlyingSwordWeapon._unlocked = true`
- When: `_get_upgrade_pool()` runs
- Then: `UPGRADE_FLYING_SWORD_DAMAGE / COOLDOWN / PIERCE / COUNT` all present AND `UPGRADE_UNLOCK_FLYING_SWORD` NOT present

**Stack-cap filter regression** (per Level Up Pool r2 D-B2):
- Given: Player with `_upgrade_pick_count["UPGRADE_TALISMAN_DAMAGE"] = 3` (at cap)
- When: `_get_upgrade_pool()` runs
- Then: `UPGRADE_TALISMAN_DAMAGE` filtered OUT (excluded from pool)
- Edge: all damage upgrades hit cap (3 stacks each) → pool excludes all `*_DAMAGE` entries; UNLOCK upgrade cap=1 → after taking, never appears again (matches AC-14 reverse)

## Test Evidence
**Required**: `tests/unit/player/upgrade_pool_filter_test.gd` — must exist and pass
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Story 005 (`_upgrade_pick_count` Dictionary lives there)
- Unlocks: Story 007 (deterministic shuffle), Level Up Pool epic
