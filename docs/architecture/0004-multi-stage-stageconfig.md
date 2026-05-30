# ADR-0004: Multi-Stage Architecture (StageConfig + RunDirector)

## Status

Accepted

> **2026-05-30** — Implemented and synced. The StageConfig + RunDirector architecture
> shipped; Stage 1, the Ghost Market interlude, and the Judge combat stage all run
> through it. During implementation the run shape evolved from a 2-stage sequence
> (荒山 → 幽都) into a **7-stage interleaved run** where combat stages alternate with
> calm Ghost Market trade interludes, and `is_interlude` + `difficulty_multiplier`
> were added to StageConfig. See the **2026-05-30 implementation-sync** note in the
> Decision section below for the as-built sequence.
>
> _(Originally proposed 2026-05-29 under the owner's delegated authority.)_

## Date

2026-05-29

## Last Verified

2026-05-30 (implementation-sync — verified against `scripts/system/run_director.gd`,
`scripts/resources/stage_config.gd`, `scripts/resources/ghost_market_interlude_config.gd`,
`scripts/system/stage_director.gd`, `scripts/system/enemy_spawner.gd`)

## Decision Makers

claude (lead), with `technical-director` agent consultation. Owner delegated full
dev authority for the Stage 2 content pack.

## Summary

The Stage Director is hardcoded for one 5-minute stage (wave timing constants + five
`_get_wave_*()` functions), violating the project's "no hardcoded waves" rule and
leaving multi-stage sequencing nowhere to live. This ADR makes a stage **data**
(a `StageConfig` Resource + nested `WaveConfig`/`EliteSpawnEvent` sub-resources read
by a now-generic Stage Director) and introduces a **`RunDirector`** node that owns
the run lifecycle and sequences stages — carrying the live Player (build / level /
HP) from stage to stage on a single life until run victory.

> **2026-05-30 (as built):** the sequence the `RunDirector` ships is a **7-stage
> interleaved run** — combat stages alternate with calm Ghost Market trade
> *interludes* (a new `StageConfig.is_interlude` mode), and the run escalates via a
> new `StageConfig.difficulty_multiplier`. Two further additions vs the original
> proposal: stage durations are **3 minutes** (was 5), and the
> `@export var stage_director` typed-NodePath gained a sibling-lookup fallback in
> `_ready()` because the typed export did not always resolve on load. Details in the
> Decision section's implementation-sync note.

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
            RunDirector (Node)                       owns run lifecycle
                │  _stage_configs: Array[StageConfig]  (built in _ensure_sequence)
                │  _stage_index
                │  @export stage_director  (+ sibling-lookup fallback in _ready)
                ├── carries the live Player across stages (no save/load)
                ├── on StageDirector.stage_advance_requested → advance_to_next_stage()
                │     → stage_director.reset_for_stage(next) + heal player (+40% max_hp)
                └── final stage's boss death → run_completed()
                            │
        ┌───────────────────┼───────────────────┐
   StageDirector        EnemySpawner            HUD (display-only)
   reads StageConfig    apply_wave_config()     unchanged signals
        │                difficulty_multiplier  TradePanel (interludes/trade)
        │                → volume + stat scale
   StageConfig ── is_interlude: bool            (2026-05-30: trade-interlude mode)
              ├─ difficulty_multiplier: float   (2026-05-30: escalation knob)
              ├─ waves: Array[WaveConfig]
              ├─ elite_events: Array[EliteSpawnEvent]
              ├─ boss_scene: PackedScene         (null for interludes)
              ├─ demon_seal_config: DemonSealConfig
              └─ trade_stall_config: TradeStallConfig
                   (Stage 1 + 幽都 combat: null; trade interludes: 3 stalls)

   As-built run = 7-stage interleaved sequence (combat ⇄ trade interlude, escalating):
     荒山 → 鬼市间隙 → 幽都(判官) → 鬼市间隙 → 荒山·再临(×1.4)
          → 鬼市间隙 → 幽都·深渊(×1.7) → run victory
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
@export var is_interlude: bool = false           # 2026-05-30: true ⇒ trade interlude
                                                 #   (no boss/seal/passive-spawn; auto-advances)
@export var stage_duration: float = 300.0        # combat: 180 as built; interlude: ~25 (its length)
@export var difficulty_multiplier: float = 1.0   # 2026-05-30: escalation knob
                                                 #   (wave volume + gentler enemy/boss stat scale)
@export var waves: Array[WaveConfig] = []
@export var elite_events: Array[EliteSpawnEvent] = []
@export var boss_scene: PackedScene
@export_group("Boss Fallback")   # only used when boss.archetype == null (dead-code parity)
@export var boss_warning_lead_time: float = 30.0
@export var boss_spawn_distance: float = 420.0
# ... boss_move_speed/max_hp/damage/scale/phase_spawn_interval/phase_max_enemies
@export_group("Demon Seal")
@export var demon_seal_config: DemonSealConfig
@export_group("Stage 2+ (Ghost Market)")
@export var trade_stall_config: TradeStallConfig = null   # null ⇒ stage has no stalls

# StageDirector additions
@export var stage_config: StageConfig
func begin() -> void
func reset_for_stage(config: StageConfig) -> void   # re-init _is_* flags, elapsed_time
                                                    #   disables passive spawning for interludes

# RunDirector (new Node) — as built
@export var stage_director: StageDirector           # 2026-05-30: + sibling-lookup fallback in _ready()
signal stage_advanced(stage_index: int, stage_config: StageConfig)
signal run_completed()                              # named run_completed (not run_victory)
func advance_to_next_stage() -> StageConfig
# Sequence is built in _ensure_sequence() (7-stage interleaved); set_stage_sequence()
# overrides it for tests / custom run modes.
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

### Implementation Sync (2026-05-30 — as built)

The architecture landed as designed (StageConfig data + generic StageDirector +
RunDirector owner, Player carried in-memory). During the Stage 2 build the **run
shape and StageConfig schema** evolved past the original proposal. The as-built
reality:

**1. Seven-stage interleaved sequence (`run_director.gd::_ensure_sequence`).**
The `RunDirector` no longer sequences two stages; it builds a finite 7-entry
`Array[StageConfig]` where combat stages alternate with calm **Ghost Market trade
interludes**:

| idx | StageConfig builder | kind | notes |
|---|---|---|---|
| 0 | `StageOneConfig.build()` | combat (荒山古道, 饕餮 boss) | difficulty ×1.0 |
| 1 | `GhostMarketInterludeConfig.build()` | **trade interlude** | calm, auto-advances |
| 2 | `StageTwoConfig.build()` | combat (幽都鬼市, 判官 boss) | difficulty ×1.0 |
| 3 | `GhostMarketInterludeConfig.build()` | **trade interlude** | calm, auto-advances |
| 4 | `StageOneConfig` remix "荒山古道 · 再临" | combat | difficulty **×1.4** |
| 5 | `GhostMarketInterludeConfig.build()` | **trade interlude** | calm, auto-advances |
| 6 | `StageTwoConfig` remix "幽都鬼市 · 深渊" | combat | difficulty **×1.7** → run victory |

The remix combat stages (idx 4, 6) are the two designed stages re-themed with a
raised `difficulty_multiplier`; the run ends when the final stage's boss dies.
Endless looping is **not** implemented — the sequence is finite. An infinite-loop
mode (cycling the themes at ever-rising `difficulty_multiplier`) remains a viable
future option but is explicitly out of scope here.

**2. `StageConfig.is_interlude: bool` (new field).** A trade interlude is a
`StageConfig` with `is_interlude = true`: no boss (`boss_scene = null`), no Demon
Seal, **no passive wave spawning** (the StageDirector calls
`EnemySpawner.set_spawning_enabled(false)` for interludes), a short
`stage_duration` (~25s), and a `TradeStallConfig` that spawns 3 stalls early. The
StageDirector treats `stage_duration` as the interlude length and **auto-advances**
(`_end_interlude`) instead of spawning a boss. The single `WaveConfig` an interlude
carries exists only to give the demon-tide a spawn pool. **Consequence:** the
Ghost Market trade mechanic moved OUT of the 幽都 combat stage and INTO these
interludes; `StageTwoConfig` now sets `trade_stall_config = null` and is a pure
combat stage (判官 boss + the 5 Ghost Market enemies). See `ghost-market-trade.md`
revision-2 (2026-05-30) for the gameplay design of this restructure.

**3. `StageConfig.difficulty_multiplier: float` (new field).** The endless-escalation
knob. It scales **two** dimensions for remix combat stages:
- **Wave volume** — `EnemySpawner` reads it directly; higher = more enemies / shorter
  spawn interval (no wave re-authoring).
- **Enemy + boss stats** — applied as a *gentler* factor than the volume bump so a
  ×1.7 stage is not a flat ×1.7 HP wall:
  - Spawned enemies (`enemy_spawner.gd`): `stat_scale = 1.0 + (mult − 1.0) × 0.5`
    on `max_hp` + `damage` (current_hp re-synced).
  - Boss (`stage_director.gd::_spawn_boss`): `boss_scale = 1.0 + (mult − 1.0) × 0.6`
    on `max_hp` + `damage`.

  Both write only the spawned node's public fields — they do **not** modify the
  frozen `enemy.gd` / boss scripts. `difficulty_multiplier = 1.0` = the authored
  values (the two non-remix combat stages, idx 0 & 2).

**4. 3-minute stages.** `stage_duration` for combat stages is **180** (was 300);
the final wave (the 怪浪 swarm) starts at 2:00. The boss / final wave / elite times
in `StageOneConfig` / `StageTwoConfig` were rescaled to the compressed timeline.

**5. Sibling-lookup fallback for the typed-NodePath export.** `RunDirector` wires
its `StageDirector` via `@export var stage_director: StageDirector`. A typed-NodePath
`@export` was observed to *not* resolve on load (the Stage 1→2 transition silently
never fired). `_ready()` now falls back to `get_parent().get_node_or_null(^"StageDirector")`
when the export is null, then connects `stage_advance_requested`. This is the fix
behind commit `ed03f4b` ("Stage 1→2 transition never fired").

**6. Stage data is still code-builders, not `.tres`.** `StageOneConfig` /
`StageTwoConfig` / `GhostMarketInterludeConfig` are GDScript `RefCounted` builders
(`static func build() -> StageConfig`) so CI can compile + unit-test them headlessly.
The `resources/stages/*.tres` serialization in the original migration plan (step 2)
remains a deferred editor follow-up — there is no `resources/stages/` directory yet.

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
| `design/gdd/ghost-market-trade.md` | Ghost Market Trade (#26) | Trade stalls + demon-tide penalty owned by StageConfig/StageDirector | `TradeStallConfig` sub-resource + RunDirector sequencing. **2026-05-30:** trade moved into `is_interlude` StageConfigs (`GhostMarketInterludeConfig`) between combat stages, not the 幽都 combat stage |
| `design/gdd/stage-2-enemies.md` | Enemy roster | Stage 2 wave pools reference new archetypes | `WaveConfig.archetype_pool` data; the 5 archetypes appear in the 幽都 combat stage AND the interlude demon-tides |
| `design/gdd/boss-system.md` (r2) | Boss System | Stage 2 Boss swap + BossBase | `StageConfig.boss_scene` (already swappable) + parallel BossBase refactor |
| `design/gdd/run-state.md` | Run State | Single-run lifecycle / pause / timing ownership | RunDirector consolidates run-flow ownership (currently scattered across UI) |

## Related

- ADR-0001 (Godot 4 + GDScript) — foundational, Accepted.
- boss-system.md OQ-3 — BossBase refactor (parallel, lands in the same epic).
- ghost-market-trade.md — the trade mechanic that depends on this architecture (revision-2 documents the interlude restructure synced here).
- Code (as built): `scripts/resources/stage_config.gd`, `scripts/resources/ghost_market_interlude_config.gd`, `scripts/resources/stage_one_config.gd`, `scripts/resources/stage_two_config.gd`, `scripts/system/run_director.gd`, the generic `scripts/system/stage_director.gd`, `scripts/system/enemy_spawner.gd` (difficulty_multiplier stat scaling). Stage data ships as code-builders; `resources/stages/*.tres` serialization is still deferred (no such directory yet).
