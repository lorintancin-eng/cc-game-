# Story 002: HP Application + Overkill Clamp

> **Epic**: Combat System
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: S (1-2 hours)
> **Manifest Version**: 2026-05-25.1
> **Last Updated**: 2026-05-27

## Context

**GDD**: `design/gdd/combat-system.md`
**Requirement**: `TR-core-001` (auto-attack causes damage)

**ADR Governing Implementation**: ADR-0001: Godot 4.x + GDScript
**ADR Decision Summary**: Each target owns its own HP. Damage events trigger HP decrement via signal subscription.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Use `maxf()` for clamp at 0 (Godot 4.x typed float math).

**Control Manifest Rules (Core Layer)**:
- Required: Target's own script decrements its own HP — other systems request damage via signal
- Forbidden: `target.hp -= damage` from one system into another
- Guardrail: All damage values come from `.tres` Resource files, not hardcoded

---

## Acceptance Criteria

*From GDD `design/gdd/combat-system.md`:*

- [ ] **AC-01**: 修行者 at `current_hp = 30`, Wandering Soul with `damage = 8` hits → Player's `current_hp` becomes 22 AND Player emits `health_changed(22, 30)` exactly once
- [ ] **AC-20**: Enemy at `current_hp = 5`, damage event with `amount = 999` arrives → `current_hp = 0` (clamped, not -994) AND `died` fires AND no second `died` emits

---

## Implementation Notes

*Per ADR-0001 + Combat GDD Formula 1 + Core Rule 3:*

1. Formula 1: `new_hp = max(0, current_hp - final_damage)` where `final_damage = raw_damage × source_modifier × crit_multiplier × element_modifier × pierce_falloff`
   - In v0.4 baseline: `crit_multiplier = element_modifier = pierce_falloff = 1.0` (reserved slots — see Story 011)
2. Player and Enemy each implement `take_damage(amount: float) -> void`:
   ```gdscript
   func take_damage(amount: float) -> void:
       if _is_dead or amount <= 0.0:
           return
       current_hp = maxf(current_hp - amount, 0.0)
       health_changed.emit(current_hp, max_hp)  # Player; OR damage_taken.emit(current_hp, max_hp, amount) for Enemy
       if current_hp == 0.0:
           _die()  # see Story 003
   ```
3. Player signal name: `health_changed(current_hp: float, max_hp: float)` — per Combat GDD signal payload contract
4. Enemy signal name: `damage_taken(current_hp: float, max_hp: float, last_damage_amount: float)` — different payload from Player

---

## Out of Scope

- Damage tuple emit (Story 001)
- Death lifecycle / DYING state (Story 003) — this story ends at "HP reaches 0, _die() invoked"
- Friendly fire skip (Story 001)
- Throttling — `last_hit_time` (Story 007)

---

## QA Test Cases

**AC-01**: Standard HP decrement
- **Given**: Player CharacterBase with `current_hp = 30, max_hp = 30`; Wandering Soul with `damage = 8`
- **When**: `Player.take_damage(8)` invoked
- **Then**: `current_hp == 22` AND `health_changed(22, 30)` emitted exactly once AND signal payload types are `(float, float)`
- **Edge cases**: damage = max_hp (kill in one hit) → `current_hp == 0` AND `died` fires; damage < 1.0 (sub-integer) → fractional HP supported via float math

**AC-20**: Overkill clamp
- **Given**: Enemy at `current_hp = 5, max_hp = 24`
- **When**: `Enemy.take_damage(999)` invoked
- **Then**: `current_hp == 0` (NOT -994) AND `died` signal fires exactly once AND no negative HP value persists
- **Edge cases**: damage = current_hp exactly (no overkill) → still triggers death; damage = float NaN/inf → defensive: clamp at max_hp damage value

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/combat/hp_application_test.gd` — must exist and pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (damage tuple) must be DONE
- Unlocks: Story 003 (death lifecycle), Story 007 (throttling builds on take_damage)
