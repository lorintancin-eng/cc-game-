# Story 003: CombatEvents autoload signal bus

> **Epic**: Five Phases Synergy
> **Status**: Ready
> **Layer**: Feature (Core infrastructure)
> **Type**: Integration
> **Estimate**: S (~2h)
> **Manifest Version**: 2026-06-04.1
> **Last Updated**: (set by /dev-story)

## Context

**GDD**: `design/gdd/elements-five-phases.md` (Detailed Rules — 燎原 §; ADR-0006 §Decision 4)
**Requirement**: `TR-elem-004` (bus portion)

**ADR Governing Implementation**: ADR-0006 (Element System Pipeline)
**ADR Decision Summary**: `CombatEvents` is a stateless autoload signal relay (zero gameplay logic) for broadcast combat events. Declares `enemy_killed(kill_data: EnemyKillData)` where `EnemyKillData extends RefCounted` carries **value data only** (`source_element: String`, `damage: float`, `position: Vector2`) — NEVER the enemy Node. Each enemy emits before `queue_free()`; consumers connect ONCE. This replaces per-enemy `died.connect()` (an anti-pattern at 50-100 enemies).

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: Second infrastructure autoload (after SaveService) — justified as a pure relay. `EnemyKillData` must `extends RefCounted` with its own `class_name`. Payload carries VALUE data only — the enemy Node is freed end-of-frame (R-1). Connect via typed callable form, never the deprecated string form.

**Control Manifest Rules (Core)**:
- Required: CombatEvents is a stateless relay — `signal` declarations + emit pass-through ONLY
- Forbidden: any gameplay logic/state in CombatEvents (registry forbidden-pattern `gameplay_logic_in_combat_events`); per-enemy `died.connect()` for broadcast (`per_enemy_signal_connect_for_broadcast`)
- Guardrail: one emit per enemy death (replaces 50-100 live per-enemy connections)

---

## Acceptance Criteria

- [ ] `CombatEvents` autoload registered in project.godot; declares `signal enemy_killed(kill_data: EnemyKillData)`
- [ ] `EnemyKillData extends RefCounted` with `source_element: String`, `damage: float`, `position: Vector2` (value-only, no Node ref)
- [ ] Each enemy's `_die()` emits `CombatEvents.enemy_killed(data)` BEFORE `queue_free()`, with the killing blow's source element + damage + death position
- [ ] A consumer connecting once to `enemy_killed` receives exactly one event per enemy death
- [ ] CombatEvents holds no state and no gameplay logic (pure relay)

---

## Implementation Notes

*Derived from ADR-0006 §Decision 4 + Risks:*

- Autoload `CombatEvents` (Core). Body: just `signal enemy_killed(kill_data: EnemyKillData)` (+ future broadcast signals as needed). No `_process`, no state.
- `class_name EnemyKillData extends RefCounted` in its own file; populate in `enemy._die()` from the killing blow context.
- `enemy._die()`: build `EnemyKillData` (element/damage/position) → `CombatEvents.enemy_killed.emit(data)` → THEN `queue_free()`. Coordinate with combat OQ-7 B-13 (the `_die()` collision-disable fix also lives here).
- Consumers (ComboManager 燎原, future analytics) `CombatEvents.enemy_killed.connect(_on_enemy_killed)` once in `_ready()`.

---

## Out of Scope

- Story 006 (燎原): the ComboManager handler that reacts to `enemy_killed`
- The `source_element` value depends on weapon element tags (Story 005)

---

## QA Test Cases

- **AC (single emit)**: Given an enemy killed by a fire weapon, When `_die()` runs, Then `enemy_killed` fires exactly once with `source_element=="fire"`, correct `damage`, `position`. Edge: emit happens BEFORE queue_free (data captured while valid).
- **AC (value-only)**: Given the payload, Then it contains no Node reference (only String/float/Vector2) — a handler reading it next frame does not touch a freed node.
- **AC (relay purity)**: assert CombatEvents has no member vars / no logic methods (review-level + structural test).
- **Integration**: Given a ComboManager-stub connected once, When 3 enemies die, Then the stub's handler runs exactly 3 times.

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/combat/combat_events_bus_test.gd` — emit-once-per-death + value-only payload
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None (infrastructure). `source_element` is fully meaningful only after Story 005 (weapon element tags), but the bus + payload can be built + tested with a stub element now.
- Unlocks: Story 006 (燎原)
