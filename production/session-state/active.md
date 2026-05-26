# Active Session State

> **Last Updated**: 2026-05-25
> **Last Hand-Off**: /design-system combat-system complete — first single-system GDD landed

---

## Current Task

**Combat GDD Authored (1 / 25 single-system GDDs done)**

`design/gdd/combat-system.md` written end-to-end in one pass (user全权授权
to skip per-section approval cycle). 8 required sections + 3 optional (Visual/Audio,
UI Requirements, Open Questions) all populated based on existing code + 03_CORE §10
+ 04_SKILL §3 + ADR-0001.

Combat GDD is a **reverse-documentation** of the existing v0.4-pre-qa implementation
— numbers and contracts traced directly from `scripts/weapon/*.gd`,
`scripts/enemy/enemy.gd`, and `resources/enemies/*.tres`. Cross-doc consistency
verified against `entities.yaml`.

---

## Status

| Item | Value |
|---|---|
| Project Stage | Production |
| Review Mode | lean |
| Active Milestone | v0.4-qa (planning) |
| Systems Index | ✅ Combat row updated to Designed |
| Single-System GDDs | **1 / 25** (Combat ✅ — pending /design-review) |
| Adoption Plan | ✅ All BLOCKING + HIGH closed |
| Tests Scaffold | ✅ tests/ ready (GUT addon manual install pending) |
| Entity Registry | ✅ 7 enemies updated with combat-system.md reference; 4 new formulas registered |
| Sprint Status | v0.4-qa planning |

---

## Files Touched This Session

- `design/gdd/combat-system.md` — new (548 lines, 8 required + 3 optional sections)
- `design/registry/entities.yaml` — 7 enemies' referenced_by += combat-system.md; target_framerate += combat-system.md; 4 new formula entries
- `design/gdd/systems-index.md` — Combat row Status → Designed; Progress Tracker updated to 1/25
- `production/session-state/active.md` — this file

---

## Combat GDD Highlights

- **Reverse-documented** from existing code, not invented
- **4 damage types** locked into contract: direct / tick / explosion / burn
- **4 formulas** registered:
  - `damage_application_formula`: `new_hp = max(0, current_hp - damage_amount)`
  - `weapon_dps_formula`: `dps = damage / cooldown`
  - `multi_target_effective_dps`: `(damage × hits_per_tick) / tick_rate`
  - `damage_interval_throttle`: per-enemy hit throttle
- **10 acceptance criteria** in GIVEN-WHEN-THEN format (testable by QA)
- **4 open questions** flagged for future GDDs (crit support, status pipeline integration, five-phase scaling)
- **TR coverage**: TR-core-001, TR-core-005, TR-wpn-001, TR-wpn-002, TR-enemy-002

---

## Recommended Next Actions

1. **Run `/design-review design/gdd/combat-system.md` in a fresh session** — independent critique of the Combat GDD (CCGS requires fresh session for design-review)
2. **Or continue down the design order**: `/design-system player-system` (next in retrofit order — Player is #2 bottleneck with 6 downstream dependencies)
3. **Or jump to a smaller system** to maintain momentum: `/design-system camera-system` (S effort, 1 session)
4. **`/consistency-check`** — now that Combat formulas + entity references are registered, re-run to verify cross-doc consistency

---

## Recovery Instructions

If session crashes, in a new session:
1. Read this file
2. Read `design/gdd/combat-system.md` (latest single-system GDD)
3. Read `design/gdd/systems-index.md` Recommended Design Order
4. Continue with next system in order
