# Story 011: Upgrade-pool element icons + 相生 proximity hint

> **Epic**: Five Phases Synergy
> **Status**: In Progress — logic core (element-gain wiring) DONE + tested; UI (element icons + 相生 hint) DEFERRED
> **Layer**: Feature (UI)
> **Type**: UI
> **Estimate**: M (~3h)
> **Manifest Version**: 2026-06-04.1
> **Last Updated**: 2026-06-05

## Context

**GDD**: `design/gdd/elements-five-phases.md` (Integration with Upgrade Pool §, UI Requirements §, AC-16) + `design/gdd/level-up-pool.md`
**Requirement**: `TR-elem-003` (combo discovery UI) — Level Up Pool side cites `level-up-pool.md` (no Level Up ADR yet)

**ADR Governing Implementation**: ADR-0006 (Element System — combo proximity) — primary. Level Up Pool integration cites `level-up-pool.md` as contract.
**ADR Decision Summary**: Each upgrade in the LevelUpPanel shows its element icon. When taking an upgrade would activate a NEW combo (player has ≥1 of A and this upgrade's element is B where A→B is a generating pair, or vice versa), show a "相生!" glow border + tooltip "激活 [combo name]". This is the primary combo-discovery mechanism. No layout change beyond additive info; element info added to the existing 3-option panel.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: UI Toolkit/Control work on the existing LevelUpPanel. Element icons 16×16 (12×12 min readable). `combo_activated` may fire during the level-up pause — its activation VFX should be visible during the paused panel.

**Control Manifest Rules (UI)**:
- Required: UI presents state + forwards choices; event-driven
- Forbidden: UI owning combo logic (reads ComboManager / element_inventory; does not compute combos)
- Guardrail: HUD/panel updates event-driven, not per-frame

## Acceptance Criteria

- [ ] Each upgrade option shows its element icon (金=white/silver, 木=green, 水=blue, 火=red, 土=yellow-brown)
- [ ] AC-16: Given player has metal≥1 and a Water upgrade is offered, When the panel renders, Then that option shows "相生! 激活 寒露凝锋" hint + glow border
- [ ] No forced element filtering — all eligible upgrades still appear (Level Up Pool Rules 2-3 intact); element info is additive
- [ ] On selection, `upgrade_applied` updates element_inventory; if a generating pair completes, `combo_activated` fires during the panel pause (activation VFX visible)

## Implementation Notes

- Tag each `UpgradeDefinition` with `element` (weapon upgrades inherit weapon element; player-attribute upgrades = wood). Cite `level-up-pool.md` for the pool contract.
- Panel render: per option, draw the element icon; compute "would this activate a new combo?" by checking current `element_inventory` against the generating pairs given the option's element; if yes, add glow + tooltip.
- Do not change the 3-option layout (or 4 if Merit Node 3) — additive only.

## Out of Scope

- ComboManager activation logic (Story 004). Element assignment data correctness (Story 005). Merit Node 3 4-choice panel (Merit epic) — this story must not break when count is 4.

## QA Test Cases (manual + interaction)

- **AC-16**: Setup: give player metal≥1; trigger level-up with a Water upgrade in the 3 options. Verify: the Water option shows "相生! 激活 寒露凝锋" + glow. Pass: hint present + correct combo name.
- **Icons**: Setup: any level-up. Verify: each option shows the correct element color icon, readable at panel size.
- **No filtering**: Verify all eligible upgrades still appear (element info doesn't hide any).
- **Activation during pause**: Setup: pick the combo-completing upgrade. Verify: `combo_activated` VFX plays while the panel is still up / on close.

## Test Evidence

**Story Type**: UI
**Required evidence**: `production/qa/evidence/element-upgrade-hints-evidence.md` — screenshots of icons + 相生 hint + sign-off (→ consider `/ux-design` for the panel spec first)
**Status**: [ ] Not yet created

## Dependencies

- Depends on: Story 004 (ComboManager / activation), Story 002 (element_inventory), Story 005 (upgrade element tags)
- Unlocks: None

---

## Implementation Status (2026-06-05) — split into logic core + deferred UI

The user scoped this story to its **logic core** (the part that makes 相生 combos
actually activatable in-game), deferring the **visual UI half** because headless CI
cannot render or verify the required screenshot evidence.

### ✅ DONE (logic core — automated-tested)
- `_get_upgrade_element(upgrade_id)` now maps every 修行者 upgrade to its element
  (weapon-family upgrades → weapon element; player-attribute upgrades → wood;
  unlock_*/character/unknown → neutral). Was a `return "neutral"` placeholder.
- `WEAPON_UNLOCK_ELEMENTS` corrected (thunder=water, bagua=earth, explosive=fire,
  mountain=earth; flying_sword=metal already). Weapon unlocks now feed the inventory.
- **Effect**: `upgrade_applied` → `element_inventory` gains the right element → a
  completed generating pair fires `combo_activated`. AC clause "On selection,
  `upgrade_applied` updates element_inventory; if a pair completes, `combo_activated`
  fires" is satisfied (minus the in-pause VFX, which is UI).
- **This is the first time 相生 combos can activate in a real run.**
- Evidence: `tests/unit/element/upgrade_element_gain_test.gd` — 8 tests incl. an
  end-to-end (fire seed + Wood upgrade → 木生火 activates via a real ComboManager).
  Full suite 392/392 green. `/code-review` APPROVED (GDD mapping verified exact;
  no-double-count invariant proven).

### ⏳ DEFERRED (UI half — needs playtest/screenshot sign-off)
- AC: each upgrade option shows its element icon (色彩 by element).
- AC-16: the "相生! 激活 [combo]" glow border + tooltip proximity hint.
- AC: `combo_activated` activation VFX visible during the level-up pause.
- These require LevelUpPanel `.tscn`/UI work + the evidence doc at
  `production/qa/evidence/element-upgrade-hints-evidence.md` (consider `/ux-design`
  for the panel spec first). Reopen this story's UI half when ready to playtest.
