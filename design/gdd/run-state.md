# Run State System

> **Status**: Approved (revision-2 — addresses C-B1 from /review-all-gdds 2026-05-27: ownership-conflict with Stage Director resolved via lifecycle-view framing)
> **Author**: claude (revision-2 by claude — clarifies that Run State is the lifecycle-view of the underlying StageDirector node; Stage Director GDD is the canonical implementation spec)
> **Last Updated**: 2026-05-27 (revision-2, approved)
> **Implements Pillar**: Pillar 1 (清晰的生存压力 — Run State enforces the 5-minute pressure ramp), Pillar 5 (先完成小型 MVP — Run State is the loop that makes the project a *game* rather than a sandbox)
> **TR Coverage**: TR-core-002 (5-minute run with phase beats), TR-core-006 (demon seal spawn time), TR-enemy-003 (Boss spawn + victory), TR-run-001 (run-end states)

## Overview

Run State is the **lifecycle view** of the underlying `StageDirector` node. It describes the run from the perspective of "what state is the run in?" — Pre-stage, Running, Demon-seal pressure active, Boss phase, Cleared, Failed — and the policy contract for run-end transitions (`Player.died` → `stage_failed`; Boss `died` → `stage_cleared`). It is the temporal spine of every play session.

**Authority split with Stage Director GDD (C-B1 resolution)**:
- **Run State GDD (this doc)** owns: lifecycle state machine, run-end transition policy, the "what is this run in?" mental model, and the timeline narrative (act structure).
- **Stage Director GDD** owns: canonical signal contracts (9 signals enumerated below), Tuning Knobs (`stage_duration`, `boss_warning_lead_time`, etc.), wave config implementation details, and per-phase `EnemySpawner` reconfiguration.
- Both GDDs describe the SAME `StageDirector` node (`scripts/system/stage_director.gd` instanced under `Main.tscn`). There is only one node. Run State is the abstract role; Stage Director is the implementation spec. If they ever disagree, **Stage Director GDD wins** (it is the implementation-truth source).

Implementation: a single `StageDirector` node. The 9 signals enumerated in §Signal contracts below are the canonical list — see Stage Director GDD §Signals for full payload-typed contracts. HUD, Combat Feedback, Audio, and analytics subscribe to those signals.

Reference ADRs: ADR-0001 (Godot 4.x signal architecture). No ADR currently owns the "stage director" decision itself — Stage Director GDD is the spec source until an ADR is requested.

## Player Fantasy

Time is the antagonist the player doesn't see. The Run State System is the invisible director that:

> "Eases me in for a minute so I learn the controls. Tightens the screws at 1:00 when Fox Spirits show up to flank me. At 2:00 a 镇妖碑 appears and I have to decide: do I push toward it now, knowing the spawn rate just doubled while I'm sealing? Elites show up at 3:00 and 4:00 — they don't kill me but they tell me 'this is no longer the warm-up.' At 4:30 the screen flashes a warning. At 5:00 a Famine Beast lands 420 pixels from me and the spawner throttles down — now it's just me and the Boss."

The Run State is **the act structure**. Players never think "the stage director did that" — they think "the run was paced really well today" or "I died because I went for the seal too late." Both reactions are the system working.

Anti-fantasy: a player should never feel the stage is **random** in its escalation. Wave configs are deterministic per phase; randomness is only in spawn positions and archetype choice within a wave's pool.

## Detailed Rules

### Core Rules

1. **The stage clock advances monotonically from 0.0 to `stage_duration` (default 300.0 s) at real time.** Every frame, `elapsed_time += delta`, clamped to `stage_duration`. The clock does not pause for the Level Up panel — Player GDD's "pause" is local to upgrade UI; the StageDirector keeps running. (Note: this is a documented design choice — if upgrade-pause-stops-the-clock is desired, it requires a code change. See Open Questions.)

2. **Stage phases are time-triggered, not condition-triggered.** Wave config index is purely a function of `elapsed_time` (Formula 2). Elites spawn at hard-coded times (180.0s and 240.0s). Demon seal spawns at `demon_seal_spawn_time` (default 120.0s). Boss spawns at `stage_duration` exactly (300.0s). No "kill X enemies to advance the phase" mechanic exists.

3. **Run-end has exactly two paths.** Stage cleared (Boss `died` signal received) OR stage failed (Player `died` signal received). Both are terminal — once either fires, `_process()` early-returns and no further wave/elite/Boss work is done. There is no "you survived the timer" win condition because there is always a Boss at 5:00.

4. **Stage clearing throttles spawn pressure but does not stop spawns immediately.** When Boss `died` fires, `EnemySpawner.set_spawning_enabled(false)` is called — already-alive enemies continue to act, but no new enemies spawn. This gives the player a quiet victory-screen moment.

5. **All wave config values come from a hardcoded `match` statement, not `.tres`.** Wave 0 (intervals 1.35s, max 18 enemies, archetype pool [PaperDoll, WanderingSoul]), Wave 1 (1.08s, 24, +FoxSpirit/GhostFlame), Wave 2 (0.90s, 32, +StoneGolem), Wave 3 (0.72s, 42), Wave 4/Boss-warning (0.55s, 56). This is intentional for v0.4 simplicity but tech debt for Pillar 4 — see OQ-3.

