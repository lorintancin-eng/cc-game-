# Story 006: Multi-Target Tick (Bagua Array)

> **Epic**: Combat System
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M (2-3 hours — deterministic timing tests require careful frame-pump setup)
> **Manifest Version**: 2026-05-25.1
> **Last Updated**: 2026-05-27

## Context

**GDD**: `design/gdd/combat-system.md`
**Requirement**: `TR-wpn-001` (WeaponBase contract — tick semantics), `TR-wpn-002` (damage type: tick)

**ADR Governing Implementation**: ADR-0001: Godot 4.x + GDScript
**ADR Decision Summary**: Per-zone tick accumulator; enemies inside zone take damage at fixed intervals.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Use a per-zone accumulator that persists across enemy entry/exit; do NOT reset on body_entered.

**Control Manifest Rules (Feature Layer)**:
- Required: Damage type `tick` declared in WeaponBase (per Combat GDD Damage Types table)
- Guardrail: `MAX_HITS_PER_TICK = 20` cap to prevent runaway DPS in dense swarms

---

## Acceptance Criteria

*From GDD `design/gdd/combat-system.md` + Formula 3:*

- [ ] **AC-08-A**: Bagua Array with `tick_rate = 0.65`, 5 enemies inside radius continuously, first tick at `t = 0.0` → subsequent ticks at `t = 0.65, 1.30, 1.95` (4 ticks total in first 2.0s) AND each enemy receives exactly 4 damage applications
- [ ] **AC-08-B**: Same setup, 1 enemy exits at `t = 1.0` → exiting enemy receives 2 damage applications (at t=0.0 and t=0.65) AND remaining 4 enemies receive 4 each

---

## Implementation Notes

*Per Combat GDD Formula 3 + Damage Types:*

1. Tick implementation pattern (do NOT reset accumulator on enemy entry):
   ```gdscript
   class_name BaguaArrayWeapon
   extends WeaponBase

   const MIN_TICK_RATE: float = 0.05
   const MAX_HITS_PER_TICK: int = 20  # engine constant

   @export var tick_rate: float = 0.65
   @export var radius: float = 100.0

   var _tick_accumulator: float = 0.0
   var _enemies_in_radius: Array[Node] = []

   func _process(delta: float) -> void:
       _tick_accumulator += delta
       var effective_tick_rate := maxf(tick_rate, MIN_TICK_RATE)
       while _tick_accumulator >= effective_tick_rate:
           _apply_tick()
           _tick_accumulator -= effective_tick_rate

   func _apply_tick() -> void:
       var hits := 0
       for enemy in _enemies_in_radius:
           if hits >= MAX_HITS_PER_TICK:
               break
           if not is_instance_valid(enemy):
               continue
           enemy.take_damage(damage)
           hits += 1
   ```
2. Formula 3: `per_enemy_dps = damage / tick_rate`; `total_effective_dps = (damage × hits_per_tick) / tick_rate`
3. **Critical determinism rule** (AC-08-A): tick timing is independent of enemy entry/exit — accumulator runs unconditionally. Enemy entering mid-tick-window does NOT shift the schedule.

---

## Out of Scope

- Specific Bagua Array visual / radius rendering (Weapon System epic)
- Damage tuple emission (Story 001)
- Frame-rate independence proof — but this story's accumulator pattern mirrors Story 009's burn fixed-step, which has explicit FPS-independence ACs

---

## QA Test Cases

**AC-08-A**: Deterministic tick schedule (5 enemies, full duration)
- **Given**: Bagua Array with `tick_rate = 0.65, damage = 4.0, radius = 100`; 5 Paper Dolls inside radius from t=0; `_tick_accumulator = 0.0`
- **When**: Simulation runs for 2.0s (frame-pumped at any FPS; recommend test fixture at 60 FPS for clarity)
- **Then**: Ticks fire at t=0.0, 0.65, 1.30, 1.95 (4 ticks total) AND each Paper Doll's HP decreased by `4 × 4 = 16` total damage AND total damage events emitted = `5 enemies × 4 ticks = 20`
- **Edge cases**: tick_rate = 0.01 (below MIN_TICK_RATE) → effective rate clamps to 0.05; >20 enemies → only first 20 take damage per tick (MAX_HITS_PER_TICK cap)

**AC-08-B**: Partial-duration enemy (exits mid-tick)
- **Given**: Same setup as AC-08-A, but Enemy[0] removed from `_enemies_in_radius` at exactly t=1.0 (or before t=1.30 third tick)
- **When**: Simulation runs for 2.0s
- **Then**: Enemy[0] took damage at t=0.0, 0.65 only (2 applications, total 8 damage) AND Enemies[1-4] took damage at all 4 ticks (16 each)
- **Edge cases**: Enemy exits AT t=0.65 (exactly on tick boundary) → ambiguous; recommend test fixture sets clear "exited BEFORE next tick" semantics; enemy re-enters at t=1.5 → takes the t=1.95 tick

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/combat/multi_target_tick_test.gd` — must exist and pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (damage tuple), Story 004 (WeaponBase)
- Unlocks: None directly (Bagua Array implementation in Weapon System epic depends on this contract)
