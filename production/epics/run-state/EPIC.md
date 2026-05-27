# Epic: Run State

> **Layer**: Foundation
> **GDD**: design/gdd/run-state.md (revision-1, Approved)
> **Architecture Module**: Foundation / Stage Lifecycle (per `docs/architecture/ARCHITECTURE.md` §核心模块 — 单局状态 / 场景切换)
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories run-state`

## Overview

Run State owns the 5-minute stage lifecycle: the monotonic clock, wave-config scheduling, Demon Seal spawn at 2:00, Elite spawns at 3:00 / 4:00, Boss warning at 4:30, Boss spawn at 5:00, and the two terminal transitions (`stage_cleared` via Boss `died`; `stage_failed` via Player `died`). Implementation lives in `scripts/system/stage_director.gd` (454 lines) as the `StageDirector` node under `scenes/Main.tscn`. It emits 9 signals that HUD, Combat Feedback, Audio, and analytics consume.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|---|---|---|
| ADR-0001: Godot 4.x + GDScript | Signal-based architecture; Resource-driven content; Forward+ renderer + Jolt physics | MEDIUM (post-cutoff API risk — see Engine Compatibility section) |

> **Note**: No StageDirector-specific ADR exists yet. ADR-0001 is foundational coverage only. If StageDirector evolves significantly (e.g. multi-stage progression in v0.5+), a dedicated ADR would be appropriate.

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|---|---|---|
| TR-core-002 | 5-minute run with 0:00 / 2:00 / 4:30 / 5:00 beats | ❌ No ADR — suggested: ADR for Stage Director timing rules |
| TR-core-006 | Demon seal 8s seal process with risk events | ❌ No ADR — suggested: ADR for Demon Seal contract |
| TR-enemy-003 | Boss spawns at 5:00 with warning; defeat triggers victory | ❌ No ADR — suggested: ADR for Boss spawn + victory |
| TR-run-001 | Run-end states (death / victory / quit) | ❌ No ADR — suggested: ADR for Run lifecycle states |

> ⚠️ **All 4 TRs in Run State are untraced.** Epic can be created and stories drafted, but stories will be marked Blocked until ADRs exist. Run `/architecture-decision` for the 4 suggested ADRs, OR proceed with placeholder TR references (stories will fall back to direct GDD section cites).

## Definition of Done

This epic is complete when:
- All stories implemented, reviewed, and closed via `/story-done`
- All 22 acceptance criteria from `design/gdd/run-state.md` verified
- All Logic stories (clock progression, wave config sequence, demon seal mechanic, run-end signals) have passing test files in `tests/unit/run-state/`
- All Integration stories (StageDirector ↔ EnemySpawner ↔ Player ↔ Boss) have either integration test or playtest evidence in `production/qa/evidence/`
- Run a clean 5-minute stage and confirm: timer ticks 0:00 → 5:00, all 5 wave configs activate in sequence, demon seal spawns at 120s, elites spawn at 180s/240s, boss warning at 270s, boss at 300s, victory or defeat triggers GameOverPanel
- All 6 Open Questions (clock pause, error handling, tech-debt extraction, archetype-vs-exports cleanup, debug-multiplier guards, multi-stage scope) have a resolution decision logged

## Next Step

Run `/create-stories run-state` to break this epic into implementable stories.