6. **Demon Seal sealing applies a temporary spawn pressure boost.** While the player is in the seal radius and sealing is active, the **next** `_apply_current_wave_config()` call computes `wave_spawn_interval × 0.65` (clamped ≥ 0.1) and `wave_max_enemies + 6` before invoking `EnemySpawner.apply_wave_config(...)`. The spawner's properties are not mutated in-place; the whole wave config is re-applied with the multiplier baked in. When sealing ends (completed OR player leaves radius), the pressure boost reverts: the next `_apply_current_wave_config()` re-applies without the multiplier. Implementation: `_set_demon_seal_pressure_active(bool)` toggles the internal flag and calls `_apply_current_wave_config(force_apply=true)`.

7. **Boss phase is its own implicit wave config.** After `_spawn_boss()`, `EnemySpawner.spawn_interval ≥ 2.5` and `max_enemies ≤ 8`. This is enforced in `_apply_boss_phase_spawn_pressure()` and overrides any in-progress wave config. The Boss does not stop normal spawning entirely — a small trickle of fillers continues, which is the design intent for Boss-phase chaos.

8. **All stage parameters export defaults are clamped in `_ready()`.** `stage_duration ≥ MIN_STAGE_DURATION (1.0s)`, `boss_warning_lead_time ∈ [0, stage_duration]`, `demon_seal_spawn_time ∈ [0, stage_duration]`, etc. If a designer sets `stage_duration = 0` in `.tres` (typo), the engine doesn't crash — it clamps to 1.0s.

9. **Stage director observes Player and Boss `died` signals via direct connect in `_ready()`.** Signal name is `died`, matching Combat GDD revision-3 + Player GDD revision-2 (`signal died`). Wiring: `_player.died.connect(_on_player_died)` and `boss.died.connect(_on_boss_died)`. No intermediate signal bus.

### Stage Phase Timeline (canonical)

This is the design contract the rest of the spec implements. All times in seconds from stage start.

| Time | Event | Source |
|---|---|---|
| 0.0 | Stage begins (`stage_time_changed` first emit) | `_ready()` |
| 0.0 - 60.0 | **Wave 0**: spawn_interval 1.35s, max 18, pool [PaperDoll, WanderingSoul] | `_get_wave_config_index() == 0` |
| 60.0 - 120.0 | **Wave 1**: spawn_interval 1.08s, max 24, pool +FoxSpirit +GhostFlame | `_get_wave_config_index() == 1` |
| 120.0 | **Demon Seal spawns** (random angle, distance 200-280 px from Player) | `_spawn_demon_seal()` |
| 120.0 - 180.0 | **Wave 2**: spawn_interval 0.90s, max 32, pool +StoneGolem | `_get_wave_config_index() == 2` |
| 180.0 | **First Elite spawns** (Shanxiao + iron_bones affix, 420 px from Player) | `_spawn_first_elite()` |
| 180.0 - 240.0 | **Wave 3**: spawn_interval 0.72s, max 42 | `_get_wave_config_index() == 3` |
| 240.0 | **Second Elite spawns** (Shanxiao + swift affix, 420 px from Player) | `_spawn_second_elite()` |
| 240.0 - 270.0 | Wave 3 continues | (no event) |
| 270.0 | **Boss warning** (`boss_warning_started` emit, lead time 30s) | wave config index → 4 |
| 270.0 - 300.0 | **Wave 4**: spawn_interval 0.55s, max 56 (peak pressure pre-Boss) | `_get_wave_config_index() == 4` |
| 300.0 | **Boss spawns** (Famine Beast, 420 px from Player, archetype-loaded stats) | `_spawn_boss()` |
| 300.0+ | Boss phase: spawn_interval ≥ 2.5, max_enemies ≤ 8 (trickle) | `_apply_boss_phase_spawn_pressure()` |
| Boss death | `stage_cleared` emit; EnemySpawner disabled; alive enemies continue | `_on_boss_died()` |
| Player death (any time) | `stage_failed` emit; pressure boost cleared | `_on_player_died()` |

### States and Transitions

The StageDirector has 4 boolean state flags + a wave-config-index gate. Together they form an implicit state machine:

| State (boolean combination) | Active behavior | Exit transitions |
|---|---|---|
| **Pre-stage** (not entered — only in `_ready()`) | Clamp exports, wire signals, emit first `stage_time_changed` | → Running (immediately after `_ready()` completes) |
| **Running** (`!_is_stage_cleared && !_is_stage_failed`) | Advance clock, apply wave config, schedule events | → Cleared (Boss `died`) or → Failed (Player `died`) |
| **Demon-seal pressure active** (`_is_demon_seal_pressure_active`) | Multiplier `0.65` applied to spawn_interval, +6 to max_enemies | → cleared by seal completion or player leaving radius |
| **Boss phase** (`_is_boss_spawned`) | Spawn pressure throttled; wave config no longer re-applied | → Cleared (Boss `died`) |
| **Cleared** (`_is_stage_cleared == true`) | `_process()` early-returns; `EnemySpawner.set_spawning_enabled(false)` | terminal |
| **Failed** (`_is_stage_failed == true`) | `_process()` early-returns; pressure cleared | terminal |

### Interactions with Other Systems

