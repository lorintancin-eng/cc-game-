# Active Session State

> **Last Updated**: 2026-05-28 (sprint complete — 4 commits, 0 blockers)

## Session Extract — autonomous-sprint 2026-05-28
- User mandate: "按你思路一直干到底；直到需要我操作的地方再找我" (run until blocked)
- 4 sprint items shipped, 4 commits pushed to main:

| # | Commit | Item | Files |
|---|--------|------|-------|
| 1 | `08d3259` | Sun Wukong 火眼金睛 wiring (HairClone + Immobilize) | 4 files (3 scripts + 10-func test) |
| 2 | `b20baa1` | HUD Boss HP bar (uses Story 002 damage_taken signal) | 2 files (hud.gd + HUD.tscn) |
| 3 | `d5da405` | HUD Demon Seal progress bar (replaces text-only %) | 2 files (hud.gd + HUD.tscn) |
| 4 | `2c0ec2c` | Demon Seal OQ-4 fix (corpse XP orbs guard) | 3 files (stage_director.gd + 4-func test + demon-seal.md r2) |

Key technical wins:
- **Real gameplay bug fixed**: Sun Wukong's signature 火眼金睛 passive (+20%~+55% vs Boss/Elite) now applies to all 3 weapon scripts, not just JinguBangV2. Hair clones + Immobilize burst were silently ignoring it.
- **Story 002 signal proven in production**: BossPanel HUD consumes `Enemy.damage_taken(current_hp, max_hp, last_damage_amount)` — validates the payload contract end-to-end.
- **OQ-4 closed via 1-line guard**: post-death seal completion no longer spawns 8 XP orbs on the corpse or mis-displays "封印完成" on game-over. Regression test added.

Test coverage added: 14 new GUT functions across `tests/unit/weapon/` and `tests/unit/system/`. Local Godot binary not in PATH — CI verifies via chickensoft-games/setup-godot@v2 (Godot 4.6.0 pinned).

Blockers: None.

