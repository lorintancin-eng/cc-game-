# Story 005: Upgrade Application Pipeline

> **Epic**: Player System | **Status**: Ready | **Layer**: Core | **Type**: Logic | **Estimate**: M (2-3 hours)
> **Manifest Version**: 2026-05-25.1 | **Last Updated**: 2026-05-27

## Context

**GDD**: `design/gdd/player-system.md` + `design/gdd/level-up-pool.md` (r2)
**Requirement**: TR-core-001 (Player owns upgrade application)
**ADR Governing Implementation**: ADR-0001. **Engine**: Godot 4.6 | **Risk**: MEDIUM (hardcoded `match` statement is Pillar-4 violation; tracked as OQ-6 tech debt).

**Control Manifest Rules**:
- Forbidden: Hardcoded balance values in `.gd` (use `.tres` Resource files) ← **v0.4 violates this; tracked as OQ-6 tech debt; this story implements the hardcoded version per code reality**
- Required: Signal emission post-mutation: `upgrade_applied(upgrade_id: StringName)`

---

## Acceptance Criteria

- [ ] **AC-13**: Level Up panel returns `UPGRADE_TALISMAN_DAMAGE` → applied → Talisman child weapon's `damage` field += **10.0** (v0.4 hardcoded delta in `_apply_upgrade` match) AND `upgrade_applied(UPGRADE_TALISMAN_DAMAGE)` emit exactly once
- [ ] **Per-upgrade stack cap enforcement** (Level Up Pool r2 D-B2 — capped at `max_stacks` per category per `level-up-pool.md` Rule 6):
  - Damage upgrades: max 3 stacks (3×+10 = 38 dmg, 4.75× ≤ Combat 5× ceiling)
  - Cooldown upgrades: max 5 stacks
  - HP / attribute upgrades: max 5 stacks
  - Weapon-unlock upgrades: max 1 stack

## Implementation Notes

Per Player GDD Core Rule 4 + Level Up Pool GDD r2 Rule 6 + AC-13:
```gdscript
signal upgrade_applied(upgrade_id: StringName)

var _upgrade_pick_count: Dictionary = {}  # upgrade_id (String) → count (int)

func apply_upgrade(upgrade_id: StringName) -> void:
    # Stack cap check (Level Up Pool r2 D-B2 enforcement)
    var pick_count: int = _upgrade_pick_count.get(upgrade_id, 0)
    var max_stacks := _get_max_stacks(upgrade_id)
    if pick_count >= max_stacks:
        push_warning("Upgrade %s already at max_stacks (%d) — skipping" % [upgrade_id, max_stacks])
        return
    _upgrade_pick_count[upgrade_id] = pick_count + 1

    # Hardcoded delta application (OQ-6 tech debt — extract to .tres post-MVP)
    match upgrade_id:
        &"UPGRADE_TALISMAN_DAMAGE":
            $TalismanWeapon.damage += 10.0
        &"UPGRADE_TALISMAN_COOLDOWN":
            $TalismanWeapon.cooldown *= 0.9
        &"UPGRADE_MAX_HP":
            max_hp += 20.0
            current_hp = minf(current_hp + 20.0, max_hp)
            health_changed.emit(current_hp, max_hp)
        &"UPGRADE_UNLOCK_FLYING_SWORD":
            $FlyingSwordWeapon.set_unlocked(true)
        # ... 25+ more upgrade IDs per code audit
        _:
            push_error("Unknown upgrade_id: %s" % upgrade_id)
            return

    upgrade_applied.emit(upgrade_id)

func _get_max_stacks(upgrade_id: StringName) -> int:
    # Lookup per Level Up Pool r2 Rule 6 category caps
    if str(upgrade_id).ends_with("_DAMAGE"): return 3
    if str(upgrade_id).ends_with("_COOLDOWN"): return 5
    if str(upgrade_id).ends_with("_PIERCE"): return 2
    if str(upgrade_id).ends_with("_COUNT"): return 3
    if str(upgrade_id) == "UPGRADE_MAX_HP": return 5
    if str(upgrade_id).begins_with("UPGRADE_UNLOCK_"): return 1
    return 5  # default for attribute upgrades (speed, pickup_radius, xp_gain)
```

**Tech debt (OQ-6)**: Each `match` arm hardcodes the delta value. Future: extract to `resources/upgrades/UPGRADE_TALISMAN_DAMAGE.tres` (UpgradeDefinition Resource with `target_node_path`, `field_name`, `delta_value`, `max_stacks`). Out of v0.4 scope.

## Out of Scope
- Upgrade pool generation (Story 006 — filter logic)
- Deterministic upgrade seed (Story 007)
- `.tres` extraction (OQ-6 — future sprint)
- Level Up panel UI (Level Up Pool epic)

## QA Test Cases

**AC-13**: TALISMAN_DAMAGE upgrade application
- Given: Player with Talisman weapon child node `damage = 8.0`; `_upgrade_pick_count` empty
- When: `apply_upgrade(&"UPGRADE_TALISMAN_DAMAGE")`
- Then: `$TalismanWeapon.damage == 18.0` (8 + 10) AND `_upgrade_pick_count["UPGRADE_TALISMAN_DAMAGE"] == 1` AND `upgrade_applied.emit(&"UPGRADE_TALISMAN_DAMAGE")` once
- Edge: unknown upgrade_id → `push_error` + no mutation + no signal; same upgrade applied 4 times → 4th application stops at cap (max_stacks=3); upgrade for not-yet-unlocked weapon → silently no-op (defensive guard per Player GDD edge case)

**Stack cap regression — TALISMAN_DAMAGE 4× attempt**:
- Given: Player; apply UPGRADE_TALISMAN_DAMAGE 3 times successfully (pick_count = 3)
- When: 4th call `apply_upgrade(&"UPGRADE_TALISMAN_DAMAGE")`
- Then: `push_warning` fires; damage stays 8+30=38 (NOT 48); `upgrade_applied` does NOT emit for the 4th; pool filter (Story 006) should have prevented this scenario in practice

**UPGRADE_MAX_HP application + heal**:
- Given: Player `current_hp = 50, max_hp = 100`
- When: `apply_upgrade(&"UPGRADE_MAX_HP")`
- Then: `max_hp = 120` AND `current_hp = 70` (50 + 20 heal) AND `health_changed.emit(70, 120)`
- Edge: current_hp = 100 (full) → max_hp = 120, current_hp = 120 (clamped to new max)

**UPGRADE_UNLOCK_FLYING_SWORD**:
- Given: Player with FlyingSwordWeapon child node `_unlocked = false`
- When: `apply_upgrade(&"UPGRADE_UNLOCK_FLYING_SWORD")`
- Then: `$FlyingSwordWeapon._unlocked == true` AND `upgrade_applied` emit AND pick_count = 1 (cap reached — won't appear in pool again per Story 006)

## Test Evidence
**Required**: `tests/unit/player/upgrade_application_test.gd` — must exist and pass
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Story 001, 002 (Player base + HP)
- Unlocks: Story 006 (pool filter consumes `_upgrade_pick_count`)
