# ADR-0010: Run Lifecycle & Stage Signal Contract

## Status
Accepted (2026-06-04 — independent /architecture-review verdict CONCERNS: architecture substantively passes; 9-signal contract + run-end policy sound. C-5 timing tail (3-min propagation to ~17 docs) tracked separately as a /propagate-design-change task.)

## Date
2026-06-04

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Scripting / Core |
| **Knowledge Risk** | LOW (signal-based lifecycle; no post-cutoff API) |
| **References Consulted** | `design/gdd/run-state.md`, `stage-director.md`, `03_CORE_GAMEPLAY.md`, `boss-system.md`, `demon-seal.md`; `docs/architecture/0004-multi-stage-stageconfig.md`; `/architecture-review` (2026-06-04) |
| **Post-Cutoff APIs Used** | None. Typed signals (4.0+). |
| **Verification Required** | None new — `tests/` cover run-end transitions; this ADR formalizes the as-built lifecycle and **corrects the stale 5-minute timing** across docs. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0004 (Multi-Stage StageConfig / RunDirector — Accepted), ADR-0001 |
| **Enables** | ADR-0005 (Merit reads run-end metric accessors), Demon Seal / Boss / Stage Director / HUD ADRs (consume the 9 signals) |
| **Blocks** | Merit, Demon Seal, Boss, HUD epics (they subscribe to this contract) |
| **Ordering Note** | Formalizes the lifecycle ADR-0004 implements. Resolves conflict C-5 (stale 5-min timing) and rewrites TR-core-002. |

## Context

### Problem Statement
Run lifecycle is owned by `StageDirector` (per-stage) under `RunDirector` (ADR-0004, the 7-stage orchestrator), but has **no governing ADR** for its **9-signal contract** — the canonical interface HUD, Combat Feedback, Audio, Demon Seal, Boss, and Merit all subscribe to. Compounding this, the **5-minute single-stage timing is stale across four documents** (`03_CORE`, `05_ENEMY`, `game-concept`, `stage-director.md` Core Rule 1 still say 300 s) while the shipped reality (ADR-0004, 2026-05-30) is **3-minute combat stages in a 7-stage interleaved run** (荒山 → 鬼市 → 幽都 → 鬼市 → 荒山·再临 → 鬼市 → 幽都·深渊). A programmer or designer reading the stale timing builds to the wrong arc. This ADR locks the signal contract and the corrected timing.

### Constraints
- Brownfield: `StageDirector` + `RunDirector` implemented and test-covered; this ADR documents as-built and fixes doc drift.
- Single `StageDirector` node is the implementation; Run State is its lifecycle *view* (run-state.md authority split — Stage Director GDD wins on implementation specifics).
- Must expose the run-end metric accessors Merit (ADR-0005) depends on.

### Requirements
- Enumerate the 9 canonical signals with typed payloads.
- Lock run-end transition policy.
- Correct the 5-min → 3-min / 7-stage timing everywhere it is referenced.

## Decision

### 1. Lifecycle states (the "what state is the run in?" view)
`Pre-stage → Running → (Demon-seal pressure active) → Boss phase → Cleared | Failed`. Terminal on `Cleared` or `Failed`; once either fires, `_process` early-returns (no further wave/elite/Boss work). There is no "survive the timer" win — every combat stage ends at a Boss.

### 2. The 9 canonical signals (StageDirector — the authoritative contract)
```gdscript
signal stage_time_changed(elapsed: float, duration: float)
signal boss_warning_started(lead_time: float)
signal boss_spawned(boss: Node)
signal elite_spawned(enemy: Node)
signal demon_seal_spawned(position: Vector2)
signal demon_seal_progress_changed(progress: float)   # 0.0–1.0
signal demon_seal_completed(reward_position: Vector2)
signal stage_cleared(elapsed: float)
signal stage_failed(elapsed: float)
```
Subscribers: HUD (timer/warnings), Combat Feedback, Audio (phase cues), Demon Seal, Boss, Merit (run-end). No intermediate signal bus — direct `connect` in `_ready()` (per run-state.md Core Rule 9).

### 3. Run-end transition policy
`Player.died` → `stage_failed`; Boss `died` → `stage_cleared`. Both terminal. On `stage_cleared`, `EnemySpawner.set_spawning_enabled(false)` (quiet victory moment); alive enemies finish their actions.

