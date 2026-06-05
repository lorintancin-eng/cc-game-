# Story 010: 春生回元 Vernal Restoration regen + XP (水生木)

> **Epic**: Five Phases Synergy
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: S (~2h)
> **Manifest Version**: 2026-06-04.1
> **Last Updated**: 2026-06-05

## Context

**GDD**: `design/gdd/elements-five-phases.md` (春生回元 combo, Formula 7)
**Requirement**: `TR-elem-003` (combo effect)

**ADR Governing Implementation**: ADR-0006 (Element System)
**ADR Decision Summary**: When 水生木 active, Player regenerates `2 HP / 4s` (+1/step, cap 7) unconditionally (works while taking damage), and XP orb pickup value +15% (+5%/step, cap 40%, multiplicative with existing XP gain).

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Pure Player-side timer/accumulator + an XP pickup multiplier. No new systems.

**Control Manifest Rules (Feature)**:
- Required: params from ComboManager `get_regen_params()`; HP regen clamped to max_hp
- Forbidden: regen logic in ComboManager (Player owns HP state)
- Guardrail: accumulator-based regen, not per-frame allocation

## Acceptance Criteria

- [x] AC-11: 水生木 active → Player +2 HP every 4s (or scaled), clamped to max_hp; works even while taking damage
- [x] AC-12: with +30% XP bonus, XP orb worth 5.5 → effective 5.5 × 1.30 = 7.15
- [x] Formula 7: `hp_regen = 2 + min(steps,5)×1` per 4s (cap 7); `xp_bonus = 0.15 + min(steps,5)×0.05` (cap 0.40)
- [x] XP bonus is multiplicative with existing XP-gain upgrades

## Implementation Notes

- Player: on 水生木 active, read `get_regen_params() -> {hp_per_4s, xp_bonus}`. Accumulate time; every 4s add `hp_per_4s` to HP (clamp max_hp).
- XP pickup: when collecting an XP orb, multiply its value by `(1 + xp_bonus)` (after existing xp_gain multipliers — multiplicative).

## Out of Scope

- Other combos. XP orb pickup base mechanic (Pickup/Experience epics) — this only applies the bonus multiplier.

## QA Test Cases

- **AC-11**: Given 水生木 active, When 4s elapse, Then HP +2 (clamped). Edge: regen continues while taking damage (unconditional).
- **AC-12**: Given xp_bonus=0.30, orb=5.5, Then effective 7.15. Edge: stacks multiplicatively with a +XP upgrade.
- **Formula 7**: steps=3 → 5 HP/4s, +30% XP.
- **Clamp**: regen never exceeds max_hp.

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/element/vernal_restoration_test.gd` — regen rate + clamp, XP multiplier, Formula 7 scaling
**Status**: [x] Created — 14 tests, all green (`tests/unit/element/vernal_restoration_test.gd`); full suite 384/384 green under CI-equivalent `-gconfig`

## Dependencies

- Depends on: Story 004 (ComboManager), Story 005 (水生木 activation)
- Unlocks: None

## Completion Notes

**Completed**: 2026-06-05
**Criteria**: 4/4 passing (AC-11, AC-12, Formula 7, multiplicative XP) — no deferred items
**Deviations**: None blocking. Implementation follows ADR-0006 Decision 3 exactly — Player reads `ComboManager.get_regen_params()` and owns HP state (regen via `heal()`, clamped to `max_hp`; regen logic lives in Player, NOT ComboManager). `VERNAL_REGEN_INTERVAL` is a named const; combo tuning constants live in ComboManager — no hardcoded balance.
**Known limitation (follow-up)**: Only base `Player.tscn` (修行者) has a `ComboManager` child node, so the Five Phases combo effects currently apply only to 修行者. `PlayerSunWukong.tscn` (and other character scenes) have NO `ComboManager`, so combos are inert for them. The null guard in `_tick_vernal_regen` / `_vernal_xp_bonus` makes this safe (no crash). Adding `ComboManager` to the other character scenes is future work.
**Related fix (separate commit)**: A Story-005 regression was fixed in the same working session — `scripts/weapon/sun_wukong/jingu_bang_v2.gd` removed an `@export var element` redeclaration that collided with the inherited `WeaponBase.element` (Story 005), which was a GDScript parse error; `scenes/player/PlayerSunWukong.tscn` sets `element = "metal"` on the JinguBangV2 node. This ships as a separate `fix:` commit, not part of Story 010.
**Test Evidence**: Logic — `tests/unit/element/vernal_restoration_test.gd` (14 tests, all green). Full suite 384/384 green under CI-equivalent `-gconfig`, no parse/load errors.
**Code Review**: APPROVED — `/code-review` run (lead-programmer: ADR-0006 compliant, 6/6 standards, SOLID, architecture clean, no required changes; qa-tester: all 4 ACs + all QA cases covered, deterministic).
