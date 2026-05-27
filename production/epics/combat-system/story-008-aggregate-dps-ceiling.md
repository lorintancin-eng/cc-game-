# Story 008: Aggregate DPS Ceiling (MAX_CONTACT_ATTACKERS = 4)

> **Epic**: Combat System
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Estimate**: M (2-3 hours — requires 8-enemy multi-body simulation)
> **Manifest Version**: 2026-05-25.1
> **Last Updated**: 2026-05-27

## Context

**GDD**: `design/gdd/combat-system.md`
**Requirement**: `TR-wpn-002` (damage types — aggregate DPS ceiling enforcement)

**ADR Governing Implementation**: ADR-0001: Godot 4.x + GDScript
**ADR Decision Summary**: Hard cap on simultaneous contact attackers (4); engine constant, not designer-tunable.

**Engine**: Godot 4.6 | **Risk**: MEDIUM (multi-body contact tracking; physics broadphase order matters per Formula 7)
**Engine Notes**: Use `Area2D.body_entered/exited` signals to maintain contact list; sort by entry time descending for most-recent-4 selection.

**Control Manifest Rules (Core Layer)**:
- Required: Aggregate ceiling enforced as engine constant (NOT a `.tres` tuning knob)
- Guardrail: Pillar 1 (清晰的生存压力) — without this ceiling, 8+ enemies = 0.4s wipe

---

## Acceptance Criteria

*From GDD `design/gdd/combat-system.md` + Formula 7 + Core Rule 8:*

- [ ] **AC-13**: 8 Paper Dolls in contact with player (>MAX_CONTACT_ATTACKERS = 4) → only the 4 most-recently-entered Paper Dolls' damage applies this frame AND the remaining 4 Paper Dolls' `last_hit_time` is NOT updated (they remain ready for next eligible frame)
- [ ] **AC-14**: Player at `current_hp = 5`, Stone Golem in contact (`damage = 12`) → next hit applies → `current_hp = 0` (clamped) AND Player emits `health_changed(0, 100)` AND `died()` exactly once AND no further enemy damage events apply for rest of run

---

## Implementation Notes

*Per Combat GDD Formula 7 + Core Rule 8 + Pressure Curve §Survival Budget:*

1. `MAX_CONTACT_ATTACKERS = 4` is an **engine constant**, not a tuning knob:
   ```gdscript
   const MAX_CONTACT_ATTACKERS: int = 4  # Hard cap per Combat GDD Core Rule 8
   ```
2. Player tracks contact list with entry timestamps:
   ```gdscript
   var _contact_attackers: Array[Dictionary] = []  # [{enemy: Node, entry_time: float}, ...]

   func _on_contact_body_entered(body: Node) -> void:
       if not body.is_in_group("enemies"):
           return
       _contact_attackers.append({"enemy": body, "entry_time": Time.get_ticks_msec() / 1000.0})

   func _on_contact_body_exited(body: Node) -> void:
       _contact_attackers = _contact_attackers.filter(func(e): return e.enemy != body)
   ```
3. Per-frame damage resolution:
   ```gdscript
   func _physics_process(_delta: float) -> void:
       if _is_dead: return
       # Sort by entry_time DESCENDING (most recent first)
       _contact_attackers.sort_custom(func(a, b): return a.entry_time > b.entry_time)
       var active_count := mini(_contact_attackers.size(), MAX_CONTACT_ATTACKERS)
       for i in range(active_count):
           var enemy = _contact_attackers[i].enemy
           if is_instance_valid(enemy):
               # Each enemy's _try_damage_player applies Formula 4 throttle
               # If throttled, NO damage AND last_hit_time NOT updated (Story 007)
               enemy._try_damage_player(self)
       # Queued attackers (index >= MAX_CONTACT_ATTACKERS) get NO call this frame.
       # Their last_hit_time NOT touched — they remain ready for next frame.
   ```
4. **N-4 explicit behavior** (per Combat GDD Formula 7): if every enemy in `active_attackers` has `can_hit = false` (throttled), zero damage applies this frame even though queued attackers exist. Formula 4 (throttle) always takes precedence over slot availability — the ceiling caps maximum DPS but does not bypass per-enemy throttles.
5. Player death + signal contract: `health_changed(0, max_hp)` followed by `died()` exactly once.

---

## Out of Scope

- Per-enemy throttle (Story 007) — this story consumes that contract
- Death lifecycle on Player (Story 003 patterns apply to Player)
- HP value debate (D-B1 OQ-5 — playtest in progress)

---

## QA Test Cases

**AC-13**: 8-Paper-Doll cap enforcement
- **Given**: Player at world (0,0); 8 Paper Dolls all in contact at varying entry times (e.g. enemy 0 entered at t=0.0, enemy 1 at t=0.1, ..., enemy 7 at t=0.7); all with `damage = 5, damage_interval = 0.85`; all `last_hit_time` ready
- **When**: `_physics_process` runs at t=1.0
- **Then**: Only enemies 4-7 (most recently entered) apply damage AND player takes `4 × 5 = 20` damage AND enemies 0-3 last_hit_time UNCHANGED AND enemies 4-7 last_hit_time updated to 1.0
- **Edge cases**: 5 enemies (count = MAX+1) → 4 most-recent fire, 1 queued; 4 enemies exactly → all 4 fire (no queueing); all enemies entered same frame → physics broadphase iteration order is implementation-defined (OQ-6 — fall back to deterministic ordering by spawn_id if replay matters)

**AC-14**: Death event sequence + post-death damage suppression
- **Given**: Player at `current_hp = 5, max_hp = 100`; Stone Golem in contact with `damage = 12, damage_interval = 1.0`, last_hit_time ready
- **When**: Stone Golem's damage event applies at t=10.0
- **Then**: In order: (1) `health_changed(0, 100)` emits ONCE (clamped from -7 to 0), (2) `died()` emits ONCE, (3) `_is_dead = true` flag set, (4) any subsequent enemy damage events from any source early-return on `_is_dead` guard
- **Edge cases**: Multiple enemies hit player on same frame, killing → first one triggers death; subsequent hits suppressed (mirror of Core Rule 6 for Player); Player HP regenerates after death (impossible v0.4) → terminal state

**Survival Budget regression test (Pressure Curve §Survival Budget)**:
- **Given**: Player at HP=100; 4 Paper Dolls in contact (`damage = 5, damage_interval = 0.85`) all ready
- **When**: Simulation runs without movement
- **Then**: Player survives ≥4.0 seconds (per Combat GDD: `100 / 23.5 ≈ 4.25s`) — within ±1 frame tolerance
- **Note**: This is the canonical Pressure Curve target. If playtest (D-B1) chooses to lower HP or raise enemy damage, update this test accordingly.

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/combat/aggregate_ceiling_test.gd` — must exist and pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 (HP application), Story 003 (death lifecycle), Story 007 (throttle)
- Unlocks: Story 011 (perf test depends on multi-enemy infrastructure)