### 4. RunDirector orchestration (ADR-0004) + corrected timing
`RunDirector` chains **7 stages**: 4 combat stages (**3 minutes each**, 180 s — NOT 300 s) interleaved with 3 calm Ghost Market interludes. Combat stages: 荒山 → 幽都 → 荒山·再临 ×1.4 → 幽都·深渊 ×1.7. Per-stage beats scale to the 3-minute arc (familiarisation → first pressure → demon-seal decision → elite pressure → Boss). RunDirector exposes the run-end metric accessors:
```gdscript
func get_total_elapsed() -> float        # sum of all stages' elapsed (Merit survival_time)
func get_stages_cleared() -> int         # 0–4
func get_bosses_defeated() -> int        # increments on Boss died
```
(These are the contract ADR-0005 / Merit §Run Metrics depend on.)

### 5. Timing correction (resolves C-5)
The canonical run timing is **3-minute combat stages, 7-stage interleaved run** (ADR-0004). All references to "5-minute / 300 s single run" are STALE and corrected: `stage-director.md` Core Rule 1, `03_CORE_GAMEPLAY.md`, `05_ENEMY_DESIGN.md`, `game-concept.md`, and **TR-core-002** (rewritten — see Migration Plan). Per-stage beat times (demon seal, boss warning, boss spawn) are expressed relative to the 180 s stage, not 300 s.

## Alternatives Considered

### Alternative 1: Intermediate signal bus for lifecycle events
- **Cons**: run-state.md Core Rule 9 specifies direct connect; a bus adds indirection for a small, stable signal set with known subscribers.
- **Rejection**: Direct `connect` is the as-built, simpler model. (Contrast ADR-0006's `CombatEvents` bus, justified by *per-instance* enemy connections at scale — the 9 lifecycle signals are single-source, so no bus needed.)

### Alternative 2: Leave timing docs as-is, fix later
- **Cons**: Four docs actively mislead on the core arc; `/create-stories` would embed 5-min assumptions.
- **Rejection**: Correcting now (this ADR + propagation) prevents wrong stories.

## Consequences

### Positive
- One locked 9-signal contract for all run-phase subscribers; run-end policy is unambiguous.
- Merit's metric accessors are anchored in an Accepted ADR.
- The stale 5-min timing is corrected at the source (ADR) and propagated.

### Negative
- Doc propagation cost (4 docs + TR-core-002) — mechanical, done in Migration Plan / `/propagate-design-change`.

### Risks
- **R-1**: `RunDirector` vs `StageDirector` naming appears in multiple docs; the metric accessors live on RunDirector (the 7-stage owner), not the per-stage StageDirector. Documented to prevent mis-wiring (Merit connects to RunDirector for totals, to StageDirector's `stage_cleared`/`stage_failed` for the run-end edge).

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| run-state.md | 9-signal canonical contract | §Decision 2 |
| run-state.md | run-end policy (Player.died→failed, Boss died→cleared) | §Decision 3 |
| run-state.md / merit-system.md | RunDirector metric accessors | §Decision 4 |
| stage-director.md / 03_CORE | 3-min stage / 7-stage run (was 5-min) | §Decision 4/5 (resolves C-5) |
| TR-core-002 | run timing requirement | §Decision 5 (rewritten) |
| TR-run-001 | run-end states | §Decision 1/3 |

## Performance Implications
- **CPU**: Signal emits on phase events (low frequency) + `stage_time_changed` once/frame (cheap). N/A for memory/draw/network.

## Migration Plan
Brownfield: lifecycle + RunDirector exist. **Doc corrections** (this ADR is canonical; propagate):
- Rewrite **TR-core-002** from "Single run lasts ~5 minutes: 0:00 → 2:00 seal → 4:30 warning → 5:00 Boss" to "Combat stage lasts 3 minutes (180 s); 7-stage interleaved run (4 combat + 3 Ghost Market interludes) per ADR-0004; per-stage beats: seal ~mid-stage, Boss warning before stage end, Boss at stage end."
- `/propagate-design-change` the 3-min/7-stage timing into `stage-director.md` Core Rule 1, `03_CORE_GAMEPLAY.md`, `05_ENEMY_DESIGN.md`, `game-concept.md`.
- Confirm RunDirector exposes `get_total_elapsed/get_stages_cleared/get_bosses_defeated` (add if missing — Merit dependency).

## Validation Criteria
- Existing run-end transition tests stay green (Player death → failed, Boss death → cleared).
- New: the 9 signals fire with correct payloads at their beats; `get_total_elapsed` sums across stages; metric accessors return correct counts at run-end (Merit integration).

## Related Decisions
- ADR-0004 (Multi-Stage StageConfig / RunDirector). ADR-0005 (Merit — metric accessors). ADR-0008 (spawning per wave). Demon Seal / Boss / HUD ADRs (consume the 9 signals).
- `run-state.md`, `stage-director.md`. TR-core-002 (rewritten), TR-run-001.
