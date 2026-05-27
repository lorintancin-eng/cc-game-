# Story 009: Burn Damage Fixed-Step (FPS Independent)

> **Epic**: Combat System
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M (2-3 hours — requires running tests at 30 FPS and 60 FPS)
> **Manifest Version**: 2026-05-25.1
> **Last Updated**: 2026-05-27

## Context

**GDD**: `design/gdd/combat-system.md`
**Requirement**: `TR-wpn-002` (damage types — burn fixed-step accumulator)

**ADR Governing Implementation**: ADR-0001: Godot 4.x + GDScript
**ADR Decision Summary**: Burn damage decoupled from frame rate via accumulator; deterministic tick count regardless of FPS.

**Engine**: Godot 4.6 | **Risk**: MEDIUM (FPS independence proof is subtle — must test at multiple frame rates)
**Engine Notes**: Use a per-zone accumulator; do NOT use `Timer` nodes (frame-coupled in `_process` mode); do NOT call `apply_damage` from `_process(delta)` directly (would be FPS-coupled).

**Control Manifest Rules (Feature Layer)**:
- Required: Damage type `burn` declared in WeaponBase
- Guardrail: `BURN_TICK_INTERVAL = 0.1` is engine constant (not `.tres` tunable)

---

## Acceptance Criteria

*From GDD `design/gdd/combat-system.md` + Formula 5:*

- [ ] **AC-15**: Thunder Strike burn patch (`burn_dps = 6, burn_duration = 2.0`), player in zone full 2.0s → player takes exactly 20 ticks of 0.6 damage = 12 total damage (±0.05 floating tolerance)
- [ ] **AC-16**: Same patch, run at 30 FPS instead of 60 FPS → player still takes exactly 20 ticks of 0.6 damage over 2.0s (frame-rate independent)
- [ ] **AC-17**: Burn patch with `burn_duration = 2.0` → 2.0s elapses → patch `queue_free`'d AND subsequent player presence at that location takes 0 damage

---

## Implementation Notes

*Per Combat GDD Formula 5 + Edge Cases:*

1. Burn zone pattern (accumulator-based, frame-rate independent):
   ```gdscript
   class_name BurnZone
   extends Area2D

   const BURN_TICK_INTERVAL: float = 0.1  # engine constant

   @export var burn_dps: float = 6.0
   @export var burn_duration: float = 2.0
   var _accumulator: float = 0.0
   var _lifetime_remaining: float
   var _targets_in_zone: Array[Node] = []

   func _ready() -> void:
       _lifetime_remaining = burn_duration
       body_entered.connect(_on_body_entered)
       body_exited.connect(_on_body_exited)

   func _process(delta: float) -> void:
       _accumulator += delta
       while _accumulator >= BURN_TICK_INTERVAL:
           _apply_tick()
           _accumulator -= BURN_TICK_INTERVAL
       _lifetime_remaining -= delta
       if _lifetime_remaining <= 0.0:
           queue_free()

   func _apply_tick() -> void:
       var damage_per_tick := burn_dps * BURN_TICK_INTERVAL
       for target in _targets_in_zone:
           if is_instance_valid(target) and target.has_method("take_damage"):
               target.take_damage(damage_per_tick)
   ```
2. **Critical FPS independence rule**: the `while` loop in `_process` catches up if delta is large (e.g. 30 FPS = 33.3ms delta covers 3 ticks in one frame). At 60 FPS = 16.7ms delta covers 1 tick (with leftover accumulator). Both frame rates produce the same total tick count over the same wall-clock duration.
3. Lifetime is also frame-rate independent (counted in seconds via delta, not frame count).
4. `BURN_TICK_INTERVAL = 0.1` is engine constant per Combat GDD §Tuning Knobs — changing it requires an ADR amendment.

---

## Out of Scope

- Thunder Strike weapon implementation (Weapon System epic — this story implements only the burn-zone primitive)
- Status effect stacking (Status Effects epic)
- Visual effect of burn (VFX epic)

---

## QA Test Cases

**AC-15**: Deterministic burn at 60 FPS
- **Given**: BurnZone instance with `burn_dps = 6.0, burn_duration = 2.0`; Player remains inside zone for full 2.0s; simulated at 60 FPS (delta = 0.0166...)
- **When**: 2.0s elapses
- **Then**: Player took exactly 20 ticks of 0.6 damage (each tick = 6.0 × 0.1) AND total damage = 12.0 (±0.05 floating tolerance for accumulated rounding) AND zone is `queue_free`'d at t=2.0
- **Edge cases**: Player enters at t=1.0 (mid-zone) → takes 10 ticks of 0.6 = 6.0 damage; burn_dps = 0 → no damage but lifetime still ticks

**AC-16**: FPS independence (30 FPS)
- **Given**: Same BurnZone setup; simulated at 30 FPS (delta = 0.0333...)
- **When**: 2.0s elapses (60 simulated frames)
- **Then**: Player took exactly 20 ticks of 0.6 damage = 12.0 total (same as AC-15) AND **NOT** 6 ticks (which would be FPS-coupled) AND each `_process` frame fires multiple ticks via the while-loop catch-up
- **Edge cases**: 120 FPS → smaller accumulator increments but same tick count; lag spike (delta = 0.5s) → 5 ticks fire in one frame (catch-up); frame skipped entirely → next frame catches up

**AC-17**: Lifetime expiration + zone cleanup
- **Given**: BurnZone with `burn_duration = 2.0` spawned at t=0
- **When**: t=2.0 elapses
- **Then**: Zone calls `queue_free()` AND zone is removed from scene tree by next frame AND any player entering the previous zone location takes 0 damage AND `_targets_in_zone` array is gone
- **Edge cases**: Zone duration = 0 → freed immediately on first `_process`; zone duration = -1 → defensive: clamp at 0 or treat as instant; player exits and re-enters mid-life → both should not affect duration timer

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/combat/burn_fixed_step_test.gd` — must exist and pass at both 60 FPS and 30 FPS
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 (HP application), Story 006 (tick accumulator pattern reference)
- Unlocks: Thunder Strike weapon (Weapon System epic), Status Effects epic burn-stacks
