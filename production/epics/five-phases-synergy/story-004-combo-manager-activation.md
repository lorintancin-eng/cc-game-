# Story 004: ComboManager skeleton + activation

> **Epic**: Five Phases Synergy
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: M (~3-4h)
> **Manifest Version**: 2026-06-04.1
> **Last Updated**: 2026-06-05

## Context

**GDD**: `design/gdd/elements-five-phases.md` (Formula 2 activation, Formula 3 scaling, Core Rules 4-7)
**Requirement**: `TR-elem-003`

**ADR Governing Implementation**: ADR-0006 (Element System Pipeline)
**ADR Decision Summary**: `ComboManager` is a per-Player child node (NOT autoload, NOT Resource), signal-driven. Connects to `Player.element_inventory_changed` (after run-init), recomputes the active-combo set (Formula 2) + scaling (Formula 3), emits `combo_activated(combo_id)` on a newly-activated pair. Exposes read accessors for the 5 effects; does NOT implement the effects inline. No `_process` polling.

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: Per-Player child node — resets with the run (matches run lifecycle). Must connect to `element_inventory_changed` only AFTER Player seeds the inventory (R-2 — await a `run_initialized` signal). Recompute is event-driven only, never per-frame.

**Control Manifest Rules (Feature)**:
- Required: ComboManager is a Player-child node; combos recompute on inventory-change signal only
- Forbidden: ComboManager as autoload (holds per-run state — must reset per run); per-frame polling
- Guardrail: recompute fires ~1/level-up (~10-15×/run), not per frame

---

## Acceptance Criteria

- [x] AC-01: Given inventory `{fire:1, earth:0}`, When an Earth upgrade applied → `{fire:1, earth:1}`, Then `combo_activated("火生土")` fires
- [x] Formula 2: a generating pair activates when inventory has ≥1 of each element in the pair (5 pairs: 木生火/火生土/土生金/金生水/水生木)
- [x] Core Rule 6: combos persist once activated (cannot deactivate)
- [x] Core Rule 7 / AC-18: all 5 generating combos can coexist; with all 5 elements ≥1, all 5 active; no special "五行齐全" bonus
- [x] Formula 3: scaling = `min(pair_element_total - 2, MAX_SCALE_STEPS=5) × STEP` — exposed per-combo via accessors
- [x] Read accessors present: `is_combo_active(id)`, `get_pierce_bonus()`, `get_ore_crit_chance()`, `get_shield_params()`, `get_regen_params()` (effects implemented in Stories 006-010)
- [x] R-2: does not emit `combo_activated` mid-init (connects after `run_initialized`)

---

## Implementation Notes

*Derived from ADR-0006 §Decision 3 + Formula 2/3:*

- `extends Node`, child of Player. In `_ready()`: await Player `run_initialized`, then `Player.element_inventory_changed.connect(_on_inventory_changed)`.
- `_on_inventory_changed(inv)`: for each of the 5 generating pairs, `active = inv[A]>=1 and inv[B]>=1`; on a pair newly true (was false), add to `_active_combos` + emit `combo_activated(combo_id)`. Never remove (Rule 6).
- Scaling: `_scale_steps[pair] = min(inv[A]+inv[B]-2, 5)`; accessors compute effect values from steps (e.g. shield = 15 + steps×5).
- This story builds the activation engine + accessors + the activation VFX/signal; the 5 effects themselves are Stories 006-010 (they READ these accessors / connect to `combo_activated`).

---

## Out of Scope

- Stories 006-010: the actual 5 combo effects (燎原/熔岩甲/矿脉精粹/寒露凝锋/春生回元)
- Story 011: the LevelUpPanel "相生!" proximity hint (reads ComboManager state)

---

## QA Test Cases

- **AC-01**: Given `{fire:1}`, When earth→1, Then `combo_activated("火生土")` once. Edge: adding fire when wood≥1 AND earth≥1 activates BOTH 木生火 and 火生土 (double activation).
- **Formula 2**: Given each of the 5 pairs satisfied, Then the right combo activates; given only 1 element of a pair, Then it does not.
- **AC-18**: Given all 5 elements ≥1, Then all 5 combos active; no extra bonus.
- **Rule 6 (persist)**: Given a combo active, When inventory changes such that the pair would no longer be 1+1 (not possible by increment-only, but test the guard), Then it stays active.
- **Formula 3 (scaling)**: Given pair total=5, Then steps=3; accessor returns base + 3×step. Edge: total=7+ clamps at 5 steps.
- **R-2 (init order)**: Given seed produces an active combo at run-start (Node 11), Then `combo_activated` fires AFTER `run_initialized`, not during seeding.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/element/combo_manager_test.gd` — activation (Formula 2), scaling (Formula 3), persistence, double-activation, init-order
**Status**: [x] Created — 30 tests, all green (full suite 362/362 under `-gconfig`)

---

## Dependencies

- Depends on: Story 002 (element_inventory + `element_inventory_changed` + `run_initialized`)
- Unlocks: Stories 006, 007, 008, 009, 010 (the 5 effects), Story 011 (hint)

---

## Completion Notes

**Completed**: 2026-06-05
**Criteria**: 7/7 passing (no deferred items)
**Deviations**: None blocking. ADVISORY: tuning constants are named consts at the top of `combo_manager.gd` (acceptable for this Feature-activation engine; ADR-0006 schedules their migration to `.tres` in Stories 006-010). Manifest version matches (`2026-06-04.1`); ComboManager confirmed NOT an autoload and contains no `_process` polling (ADR-0006 forbidden patterns avoided).
**Test Evidence**: Logic unit test at `tests/unit/element/combo_manager_test.gd` — 30 tests green (full suite 362/362 green under CI-equivalent `-gconfig=res://tests/.gutconfig.json`).
**Code Review**: Complete — `/code-review` APPROVED (lead-programmer: full ADR-0006 compliance, 6/6 standards, SOLID; qa-tester: TESTABLE, all 7 ACs + 9 QA cases covered, no blocking gaps).
