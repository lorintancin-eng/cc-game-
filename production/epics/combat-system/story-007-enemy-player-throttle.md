# Story 007: Enemy → Player Damage Throttle

> **Epic**: Combat System
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M (2-3 hours)
> **Manifest Version**: 2026-05-25.1
> **Last Updated**: 2026-05-27

## Context

**GDD**: `design/gdd/combat-system.md`
**Requirement**: `TR-wpn-002` (damage types — direct from enemy contact)

**ADR Governing Implementation**: ADR-0001: Godot 4.x + GDScript
**ADR Decision Summary**: Per-enemy `last_hit_time` field; independent throttles per-enemy per Core Rule 9.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Use `Time.get_ticks_msec() / 1000.0` for monotonic time; do NOT use `Engine.get_process_frames()` (frame-dependent).

**Control Manifest Rules (Core Layer)**:
- Required: Combat damage applied via signals — never direct property writes
- Required: `damage_interval` enforced per-enemy, not global

---

## Acceptance Criteria

*From GDD `design/gdd/combat-system.md` + Formula 4 + Core Rule 9:*

- [ ] **AC-10**: Stone Golem (`damage = 12, damage_interval = 1.0`) spawns and immediately contacts player at `t = 5.0` → player takes 12 damage at `t = 5.0` (no spawn grace period) AND `last_hit_time = 5.0`
- [ ] **AC-11**: Stone Golem in contact from `t = 0.0` to `t = 2.5` → player takes damage at exactly `t = 0.0, 1.0, 2.0` (3 hits) AND no per-frame damage
- [ ] **AC-12**: Two different enemies (Stone Golem + Paper Doll) both in contact, both `last_hit_time` ready → player takes BOTH damage values (independent throttles per Core Rule 9) AND each enemy updates its own `last_hit_time`

---

## Implementation Notes

*Per Combat GDD Formula 4 + Core Rules 4, 9:*

1. Each Enemy carries its own `last_hit_time` field:
   ```gdscript
   var last_hit_time: float = 0.0

   func _ready() -> void:
       # Spawn-grace initialization per Formula 4: enemy can hit immediately on first contact
       last_hit_time = (Time.get_ticks_msec() / 1000.0) - damage_interval
   ```
2. Damage application gate:
   ```gdscript
   func _try_damage_player(player: Node) -> void:
       var now := Time.get_ticks_msec() / 1000.0
       if (now - last_hit_time) < maxf(damage_interval, MIN_DAMAGE_INTERVAL):
           return  # throttle
       player.take_damage(damage)
       last_hit_time = now
   ```
3. Note: `MIN_DAMAGE_INTERVAL = 0.1` (engine constant) — clamped via `maxf()` like other tuning knobs.
4. Each Enemy instance has its own `last_hit_time` (no shared state) — guarantees Core Rule 9 independence.

---

## Out of Scope

- Aggregate DPS ceiling (Story 008) — this story handles per-enemy throttle only
- Player HP application math (Story 002)
- Player death (Story 003)
- Friendly-fire skip (Story 001)

---

## QA Test Cases

**AC-10**: No spawn grace period
- **Given**: Player at world (0,0); Stone Golem spawns at world (5,0) at `t=5.0` with `damage = 12, damage_interval = 1.0`; Stone Golem's `_ready()` initializes `last_hit_time = 4.0`
- **When**: Physics broadphase detects contact at `t=5.0` AND `_try_damage_player()` runs
- **Then**: `can_hit = (5.0 - 4.0 ≥ 1.0) = true` (Formula 4 condition met) AND player takes 12 damage AND `last_hit_time` updates to 5.0
- **Edge cases**: Player at exact spawn position → still triggers (overlap is contact); damage_interval set to 0 in `.tres` → clamps to 0.1; player invulnerable somehow → defensive

**AC-11**: Throttle enforces exactly 3 hits in 2.5s
- **Given**: Stone Golem in continuous contact with player from `t=0.0` to `t=2.5`; `damage_interval = 1.0`
- **When**: Simulation runs full 2.5s at any frame rate
- **Then**: Damage events fire at exactly `t=0.0, 1.0, 2.0` (3 hits) AND NO event at `t=0.5` or `t=1.5` AND `last_hit_time` ends at 2.0
- **Edge cases**: Frame timing varies (60 FPS vs 30 FPS) → still 3 hits (throttle is monotonic-time based, not frame-based); player exits contact at t=1.5 → only 2 hits (t=0.0, 1.0)

**AC-12**: Independent per-enemy throttles
- **Given**: Stone Golem (`damage = 12, damage_interval = 1.0`) AND Paper Doll (`damage = 5, damage_interval = 0.85`) both contacting player at t=0.0; both with `last_hit_time` initialized to allow immediate hit
- **When**: `_try_damage_player()` runs on the same frame for both
- **Then**: Player takes `12 + 5 = 17` damage AND Stone Golem's `last_hit_time = 0.0` AND Paper Doll's `last_hit_time = 0.0` (different objects, independent state)
- **Edge cases**: Both enemies are the same archetype (two Paper Dolls) — still independent per-instance; one is throttled and one ready → only the ready one applies damage

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/combat/throttle_test.gd` — must exist and pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 (HP application — player.take_damage exists)
- Unlocks: Story 008 (aggregate ceiling builds on per-enemy throttle)
