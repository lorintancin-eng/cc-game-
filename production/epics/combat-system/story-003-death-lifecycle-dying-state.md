# Story 003: Death Lifecycle (DYING state + single died emit)

> **Epic**: Combat System
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M (2-3 hours — covers multiple subtle frame-ordering edge cases)
> **Manifest Version**: 2026-05-25.1
> **Last Updated**: 2026-05-27

## Context

**GDD**: `design/gdd/combat-system.md`
**Requirement**: `TR-enemy-002` (Enemy hit-feedback + death state)

**ADR Governing Implementation**: ADR-0001: Godot 4.x + GDScript
**ADR Decision Summary**: Signal-based death notification; visual lifetime decoupled from data-death (VFX GDD owns `queue_free()`).

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Frame ordering in Godot 4.x — use `_is_dead` boolean as guard; `queue_free()` is deferred until end of frame (this matters for AC-22 visual-death timing per Story 011).

**Control Manifest Rules (Core Layer)**:
- Required: `died(enemy_payload)` signal emits exactly once per enemy
- Forbidden: Direct `queue_free()` in Enemy on damage event — wait for VFX subscriber (per `design/gdd/enemy-system.md` r2 + `design/gdd/vfx-system.md` r1 contract)

---

## Acceptance Criteria

*From GDD `design/gdd/combat-system.md`:*

- [ ] **AC-02**: Enemy with `max_hp = 14` (Paper Doll), total damage across any number of events reaches exactly 14 → Enemy emits `damage_taken(0, 14, ...)` AND transitions to `DYING` AND emits `died(payload)` exactly once — all within 1 frame
- [ ] **AC-03**: Paper Doll in `DYING` state, additional damage event from any source → no `died` re-emits AND `current_hp` remains 0 AND no XP orb is spawned for the second event

---

## Implementation Notes

*Per Combat GDD Core Rules 4 + 6 + AC-22 contract:*

1. Add `_is_dead: bool = false` field to Enemy.
2. Modify `take_damage(amount)` to guard:
   ```gdscript
   func take_damage(amount: float) -> void:
       if _is_dead:
           return  # Core Rule 6: DYING is inert
       if amount <= 0.0:
           return
       current_hp = maxf(current_hp - amount, 0.0)
       damage_taken.emit(current_hp, max_hp, amount)
       if current_hp == 0.0:
           _die()
   ```
3. `_die()` implementation:
   ```gdscript
   func _die() -> void:
       if _is_dead:
           return  # paranoid double-guard
       _is_dead = true
       velocity = Vector2.ZERO
       if xp_drop_value > 0.0 and experience_orb_scene != null:
           # spawn XP orb (Experience system handles this)
           pass
       died.emit({
           "enemy": self,
           "position": global_position,
           "xp_drop_value": xp_drop_value,
           "archetype_name": archetype.display_name if archetype else "unknown",
           "is_boss": is_in_group("bosses")
       })
       # NOTE: queue_free() is NOT called here per VFX GDD r1 + C-B4 resolution.
       # VFX subscribes to `died`, plays dissolve for ≤0.5s, then calls
       # `payload.enemy.queue_free()`. See Story 011 (AC-22 reserved placeholder).
   ```
4. Player's `_die()` is similar but emits parameterless `died()` signal per signal contract — and Player does NOT queue_free (Stage Director reads `_is_dead` flag).

---

## Out of Scope

- VFX dissolve animation timing (Story 011 — AC-22 reserved placeholder)
- XP orb spawn logic (out of Combat epic — see Experience epic)
- Boss-specific death handling (Story 010)

---

## QA Test Cases

**AC-02**: Single-frame death with exactly-fatal damage
- **Given**: Paper Doll at `current_hp = 14, max_hp = 14`
- **When**: `Enemy.take_damage(14)` invoked (exact-fatal)
- **Then**: Within 1 frame: `damage_taken(0, 14, 14)` emits AND `_is_dead == true` AND `died(payload)` emits exactly once AND `payload.enemy == self` AND `payload.position` == enemy's global_position
- **Edge cases**: Multiple incremental hits summing to 14 (e.g. 5 + 5 + 4) → same result (`died` fires on the hit that crosses 0); damage = max_hp + 1 → still fires `died` once (no double emit)

**AC-03**: Inert DYING state
- **Given**: Paper Doll just transitioned to `_is_dead = true` (from AC-02 setup)
- **When**: A second `Enemy.take_damage(5)` event fires before VFX-side `queue_free()` completes
- **Then**: `current_hp` STAYS at 0 (no decrement attempted) AND `damage_taken` does NOT re-fire AND `died` does NOT re-fire AND no XP orb spawns for the second event (per `payload.xp_drop_value` is already consumed on first emit)
- **Edge cases**: 5+ simultaneous damage events on the killing frame → first triggers `_die()`, subsequent early-return; cross-source damage (different weapons hitting same dying enemy) → all silently dropped

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/combat/death_lifecycle_test.gd` — must exist and pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 (HP application) must be DONE
- Unlocks: Story 010 (Boss victory hooks into `died` signal)
