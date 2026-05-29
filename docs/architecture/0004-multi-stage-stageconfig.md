# ADR-0004: Multi-Stage Architecture (StageConfig + RunDirector)

## Status

Proposed

> Proceeding to implementation under the owner's delegated authority (2026-05-29).
> Recommended validation: `/architecture-review` in a fresh session before the
> implementation epic is closed. Stories may reference this ADR as the governing
> decision for the Stage 2 content pack.

## Date

2026-05-29

## Last Verified

2026-05-29

## Decision Makers

claude (lead), with `technical-director` agent consultation. Owner delegated full
dev authority for the Stage 2 content pack.

## Summary

The Stage Director is hardcoded for one 5-minute stage (wave timing constants + five
`_get_wave_*()` functions), violating the project's "no hardcoded waves" rule and
leaving multi-stage sequencing nowhere to live. This ADR makes a stage **data**
(a `StageConfig` Resource + nested `WaveConfig`/`EliteSpawnEvent` sub-resources read
by a now-generic Stage Director) and introduces a **`RunDirector`** node that owns
the run lifecycle and sequences stages (clear Stage 1 → carry the live Player into
Stage 2 → run victory).

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Core (scene/resource architecture) |
| **Knowledge Risk** | LOW — Resource/`@export` typed arrays + nested sub-resources are stable Godot 4 features; nested typed-Resource array `.tres` serialization is reliable in 4.4+ |
| **References Consulted** | `scripts/system/stage_director.gd`, `scripts/system/enemy_spawner.gd`, `scripts/player/player.gd`, `scripts/ui/hud.gd`, `scripts/ui/character_select_panel.gd`, `scenes/Main.tscn`, `scripts/enemy/enemy_archetype.gd` |
| **Post-Cutoff APIs Used** | None (Resource composition is pre-4.0) |
| **Verification Required** | Confirm nested `Array[WaveConfig]` of separate `.tres` files serializes + reloads (author wave configs as standalone `.tres` referenced by path, not inline). Confirm `@export var x: StageConfig = null` default is honored on Stage 1. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Godot 4 + GDScript) — Accepted |
| **Enables** | Stage 2 content pack (Ghost Market Trade, enemy roster, Ghost Market Judge boss); future Stage 3 (昆仑残境) as a 3rd `StageConfig` |
| **Blocks** | Stage 2 implementation epic — cannot start until this ADR governs the StageConfig contract |
| **Ordering Note** | The BossBase refactor (boss-system.md OQ-3) is parallel and independent; both land in the Stage 2 epic |

## Context

### Problem Statement

We are adding Stage 2 (幽都鬼市). The player reaches it **sequentially** (clear Stage 1
→ continue with the same build). The current architecture cannot express a second
stage at all: stage content is hardcoded in `stage_director.gd`, and there is no
owner for run-level flow (spawning the player, pausing, ending vs advancing the run).
Deciding now prevents Stage 2 from being a copy-pasted second director (doubling the
hardcoding debt).

### Current State

- `scripts/system/stage_director.gd` (~460 lines, Node2D) hardcodes the single stage:
  timing constants `WAVE_TWO/THREE/FOUR_START_TIME` + `WAVE_BOSS_WARNING_START_TIME`;
  five wave configs in `_get_wave_config_index/_get_wave_spawn_interval/_get_wave_max_enemies/_get_wave_archetype_pool/_get_wave_archetype_weights`; fixed elite times.
  Only `boss_scene` + demon-seal params are `@export`.
- **No run-lifecycle owner.** `CharacterSelectPanel` spawns the Player and re-wires
  siblings via `set()/call()`; `HUD._on_stage_cleared` pauses the tree and ends the
  run; `Main.tscn` has no root script. Sequencing has nowhere to live.
