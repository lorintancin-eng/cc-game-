# Story 006: 燎原 Wildfire chain burst (木生火)

> **Epic**: Five Phases Synergy
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: M (~3-4h)
> **Manifest Version**: 2026-06-04.1
> **Last Updated**: (set by /dev-story)

## Context

**GDD**: `design/gdd/elements-five-phases.md` (燎原 combo, Formula 3/4, Edge Cases, OQ-7)
**Requirement**: `TR-elem-004`

**ADR Governing Implementation**: ADR-0006 (Element System — CombatEvents bus + 燎原 pipeline contract)
**ADR Decision Summary**: When 木生火 is active and a Fire-element weapon kills an enemy, spawn a fire burst at the death location (40px base, +8/step, cap 80@7) dealing 50% of the killing blow to enemies in range; chains up to 3 (no decay). Burst is `damage_type=EXPLOSION, source_kind=WEAPON`, **bypasses Formula 1** (direct `take_damage`) — the source killing-blow is already clamped so burst ≤100. Driven by `CombatEvents.enemy_killed`, NOT per-enemy connect.

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: Connect ONCE to `CombatEvents.enemy_killed` (Story 003). Burst uses an Area2D / radius query for in-range enemies. **OQ-7 (R-4): the 3-chain cascade is a BLOCKING playtest gate** — chain-kill count per trigger must be validated against Combat's aggregate-DPS expectations before this ships.

**Control Manifest Rules (Feature)**:
- Required: 燎原 reacts to `CombatEvents.enemy_killed` (bus), not per-enemy `died`
- Forbidden: routing burst through Formula 1's source_modifier (it's a derived EXPLOSION value)
- Guardrail: max 3 chains per trigger; respect the 84-enemy perf budget (no per-burst tree scan — use the Targeting cache / Area2D)

## Acceptance Criteria

- [ ] AC-02: 燎原 active + Fire weapon kills enemy with 3 others within 40px → burst deals 50% of killing-blow to all 3
- [ ] AC-03: burst kills a 2nd enemy AND chain<3 → new burst at the 2nd death location; chain counter increments
- [ ] AC-04: chain=3 AND a chain burst kills another → no further burst (cap)
- [ ] Formula 4: `burst_damage = killing_blow × 0.5`; radius = 40 + min(steps,5)×8 (cap 80)
- [ ] Burst is EXPLOSION-type, bypasses Formula 1; chain damage does NOT decay
- [ ] Edge: burst CAN hit the Boss + summons; chain kills count toward kill stats + drop pickups
- [ ] **OQ-7 playtest gate signed off** before merge

## Implementation Notes

- In ComboManager, `_on_enemy_killed(kill_data)`: if `is_combo_active("木生火")` and `kill_data.source_element=="fire"` → spawn burst at `kill_data.position`.
- Burst: query enemies within radius (Area2D or Targeting cache), `enemy.take_damage(burst_damage, EXPLOSION, WEAPON, self)`; if a hit kills + chain<3, recurse at that position (chain+1).
- radius from ComboManager scaling accessor; `burst_damage = kill_data.damage × WILDFIRE_DAMAGE_RATIO(0.5)`.

## Out of Scope

- Other 4 combos (Stories 007-010). CombatEvents bus itself (Story 003).

## QA Test Cases

- **AC-02**: Given 燎原 active + 3 enemies in 40px, When fire-weapon kill, Then 3 take `killing_blow×0.5`. 
- **AC-03/04**: chain to 2nd death; cap at 3 (4th chain does not spawn). Edge: dense 10-enemy cluster — assert ≤ WILDFIRE_MAX_CHAINS triggers (OQ-7).
- **Non-fire kill**: Given a metal-weapon kill, Then no burst (source_element gate).
- **Bypass**: burst damage not affected by source_modifier; equals 0.5×killing_blow exactly.
- **Playtest (manual, BLOCKING)**: OQ-7 — in a 2:00 Stage-2 wave, chain cascade does not exceed the aggregate-DPS ceiling expectation; sign off in evidence doc.

## Test Evidence

**Story Type**: Integration (+ playtest gate)
**Required evidence**: `tests/integration/element/wildfire_chain_test.gd` (chain logic, cap, gate) + `production/qa/evidence/wildfire-oq7-playtest.md` (OQ-7 sign-off)
**Status**: [ ] Not yet created

## Dependencies

- Depends on: Story 003 (CombatEvents bus), Story 004 (ComboManager), Story 005 (weapon.element so source_element is meaningful)
- Unlocks: None (leaf combo)
