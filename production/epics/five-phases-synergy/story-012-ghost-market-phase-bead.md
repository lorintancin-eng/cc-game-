# Story 012: Ghost Market 五行灵珠 (Phase Bead) + element tags

> **Epic**: Five Phases Synergy
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: M (~3h)
> **Manifest Version**: 2026-06-04.1
> **Last Updated**: (set by /dev-story)

## Context

**GDD**: `design/gdd/elements-five-phases.md` (Integration with Ghost Market §, AC-17) + `design/gdd/ghost-market-trade.md` (Phase Bead stall §)
**Requirement**: `TR-elem-003` (combo enabler) — Ghost Market side cites `ghost-market-trade.md` (no Ghost Market ADR; Merit Node 7 gates the stall)

**ADR Governing Implementation**: ADR-0006 (Element System) — primary. Ghost Market integration cites `ghost-market-trade.md`.
**ADR Decision Summary**: New Ghost Market stall **五行灵珠 (Phase Bead)**: costs 40 XP (flat), adds +1 to a specific element count with NO stat buff (pure combo-enabler), element weighted toward the player's weakest. Behaves as a normal stall in the SPENT/EXPIRED state machine, presence-based hold, **no demon tide** on purchase. Availability gated on Merit Node 7. Existing Blood Pact / Soul Codex stalls show an element icon.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Reuses the Ghost Market interlude stall machinery (`trade_stall.gd` / `trade_panel.gd`). Phase Bead is a 4th archetype the stall slot can roll (not a physical 4th stall). Gated on Merit Node 7 (Merit epic).

**Control Manifest Rules (Feature)**:
- Required: Phase Bead reuses the stall state machine; element grant goes through Player.element_inventory increment (Story 002)
- Forbidden: Phase Bead triggering a demon tide (it's a calm costed trade)
- Guardrail: weakest-element weighting deterministic (seeded) for testability

## Acceptance Criteria

- [ ] AC-17: Ghost Market offers a 五行灵珠 of element Wood costing 40 XP; on completing the trade → `element_inventory.wood += 1` AND no stat buff applied AND 40 XP deducted
- [ ] Phase Bead element weighted toward the player's weakest element
- [ ] Purchasing a Phase Bead does NOT trigger a demon tide (unlike Yin Debt)
- [ ] Phase Bead only appears if Merit Node 7 (五行灵珠) is unlocked (else never spawns)
- [ ] Blood Pact / Soul Codex stalls display an element icon (Blood Pact's element = buffed weapon; Soul Codex = offered upgrade's element)
- [ ] Edge: if all elements ≥1, the bead still offers +1 to weakest (never a wasted purchase — all combos scale)

## Implementation Notes

- Add Phase Bead as a 4th trade archetype (cite `ghost-market-trade.md` Phase Bead §). Cost 40 XP flat (registry `phase_bead_xp_cost`). Effect: `Player.element_inventory[weakest] += 1` (Story 002 increment path), no stat buff.
- Weakest-element pick: min over the 5 counts (deterministic tiebreak); seeded for tests.
- Gate spawn on Merit Node 7 unlock state (read from SaveService/Merit — Merit epic). Until Merit ships, gate behind a flag defaulting off.
- Element icons on Blood Pact / Soul Codex stalls (display + targeting metadata only; no cost/buff change).

## Out of Scope

- Merit Node 7 itself (Merit epic) — this story reads the unlock flag.
- ComboManager (Story 004); element_inventory increment (Story 002 — reused here).

## QA Test Cases

- **AC-17**: Given a Wood Phase Bead at 40 XP, When traded, Then wood+1, no stat buff, XP−40.
- **Weakest weighting**: Given inventory {fire:3,...,water:0}, Then bead offers water (weakest). Edge: all ≥1 → still offers weakest, valid.
- **No tide**: Given a Phase Bead purchase, Then no demon tide fires (contrast Yin Debt).
- **Node 7 gate**: Given Node 7 locked, Then Phase Bead never appears.
- **Element icons**: Blood Pact / Soul Codex show correct element icon.

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/ghost_market/phase_bead_test.gd` — grant +1 element, no buff, no tide, Node-7 gate, weakest weighting
**Status**: [ ] Not yet created

## Dependencies

- Depends on: Story 002 (element_inventory increment). Soft: Merit Node 7 (Merit epic — gate flag).
- Unlocks: None
