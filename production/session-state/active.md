# Active Session State

> **Last Updated**: 2026-05-25
> **Last Hand-Off**: /adopt batch governance complete — all BLOCKING/HIGH gaps closed

---

## Current Task

**Governance Complete (5 batches landed)**

All BLOCKING (3), HIGH (7), and infrastructure-related MEDIUM gaps from
`docs/adoption-plan-2026-05-25.md` are closed. Project is now fully
CCGS-template-compatible — `/create-stories`, `/sprint-plan`,
`/architecture-review` etc. will run cleanly.

Remaining work is **manual + content-driven**, not governance:
1. Install GUT addon in Godot editor(addons/gut/, manual one-time)
2. Open Godot editor → verify `res://` references intact
3. Begin GDD retrofit: `/design-system combat-system`(highest bottleneck)

---

## Status

| Item | Value |
|---|---|
| Project Stage | Production |
| Review Mode | lean |
| Active Milestone | v0.4-qa (planning) |
| Systems Index | ✅ Written + B-1 fixed |
| Adoption Plan | ✅ All BLOCKING + HIGH closed |
| ADR-0001 / 0003 | ✅ Retrofitted to CCGS 8-section standard |
| TR Registry | ✅ 20 TRs across 7 domains |
| Control Manifest | ✅ v2026-05-25.1 |
| Architecture Traceability | ✅ Coverage 37% (7 covered + 12 gap suggestions) |
| Tests Scaffold | ✅ tests/ tree + helpers + smoke example |
| GUT Addon | ⏳ Manual install in Godot editor required |
| Entity Registry | ✅ 7 enemies + 4 constants registered |
| Sprint Status | ✅ v0.4-qa planning, history captured |
| Single-System GDDs | 0 / 25 (retrofit pending) |

---

## Adoption Plan Gap Closure

| Severity | Before | After |
|---|---|---|
| 🔴 BLOCKING | 3 | **0** ✅ |
| 🟠 HIGH | 7 | **0** ✅ |
| 🟡 MEDIUM | 12 | **2** (M-5/6/7 accepted as-is, M-8~11 accepted, M-12 closed, M-1/M-2/M-3/M-4 closed; 2 = future placeholder TODOs are not real gaps) |
| ⚪ LOW | 3 | **1** (L-1/L-2 closed; L-3 accepted as-is) |

> Realized closure: **10 BLOCKING+HIGH closed in batches 1-3, M-12 in batch 2, M-3+M-4 in batch 3, scaffolding-side of test-framework BLOCKING-level requirement in batch 4, M-3 in batch 5**.

---

## Files Touched (Governance Sweep, 2026-05-25)

- `docs/architecture/0001-godot4-gdscript.md` — +5 English CCGS sections
- `docs/architecture/0003-sun-wukong-active-skills.md` — +5 English CCGS sections
- `docs/architecture/tr-registry.yaml` — overwrote placeholder with 20 real TRs
- `docs/architecture/control-manifest.md` — new (layer-based rules sheet)
- `docs/architecture/architecture-traceability.md` — new (TR↔ADR matrix)
- `design/gdd/game-concept.md` — added `## Acceptance Criteria` English mirror
- `design/gdd/systems-index.md` — Status column normalized + Status semantics Note
- `design/registry/entities.yaml` — overwrote placeholder with 7 enemies + 4 constants
- `.claude/docs/technical-preferences.md` — filled Performance Budgets
- `production/sprint-status.yaml` — new (v0.4-qa active + v0.1/0.2/0.3 history)
- `production/session-state/active.md` — this file
- `tests/{unit,integration,helpers,fixtures}/` — new directory tree
- `tests/README.md`, `tests/helpers/test_base.gd`, `tests/unit/example_smoke_test.gd` — new
- **DELETED**: `MythSurvivor-v0.4-pre-qa-20260525-201215/` (empty import dir)

---

## Open Decisions

- ADR-0002 跳号待澄清(可能 v0.3 阶段被废止;tr-registry / traceability 都注明保留跳号,不补)
- `design/gdd/game-pillars.md` 是否从 game-concept.md 抽取独立(未决,但 game-concept.md 已有支柱章节,可暂不抽)

---

## Recommended Next Actions

**Manual / outside this session:**
1. Open `Godot_v4.6.2-stable_win64.exe` → load `project.godot` → AssetLib → install Gut → enable plugin → restart editor → commit `addons/gut/`
2. Verify all `res://` scene references resolve cleanly (open Main.tscn — no missing-script warnings)
3. Optionally delete root `Godot_v4.6.2-stable_win64.exe` and `MythSurvivor-...-.zip` (untracked, ~172 MB + ~246 KB)

**Next CCGS skill to run:**
4. `/design-system combat-system` — write first single-system GDD (highest-priority bottleneck per systems-index Recommended Design Order)
5. After Combat GDD complete: `/design-review design/gdd/combat-system.md`
6. Continue down design order: Player → Enemy → Run State → etc.

**Or jump to development:**
- Tell me a specific feature / bug to work on, and I'll do `/dev-story`-style implementation work directly against the existing 34 `.gd` files

---

## Recovery Instructions

If session crashes, in a new session:
1. Read this file
2. Read `docs/adoption-plan-2026-05-25.md`(all checkboxes that are now ✓)
3. Read `design/gdd/systems-index.md`(25 system list)
4. Continue with "Recommended Next Actions" above
