# Architecture Traceability Index

<!-- Living document — initial brownfield baseline written by hand on 2026-05-25.
     Subsequent updates will be made by /architecture-review. -->

## Document Status

- **Last Updated**: 2026-05-25
- **Engine**: Godot 4.6
- **GDDs Indexed**: 7 (game-concept + 03/04/05/06 macros + 2 narrative + style guides)
- **ADRs Indexed**: 2 (ADR-0001, ADR-0003)
- **Last Review**: Initial baseline — no `/architecture-review` run yet

## Coverage Summary

| Status | Count | Percentage |
|--------|-------|-----------|
| ✅ Covered | 7 | 37% |
| ⚠️ Partial | 0 | 0% |
| ❌ Gap | 12 | 63% |
| **Total** | **19** | 100% |

> Source: `docs/architecture/tr-registry.yaml`. As expected for a brownfield import — the project has working code for nearly all systems, but the formal traceability layer is sparse until `/architecture-decision` runs add more ADRs.

---

## Traceability Matrix

| Req ID | GDD | System | Requirement Summary | ADR(s) | Status | Notes |
|--------|-----|--------|---------------------|--------|--------|-------|
| TR-STACK-001 | game-concept.md | (foundational) | Godot 4.x + GDScript stack | ADR-0001 | ✅ | |
| TR-CORE-001 | 03_CORE_GAMEPLAY.md | Player + Combat | Manual movement, auto attacks | ADR-0001 | ✅ | Implied by stack ADR; could justify a dedicated Input ADR |
| TR-CORE-002 | 03_CORE_GAMEPLAY.md | Stage Director | 5-minute run with 2:00 / 4:30 / 5:00 beats | — | ❌ GAP | Needs `/architecture-decision "Stage Director timing"` |
| TR-CORE-003 | game-concept.md | Pickup | Auto-collect on radius entry | — | ❌ GAP | Needs `/architecture-decision "Pickup radius contract"` |
| TR-CORE-004 | 03_CORE_GAMEPLAY.md | Level Up + Run State | Pause + 3-choice UI | — | ❌ GAP | Needs `/architecture-decision "Run-state pause contract"` |
| TR-CORE-005 | 03_CORE_GAMEPLAY.md | (foundational) | 60 FPS @ 50-100 enemies / 200+ projectiles | ADR-0001 | ✅ | Covered via Performance Implications section |
| TR-CORE-006 | 06_LEVEL_DESIGN.md | Demon Seal | 8s seal process with risk events | — | ❌ GAP | Needs `/architecture-decision "Demon Seal contract"` |
| TR-DATA-001 | ARCHITECTURE.md | Resource Data Framework | All content via .tres Resource | ADR-0001 | ✅ | |
| TR-WPN-001 | 04_SKILL_DESIGN.md | Weapon System | WeaponBase + subclass contract | — | ❌ GAP | Needs `/architecture-decision "Weapon base class"` |
| TR-WPN-002 | 03_CORE_GAMEPLAY.md | Combat | 4 damage types (direct/tick/explosion/burn) | — | ❌ GAP | Needs `/architecture-decision "Damage type taxonomy"` |
| TR-WPN-003 | 04_SKILL_DESIGN.md | Level Up & Upgrade Pool | Upgrade pool filtered by character | — | ❌ GAP | Needs `/architecture-decision "Upgrade pool filter"` |
| TR-ENEMY-001 | 05_ENEMY_DESIGN.md | Enemy | Archetype pattern with .tres | — | ❌ GAP | Needs `/architecture-decision "Enemy archetype"` |
| TR-ENEMY-002 | 03_CORE_GAMEPLAY.md | Combat Feedback | 0.1s flash + screen shake | — | ❌ GAP | Needs `/architecture-decision "Combat feedback signals"` |
| TR-ENEMY-003 | 03_CORE_GAMEPLAY.md | Boss System | Boss at 5:00 with victory trigger | — | ❌ GAP | Needs `/architecture-decision "Boss spawn + victory"` |
| TR-CHAR-001 | 02_CHARACTER_DESIGN.md | Character System | 6 characters with unique weapon sets | ADR-0003 | ✅ | Framework implied by Sun Wukong special case |
| TR-CHAR-002 | SUN_WUKONG_V2_DESIGN.md | Active Skills | Sun Wukong active skills (1/2/3/4 keys) | ADR-0003 | ✅ | |
| TR-CHAR-003 | ADR-0003 | Active Skills + HUD | Event-driven input, signal-driven HUD | ADR-0003 | ✅ | |
| TR-UI-001 | game-concept.md | HUD | HP/Level/XP/Timer/Kill, event-driven | — | ❌ GAP | Needs `/architecture-decision "HUD data binding"` |
| TR-UI-002 | 03_CORE_GAMEPLAY.md | Menu System | Main / Pause / Char-Select / Level-Up / Game-Over / Settle | — | ❌ GAP | Needs `/architecture-decision "Menu state machine"` |
| TR-RUN-001 | 03_CORE_GAMEPLAY.md | Run State | 3 end states (death / victory / quit) | — | ❌ GAP | Needs `/architecture-decision "Run lifecycle"` |

---

## Known Gaps

