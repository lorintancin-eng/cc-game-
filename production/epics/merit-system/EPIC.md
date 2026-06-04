# Epic: Merit System (功德系统 — Meta Progression)

> **Layer**: Progression (Feature) + Core (persistence)
> **GDD**: design/gdd/merit-system.md (revision-1)
> **Architecture Module**: Progression (功德簿 unlock chain, merit scoring, difficulty modes) + Core (SaveService persistence — ADR-0005)
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories merit-system`

## Overview

Merit System is the project's first between-run persistence + meta-progression layer — the answer to "why play again?". Each run earns 功德 (Merit) from a 6-metric performance score (survival time / kills / boss / combos / trades / stages); Merit is spent on a 15-node linear unlock chain (功德簿, 2,780 total) that permanently expands starting conditions and options (starting HP/speed, weapon unseals into the pool, Phase Bead stall, +1 starting element, free upgrade, Hard 天劫 / Ascension 渡劫 difficulty modes). Architecturally it sits on the new `SaveService` autoload (ADR-0005 — single `user://save.cfg`, section-namespaced, schema-versioned) and reads RunDirector's run-end metric accessors (ADR-0010 — `get_total_elapsed/get_stages_cleared/get_bosses_defeated`) plus a new Player `_total_kills` counter and a Five Phases `combo_activated` count. Merit holds NO file I/O itself — it calls SaveService to persist primitives.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0005: Save/Load Persistence (Accepted) | `SaveService` autoload owns `user://save.cfg`; ConfigFile + `[meta]/[merit]/[unlocks]/[stats]` sections; schema_version + migration; corrupt→push_warning+fresh, never crash; primitives only | MEDIUM (atomic-write R-1, web-export R-3 — PC-first) |
| ADR-0010: Run Lifecycle (Accepted) | RunDirector exposes `get_total_elapsed/get_stages_cleared/get_bosses_defeated`; `stage_cleared/stage_failed` run-end edges | LOW |
| ADR-0008: Enemy Archetype (Accepted) | `difficulty_multiplier` hook (Hard ×1.3 / Ascension ×1.6) applied at spawn | MEDIUM-HIGH (shared) |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-save-001 | ConfigFile at `user://save.cfg`, namespaced sections | ADR-0005 ✅ |
| TR-save-002 | autoload `SaveService` sole I/O, no gameplay logic; get_value/set_value/save API | ADR-0005 ✅ |
| TR-save-003 | `[meta] schema_version` + ordered migration chain | ADR-0005 ✅ |
| TR-save-004 | corrupt/missing → push_warning + fresh, never crash, preserve corrupt file | ADR-0005 ✅ |
| (run metrics) | `get_total_elapsed/get_stages_cleared/get_bosses_defeated` | ADR-0010 ✅ |
| (merit economy) | 6-metric merit formula, 15-node Ledger costs, difficulty multipliers | ❌ No dedicated ADR — **stories cite `merit-system.md` as contract source** (TR-merit-* domain reserved, pending; the economy is GDD-specified and self-contained) |

**Coverage: persistence + run-metrics fully traced ✅ (ADR-0005/0010); merit economy cites the GDD** (per the brownfield posture — untraced economy requirements don't block; stories name the GDD section as contract). A future ADR-0019 (Merit economy) may formalize the Ledger/formula if cross-system ambiguity surfaces.

## Suggested Story Sequencing (dependency order)

1. **Persistence foundation**: `SaveService` autoload (ConfigFile, sections, schema_version + migration scaffold, corrupt/missing handling, save_completed/save_loaded signals). Unit-test the round-trip + corruption path FIRST — everything else depends on it.
2. **Run Metrics Contract**: Player `_total_kills` counter (subscribe enemy `died`); RunDirector `get_total_elapsed/get_stages_cleared/get_bosses_defeated`; Merit subscribes `combo_activated` (Five Phases) + `_trade_count` (Ghost Market); StageDirector exposes trade count.
3. **Merit scoring**: Formula 1 (6-metric + pity floor + multiplier) computed at run-end (`stage_cleared`/`stage_failed`).
4. **Unlock chain**: 15-node Merit Ledger (hand-tuned costs, NOT a formula — ADR-0005-adjacent), purchase flow, persist via SaveService.
5. **Unlock effects**: starting modifiers on Player (`_ready()`), weapon unseals into Level Up Pool, Phase Bead gate (Ghost Market Node 7), Node 3 4-choice first level-up, Node 11 +1 starting element (Five Phases seed), Node 13 free upgrade.
6. **Difficulty modes**: Hard 天劫 / Ascension 渡劫 toggles (Enemy `difficulty_multiplier` + merit multiplier, mutually exclusive).
7. **UI**: Results Screen (merit breakdown), Merit Ledger screen, pre-run difficulty toggle (→ `/ux-design`).

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/merit-system.md` (AC-01..AC-18) are verified
- Logic/Integration stories have passing tests in `tests/` (SaveService round-trip + corruption + migration; merit Formula 1 worked examples; unlock-state application)
- Save/load persists across an actual relaunch (integration: earn merit → quit → relaunch → merit/unlocks intact)
- UI stories (Results / Ledger / difficulty toggle) have UX specs (`/ux-design`) + evidence docs with sign-off

## Next Step

Run `/create-stories merit-system` to break this epic into implementable stories. **Story 1 (SaveService) is the critical-path foundation — sequence it first.**
