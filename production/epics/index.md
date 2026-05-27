# Epics Index

> **Last Updated**: 2026-05-25
> **Engine**: Godot 4.6
> **Template Version**: CCGS v1.0+ (Donchitos/Claude-Code-Game-Studios)

## Summary

4 epics created from approved GDDs, covering 4/15 MVP single-system GDDs (Foundation 1 + Core 3). All 4 GDDs went through the design-reviewer subagent verdict process and are Approved.

Each epic is **scope-defined**, not yet **story-broken** — run `/create-stories [epic-slug]` per epic to break into implementable units.

## Active Epics

| Epic | Layer | System | GDD | TR Coverage | Stories | Status |
|---|---|---|---|---|---|---|
| [run-state](run-state/EPIC.md) | Foundation | F-03 Run State | design/gdd/run-state.md (r1) | 0/4 ⚠️ all untraced | Not yet created | Ready |
| [player-system](player-system/EPIC.md) | Core | C-01 Player | design/gdd/player-system.md (r2) | 2/2 ✅ fully traced | Not yet created | Ready |
| [combat-system](combat-system/EPIC.md) | Core | C-03 Combat | design/gdd/combat-system.md (r4) | 2/5 ⚠️ 3 untraced | **11 stories** | Ready |
| [enemy-system](enemy-system/EPIC.md) | Core | C-04 Enemy | design/gdd/enemy-system.md (r1) | 0/3 ⚠️ all untraced | Not yet created | Ready |

## TR Coverage Summary

| Status | Count |
|---|---|
| ✅ ADR-covered TRs | 4 (TR-core-001, TR-core-005, TR-stack-001, TR-char-001/002/003 via ADR-0003) |
| ❌ Untraced TRs | 10 (TR-core-002/006, TR-wpn-001/002/003, TR-enemy-001/002/003, TR-run-001) |

> **Brownfield posture**: Most TRs are untraced because MythSurvivor's design decisions were captured in GDDs (and code) but not promoted to ADRs. Untraced TRs do NOT block epic creation, but stories referencing them will be marked Blocked until ADRs exist or stories explicitly cite the GDD section as the contract source.

## Suggested ADRs (post-epic / pre-stories)

In order of cross-system impact:

1. **ADR for Damage type taxonomy** (TR-wpn-002) — Core, unblocks all damage-touching stories. Authoritative for the 4-type enum and the multiplier pipeline order (per Combat GDD).
2. **ADR for Enemy archetype pattern** (TR-enemy-001) — Core, locks the Resource-as-data pattern.
3. **ADR for Weapon base class contract** (TR-wpn-001) — depends on damage taxonomy.
4. **ADR for Run lifecycle states** (TR-run-001) — Foundation/Run State.
5. **ADR for Stage Director timing rules** (TR-core-002) — Run State.
6. **ADR for Combat feedback signal contract** (TR-enemy-002 + Combat OQ-1 `damage_taken` signal) — Core, unblocks Combat Feedback GDD.
7. **ADR for Demon Seal contract** (TR-core-006) — Run State + Stage 1 polish.
8. **ADR for Boss spawn + victory** (TR-enemy-003) — Enemy + Run State seam.

Run `/architecture-decision [title]` for each, OR proceed with epic-level placeholder TR cites and revisit when more cross-team work surfaces ambiguities.

## Process Notes

### Lean review mode
PR-EPIC producer gate skipped per `production/review-mode.txt = lean`. Per skill rules, lean mode skips this gate (only PHASE-GATEs trigger full review).

### Gate-Check eligibility
Foundation + Core epics are now defined. Per `/create-epics` Step 6:
> "Foundation + Core complete: These are required for the Pre-Production → Production gate. Run `/gate-check production` to check readiness."

The project is already in Production stage (`production/stage.txt = Production`), so the gate-check would be reviewing readiness for **continued** Production work with proper story tracking — not a phase transition.

### Next Sprint Planning
After `/create-stories` runs for each epic, the resulting story files become the input for `/sprint-plan v0.4-qa` (per OQ-7 in roadmap.md) to translate them into a formal sprint backlog.

## Out of Scope (this batch)

The 11 remaining MVP-tier GDDs are not yet authored. When they land:
- Input (F-01), Resource Data Framework (F-02), Camera (C-02), Targeting (C-05) — Foundation/Core stragglers
- Enemy Spawning (FT-01), Weapon System (FT-03), Experience & Progression (FT-04), Level Up & Upgrade Pool (FT-05), Pickup System (FT-12) — Feature layer (priority MVP)
- HUD (P-01), Menu System (P-02) — Presentation layer (priority MVP)

Run `/create-epics layer:feature` (or `[system-name]` for one at a time) once those GDDs are approved.
