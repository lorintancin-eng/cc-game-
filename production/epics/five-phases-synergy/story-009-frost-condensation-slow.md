# Story 009: 寒露凝锋 Frost slow (金生水)

> **Epic**: Five Phases Synergy
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: M (~3h)
> **Manifest Version**: 2026-06-04.1
> **Last Updated**: (set by /dev-story)

## Context

**GDD**: `design/gdd/elements-five-phases.md` (寒露凝锋 combo, Formula 6, Edge Cases) + `design/gdd/status-effects.md` (frost_slow effect, refresh-only)
**Requirement**: `TR-elem-003` (combo) — frost_slow status portion cites `status-effects.md` as contract (TR-status-* / ADR-0012 pending)

**ADR Governing Implementation**: ADR-0006 (Element System) — primary. **Cross-system: the `frost_slow` refresh-only guard is OWNED by Status Effects** (ADR-0006 R-3); Status Effects has no ADR yet (ADR-0012 pending) → cite `status-effects.md` as the contract source for the stacking rule.
**ADR Decision Summary**: When 金生水 active, every weapon hit applies `frost_slow` to the target: `move_speed × 0.7` for 1.5s (+0.3s/step, cap 3.0s). Refresh-only (reapply refreshes duration, intensity never compounds). Boss IS affected on `move_speed` (NOT `charge_speed` — Boss Charge stays a full-speed threat, OQ-2 default).

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: frost_slow is a NEW status effect in the Status Effects registry. **Refresh-only guard MUST live in Status Effects** (not ComboManager) — else simultaneous multi-weapon hits (Thunder Law multi-target + Flying Sword same frame) race two "apply slow" calls (R-3). Boss slow targets `move_speed` field only.

> **DECISION (2026-06-06, user — autopilot escalation)**: the Status Effects registry
> (ADR-0006 R-3 / status-effects.md / ADR-0012) is NOT built. **frost_slow is
> TARGET-OWNED (minimal)**: the Enemy holds its own `_frost_slow_factor` +
> `_frost_slow_remaining` (refresh-only — reapply refreshes duration, intensity never
> compounds), exposes `apply_frost_slow(factor, duration)`, ticks it down, and applies
> the factor to its own movement (`move_speed` field). Weapons call `apply_frost_slow`
> on hit when 金生水 active (the Story-005 weapon-hit sites). This is race-free (each
> enemy guards its own state, like it owns its HP) and honors R-3's refresh-only intent;
> it deviates from R-3's literal "registry" wording. A future Status Effects epic
> migrates frost_slow + immobilize + burn into a central registry.

**Control Manifest Rules (Feature)**:
- Required: frost_slow registered in Status Effects with refresh-only semantics (distinct from generic multiplicative slow)
- Forbidden: applying the ×0.7 directly in ComboManager (must go through the Status Effects effect so the refresh guard is centralized)
- Guardrail: refresh-only — intensity never compounds under simultaneous hits

## Acceptance Criteria

- [ ] AC-09: 金生水 active → every weapon hit sets target `move_speed × 0.7` for 1.5s (or scaled); reapply refreshes duration, does NOT stack intensity
- [ ] AC-10: hit on Boss → Boss `move_speed` reduced to ×0.7 (Boss NOT immune); `charge_speed` UNAFFECTED (Charge stays full-speed)
- [ ] Formula 6: `slow_duration = 1.5 + min(steps,5)×0.3` (cap 3.0); SLOW_FACTOR=0.7 (constant)
- [ ] Refresh-only guard owned by Status Effects (simultaneous hits don't double-apply)
- [ ] Frost VFX overlay on slowed enemies

## Implementation Notes

- ComboManager / weapon-hit path: when 金生水 active, on each hit call `StatusEffects.apply(target, "frost_slow", duration)`.
- **Status Effects side** (cite `status-effects.md`): `frost_slow` is refresh-only — reapply sets `expiry = now + duration` (max), never multiplies the 0.7 again. This guard is the load-bearing part (R-3) — implement it in the Status Effects registry, not here.
- Boss: apply to `move_speed` only; do NOT touch `charge_speed` (OQ-2 v0.5 default).

## Out of Scope

- The broader Status Effects framework / ADR-0012 (separate epic) — this story adds the ONE frost_slow effect + its refresh-only guard, citing status-effects.md.
- Other combos.

## QA Test Cases

- **AC-09**: Given 金生水 active, When hit, Then target move_speed×0.7 for 1.5s; reapply → duration refreshed, speed still ×0.7 (not ×0.49).
- **AC-10**: Given a hit on Boss, Then Boss move_speed×0.7 AND charge_speed unchanged. Edge: enrage ×1.35 then frost — slow applies to current move_speed.
- **Refresh-only (R-3)**: Given two weapons hit same frame, Then exactly one ×0.7 applied (no compound). 
- **Formula 6**: steps=1 → 1.8s; cap at 3.0s.

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/element/frost_slow_test.gd` — apply, refresh-only, Boss move_speed-only, simultaneous-hit guard
**Status**: [ ] Not yet created

## Dependencies

- Depends on: Story 004 (ComboManager), Story 005 (金生水 activation). **Cross: Status Effects registry must accept the frost_slow effect** (cite status-effects.md; ADR-0012 pending — if Status Effects is unbuilt, the refresh-only guard ships with this story as the first registry entry).
- Unlocks: None