| System | Direction | Interface |
|---|---|---|
| **EnemySpawner** | StageDirector → Spawner | Calls `apply_wave_config(interval, max, pool, weights)` per phase change; calls `spawn_elite_at(archetype, pos, affixes)` for elite events; calls `set_spawning_enabled(false)` after Boss death |
| **Player** | Player → StageDirector | StageDirector connects to `Player.died` in `_ready()`; on emit, sets `_is_stage_failed = true` |
| **Boss (Enemy)** | Boss → StageDirector | Each Boss instance gets its `died` signal connected at spawn; on emit, sets `_is_stage_cleared = true` |
| **DemonSeal (Area2D)** | DemonSeal ↔ StageDirector | StageDirector spawns the seal at 120s; connects `seal_progress_changed` and `seal_completed`; toggles pressure on progress events; spawns reward XP orbs on completion |
| **ExperienceOrb** | StageDirector → Orb | On Demon Seal completion, spawns 8 ExperienceOrb instances in a circle of radius 54 px around the seal position, each with `xp_value = 6.0` |
| **HUD** | StageDirector → HUD | HUD subscribes to `stage_time_changed` (run timer), `boss_warning_started` (warning UI), `boss_spawned` (Boss HP bar appears), `demon_seal_progress_changed` (seal progress bar) |
| **Combat Feedback (P-03)** | StageDirector → Feedback | Subscribes to `boss_spawned` (cinematic flash?), `boss_warning_started` (screen tint?). All effects owned by P-03 |
| **Run-end UI (GameOverPanel)** | StageDirector → UI | GameOverPanel listens for `stage_failed` (defeat screen) AND `stage_cleared` (victory screen — both display final stats) |

**Signal contracts** (full list, payload-typed):

```
stage_time_changed(elapsed_time: float, stage_duration: float)
boss_warning_started(warning_lead_time: float)
boss_spawned(boss: Enemy)
elite_spawned(elite: Enemy, affixes: Array[String])
demon_seal_spawned(demon_seal: Area2D)
demon_seal_progress_changed(progress_seconds: float, required_seconds: float, is_sealing: bool)
demon_seal_completed(demon_seal: Area2D)
stage_cleared(elapsed_time: float)
stage_failed(elapsed_time: float)
```

## Formulas

### Formula 1: Stage time progression

```
on _process(delta):
    if _is_stage_cleared or _is_stage_failed:
        return
    elapsed_time = min(elapsed_time + delta, stage_duration)
    emit stage_time_changed(elapsed_time, stage_duration)
    apply_current_wave_config()
    [check schedule triggers: boss warning, demon seal, elites, Boss]
```

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| `elapsed_time` | t | float | 0.0 – stage_duration | Monotonic clock |
| `stage_duration` | T | float | 1.0 – ∞ (clamp `MIN_STAGE_DURATION = 1.0`) | Total stage length, default 300.0 |
| `delta` | δ | float | per-frame, typically 0.01667 (60 FPS) | Frame delta |

**Output Range:** `elapsed_time` cannot exceed `stage_duration`. Clock never decrements.
**Example:** at 60 FPS, after 60 seconds of real time, `elapsed_time = 60.0` (within float precision). Wave config index transitions from 0 → 1 at this point (Formula 2).

### Formula 2: Wave config index selection

```
wave_config_index =
    4 if elapsed_time >= 270.0      # Boss warning phase
    3 if elapsed_time >= 180.0      # Post-elite-1 escalation
    2 if elapsed_time >= 120.0      # Post-demon-seal escalation
    1 if elapsed_time >= 60.0       # First difficulty bump
    0 otherwise                      # Familiarization
```

Constants: `WAVE_TWO_START_TIME = 60.0`, `WAVE_THREE_START_TIME = 120.0`, `WAVE_FOUR_START_TIME = 180.0`, `WAVE_BOSS_WARNING_START_TIME = 270.0`.

**Per-phase wave parameters (data table, hardcoded in `_get_wave_*`):**

| Wave | spawn_interval (s) | max_enemies | Archetype pool | Pool weights |
|---|---|---|---|---|
| 0 | 1.35 | 18 | PaperDoll, WanderingSoul | [4.0, 3.0] |
| 1 | 1.08 | 24 | +FoxSpirit, +GhostFlame | [3.6, 3.0, 0.8, 0.6] |
| 2 | 0.90 | 32 | +StoneGolem | [2.8, 2.8, 1.2, 1.0, 0.35] |
| 3 | 0.72 | 42 | (same as Wave 2) | [2.5, 2.4, 1.8, 1.4, 0.7] |
| 4 | 0.55 | 56 | (same as Wave 2) | [2.0, 2.0, 2.3, 1.9, 1.0] |

**Weight semantics**: weighted random pick — a weight-3.6 archetype is 6x as likely as a weight-0.6 archetype within the same wave. As waves advance, weight shifts toward heavier enemies (StoneGolem 0.35 → 1.0 from Wave 2 to Wave 4).

### Formula 3: Demon Seal pressure adjustment

While `is_demon_seal_pressure_active`:

```
effective_spawn_interval = max(wave_spawn_interval × 0.65, 0.1)
effective_max_enemies = wave_max_enemies + 6
```

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| `wave_spawn_interval` | si | float | from Wave config | Base interval before boost |
| `demon_seal_pressure_interval_multiplier` | m | float | 0.1 – 1.0 (clamped) | Default 0.65 |
| `demon_seal_pressure_max_enemy_bonus` | b | int | 0 – ∞ (clamped to ≥0) | Default 6 |

**Output Range:** during seal, spawn rate is 1.54× faster (1/0.65) and 6 more enemies are allowed onscreen. Boost reverts on `seal_completed` OR player leaving the seal radius.
**Example:** at 2:30 (Wave 2 active, si=0.90, max=32). Player enters seal: si=0.585, max=38. Player completes seal at 2:38 (8 seconds later): boost reverts to si=0.90, max=32.

### Formula 4: Spawn position (Boss / Elite / DemonSeal)

Each spawn is anchored to the Player's current position + a random angle + a per-event distance.

```
spawn_position = player.global_position + Vector2.RIGHT.rotated(random_angle) × distance
random_angle = rng.randf_range(0.0, TAU)   # TAU = 2π
```

