# Story 008: 矿脉精粹 Ore Refinement pierce + crit (土生金)

> **Epic**: Five Phases Synergy
> **Status**: Complete (weapon-side crit + pierce; crit-flash VFX deferred)
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: M (~3h)
> **Manifest Version**: 2026-06-04.1
> **Last Updated**: 2026-06-06

> **Completion (2026-06-06, autopilot)**: Weapon-side per the DECISION above.
> `ComboManager.roll_ore_crit()` (seeded-RNG ×1.5 on a `get_ore_crit_chance()` success,
> ADR-0006 R-6) + the shared `WeaponBase.apply_combo_effects(cm, target, dmg)` multiply
> the per-hit crit at all 6 修行者 weapon sites (projectiles carry the ComboManager via
> spawn; direct weapons via `owner_combo_manager()`). Pierce: `FlyingSwordWeapon._get_pierce_count()`
> += `get_pierce_bonus()`; Bagua +15% tick (pierce-equivalent for the aura). Evidence:
> `tests/unit/element/ore_frost_weapon_effects_test.gd` — 9 tests (roll determinism/range,
> crit multiply, pierce guard); full suite 425/425. **Formula 8 note**: `maxf(fire_eyes,
> ore_crit)` collapses to `ore_crit` for 修行者 — the only character with a ComboManager;
> fire_eyes is Sun Wukong-only and Sun Wukong has no ComboManager, so the collision is
> moot in v0.5. **Deferred**: the crit-flash visual feedback (headless).

## Context

**GDD**: `design/gdd/elements-five-phases.md` (矿脉精粹 combo, Formula 3/8)
**Requirement**: `TR-elem-005`

**ADR Governing Implementation**: ADR-0006 (Element System — Formula 8 crit resolution) + ADR-0007 (Combat crit_multiplier slot)
**ADR Decision Summary**: When 土生金 active, all weapons gain +1 pierce (Bagua gets +15% tick instead). Plus a per-hit crit: `crit_multiplier = maxf(fire_eyes_modifier, ore_crit_roll)` where ore_crit_roll = 1.5 on success (chance = 2%/step, cap 12%@7... aligned to Formula 3 = 10%@step-5). **Pull model, `maxf` (typed) not `max(Variant)`, seeded RNG for determinism.**

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: `crit_multiplier` is a shared Combat Formula 1 slot — 矿脉精粹 + Active Skills 火眼金睛 resolve by `maxf()` (Formula 8). Crit roll uses a ComboManager-owned **seeded `RandomNumberGenerator`** (test determinism), NOT global `randf()`. Combat pulls both publishers at calc time.

> **DECISION (2026-06-06, user — autopilot escalation)**: ADR-0007's central Formula-1
> `crit_multiplier` slot is NOT built (as-built: weapons call flat `take_damage(float)`).
> **Crit is implemented WEAPON-SIDE** — matching Story 005's element-matchup approach +
> the existing Sun Wukong `_get_fire_eyes_modifier`: at each of the 6 weapon hit sites,
> multiply `damage × maxf(fire_eyes_modifier, ore_crit_roll)` before the flat `take_damage`
> call. `ore_crit_roll` returns 1.5 on a seeded-RNG success (ComboManager `_rng`, chance =
> `get_ore_crit_chance()`), else 1.0. Pierce: wire `FlyingSwordWeapon._get_pierce_count()`
> to add `ComboManager.get_pierce_bonus()` (+ Bagua +15% tick). The central Formula-1
> pipeline (ADR-0007) stays design intent for a future Combat-refactor story; a short
> ADR-0007 "weapon-side v0.5" note should follow.

**Control Manifest Rules (Feature)**:
- Required: `maxf(float,float)` in the per-hit path; seeded RNG injectable for tests
- Forbidden: global `randf()` (breaks test determinism); push model on the crit slot (frame-order-dependent)
- Guardrail: pierce +1 must not breach the Flying Sword cluster-wipe concern (Level Up Pool pierce cap interaction — pierce combo is +1 beyond the stack cap; document)

## Acceptance Criteria

- [ ] AC-07: 土生金 active → Flying Sword pierce_count = base(3) + 1 = 4; Bagua gets +15% tick instead (pierce meaningless for aura)
- [ ] AC-08: at 4 total Earth+Metal points (2 steps) → 4% crit chance per hit; ×1.5 on crit
- [ ] AC-21: Sun Wukong with 火眼金睛 + 矿脉精粹, elite hit + ore-crit success → `crit_multiplier = maxf(1.2, 1.5) = 1.5` (NOT 1.8)
- [ ] Formula 8: `crit_multiplier = maxf(fire_eyes_modifier, ore_crit_roll)`; crit roll via seeded RNG
- [ ] Formula 3: crit chance = `min(steps,5)×2%` (cap 10% at step 5)

## Implementation Notes

- ComboManager exposes `get_pierce_bonus() -> int` (1 when active, 0 else) and `get_ore_crit_chance() -> float`. Weapons add the pierce bonus; Bagua adds +15% tick.
- Combat crit resolution (per Formula 8): `crit = maxf(active_skills.get_fire_eyes_modifier(target), _roll_ore_crit())` where `_roll_ore_crit()` uses ComboManager's seeded `_rng.randf() < chance ? 1.5 : 1.0`.
- Tests inject a pre-seeded RNG.

## Out of Scope

- 火眼金睛 itself (Active Skills epic) — this story only resolves the shared slot via maxf.
- Other combos.

## QA Test Cases

- **AC-07**: Given 土生金 active, Then Flying Sword pierce=4; Bagua tick +15% (not pierce).
- **AC-08**: Given 2 steps, Then crit chance=4%; with seeded RNG forcing success, damage ×1.5.
- **AC-21**: Given fire_eyes=1.2 (elite) + ore roll=1.5, Then crit=1.5 (maxf), never 1.8. Given non-crit roll on a normal enemy, Then maxf(1.0,1.0)=1.0.
- **Determinism**: seeded RNG → same crit sequence every run.
- **Pierce-cap interaction**: document that combo +1 pierce is beyond Level Up Pool max_stacks=2.

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/element/ore_refinement_crit_test.gd` — pierce bonus, maxf resolution, seeded crit, Formula 3 chance
**Status**: [ ] Not yet created

## Dependencies

- Depends on: Story 004 (ComboManager), Story 005 (土生金 activation), ADR-0007 crit slot
- Unlocks: None
