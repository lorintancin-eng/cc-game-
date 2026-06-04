# Story 002: Player element_inventory + run-start seed

> **Epic**: Five Phases Synergy
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: S (~2-3h)
> **Manifest Version**: 2026-06-04.1
> **Last Updated**: 2026-06-04 (implemented — 12/12 new + 43/43 player-suite regression green; pending /story-done)

## Context

**GDD**: `design/gdd/elements-five-phases.md` (Core Rules 3, 11)
**Requirement**: `TR-elem-002`

**ADR Governing Implementation**: ADR-0006 (Element System Pipeline)
**ADR Decision Summary**: Player owns `element_inventory: Dictionary[String,int]` (5 keys, seeded in `_ready()` before any combo signal). Incremented on weapon-unlock / `upgrade_applied`. Player emits `element_inventory_changed(inventory)`. **Typed `Dictionary[String,int]` is mandatory** — untyped makes `inventory[key] >= 1` a Variant compare and a missing key returns `null` where `null >= 1` silently evaluates false.

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: `Dictionary[String,int]` typed syntax is 4.4+. All 5 keys MUST be initialized at run-start (R-5). Inventory seed happens in `_ready()` BEFORE ComboManager connects (R-2) — use a `run_initialized` signal or seed-then-emit ordering.

**Control Manifest Rules (Core)**:
- Required: typed Dictionary; Player owns + is sole writer of element_inventory
- Forbidden: other systems writing element_inventory directly (read via signal)
- Guardrail: event-driven; emit `element_inventory_changed` once per change, not per frame

---

## Acceptance Criteria

- [ ] AC-15: inventory starts all-zero; unlocking Flying Sword (金) → `element_inventory.metal = 1`; no combo activates (single element)
- [ ] Core Rule 3: each upgrade stack +1 to its element; weapon unlock +1 to its element
- [ ] Core Rule 11: inventory seeded at run-start in `_ready()` BEFORE first level-up — starting weapon contributes +1 (修行者 Talisman → fire=1)
- [ ] AC-22: Merit Node 11 (元素感应) seeds +1 random element at the same init step; if random=fire and starting weapon=fire(Talisman) → `fire=2` before first level-up
- [ ] `element_inventory_changed(inventory)` emits after each change

---

## Implementation Notes

*Derived from ADR-0006 + Core Rule 11:*

- `var element_inventory: Dictionary[String, int] = {"metal":0,"wood":0,"water":0,"fire":0,"earth":0}` — all 5 keys, never leave one absent.
- Seed order in `_ready()`: (1) starting weapon element, (2) Merit Node 11 bonus (if purchased — read from SaveService/Merit), THEN emit `run_initialized` so ComboManager connects AFTER seeding (avoids a combo firing mid-init before HUD exists).
- Increment hooks: weapon-unlock path + `upgrade_applied` (read the applied upgrade's element tag — Level Up Pool side, Story 011).
- Read-only to others; expose via the `element_inventory_changed` signal payload.

---

## Out of Scope

- Story 004: ComboManager reading the inventory + recompute logic
- Story 011: tagging upgrades with elements in the pool (this story only consumes the tag)
- Merit Node 11 itself (Merit epic) — this story only applies the seed if present

---

## QA Test Cases

- **AC-15**: Given all-zero inventory, When unlock Flying Sword (metal), Then `metal==1` AND no `combo_activated`. Edge: single element never activates a pair.
- **Core Rule 11**: Given 修行者 with Talisman (fire), When `_ready()` completes, Then `fire==1` before first level-up.
- **AC-22**: Given Node 11 random=fire AND Talisman(fire), When seeded, Then `fire==2`. Edge: random element == starting weapon's element stacks (not wasted).
- **Typed-dict guard**: Given a key lookup, Then comparisons are int (no `null>=1` path) — assert all 5 keys present post-init.
- **Signal**: Given an increment, Then `element_inventory_changed` emits exactly once with the updated dict.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/player/element_inventory_test.gd` — must exist and pass
**Status**: [x] Created — **12/12 passing** (49 asserts) + **player suite 43/43 regression green** (Godot 4.6.stable / GUT 9.6). Impl additive in `scripts/player/player.gd` (element_inventory typed Dict, element_inventory_changed/run_initialized signals, _seed_element_inventory + _add_element). SaveService Node-11 path is a guarded no-op in headless (documented).

---

## Dependencies

- Depends on: None (Player-side foundation; Merit Node 11 seed is optional/guarded)
- Unlocks: Story 004 (ComboManager), Story 011 (upgrade element tags)