- This violates `technical-preferences.md` Forbidden Patterns ("No hardcoded balance:
  …waves must be `.tres` Resource-driven").

### Constraints

- Godot 4.6, typed GDScript, Resource-driven, signal-based.
- Project rule: **no gameplay singletons** — prefer scene composition + DI.
- Backward compatibility: **Stage 1 must play byte-identically** after the refactor.
- Must preserve combat contracts intact (aggregate-DPS ceiling, D-B2 caps, damage tuple).

### Requirements

- A stage is fully described by data (a `StageConfig` `.tres`).
- The Player's live state (HP, level, XP, unlocked weapons, `_upgrade_pick_count`,
  buffs) carries across the Stage 1→2 transition with **no save/load** (same node).
- Existing Stage Director signal API unchanged (HUD + EnemySpawner contracts stable).
- Incremental migration: CI green + Stage 1 identical at every step.

## Decision

Make stages data; make the Stage Director a generic engine; introduce a `RunDirector`
to own the run lifecycle and stage sequence.

### Architecture

```
                         Main.tscn
                            │
                ┌───────────┴────────────┐
            RunDirector (Node, root script)         owns run lifecycle
                │  stage_sequence: Array[StageConfig]
                │  _index, _player
                ├── spawns Player (was: CharacterSelectPanel)
                ├── owns get_tree().paused + GameOverPanel (was: HUD)
                ├── stage_director.stage_config = sequence[_index]; begin()
                └── on stage_cleared → _advance_stage() or run_victory
                            │
        ┌───────────────────┼───────────────────┐
   StageDirector        EnemySpawner            HUD (display-only)
   reads StageConfig    apply_wave_config()     unchanged signals
        │
   StageConfig (.tres) ── waves: Array[WaveConfig]  (each a standalone .tres)
                       ├─ elite_events: Array[EliteSpawnEvent]
                       ├─ boss_scene: PackedScene
                       ├─ demon_seal_config: DemonSealConfig
                       └─ trade_stall_config: TradeStallConfig  (null on Stage 1)
```

### Key Interfaces

```gdscript
class_name WaveConfig
extends Resource
@export var start_time: float = 0.0           # absolute elapsed seconds (step boundary)
@export var spawn_interval: float = 1.35
@export var max_enemies: int = 18
@export var archetype_pool: Array[EnemyArchetype] = []
@export var archetype_weights: Array[float] = []

class_name EliteSpawnEvent
extends Resource
@export var spawn_time: float = 180.0
@export var archetype: EnemyArchetype
@export var affixes: Array[String] = []
@export var spawn_distance: float = 420.0

class_name StageConfig
extends Resource
@export var stage_id: StringName = &"stage_1"
@export var display_name: String = "荒山"
@export var stage_duration: float = 300.0
@export var waves: Array[WaveConfig] = []
@export var elite_events: Array[EliteSpawnEvent] = []
@export var boss_scene: PackedScene
@export_group("Boss Fallback")   # only used when boss.archetype == null (dead-code parity)
@export var boss_warning_lead_time: float = 30.0
@export var boss_spawn_distance: float = 420.0
# ... boss_move_speed/max_hp/damage/scale/phase_spawn_interval/phase_max_enemies
@export_group("Demon Seal")
@export var demon_seal_config: DemonSealConfig
@export_group("Stage 2+")
@export var trade_stall_config: TradeStallConfig = null   # null ⇒ stage has no stalls

# StageDirector additions
@export var stage_config: StageConfig
func begin() -> void
func reset_for_stage(config: StageConfig) -> void   # re-init _is_* flags, elapsed_time

# RunDirector (new Node)
@export var stage_sequence: Array[StageConfig] = []
signal stage_advanced(index: int, config: StageConfig)
signal run_victory()
```

### Implementation Guidelines

- **StageDirector**: delete the 5 `_get_wave_*()` functions + timing constants;
  `_get_wave_config_index()` becomes a linear scan of `config.waves` by `start_time`;
  elites become a loop over `config.elite_events`. **The spawn loop, the
  `apply_wave_config()` call, demon-seal pressure logic, the OQ-4 late-signal guard,
  and all ten signals stay byte-for-byte identical.**