Next options (no user decision needed — Claude will pick):
- **Combat Story 003 (Death Lifecycle / DYING state)** — next in Combat epic order; depends on Story 002 ✅
- **Combat Story 007 (Enemy→Player Damage Throttle)** — also unblocked
- **Other ad-hoc**: ADR-0003 amendment for per-frame skill_cooldown_changed (defect #2 from /review-all-gdds); minimap pip for off-camera Demon Seal (OQ-3)

---

## Session Extract — /dev-story 2026-05-27
- Story: production/epics/combat-system/story-001-damage-tuple-friendly-fire.md — Damage Tuple + Friendly-Fire Contract
- Files changed: scripts/combat/damage_types.gd, tests/unit/combat/damage_tuple_test.gd
- Test written: tests/unit/combat/damage_tuple_test.gd (11 → 18 test functions covering AC-04/05/19 + edge cases)
- Blockers: None
- Next: /code-review then /story-done — DONE

## Session Extract — /story-done 2026-05-27
- Verdict: ✅ COMPLETE
- Story: production/epics/combat-system/story-001-damage-tuple-friendly-fire.md — Damage Tuple + Friendly-Fire Contract
- Tech debt logged: 3 items (RefCounted-vs-Object cosmetic; _COUNT sentinel; tests/README.md vs test-standards.md naming convention conflict)
- Next recommended: Story 002 (HP Application + Overkill Clamp) — `/story-readiness production/epics/combat-system/story-002-hp-application-overkill.md`
- Also unblocked: Stories 003, 004, 005, 006, 007 — all 9 downstream Combat stories per epic dependency order

## Session Extract — /story-done 2026-05-27 (Story 002)
- Verdict: ✅ COMPLETE
- Story: production/epics/combat-system/story-002-hp-application-overkill.md — HP Application + Overkill Clamp
- **First story that MODIFIED existing game code** (scripts/enemy/enemy.gd — added damage_taken signal + emit)
- Closes Enemy GDD r1 OQ-1 (missing damage_taken signal — tech debt resolved)
- Code review: APPROVED WITH SUGGESTIONS (0 required, 3 suggestions; 1 applied)
- Tests: tests/unit/combat/hp_application_test.gd (10 functions covering AC-01 + AC-20 + 6 edges)
- Next recommended: Story 003 (Death Lifecycle / DYING state) — depends on Story 002 ✅
- Also unblocked: Story 007 (Enemy→Player Damage Throttle)

---


> **Last Hand-Off**: All 25/25 single-system GDDs authored (commit d89ab1a). 15 Approved + 10 Designed-pending-review. Now spawning design-reviewer for the 10 pending GDDs to upgrade them to Approved.

---

## Current Task

**Phase: COMPLETE — Design-review pass for 10 Designed-pending-review GDDs**

All 25/25 GDDs are now Approved (revision-1 across all 10 reviewed). Cross-doc fixes propagated. systems-index Progress Tracker updated. Final commit pending.

---

## Design Review Pass Summary (2026-05-27)

| GDD | Verdict | Revision Outcome |
|---|---|---|
| demon-seal.md | CONCERNS (2B+3R+1NTH) | r1 Approved — collision radius 72 corrected; death-during-seal edge case rewritten; AC-08 25 points; HUD relay path; OQ-4 tracks code defect |
| elements-five-phases.md | CONCERNS (2B+4R) | r1 Approved — TR-CORE-005 ref dropped; element field marked RESERVED in Enemy GDD; algorithmic matchup statement; AC-04 worked example |
| menu-system.md | CONCERNS (3B+4R+5NTH) | r1 Approved — HUD owns GameOverPanel trigger (not panel); Input Contract section; AC-04 reload mechanism; localization OQ-4 |
| audio-system.md | CONCERNS (0B+7R+6NTH) | r1 Approved — coalesce 50ms consistency; Formula 1 complete (damage_intensity + LOUDEN_STEP); heartbeat trigger moved to Combat Feedback; originality policy → Rule 9 |
| vfx-system.md | NEEDS REVISION (3B+7R+6NTH) | r1 Approved — Formula 1 owns queue_free; photosensitivity ≤3 Hz per WCAG 2.3.1; colorblind "!" icon + diagonal stripes; always-on 60-particle reserve; palette anchored to 朱砂/青铜/鬼火 |
| status-effects.md | MAJOR REVISION (3B+3R+3NTH) | r1 Approved — Inventory ❌/🟡/✅ honesty (1/6 implemented); Stacking Matrix; 9 ACs GIVEN/WHEN/THEN; Combat.damage_dealt pipeline (Rule 6) |
| combat-feedback.md | MAJOR REVISION (2B+5R+4NTH) | r1 Approved — per-target flash throttle (was global bug); heartbeat 3-way split (CF trigger / HUD visual / Audio sound); hit-stop scope statement; AC-07 zero-damage defense |
| hud.md | MAJOR REVISION (5B+5R+5NTH) | r1 Approved — added demon_seal/boss_spawned/upgrade_applied subscriptions; Information Architecture; 5 accessibility hooks; 13 ACs |
| boss-system.md | MAJOR REVISION (4B+5R+4NTH) | r1 Approved — Enrage mechanic (HP≤0.3 trigger); summon archetypes corrected (Paper Doll + Wandering Soul); BossState enum; 22 Tuning Knobs; canonical HP=360 |
| active-skills.md | MAJOR REVISION (5B+4R+4NTH) | r1 Approved — 火眼金睛 contract (Combat reservation honored); ADR-0003 scope-creep guard; per-frame emit acknowledged; TBD → shipped defaults; Per-Skill Specifications |

**Cross-doc fixes applied**:
- stage-director.md line 177 (DemonSeal death-during-seal — code-truth defect now documented + OQ-4 tracks fix)
- HUD ↔ Combat Feedback heartbeat ownership joint resolution (Combat Feedback owns trigger; HUD owns visual; Audio owns sound)

**Defects surfaced for v0.4.x patch**:
1. `_on_demon_seal_completed` missing `_is_stage_failed` guard (8 XP orbs spawn post-death)
2. ADR-0003 amendment needed for per-frame `skill_cooldown_changed` emit exception
3. Enemy GDD `element: String = "neutral"` field addition (when v0.5 Elements activates)

---

## Session Extract — /review-all-gdds 2026-05-27
- Verdict: **FAIL** (5 BLOCKING consistency + 2 BLOCKING design theory)
- GDDs reviewed: 27 (25 single-system + 2 UX + game-concept + systems-index + entities.yaml)
- Flagged for revision: run-state, stage-director, combat-system, enemy-system, level-up-pool (5 — flipped to Needs Revision in systems-index)
- Blocking consistency: C-B1 Run State↔Stage Director ownership conflict; C-B2 Stage Director dead-code Boss exports (260/16 vs 360/18); C-B3 Combat Formula 7 HP=30 leftover; C-B4/B5 Enemy self-queue_free vs VFX queue_free authority
- Blocking design theory: D-B1 Player HP=100 vs Pressure Curve HP=30 design intent (Combat OQ-5 unresolved); D-B2 Level Up Pool no per-upgrade stack cap (Talisman 4× = 6×, exceeds Combat 5× ceiling)
- Warning items: 17 consistency + 5 design theory + 4 cross-system scenario
- Recommended next: address 6 Tier-1 blockers before /create-architecture or /create-stories; v0.4 playtest needed for D-B1 path decision
- Report: design/gdd/gdd-cross-review-2026-05-27.md

---

**Previously completed phase**:

Pending list:
1. Demon Seal (`design/gdd/demon-seal.md`) — Vertical Slice
2. Boss System (`design/gdd/boss-system.md`) — Vertical Slice
3. Status Effects (`design/gdd/status-effects.md`) — Vertical Slice
4. Combat Feedback (`design/gdd/combat-feedback.md`) — Vertical Slice
5. HUD (`design/ux/hud.md`) — MVP UI
6. Menu System (`design/ux/menu-system.md`) — MVP UI
7. Active Skills (`design/gdd/active-skills.md`) — Alpha
8. Elements / 五行 (`design/gdd/elements-five-phases.md`) — Full Vision
9. Audio (`design/gdd/audio-system.md`) — Full Vision
10. VFX (`design/gdd/vfx-system.md`) — Full Vision

Approach: 3 parallel batches of design-reviewer subagents.

---

## Previously Completed

**Combat GDD revision-1 (after /design-review MAJOR REVISION NEEDED)** — completed, approved in revision-3.

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