**Per-event distance:**
- Boss: `boss_spawn_distance = 420.0` (fixed)
- Elite: `elite_spawn_distance = 420.0` (fixed)
- DemonSeal: random in `[demon_seal_min_spawn_distance=200, demon_seal_max_spawn_distance=280]` + 30 px Vector2 jitter on each axis

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| `random_angle` | θ | float | [0, 2π) | Uniform random direction |
| `distance` | d | float | per-event constant or range | px from Player |

**Output Range:** a ring (Boss/Elite) or annulus (Demon Seal) around the Player. No line-of-sight check — spawns can appear off-screen, behind cover, etc. (No cover system at MVP.)
**Example:** Player at (100, 100), Boss spawn → angle 1.2 rad, distance 420 → spawn at (100 + 420×cos(1.2), 100 + 420×sin(1.2)) ≈ (252, 491).

### Formula 5: Demon Seal reward placement

After seal completion, 8 XP orbs spawn in a circle around the seal:

```
for i in [0, demon_seal_reward_orb_count):
    angle = (TAU × i) / max(demon_seal_reward_orb_count, 1)
    distance = demon_seal_reward_radius   # default 54.0
    if demon_seal_reward_orb_count == 1:
        distance = 0.0   # special-case: lone orb spawns at center
    orb.global_position = seal.global_position + Vector2.RIGHT.rotated(angle) × distance
    orb.xp_value = demon_seal_reward_xp_value   # default 6.0
```

**Output:** 8 evenly-spaced orbs on a 54 px circle. Total reward XP = 8 × 6 = 48 XP. At Wandering Soul XP=5.5, this is ~8.7 normal enemy kills' worth — significant.

## Edge Cases

