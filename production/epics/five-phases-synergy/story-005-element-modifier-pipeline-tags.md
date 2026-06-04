# Story 005: Wire element_modifier into Combat + element tags on .tres

> **Epic**: Five Phases Synergy
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: M (~3h)
> **Manifest Version**: 2026-06-04.1
> **Last Updated**: (set by /dev-story)

## Context

**GDD**: `design/gdd/elements-five-phases.md` (Overcoming Cycle §, Element Assignments §, Formula 1)
**Requirement**: `TR-elem-001` (pipeline-integration side)

**ADR Governing Implementation**: ADR-0007 (Combat — element_modifier slot, primary) + ADR-0006 (ElementMatchup) + ADR-0008 (Enemy element field)
**ADR Decision Summary**: Combat Formula 1 has a reserved `element_modifier` slot (pre-clamp): `final = min(raw × source × crit × element_modifier × pierce, 200)`. This story fills that slot from `ElementMatchup.modifier(weapon.element, enemy.element)` and adds the `element` field to weapon + enemy `.tres`.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Pipeline shape is fixed (ADR-0007); only the slot value changes. `MAX_FINAL_DAMAGE_PER_HIT=200` clamp bounds the result. Enemy `element` field is the 20th archetype field (ADR-0008).

**Control Manifest Rules (Core)**:
- Required: data-driven element via `.tres` (no hardcoded element in `.gd`); modifier applied pre-clamp
- Forbidden: changing Formula 1 multiplier order
- Guardrail: per-hit lookup is a small set test (Story 001)

---

## Acceptance Criteria

- [ ] `WeaponBase` gains `element: String` export; 6 weapons tagged (符箓/爆裂符=fire, 飞剑=metal, 雷法=water, 八卦阵/山印=earth)
- [ ] `EnemyArchetype` gains `element` field; 13 enemies tagged per GDD (anti-dormancy floor: both Bosses + ≥4 Stage-1 non-neutral)
- [ ] AC-13: Flying Sword (metal) hits Paper Doll (wood) → `element_modifier=1.3`; final = base × ... × 1.3 (pre-clamp)
- [ ] AC-14: Flying Sword (metal) hits Ghost Flame (fire) → `element_modifier=0.8`
- [ ] element_modifier applies in Formula 1 BEFORE the `max(0, ...)` / `min(.., 200)` clamp (per Combat OQ-4 pre-clamp)

## Implementation Notes

- Add `@export var element: String = "neutral"` to WeaponBase + EnemyArchetype; set in the 6 weapon scenes / 13 enemy `.tres`.
- In Combat's damage application, set `element_modifier = ElementMatchup.modifier(source.element, target.element)` (Story 001 util) at the pre-clamp position.
- Verify against ADR-0008 anti-dormancy floor: Famine Beast=earth, Ghost Market Judge=metal, ≥4 Stage-1 non-neutral.

## Out of Scope

- 相生 combos (Stories 006-010). This story is the 相克 matchup ONLY.
- ComboManager (Story 004).

## QA Test Cases

- **AC-13**: Given Flying Sword(metal) vs Paper Doll(wood), When damage applied, Then `element_modifier==1.3` AND it multiplies pre-clamp. Edge: at high source_modifier the clamp still caps at 200.
- **AC-14**: Given metal vs fire, Then `0.8`.
- **Coverage floor**: assert both Bosses + ≥4 Stage-1 enemies have non-neutral element in their `.tres`.
- **Data-driven**: changing a weapon's `.tres` element changes the matchup with no code change.

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/combat/element_modifier_pipeline_test.gd` — matchup applied pre-clamp; `.tres` tags present
**Status**: [ ] Not yet created

## Dependencies

- Depends on: Story 001 (ElementMatchup). Soft: ADR-0007/0008 (Accepted).
- Unlocks: 相克 matchup is live for all weapons; Story 006 (燎原 reads weapon.element via CombatEvents)