- **RunDirector**: `_advance_stage()` **reuses the same StageDirector node**
  (`reset_for_stage`) and **never reloads the Player** (state persists in-memory) —
  so `_upgrade_pick_count` / D-B2 caps / buffs carry for free. Clears `enemies`/`xp_orbs`
  groups + nulls `_demon_seal` between stages; defers advance until the player is not
  mid-level-up (`_is_selecting_upgrade == false`).
- Author wave configs as **standalone `.tres`** referenced by path (independently
  diffable), not inline sub-resources.
- Add a stage-index offset to the EnemySpawner RNG seed so Stage 2 isn't an identical
  spawn pattern to Stage 1.

### Stage-Transition Design Decisions (game-design defaults; playtest-tunable)

The technical-director surfaced three non-architecture design questions. Owner
decisions (defaults, flagged for playtest):

1. **Score/time**: **accumulate** across stages (it is one continuous run). HUD shows
   total survival time + cumulative kills, with a stage banner on transition.
2. **Inter-stage reward**: a **"second wind"** on clearing Stage 1 — restore **+40%
   of max HP** (not full) — rewards progression without trivializing Stage 2 entry.
   No separate shop (the Ghost Market Trade IS Stage 2's shop-like mechanic).
3. **HUD**: cumulative kills + total time + a `stage_advanced`-driven stage label.

These are tuning defaults, not architecture — adjustable after playtest.

## Alternatives Considered

### Alternative 1: RunState data-object + free transition function (no RunDirector node)

- **Description**: keep run-flow scattered; add a plain data object for the sequence.
- **Cons**: leaves spawn-Player/pause/GameOverPanel logic fragmented across UI; least cohesive.
- **Rejection Reason**: the missing *owner* is the actual problem; a data object doesn't fix it.

### Alternative 2: Instantiate a fresh StageDirector per stage

- **Description**: new director node per stage.
- **Cons**: re-wiring signals to HUD each stage re-introduces the brittle `set()/call()` pattern.
- **Rejection Reason**: node reuse (`reset_for_stage`) is cheaper and safer.

### Alternative 3: Split this ADR — "stages as data" only, defer RunDirector

- **Description**: migration steps 1–3 only; run-flow refactor in a later ADR.
- **Pros**: smaller blast radius.
- **Cons**: Stage 2 sequencing still has no owner — blocked anyway.
- **Rejection Reason**: chosen to **include** RunDirector; the migration keeps Stage 1
  identical through step 3, so the run-flow steps (4–5) can still be deferred if step 3
  surfaces problems.

## Consequences

### Positive
- Stages become pure data; Stage 2 ships as `stage_2.tres` + content `.tres`, near-zero new director code.
- Run-flow finally has one owner (RunDirector); removes brittle `set()/call()` re-wiring.
- Fixes the "no hardcoded waves" rule violation.
- Player carry needs no save/load — same in-memory node.

### Negative
- One extra node + indirection; `CharacterSelectPanel`/`HUD` lose responsibilities (intentional).
- One-time risk window during the HUD-pause-ownership migration (step 4).

### Neutral
- Wave timing model switches from a hardcoded step function to an absolute-`start_time` data scan (behaviorally identical when authored to match).

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|-----------|
| Playtested 5-min pacing drifts when waves move to data | Med | High | **Golden test** (step 3) pinning wave index/interval/max/pool/weights at t=0/60/120/180/270 to the old hardcoded outputs; sign off Stage 1 unchanged before step 4 |
| Demon-seal timing/pressure breaks on extraction | Med | High | Keep `_set_demon_seal_pressure_active` + OQ-4 guard untouched; only the *params* move to `DemonSealConfig` |
| Level-up pause collides with stage transition | Med | Med | RunDirector defers `_advance_stage` until `_player._is_selecting_upgrade == false` |
| `_upgrade_pick_count` / D-B2 caps reset on carry | Low | High | Reuse the **same Player node**; assert caps persist post-transition |
| Stale enemy/orb/seal nodes leak into Stage 2 | Med | Med | Explicit cleanup pass in `_advance_stage` |
| Aggregate-DPS-ceiling / combat contract disturbed | Low | High | Director changes don't touch combat; the 99-test suite is the gate |

## Performance Implications

| Metric | Before | Expected After | Budget |
|--------|--------|---------------|--------|
| CPU (frame time) | baseline | unchanged (Resource lookups O(waves≈5) per band-change, not per-frame) | 16.67 ms |
| Memory | baseline | +negligible (a few small Resources resident) | ≤ 1 GB |
| Load Time | baseline | +negligible (StageConfig `.tres` load) | — |

## Migration Plan

CI green + Stage 1 identical at every step:

1. Add Resources (`WaveConfig`, `EliteSpawnEvent`, `DemonSealConfig`, `StageConfig`; `TradeStallConfig` stub). No behavior change.
2. Author `stage_1.tres` + 5 wave `.tres` mirroring current constants exactly (intervals 1.35/1.08/0.90/0.72/0.55; max 18/24/32/42/56; weights as-is; elites @180 iron_bones, @240 swift).
3. StageDirector reads `stage_config`; keep `@export` fallbacks. **Add a golden test** asserting wave outputs at boundary times match the old hardcoded values. Verify Stage 1 byte-identical.
4. Add `RunDirector`; move Player-spawn + pause + GameOverPanel ownership into it; `stage_sequence=[stage_1.tres]`. Stage 1 still ends the run. Re-run suite.
5. Add sequencing (`_advance_stage`, `reset_for_stage`, cleanup, `run_victory`, +40% heal). Test with `[stage_1, stage_1]` (clear → advance → clear → victory) before Stage 2 content exists.
6. Author `stage_2.tres` + 鬼市 roster `.tres` + GhostMarketJudge (BossBase refactor) + `TradeStallConfig`; append to sequence.

**Rollback plan**: each step is its own commit; revert to the last green commit. Steps 1–3 are isolated from run-flow, so a step-4 problem rolls back without losing the data-driven director.

## Validation Criteria

- [ ] Golden test: Stage 1 wave outputs at t=0/60/120/180/270 identical to pre-refactor.
- [ ] Full 99-test suite stays green at every migration step.
- [ ] `[stage_1, stage_1]` test run: clear → advance (player state carried) → clear → `run_victory`.
- [ ] Post-transition assert: `_upgrade_pick_count`, level, unlocked weapons, buffs all intact.
- [ ] Stage 2 plays with the Ghost Market roster + Judge + trade stalls from `stage_2.tres`.

## GDD Requirements Addressed

| GDD Document | System | Requirement | How This ADR Satisfies It |
|-------------|--------|-------------|--------------------------|
| `design/gdd/stage-director.md` | Stage Director | Stage pacing / wave orchestration | Wave timeline becomes `StageConfig.waves` data read by the generic director |
| `design/gdd/ghost-market-trade.md` | Ghost Market Trade (#26) | Stage 2 stalls + demon-tide penalty owned by StageConfig/StageDirector | `TradeStallConfig` sub-resource + RunDirector sequencing |
| `design/gdd/stage-2-enemies.md` | Enemy roster | Stage 2 wave pools reference new archetypes | `WaveConfig.archetype_pool` data |
| `design/gdd/boss-system.md` (r2) | Boss System | Stage 2 Boss swap + BossBase | `StageConfig.boss_scene` (already swappable) + parallel BossBase refactor |
| `design/gdd/run-state.md` | Run State | Single-run lifecycle / pause / timing ownership | RunDirector consolidates run-flow ownership (currently scattered across UI) |

## Related

- ADR-0001 (Godot 4 + GDScript) — foundational, Accepted.
- boss-system.md OQ-3 — BossBase refactor (parallel, lands in the same epic).
- ghost-market-trade.md — Stage 2 mechanic that depends on this architecture.
- Code (post-implementation): `scripts/resources/stage_config.gd`, `scripts/system/run_director.gd`, refactored `scripts/system/stage_director.gd`, `resources/stages/stage_1.tres`, `stage_2.tres`.