- **If `Player` node is not found at `_ready()`** (`get_node_or_null(player_path)` returns null): `_player` stays null. `Player.died.connect()` is skipped silently — no crash, but the stage will never receive a `stage_failed` trigger because the StageDirector never knows the player died. This is a configuration bug, not a runtime defect; should fail loudly via `push_error`. (See Open Questions.)
- **If `EnemySpawner` is not found** (same): wave configs are computed but never applied; spawn pressure stays at whatever the spawner was at scene load. Player gets a quiet stage (probably trivially easy).
- **If `boss_scene` is null** (developer typo): `push_warning` fires; the Boss simply does not spawn. Stage cannot be cleared. `_is_boss_spawned = true` is still set so the schedule check stops retrying every frame.
- **If `demon_seal_scene` is null**: similar — `push_warning` fires, no seal appears, stage proceeds without the 2:00 event. Reward orbs are never spawned.
- **If `experience_orb_scene` is null** AND seal completes: `push_warning` fires, no orbs spawn. Player completes seal but gets no XP reward. (`_is_demon_seal_completed = true` is still set; no retry.)
- **If `_apply_current_wave_config()` runs while `_is_boss_spawned == true`**: function early-returns — wave configs no longer applied during Boss phase. `_apply_boss_phase_spawn_pressure()` is authoritative.
- **If Player dies during Demon Seal sealing**: `_on_player_died` sets `_is_stage_failed = true`. Pressure boost is cleared via `_set_demon_seal_pressure_active(false)`. No partial reward is spawned.
- **If Boss dies before Player dies in the same frame**: order depends on signal-emit order. Both `_on_boss_died` and `_on_player_died` check `_is_stage_cleared || _is_stage_failed` first and early-return if either is already set. **First to fire wins.** This is a 1-frame edge case (e.g., Player and Boss both reach HP=0 from a chain hit) — almost never observable in practice.
- **If `elapsed_time` would advance past `stage_duration` in a single frame** (large `delta` from frame hitch): clamped to `stage_duration`. Boss spawn triggers normally at the clamp. `stage_time_changed` reports the clamped value, so HUD doesn't show 300.5 / 300.
- **If `set_demon_seal_pressure_active(true)` is called while already active**: no-op (idempotent check `if is_active == _is_demon_seal_pressure_active: return`).
- **If `_apply_current_wave_config()` is called with the same wave_config_index as last time**: early-returns (no redundant `apply_wave_config` calls on the spawner).
- **If two elites of the same affix are scheduled at the same time** (shouldn't happen — first_elite at 180, second at 240): each `_spawn_*_elite` has its own `_is_*_elite_spawned` flag, idempotent.
- **If stage timer runs past 300.0 because Boss spawn was somehow delayed (rare race)**: clock still clamps at 300. Boss spawns at 300.0 trigger as soon as the check sees `elapsed_time >= stage_duration`. The Boss can be slightly late if `_process` is starved, but never early.

## Dependencies

| Dependency | Type | Direction | Interface |
|---|---|---|---|
| **EnemySpawner** (FT-01) | Hard | StageDirector calls into | `apply_wave_config(interval, max, pool, weights)`, `spawn_elite_at(archetype, pos, affixes)`, `set_spawning_enabled(bool)`, `spawn_interval` and `max_enemies` properties |
| **Player** (C-01) | Hard | Bidirectional | StageDirector connects `Player.died` in `_ready()`; on emit, sets stage_failed. StageDirector does NOT call into Player. |
| **Enemy** (C-04) | Soft | Boss is an Enemy | Boss instance spawned from `boss_scene`; its `died` signal is connected at spawn time |
| **DemonSeal** (FT-08) | Hard | StageDirector spawns + connects | Seal must be an Area2D providing `seal_progress_changed(progress, required, is_sealing)` and `seal_completed(seal)` signals |
| **ExperienceOrb** (part of FT-04) | Soft | StageDirector spawns | On seal completion, 8 orbs are created with `xp_value = 6.0` |
| **HUD** (P-01) | Soft | StageDirector → HUD | HUD subscribes to `stage_time_changed`, `boss_warning_started`, `boss_spawned`, `demon_seal_progress_changed`. **HUD does not modify StageDirector state.** |
| **Combat Feedback** (P-03) | Soft | StageDirector → Feedback | Subscribes to `boss_spawned`, `boss_warning_started` for cinematic flourishes |
| **GameOverPanel** (P-02 subset) | Soft | StageDirector → UI | Subscribes to `stage_failed` (defeat screen) and `stage_cleared` (victory screen) |
| **Combat System** (C-03) | Indirect | shared signal | Combat owns `died()` signal; StageDirector consumes it from Player and Boss. No direct call. |
| **7 enemy archetype `.tres`** (FT-07 + FT-09 data) | Hard | StageDirector preloads | `WANDERING_SOUL_ARCHETYPE`, `PAPER_DOLL_ARCHETYPE`, `FOX_SPIRIT_ARCHETYPE`, `STONE_GOLEM_ARCHETYPE`, `GHOST_FLAME_ARCHETYPE`, `SHANXIAO_ELITE_ARCHETYPE` (Boss is via `boss_scene`, not archetype) |

**Bidirectional check (per design-docs rule)**:
- Player GDD lists Run State as soft-dependent on `Player.died` ✅ (Player GDD revision-2 line ~248: "`died()` signal initiates run-end transition")
- Combat GDD lists Run State as observer of `defeated()` (now `died()` per revision-3) ✅
- Enemy GDD (when written) must list Run State as observer of Boss `died` payload ⏳
- EnemySpawner GDD (when written) must list Run State as upstream caller ⏳
- DemonSeal GDD (when written) must list Run State as parent / signal consumer ⏳

## Tuning Knobs

All values are exports on the `StageDirector` node — adjustable per scene (`scenes/system/StageDirector.tscn`) or per Main.tscn override.

| Knob | Default | Design-safe range | Effect at extremes |
|---|---|---|---|
| `stage_duration` | 300.0 | 60 – 600 | <60 = no time to build; >600 = exhausting |
| `boss_warning_lead_time` | 30.0 | 5 – 60 | <5 = no warning feel; >60 = anxiety drag |
| `boss_spawn_distance` | 420.0 | 200 – 800 | <200 = unfair instant contact; >800 = off-screen invisible spawn |
| `boss_move_speed` | 70.0 | 30 – 120 | (currently unused if Boss has an `archetype` — overridden) |
| `boss_max_hp` | 260.0 | 100 – 1000 | (currently unused if Boss has an `archetype` — see code: `if boss.archetype == null:`) |
| `boss_damage` | 16.0 | 8 – 30 | Same as above |
| `boss_scale` | 1.8 | 1.0 – 3.0 | Visual only |
| `boss_phase_spawn_interval` | 2.5 | 1.0 – 10.0 | During Boss phase, spawner is clamped ≥ this value |
| `boss_phase_max_enemies` | 8 | 0 – 20 | During Boss phase, spawner is clamped ≤ this value. 0 disables filler spawns entirely. |
| `demon_seal_spawn_time` | 120.0 | 30 – stage_duration | <30 = seal arrives before player is ready; >stage_duration = seal never spawns |
| `demon_seal_min_spawn_distance` | 200.0 | 80 – 500 | <80 = seal lands on player; >500 = unreasonable trek |
| `demon_seal_max_spawn_distance` | 280.0 | min + 50 – 600 | Inner bound enforced ≥ min |
| `demon_seal_required_seconds` | 8.0 | 1 – 30 | <1 = seal trivial; >30 = punishing |
| `demon_seal_pressure_interval_multiplier` | 0.65 | 0.1 – 1.0 (clamped) | <0.1 = clamped; 1.0 = no pressure boost |
| `demon_seal_pressure_max_enemy_bonus` | 6 | 0 – 20 | 0 = no enemy count boost |
| `demon_seal_reward_orb_count` | 8 | 0 – 30 | 0 = no reward; >20 = HUD chaos |
| `demon_seal_reward_xp_value` | 6.0 | 0 – 50 | Per-orb XP |
| `demon_seal_reward_radius` | 54.0 | 0 – 200 | Orb circle radius around seal |
| `first_elite_spawn_time` | 180.0 | 60 – stage_duration | When first Shanxiao iron_bones elite appears |
| `second_elite_spawn_time` | 240.0 | first+30 – stage_duration | When second Shanxiao swift elite appears |
| `elite_spawn_distance` | 420.0 | 200 – 800 | Same shape as boss_spawn_distance |
| `spawn_interval_multiplier` (Debug/QA) | 1.0 | 0.1 – 10.0 | <1 = denser (e.g. 0.3 → 3.3x faster spawns); for W214 QA. **Production must ship at 1.0.** |
| `max_enemies_multiplier` (Debug/QA) | 1.0 | 0.1 – 5.0 | <1 = fewer enemies; >1 = stress test. Production 1.0. |

**Interaction warnings**:
- `demon_seal_spawn_time` close to `first_elite_spawn_time` (e.g. 175.0 / 180.0): seal and elite arrive nearly simultaneously, overwhelming the player. Keep ≥ 60s apart.
- `boss_warning_lead_time` + `boss_phase_spawn_interval` interaction: a 60s warning with 1s spawn_interval gives the player 30 seconds at peak pressure (Wave 4) before Boss — intentional spike. Lengthening warning lead alone (without lowering Wave 4 pressure) creates a brutal pre-Boss window.
- `spawn_interval_multiplier × max_enemies_multiplier` (Debug/QA): setting both to 0.3 / 3.0 produces unplayable density. Use for stress test only.

## Visual/Audio Requirements

StageDirector emits 9 signals; visual/audio responses are owned by downstream systems:

- **`stage_time_changed`**: HUD timer ticks. No visual flourish at the system level.
- **`boss_warning_started`** (30s before Boss): Combat Feedback / VFX should:
  - Tint the screen slightly red for 1-2 seconds (cinematic flash)
  - Audio: low-frequency rumble / 大鼓声 (per Audio GDD when written)
  - HUD: warning banner "妖王降临 30s"
- **`boss_spawned`**: Combat Feedback / VFX:
  - Boss-spawn cinematic VFX (sprite zoom, screen pause 0.3s)
  - Audio: Boss theme music transition
  - HUD: Boss HP bar appears at top of screen
- **`demon_seal_spawned`**: VFX = subtle glow at seal position. Audio = bell / chime cue.
- **`demon_seal_progress_changed`** (sealing): HUD shows seal progress bar (0 → required_seconds). Audio = building tension hum.
- **`demon_seal_completed`**: Burst VFX, success chime, XP orbs visible in radius.
- **`elite_spawned`**: Combat Feedback = enemy spotlight / outline glow for 0.5s.
- **`stage_cleared`**: GameOverPanel displays victory screen. Audio: triumphant clear theme.
- **`stage_failed`**: GameOverPanel displays defeat screen. Audio: death sting.

📌 **Asset Spec** — All audio cues will be specified by Audio GDD (Full Vision tier). All VFX by VFX GDD (Full Vision tier). This GDD only defines the *triggers*.

📌 **UX Flag — Run State System**: Run timer + Boss warning + Demon Seal progress are HUD surfaces. In Phase 4 (Pre-Production), `/ux-design design/ux/hud.md` must include: (a) run timer placement & font, (b) Boss warning banner state, (c) Demon Seal progress bar style, (d) Boss HP bar style. Currently joined to the existing UX Flag in Combat GDD.

## UI Requirements

UI surfaces owned or consumed by Run State:

1. **Run timer** (HUD): subscribes to `stage_time_changed(elapsed, duration)`. Displays as `MM:SS / 05:00`. Already implemented in `scripts/ui/hud.gd` per 08_UI_UX guide.
2. **Boss warning banner** (HUD): subscribes to `boss_warning_started`. Banner shows "妖王降临 30s" with countdown (computed locally from `boss_warning_lead_time`). Vanishes when `boss_spawned` fires.
3. **Boss HP bar** (HUD): subscribes to `boss_spawned(boss)` — at that moment, HUD wires up the Boss instance's `damage_taken` signal (per Combat GDD AC-22 contract) to populate a top-screen HP bar.
4. **Demon Seal progress bar** (HUD or world-space overlay): subscribes to `demon_seal_progress_changed(progress, required, is_sealing)`. Bar fills 0 → required as player stays in radius.
5. **GameOverPanel** (`scenes/ui/GameOverPanel.tscn`): subscribes to BOTH `stage_failed` and `stage_cleared`. Single panel, two variants (defeat-vs-victory) determined by which signal fired.

## Acceptance Criteria

Numbered for traceability into `/create-stories`.

### AC group: Stage clock (Formula 1, Core Rule 1)

**AC-01** **GIVEN** a fresh stage at `elapsed_time = 0.0`, **WHEN** `_ready()` completes, **THEN** `stage_time_changed(0.0, 300.0)` is emitted exactly once.

**AC-02** **GIVEN** a stage at `elapsed_time = 50.0` and `_is_stage_cleared = _is_stage_failed = false`, **WHEN** `_process(0.0167)` runs, **THEN** `elapsed_time` becomes approximately `50.0167` AND `stage_time_changed(50.0167, 300.0)` is emitted.

**AC-03** **GIVEN** a stage at `elapsed_time = 299.99` AND `delta = 0.5` (large frame hitch), **WHEN** `_process(0.5)` runs, **THEN** `elapsed_time` is clamped to `300.0` (NOT `300.49`) AND `stage_time_changed(300.0, 300.0)` is emitted.

**AC-04** **GIVEN** a stage in `Cleared` state (`_is_stage_cleared == true`), **WHEN** `_process(0.0167)` runs, **THEN** the function early-returns AND `elapsed_time` is unchanged AND no `stage_time_changed` fires.

### AC group: Wave config sequence (Formula 2, Core Rule 2)

**AC-05** **GIVEN** `elapsed_time = 59.9`, **WHEN** `_get_wave_config_index()` is called, **THEN** returns `0`.

**AC-06** **GIVEN** `elapsed_time = 60.0`, **WHEN** `_get_wave_config_index()` is called, **THEN** returns `1`.

**AC-07** **GIVEN** wave config index transitions from 0 to 1 between two frames, **WHEN** `_apply_current_wave_config()` runs on the second frame, **THEN** `EnemySpawner.apply_wave_config(1.08, 24, [4 archetypes], [3.6, 3.0, 0.8, 0.6])` is called exactly once.

**AC-08** **GIVEN** wave config index is unchanged between consecutive frames (e.g. both at index 0), **WHEN** `_apply_current_wave_config()` runs, **THEN** `EnemySpawner.apply_wave_config` is NOT called (deduplication via `_current_wave_config_index`).

### AC group: Schedule triggers (Core Rule 2, Timeline)

**AC-09** **GIVEN** `elapsed_time` crosses `120.0` for the first time AND `_is_demon_seal_spawned == false`, **WHEN** `_process` runs, **THEN** `_spawn_demon_seal()` is called exactly once AND `_is_demon_seal_spawned` becomes `true`.

**AC-10** **GIVEN** `elapsed_time` crosses `180.0` for the first time, **WHEN** `_process` runs, **THEN** `_spawn_first_elite()` is called exactly once AND `_is_first_elite_spawned` becomes `true` AND `elite_spawned(elite, ["iron_bones"])` is emitted.

**AC-11** **GIVEN** `elapsed_time` crosses `240.0` for the first time, **WHEN** `_process` runs, **THEN** `_spawn_second_elite()` is called exactly once AND `elite_spawned(elite, ["swift"])` is emitted.

**AC-12** **GIVEN** `elapsed_time` crosses `270.0` (stage_duration - boss_warning_lead_time), **WHEN** `_process` runs, **THEN** `_is_boss_warning_started` becomes `true` AND `boss_warning_started(30.0)` is emitted exactly once.

**AC-13** **GIVEN** `elapsed_time` reaches `300.0` (stage_duration), **WHEN** `_process` runs, **THEN** `_spawn_boss()` is called AND `boss_spawned(boss)` is emitted AND `EnemySpawner.spawn_interval` is clamped ≥ 2.5 AND `EnemySpawner.max_enemies` is clamped ≤ 8.

### AC group: Demon Seal mechanic (Core Rule 6, Formula 3, Formula 5)

**AC-14** **GIVEN** an active stage with seal spawned, **WHEN** `_on_demon_seal_progress_changed(2.0, 8.0, true)` is invoked, **THEN** `_set_demon_seal_pressure_active(true)` runs AND `_apply_current_wave_config(force_apply=true)` triggers the next `EnemySpawner.apply_wave_config(...)` call with `wave_spawn_interval × 0.65` (clamped ≥ 0.1) and `wave_max_enemies + 6` baked in AND `demon_seal_progress_changed(2.0, 8.0, true)` is re-emitted by StageDirector. (Note: the spawner's existing values are NOT mutated in-place; the whole config is re-applied.)

**AC-15** **GIVEN** seal is at progress 7.9 with `is_sealing = true`, **WHEN** `seal_completed` fires, **THEN** `_is_demon_seal_completed = true` AND the next `EnemySpawner.apply_wave_config(...)` call uses the unmodified `wave_spawn_interval` and `wave_max_enemies` (pressure boost reverts via re-application, not via in-place mutation) AND 8 ExperienceOrb instances spawn in a 54px circle around the seal position AND each orb's `xp_value = 6.0`.

**AC-16** **GIVEN** `_is_demon_seal_completed == true`, **WHEN** another `seal_completed` event is received (defensive), **THEN** the second call is a no-op (deduplication via `_is_demon_seal_completed` guard).

### AC group: Run-end signals (Core Rules 3, 4)

**AC-17** **GIVEN** a stage in `Running` state, **WHEN** `Player.died` fires, **THEN** `_on_player_died()` runs AND `_is_stage_failed = true` AND `stage_failed(elapsed_time)` is emitted exactly once AND demon seal pressure (if active) is cleared.

**AC-18** **GIVEN** a stage in `Running` state with Boss spawned, **WHEN** Boss `died` fires, **THEN** `_on_boss_died()` runs AND `_is_stage_cleared = true` AND `stage_cleared(elapsed_time)` is emitted exactly once AND `EnemySpawner.set_spawning_enabled(false)` is called.

**AC-19** **GIVEN** `_is_stage_failed == true`, **WHEN** Boss `died` fires after, **THEN** the boss-died handler early-returns AND `stage_cleared` is NOT emitted (first-to-fire wins).

**AC-20** **GIVEN** `_is_stage_cleared == true`, **WHEN** Player `died` fires after (e.g. Boss death attack also killed Player), **THEN** the player-died handler early-returns AND `stage_failed` is NOT emitted.

### AC group: Configuration / boundary (Core Rule 8)

**AC-21** **GIVEN** `stage_duration = 0.0` is set in `.tres` (designer typo), **WHEN** `_ready()` runs, **THEN** `stage_duration` is clamped to `1.0` (`MIN_STAGE_DURATION`) AND no console error.

**AC-22** **GIVEN** `boss_warning_lead_time = 500.0` (greater than stage_duration), **WHEN** `_ready()` completes, **THEN** `boss_warning_lead_time` is clamped to `300.0` (= stage_duration). **AND** on the first `_process(delta)` tick (when `elapsed_time = delta ≈ 0.0167s` at 60 FPS), the condition `elapsed_time >= stage_duration - boss_warning_lead_time = 0.0` is satisfied AND `boss_warning_started(300.0)` is emitted exactly once. (Warning emission is in `_process`, not `_ready` — `_ready` only emits the first `stage_time_changed`.)

## Open Questions

- **OQ-1** (Pause-clock during Level Up): Currently the clock keeps running while the Level Up panel is open. A 3-second pause to choose an upgrade costs 3 seconds of stage time. Is this intentional, or should the clock pause? **Resolution candidate**: add `stage_director.set_paused(bool)` API; Level Up panel calls `set_paused(true)` on open, `set_paused(false)` on close. **Owner**: game-designer + ux-designer. **Target resolution**: before v0.4 playtest if it noticeably affects feel.
- **OQ-2** (Missing Player or EnemySpawner at `_ready()`): code silently no-ops (`get_node_or_null` returns null, signal connection skipped). Should fail loudly via `push_error` because both are configuration bugs the developer must fix. **Owner**: lead-programmer. **Target resolution**: code change (1-line) — add `push_error` at the null check sites.
- **OQ-3** (Wave configs hardcoded in `match` statement — tech debt vs Pillar 4): All wave configs (spawn_interval, max_enemies, archetype pool, weights) are in `_get_wave_*` functions as match statements, not `.tres`. This works but violates Pillar 4 (数据驱动迭代) in spirit. **Resolution candidate**: extract to `resources/waves/wave_*.tres` Resources, loaded into a `wave_configs: Array[WaveConfig]` array. Combat / Enemy / Player share this pattern; consider doing all four extractions at once. **Owner**: systems-designer + lead-programmer. **Target resolution**: tracked alongside Player GDD OQ-6.
- **OQ-4** (Boss `archetype` vs export defaults): `_spawn_boss()` only applies `boss_max_hp`/`boss_damage`/`boss_move_speed` IF `boss.archetype == null`. Currently `FamineBeastBoss.tscn` has an archetype (`famine_beast.tres`), so the exports are dead code. Either (a) remove the exports + fallback, or (b) document the override behavior more clearly. **Owner**: lead-programmer. **Target resolution**: cleanup pass before code-review.
- **OQ-5** (Debug/QA spawn multipliers shipping to production): `spawn_interval_multiplier` and `max_enemies_multiplier` are export fields intended for W214 QA testing. There is no compile-time guard to prevent them shipping at non-1.0 values. **Resolution candidate**: add a `_ready()` assertion `assert(spawn_interval_multiplier == 1.0 and max_enemies_multiplier == 1.0 in release builds)`, OR move to a debug-only autoload. **Owner**: qa-lead + lead-programmer. **Target resolution**: before v0.4 ship.
- **OQ-6** (Multi-stage / next stage progression): `stage_cleared` fires but the next-stage transition is undefined here. Currently 06_LEVEL_DESIGN mentions Stage 2 (幽都鬼市) and Stage 3 (昆仑残境). Who decides the next stage? GameOverPanel? A separate `RunFlow` system? **Resolution candidate**: out of scope for v0.4 (single-stage); design when v0.5+ adds Stage 2. **Owner**: game-designer. **Target resolution**: when Stage 2 is in scope.

---

## Registry Updates Recorded

References to entries in `design/registry/entities.yaml`:
- 7 enemy archetypes referenced (paper_doll, wandering_soul, fox_spirit, ghost_flame, stone_golem, shanxiao_elite, famine_beast)
- `stage_duration_seconds = 300` (constant) — StageDirector's `stage_duration` default
- `demon_seal_spawn_time = 120` (constant)
- `demon_seal_duration = 8` (constant — matches `demon_seal_required_seconds`)

**New formula candidates to register**:
- `stage_time_progression` (Formula 1)
- `wave_config_index_selection` (Formula 2)
- `demon_seal_pressure_adjustment` (Formula 3)
- `spawn_position_polar` (Formula 4 — used for Boss / Elite / DemonSeal)
- `demon_seal_reward_circle_placement` (Formula 5)

**Cross-doc consistency**:
- `demon_seal_spawn_time = 120.0` (StageDirector) ≡ `demon_seal_spawn_time = 120` (entities.yaml) ✅
- `demon_seal_required_seconds = 8.0` (StageDirector) ≡ `demon_seal_duration = 8` (entities.yaml) ✅
- `stage_duration = 300.0` ≡ `stage_duration_seconds = 300` ✅
- Wave 0 archetype pool (PaperDoll, WanderingSoul) matches 7-enemy registry ✅
- All `boss_*` defaults in StageDirector are *fallbacks* (only used if Boss has no archetype); the actual Boss is `famine_beast.tres` with max_hp=360, damage=18, move_speed=68 (registry-confirmed) — note that revision-4 Combat GDD §Per-Phase TTK Budget uses these archetype values, not the StageDirector defaults

## Revision Log

| Revision | Date | Trigger | Summary |
|---|---|---|---|
| 0 | 2026-05-25 | Initial reverse-doc by /design-system | First pass authored from `scripts/system/stage_director.gd` (454 lines) + `scenes/Main.tscn` + Combat GDD revision-4 + Player GDD revision-2 contracts. 8 required sections + Visual/Audio + UI Requirements + Open Questions + Registry Updates. 22 ACs covering 9 Core Rules + 5 Formulas. Stage timeline canonicalized (0:00 → 5:00 with all event times). 6 OQs (clock-pause, error handling, tech-debt extraction, archetype-vs-exports cleanup, debug-multiplier guards, multi-stage scope). |
| 1 | 2026-05-25 | /design-review verdict: PASS with 3 RECOMMENDED + 6 NICE-TO-HAVE (folded in alongside per reviewer permission) | **R-1 closed**: AC-14/AC-15 rewritten to describe the re-apply-with-multiplier mechanism (not the in-place mutation that QA might write tests against). **N-1 closed**: Core Rule 6 also reworded with the precise re-application mechanism. **R-2 closed**: AC-22 split into `_ready` clamp + first `_process` tick warning emission (warning emit is in `_process`, not `_ready`). **R-3 closed**: source line count "357" → "454" at lines 4 and 425. N-2 through N-6 (player-fantasy paragraph splits, missing AC preconditions, HUD-responsibility wording, hypothetical >600s stage, OQ-3 asymmetric cross-reference) are deferred as cosmetic polish. Status: Approved (no re-review needed — reviewer pre-cleared this revision as polish). |
