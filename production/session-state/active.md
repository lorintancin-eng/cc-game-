# Active Session State

> **Last Updated**: 2026-05-25
> **Last Hand-Off**: Enemy GDD revision-0 written (4 systems / 15 MVP done). Awaiting design-reviewer subagent verdict on Enemy. Combat + Player + Run State remain APPROVED.

---

## Current Task

**Combat GDD revision-1 (after /design-review MAJOR REVISION NEEDED)**

Reviewer flagged 8 BLOCKERS + 10 RECOMMENDED REVISIONS. All 8 blockers addressed
in revision-1; most of the 10 recommended also addressed in the same revision.

Key changes from revision-0:
- Added Pressure Curve § (TTK budget, hits-to-die per phase, incoming DPS targets)
- Renamed "Detailed Design" → "Detailed Rules" (CCGS tooling grep compat)
- Added Core Rule 6 (DYING guard), Rule 7 (zero-damage throttle preserve),
  Rule 8 (aggregate DPS ceiling MAX=4), Rule 9 (per-enemy throttle independence)
- Damage tuple extended with `source_kind` for friendly-fire enforcement
- Formula 1 extended with multiplier pipeline (source / crit / element / pierce)
- Formula 2 clamp embedded inline
- Formula 3 added hits_per_tick cap (MAX_HITS_PER_TICK = 20)
- Formula 4 init rule made explicit (no grace period)
- NEW Formula 5: Burn fixed-step accumulator (frame-rate independent)
- NEW Formula 6: Pierce damage (full damage per pierce, falloff slot reserved)
- NEW Formula 7: Aggregate DPS ceiling
- Death lifecycle split: data-death (1 frame) vs visual-death (≤ 0.5s dissolve)
- Signal payload contracts explicit: died / damage_taken / health_changed
- HP bar trigger via damage_taken (was undefined)
- AC count: 10 → 20 (added friendly fire AC, tuple AC, deterministic burn ACs,
  pierce_count = 0 AC, aggregate ceiling AC, etc.)
- 2 new OQs: TTK validation, ceiling tiebreak determinism

Status changed to "Needs Revision" pending re-review.

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
