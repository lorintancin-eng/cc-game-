# Story 007: 熔岩甲 Molten Aegis shield (火生土)

> **Epic**: Five Phases Synergy
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: M (~3h)
> **Manifest Version**: 2026-06-04.1
> **Last Updated**: (set by /dev-story)

## Context

**GDD**: `design/gdd/elements-five-phases.md` (熔岩甲 combo, Formula 5, Edge Cases)
**Requirement**: `TR-elem-003` (combo effect)

**ADR Governing Implementation**: ADR-0006 (Element System) + ADR-0007 (Combat damage pipeline)
**ADR Decision Summary**: When 火生土 active, Player gains a regenerating damage-absorbing shield. `shield_max=15+5/step` (cap 40), `regen=3+1/step per 5s` (cap 8), 2s grace after last hit. **Shield absorbs AFTER Formula 1 produces final_damage** (post-clamp): absorb `min(shield_hp, final_damage)`, excess → `Player.take_damage(excess)`.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Shield interception sits at the Player damage entry, after Combat Formula 1. Element matchups/crit already baked into final_damage before absorption.

**Control Manifest Rules (Feature)**:
- Required: shield params read from ComboManager `get_shield_params()` accessor
- Forbidden: shield logic in ComboManager (it only exposes params; Player owns the shield state)
- Guardrail: shield regen is timer/accumulator based, not per-frame allocation

## Acceptance Criteria

- [ ] AC-05: shield_hp=10, incoming final_damage=15 → shield absorbs 10, Player HP −5, shield=0
- [ ] AC-06: shield=0 + no damage for 2.0s → regen tick adds regen_rate (3 base)
- [ ] Formula 5: `shield_max=15+min(steps,5)×5`; `regen=3+min(steps,5)×1` per 5s; grace 2.0s
- [ ] Shield absorbs post-Formula-1 (element/crit baked in); excess passes to Player HP
- [ ] Edge (AC-19): shield regen continues during Ghost Market interlude (no combat damage to reset grace)
- [ ] Visible molten ring around player; breaks with a clear cue

## Implementation Notes

- Player holds `_shield_hp`, `_shield_max`, `_last_damage_time`. On 火生土 active (combo_activated), init shield from `get_shield_params()`.
- Damage entry: `absorbed = min(_shield_hp, final_damage); _shield_hp -= absorbed; excess = final_damage - absorbed; if excess>0: <apply to HP>; _last_damage_time = now`.
- `_process`/timer: if `now - _last_damage_time >= 2.0`, accumulate regen, add `regen_rate` per 5s up to `_shield_max`.

## Out of Scope

- Other combos. VFX polish of the ring (Visual story / VFX epic) — this story ships a functional placeholder ring.

## QA Test Cases

- **AC-05**: Given shield=10, When final_damage=15, Then absorbed=10, HP−5, shield=0. Edge: final_damage<shield → full absorb, HP unchanged.
- **AC-06**: Given shield=0 + 2.0s no damage, Then regen adds 3 (base). Edge: damage within grace resets the timer.
- **Formula 5 scaling**: steps=3 → shield_max=30, regen=6/5s.
- **Post-clamp**: Given a crit hit, Then shield absorbs the already-crit-multiplied final_damage.
- **AC-19**: regen continues during interlude.

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/element/molten_aegis_shield_test.gd` — absorb math, regen + grace, post-clamp order
**Status**: [ ] Not yet created

## Dependencies

- Depends on: Story 004 (ComboManager accessors), Story 005 (so 火生土 can activate via real element tags)
- Unlocks: None
