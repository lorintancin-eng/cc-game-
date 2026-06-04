# Story 001: ElementMatchup lookup util

> **Epic**: Five Phases Synergy
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: S (~2h)
> **Manifest Version**: 2026-06-04.1
> **Last Updated**: 2026-06-04 (implemented — 32/32 tests green; pending /code-review → /story-done)

## Context

**GDD**: `design/gdd/elements-five-phases.md` (Formula 1, Overcoming Cycle §)
**Requirement**: `TR-elem-001`

**ADR Governing Implementation**: ADR-0006 (Element System Pipeline) — primary; ADR-0007 (Combat — element_modifier slot consumer)
**ADR Decision Summary**: `ElementMatchup` is a stateless pure-function lookup living in the Combat module; `modifier(src, tgt) -> float` returns one of {0.8, 1.0, 1.3} from the `favorable_set` algorithm. Combat fills its Formula 1 `element_modifier` slot from this.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Pure function, no nodes, no signals. No post-cutoff API. Trivially unit-testable + deterministic.

**Control Manifest Rules (Core/Combat)**:
- Required: typed GDScript (`static func modifier(src: String, tgt: String) -> float`)
- Forbidden: storing state in this util (it must be stateless)
- Guardrail: per-hit hot path — keep the lookup to a small set membership test, no allocation

---

## Acceptance Criteria

*From GDD, scoped to this story:*

- [ ] AC-13: Metal vs Wood (favorable, 金克木) → `1.3`
- [ ] AC-14: Metal vs Fire (unfavorable, 火克金) → `0.8`
- [ ] AC-14b: each favorable pair {(wood,earth),(earth,water),(water,fire),(fire,metal)} → `1.3`
- [ ] AC-14c: each unfavorable mirror {(earth,wood),(water,earth),(fire,water),(metal,fire)} → `0.8`
- [ ] AC-14d: unrelated pairs (e.g. metal→water) → `1.0` (all 10 unrelated ordered pairs)
- [ ] AC-14e: neutral on either side (metal→neutral, neutral→fire) → `1.0`
- [ ] AC-20: invalid element string → `push_error()` + treated as neutral (returns 1.0)

---

## Implementation Notes

*Derived from ADR-0006 + Five Phases Formula 1:*

- `favorable_set = {(metal,wood),(wood,earth),(earth,water),(water,fire),(fire,metal)}`
- Algorithm: if `"neutral"` in (src,tgt) → 1.0; if `(src,tgt)` in favorable_set → `FAVORABLE_MOD` (1.3); if `(tgt,src)` in favorable_set → `UNFAVORABLE_MOD` (0.8); else 1.0 (same element / unrelated).
- Constants `FAVORABLE_MOD=1.3`, `UNFAVORABLE_MOD=0.8` exposed for tuning (registry `favorable_element_modifier`/`unfavorable_element_modifier`).
- Validate element strings against the closed set `{metal,wood,water,fire,earth,neutral}`; invalid → `push_error()` + return 1.0.
- This is the 相克 (overcoming) modifier ONLY. 相生 (generating) is the combo system (Stories 004,006-010), NOT this table.

---

## Out of Scope

- Story 005: wiring this into Combat Formula 1's element_modifier slot + element tags on `.tres`
- Combo (相生) effects: Stories 004, 006-010

---

## QA Test Cases

- **AC-13/14b** (favorable): Given each of the 5 favorable ordered pairs, When `modifier(src,tgt)`, Then returns `1.3`. Edge: all 5 pairs, not just metal→wood (guards a dropped tuple).
- **AC-14/14c** (unfavorable): Given each of the 5 reversed pairs, When `modifier`, Then `0.8`.
- **AC-14d** (unrelated): Given metal→water + the other 9 unrelated ordered pairs, When `modifier`, Then `1.0`. Edge: this is the branch most likely to regress to a wrong 0.8/1.3.
- **AC-14e** (neutral): Given (metal,neutral) AND (neutral,fire), Then `1.0` (both directions short-circuit).
- **AC-20** (invalid): Given src="lightning", Then `push_error` fired AND returns `1.0`.
- Determinism: pure function, same input → same output, no RNG.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/combat/element_matchup_test.gd` — must exist and pass (covers all 25 ordered pairs + neutral + invalid)
**Status**: [x] Created — **32/32 passing** (Godot 4.6.stable / GUT 9.6.0, headless, 0.49s). Impl: `scripts/combat/element_matchup.gd` (`class_name ElementMatchup`, stateless static `modifier()`).

---

## Dependencies

- Depends on: None (pure util — start here)
- Unlocks: Story 005 (element_modifier pipeline wiring)
