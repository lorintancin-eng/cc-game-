# Story 005: Wire element_modifier into Combat + element tags on .tres

> **Epic**: Five Phases Synergy
> **Status**: Complete
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: M (~3h)
> **Manifest Version**: 2026-06-04.1
> **Last Updated**: 2026-06-05

## Context

**GDD**: `design/gdd/elements-five-phases.md` (Overcoming Cycle §, Element Assignments §, Formula 1)
**Requirement**: `TR-elem-001` (pipeline-integration side)

**ADR Governing Implementation**: ADR-0007 (Combat — element_modifier slot, primary) + ADR-0006 (ElementMatchup) + ADR-0008 (Enemy element field)
**ADR Decision Summary**: ADR-0007 §4 specifies Formula 1 with a reserved `element_modifier` slot (pre-clamp). This story fills the element-matchup intent from `ElementMatchup.modifier(weapon.element, enemy.element)` and adds the `element` field to weapon + enemy data.

> **AS-BUILT NOTE (decided 2026-06-05, /story-readiness)**: ADR-0007 §4's Formula 1 pipeline (`min(raw × source_modifier × crit × element_modifier × pierce, 200)`) and the multi-param `take_damage(amount, damage_type, source_kind, source)` are **design intent, NOT as-built**. Real code: `Enemy.take_damage(amount: float)` is single-param, weapons call `body.call("take_damage", damage)` with a flat float, and there is no central pipeline, no `element_modifier` slot, and no `MAX_FINAL_DAMAGE_PER_HIT=200` clamp. **This story applies the matchup WEAPON-SIDE**: at hit time the weapon/projectile multiplies its outgoing damage by `ElementMatchup.modifier(weapon.element, target.element)` before the flat `take_damage` call. The single-param `take_damage` signature is retained; building the full Formula 1 pipeline is a separate future Combat story.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Weapon-side multiply — no change to `take_damage` signature, no pipeline refactor. Enemy `element` field added to `EnemyArchetype` (ADR-0008 archetype schema). Modifier is the stateless `ElementMatchup` lookup from Story 001.

**Control Manifest Rules (Core)**:
- Required: data-driven element via `.tres` (no hardcoded element in `.gd`); modifier applied pre-clamp
- Forbidden: changing Formula 1 multiplier order
- Guardrail: per-hit lookup is a small set test (Story 001)

---

## Acceptance Criteria

- [x] `WeaponBase` gains `element: String` export; 6 weapons tagged (符箓/爆裂符=fire, 飞剑=metal, 雷法=water, 八卦阵/山印=earth)
- [x] `EnemyArchetype` gains `element` field; 13 enemies tagged per GDD (anti-dormancy floor: both Bosses + ≥4 Stage-1 non-neutral)
- [x] AC-13: Flying Sword (metal) hits Paper Doll (wood) → `ElementMatchup.modifier("metal","wood")==1.3`; the weapon's dealt damage is multiplied by 1.3 at hit time
- [x] AC-14: Flying Sword (metal) hits Ghost Flame (fire) → `ElementMatchup.modifier("metal","fire")==0.8`; dealt damage multiplied by 0.8
- [x] Weapon-side application: the matchup multiplier is applied to outgoing damage BEFORE the flat `take_damage(amount)` call (no central Formula 1 pipeline / clamp exists as-built — see AS-BUILT NOTE)

## Implementation Notes

- Add `@export var element: String = "neutral"` to WeaponBase + EnemyArchetype; set in the 6 weapon scripts/scenes / 13 enemy `.tres`.
- **Weapon-side**: where a weapon/projectile resolves its hit and currently calls `take_damage(damage)`, first compute `var mod := ElementMatchup.modifier(self.element, target.element)` (Story 001 util, target's element read from its archetype) and pass `damage * mod`. A `"neutral"` on either side returns 1.0 (no change). Guard: only call modifier when the target exposes an `element` (else treat as neutral → 1.0).
- Keep the single-param `take_damage(amount: float)` signature untouched.
- Verify against ADR-0008 anti-dormancy floor: Famine Beast=earth, Ghost Market Judge=metal, ≥4 Stage-1 non-neutral.

## Out of Scope

- 相生 combos (Stories 006-010). This story is the 相克 matchup ONLY.
- ComboManager (Story 004).

## QA Test Cases

- **AC-13**: Given Flying Sword(metal) vs Paper Doll(wood), When the weapon resolves the hit, Then the dealt damage == base × 1.3 (`ElementMatchup.modifier("metal","wood")==1.3`). Edge: neutral target → ×1.0 (unchanged).
- **AC-14**: Given metal vs fire, Then dealt damage == base × 0.8 (`modifier==0.8`).
- **Coverage floor**: assert both Bosses + ≥4 Stage-1 enemies have non-neutral element in their `.tres`.
- **Data-driven**: changing a weapon's or enemy's `element` value changes the matchup with no code change.

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/combat/element_modifier_pipeline_test.gd` — matchup applied pre-clamp; `.tres` tags present
**Status**: [x] Created and passing — `tests/integration/combat/element_modifier_pipeline_test.gd` (8 tests, 23 asserts, 8/8 green; full suite 370/370 green under CI-equivalent `-gconfig`)

## Dependencies

- Depends on: Story 001 (ElementMatchup). Soft: ADR-0007/0008 (Accepted).
- Unlocks: 相克 matchup is live for all weapons; Story 006 (燎原 reads weapon.element via CombatEvents)

## Completion Notes

**Completed**: 2026-06-05
**Criteria**: 5/5 passing (all COVERED by the integration test; 0 untested, 0 deferred)
**Deviations**: None blocking. The weapon-side multiply (each weapon/projectile multiplies outgoing damage by `ElementMatchup.modifier(element, target.element)` before the flat `take_damage(amount)` call) is the **deliberate as-built approach documented in the AS-BUILT NOTE** — it is NOT a deviation from the story. ADR-0007 §4's full Formula 1 pipeline + multi-param `take_damage` remain design intent for a separate future Combat story. Manifest version matches (2026-06-04.1, no staleness). Element values are data-driven (Player.tscn scene overrides + 13 enemy `.tres`); only the `"neutral"` default literal lives in `.gd`.
**Forward dependency**: `enemy.gd` `_last_kill_source_element` stays `"neutral"` because the weapon-side approach does not thread the source weapon's element into the single-param `take_damage` — flagged via a `TODO(Story-006)` comment in `enemy.gd`. This is a Story 006 (燎原) obligation, not a Story 005 deviation; Story 005's ACs only require the per-hit matchup multiplier, which is fully delivered.
**Test Evidence**: Integration test at `tests/integration/combat/element_modifier_pipeline_test.gd` — 8 tests, 23 asserts, 8/8 green (full suite 370/370 green under CI-equivalent `-gconfig`).
**Code Review**: Complete — APPROVED. `/code-review` (lead-programmer): ADR-0006/0007/0008 compliant, 6/6 standards, SOLID, architecture clean, no required changes. One advisory (`_last_kill_source_element` stub) forwarded to Story 006.