Requirements with no ADR coverage, prioritised by layer (Foundation first):

### Foundation Layer Gaps (BLOCKING — must resolve before coding new systems)

(none — Foundation TR-STACK-001 + TR-CORE-005 + TR-DATA-001 all covered by ADR-0001)

### Core Layer Gaps (must resolve before relevant system is built)

- [ ] TR-WPN-002: 4 damage types — Suggested ADR: "Damage type taxonomy"
- [ ] TR-ENEMY-001: Enemy archetype — Suggested ADR: "Enemy archetype pattern"
- [ ] TR-ENEMY-002: Combat feedback signals — Suggested ADR: "Combat feedback signal contract"

### Feature Layer Gaps (should resolve before next sprint)

- [ ] TR-CORE-002: Stage Director timing — Suggested ADR: "Stage Director timing rules"
- [ ] TR-CORE-003: Pickup radius — Suggested ADR: "Pickup radius detection"
- [ ] TR-CORE-004: Run-state pause — Suggested ADR: "Run-state pause contract"
- [ ] TR-CORE-006: Demon Seal — Suggested ADR: "Demon Seal contract"
- [ ] TR-WPN-001: Weapon base class — Suggested ADR: "Weapon base class contract"
- [ ] TR-WPN-003: Upgrade pool filter — Suggested ADR: "Upgrade pool filter rules"
- [ ] TR-ENEMY-003: Boss spawn + victory — Suggested ADR: "Boss spawn + victory"
- [ ] TR-RUN-001: Run lifecycle — Suggested ADR: "Run lifecycle states"

### Presentation Layer Gaps (can defer to implementation)

- [ ] TR-UI-001: HUD data binding — Suggested ADR: "HUD data binding pattern"
- [ ] TR-UI-002: Menu state machine — Suggested ADR: "Menu state machine"

---

## Cross-ADR Conflicts

| Conflict ID | ADR A | ADR B | Type | Status |
|-------------|-------|-------|------|--------|
| (none) | — | — | — | — |

ADR-0001 and ADR-0003 are compatible. ADR-0003 explicitly states it does not override the auto-battle design for non-Wukong characters; this is consistent with ADR-0001.

---

## ADR → GDD Coverage (Reverse Index)

| ADR | Title | GDD Requirements Addressed | Engine Risk |
|-----|-------|---------------------------|-------------|
| ADR-0001 | Godot 4.x + GDScript | TR-STACK-001, TR-CORE-001, TR-CORE-005, TR-DATA-001 | HIGH (post-4.3 API checks needed) |
| ADR-0003 | Sun Wukong active skills (exception) | TR-CHAR-001, TR-CHAR-002, TR-CHAR-003 | LOW (Input + signals stable across 4.x) |

---

## Superseded Requirements

| Req ID | GDD | Change | Affected ADR | Status |
|--------|-----|--------|-------------|--------|
| (none recorded) | — | — | — | — |

> Note: the v0.3 Sun Wukong design (灵气-based passive skills) is fully superseded by ADR-0003 (key-bound active skills). The v0.3 archive lives at `production/archive/v0.3/V0_3_CHARACTERS.md` §4.2. No active TR ID references the v0.3 implementation; the supersession is recorded inside ADR-0003 itself.

---

## How to Use This Document

- **When writing a new ADR**: Add it to the "ADR → GDD Coverage" table and mark the requirements it satisfies as ✅ in the matrix. Update Coverage Summary.
- **When approving a GDD change**: Scan the matrix for that GDD's TRs and check whether any existing ADR is invalidated. Add to "Superseded Requirements" if so.
- **When running `/architecture-review`**: The skill will update this document automatically with current state.
- **Gate check**: Pre-Production gate requires this document to exist (✅) and to have **zero Foundation Layer Gaps** (✅ — already passes).

---

## Next-ADR Priority Queue

Based on the gap list above, ordered by dependency + risk:

1. **ADR-0004 — Damage type taxonomy** (TR-WPN-002, Core, unblocks Weapon System redesign)
2. **ADR-0005 — Enemy archetype pattern** (TR-ENEMY-001, Core, unblocks new enemy types)
3. **ADR-0006 — Weapon base class contract** (TR-WPN-001, Feature, depends on ADR-0004)
4. **ADR-0007 — Run-state lifecycle** (TR-CORE-004 + TR-RUN-001, Foundation, unblocks pause/UI)
5. **ADR-0008 — Stage Director timing** (TR-CORE-002, Feature, level pacing)
6. **ADR-0009 — Demon Seal contract** (TR-CORE-006, Feature)
7. **ADR-0010 — Upgrade pool filter** (TR-WPN-003, Feature)
8. **ADR-0011 — Combat feedback signals** (TR-ENEMY-002, Core/Presentation seam)
9. **ADR-0012 — Boss spawn + victory** (TR-ENEMY-003, Feature)
10. **ADR-0013 — Pickup radius** (TR-CORE-003, Feature)
11. **ADR-0014 — HUD data binding** (TR-UI-001, Presentation)
12. **ADR-0015 — Menu state machine** (TR-UI-002, Presentation)

> Note: ADR-0002 number remains unused (legacy skip from v0.3 era). Do not renumber existing ADRs.
