# Story 003: take_damage + Death Delegation to VFX

> **Epic**: Enemy System | **Status**: Ready | **Layer**: Core | **Type**: Logic | **Estimate**: M

## Context

**GDD**: `design/gdd/enemy-system.md` (r2 after C-B4 cross-doc fix) | **Requirement**: TR-enemy-002
**ADR**: ADR-0001 | **Risk**: LOW

**Cross-doc contract**: Per /review-all-gdds 2026-05-27 C-B4 resolution, Enemy does NOT self-queue_free. VFX subscribes to `died`, plays dissolve, then calls `payload.enemy.queue_free()`. See VFX GDD AC-01.

## Acceptance Criteria

- [ ] **AC-08**: Paper Doll at `current_hp = 14`, `take_damage(5)` → `current_hp = 9` AND `damage_taken(9, 14, 5)` emit
- [ ] **AC-09**: Paper Doll at `current_hp = 14`, `take_damage(15)` overkill → `current_hp = 0` (clamped) AND `died(self)` emits exactly once. **`queue_free()` is then called by VFX subscriber** (NOT by Enemy itself per C-B4 resolution + VFX GDD AC-01).
- [ ] **AC-10**: Paper Doll in `_is_dead = true`, subsequent `take_damage(5)` → function early-returns AND `current_hp` stays 0 AND no signal re-emits
- [ ] **AC-11**: Paper Doll with `xp_drop_value = 3.5`, `_die()` → ExperienceOrb instance created AND added to scene tree AND `xp_value = 3.5` AND position = Enemy's position at death

## Implementation Notes

Per Enemy GDD r2 Rule 3 (C-B4 closed):
```gdscript
signal damage_taken(current_hp: float, max_hp: float, last_damage_amount: float)
signal died(payload: Dictionary)

var _is_dead: bool = false

func take_damage(amount: float) -> void:
    if _is_dead or amount <= 0.0: return
    current_hp = maxf(current_hp - amount, 0.0)
    damage_taken.emit(current_hp, max_hp, amount)
    if current_hp == 0.0:
        _die()

func _die() -> void:
    if _is_dead: return
    _is_dead = true
    velocity = Vector2.ZERO
    if xp_drop_value > 0.0 and experience_orb_scene != null:
        var orb = experience_orb_scene.instantiate()
        orb.xp_value = xp_drop_value
        orb.global_position = global_position
        get_tree().current_scene.add_child(orb)
    died.emit({
        "enemy": self,
        "position": global_position,
        "xp_drop_value": xp_drop_value,
        "archetype_name": archetype.display_name if archetype else "unknown",
        "is_boss": is_in_group("bosses")
    })
    # NOTE: NO queue_free() here — VFX subscriber owns the call (C-B4)
```

## QA Test Cases

**AC-08**: Standard damage decrement
- Given: Paper Doll `current_hp = 14`
- When: `take_damage(5.0)`
- Then: `current_hp == 9.0` AND `damage_taken.emit(9.0, 14.0, 5.0)` once
- Edge: amount = 0 → early-return; amount = 14 (exact-fatal) → fires `_die()` chain

**AC-09**: Overkill clamp + delegation
- Given: Paper Doll `current_hp = 14`
- When: `take_damage(15.0)`
- Then: `current_hp == 0.0` (NOT -1) AND `died.emit(payload)` ONCE AND `payload.enemy == self` AND `_is_dead == true` AND **`queue_free()` NOT called by Enemy itself** (verify scene tree still contains node 1 frame after; VFX subscriber stub completes free after 0.5s per VFX AC-01)

**AC-10**: Inert DYING state
- Given: `_is_dead = true`
- When: `take_damage(5)`
- Then: Function early-returns; no signal re-emit; `current_hp` stays 0

**AC-11**: XP orb spawn on death
- Given: Paper Doll with `xp_drop_value = 3.5, experience_orb_scene != null`
- When: `_die()` runs
- Then: ExperienceOrb instance added to scene tree AND `orb.xp_value == 3.5` AND `orb.global_position == enemy.global_position`
- Edge: xp_drop_value = 0 (Boss) → no orb spawn; experience_orb_scene = null → no orb (defensive)

## Test Evidence
`tests/unit/enemy/take_damage_test.gd`

## Dependencies
- Depends on: Story 001
- Unlocks: Story 004 (contact damage), Boss System epic (Boss inherits)
