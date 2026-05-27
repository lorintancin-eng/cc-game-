# Story 004: WeaponBase Cooldown + Single-Target DPS

> **Epic**: Combat System
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: S (1-2 hours)
> **Manifest Version**: 2026-05-25.1
> **Last Updated**: 2026-05-27

## Context

**GDD**: `design/gdd/combat-system.md`
**Requirement**: `TR-wpn-001` (WeaponBase contract: cooldown / damage / targeting / projectile)

**ADR Governing Implementation**: ADR-0001: Godot 4.x + GDScript
**ADR Decision Summary**: Per-weapon `.tres` for stats; base class for shared cooldown/targeting logic.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Use `_process(delta)` for cooldown decrement; `maxf()` for MIN_COOLDOWN clamp.

**Control Manifest Rules (Feature Layer)**:
- Required: Weapons inherit from `WeaponBase` (this story creates the contract)
- Required: Cooldown + targeting handled by base
- Forbidden: Weapon A calling Weapon B directly — weapons are independent

---

## Acceptance Criteria

*From GDD `design/gdd/combat-system.md` + Formula 2:*

- [ ] **AC-09**: Weapon `.tres` with `cooldown = 0.01` (below `MIN_COOLDOWN = 0.05`) → effective cooldown is `0.05` AND no console error AND `dps = damage / 0.05`
- [ ] **Formula 2 verification**: `dps = damage / max(MIN_COOLDOWN, cooldown)` produces expected DPS for Flying Sword (d=14, c=0.8) → 17.5 dps

---

## Implementation Notes

*Per Combat GDD Formula 2 + Tuning Knobs:*

1. Create `scripts/weapon/weapon_base.gd` (already exists per project audit — extend if needed):
   ```gdscript
   class_name WeaponBase
   extends Node2D

   const MIN_COOLDOWN: float = 0.05
   const MIN_ATTACK_RANGE: float = 1.0
   const MIN_PROJECTILE_LIFETIME: float = 0.05

   @export var damage: float = 1.0
   @export var cooldown: float = 1.0
   @export var attack_range: float = 100.0
   @export var projectile_speed: float = 400.0
   @export var projectile_lifetime: float = 1.0

   var _cooldown_remaining: float = 0.0

   func _process(delta: float) -> void:
       if _cooldown_remaining > 0.0:
           _cooldown_remaining = maxf(_cooldown_remaining - delta, 0.0)
       elif _try_attack():
           _cooldown_remaining = maxf(cooldown, MIN_COOLDOWN)

   # Subclass overrides:
   func _try_attack() -> bool:
       push_error("WeaponBase._try_attack() must be overridden by subclass")
       return false
   ```
2. Formula 2 enforcement: the `_cooldown_remaining = maxf(cooldown, MIN_COOLDOWN)` line embeds the clamp — designers can set cooldown < 0.05 in `.tres`, but effective rate caps at 20 Hz.
3. No console error on under-MIN cooldown (per AC-09). Just clamp silently.

---

## Out of Scope

- Specific weapon implementations (Talisman, Flying Sword, etc. — out of Combat epic; covered in Weapon System epic)
- Targeting service (separate Targeting epic)
- Pierce (Story 005)
- Tick weapons (Story 006)

---

## QA Test Cases

**AC-09**: Cooldown clamp
- **Given**: WeaponBase subclass with `cooldown = 0.01` in `.tres` (or set via export)
- **When**: weapon fires AND cooldown is set
- **Then**: `_cooldown_remaining == 0.05` (clamped to MIN_COOLDOWN) AND `dps = damage / 0.05` (NOT damage / 0.01) AND no `push_error()` or `push_warning()` emitted
- **Edge cases**: cooldown = 0 (designer typo) → clamp to 0.05; cooldown = negative → clamp to 0.05; cooldown = 0.0500001 → no clamp (above threshold)

**Formula 2 worked example**: Flying Sword DPS
- **Given**: Flying Sword weapon with `damage = 14.0, cooldown = 0.8`
- **When**: Formula 2 evaluates
- **Then**: `dps = 14.0 / 0.8 = 17.5` (within ±0.001 floating-point tolerance)
- **Edge cases**: damage = 0 → dps = 0 (no division by zero since cooldown clamp prevents 0 denominator); cooldown very large → dps approaches 0

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/combat/weapon_cooldown_test.gd` — must exist and pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (damage tuple contract) must be DONE
- Unlocks: Stories 005 (pierce), 006 (tick — both inherit from WeaponBase)
