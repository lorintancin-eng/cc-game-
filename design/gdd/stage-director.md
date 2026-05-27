# Stage Director

> **Status**: Approved (revision-0 — first-try PASS, 3 cosmetic nits non-blocking)
> **Author**: claude (reverse-documented from `scripts/system/stage_director.gd` — 300 lines, full read)
> **Last Updated**: 2026-05-25
> **Implements Pillar**: Pillar 1 (清晰的生存压力 — Stage Director IS the time-based pressure curve), Pillar 5 (先完成小型 MVP — bounds run length to 5 minutes)
> **TR Coverage**: TR-core-002 (5-minute run with timed beats), TR-enemy-003 (Boss spawn at 5:00), TR-core-006 (Demon Seal at 2:00)
> **Layer**: Feature (depends on Run State, Enemy Spawner, Demon Seal)

## Overview

The Stage Director is the **5-minute pacing engine**. It owns the run's timeline: increment elapsed time per frame, fire phase transitions at fixed marks (0:00 / 1:00 / 2:00 / 3:00 / 4:30 / 5:00), inject named events (Demon Seal at 2:00, Elite spawns at 3:00 + 4:00, Boss at 5:00), and continuously reconfigure the EnemySpawner via `apply_wave_config()` to ramp pressure.

This system is the **temporal binding layer** between Combat GDD §Pressure Curve (the per-minute incoming-DPS targets) and Enemy Spawning (the threat-injection engine). Without Stage Director, Enemy Spawning runs at static defaults forever; with it, every 60 seconds the pool, interval, and cap all shift to produce the designed escalation.

Reference: Combat GDD §Pressure Curve, Enemy Spawning GDD (the spawner being directed), Combat GDD §Per-Tier Enemy TTK Budget (the expected pace), 03_CORE_GAMEPLAY.md §4 (the high-level "0:00→5:00 beats" the code implements).

## Player Fantasy

Stage Director is the **invisible conductor**. The player's experience:

> "First minute: I'm just learning. By 1:00 it's getting busier — Fox Spirits dart past, I have to pay attention. At 2:00 a glowing stone appears in the distance — should I detour to seal it? A few risk-reward decisions later, by 3:00 a Shanxiao Elite cuts in. By 4:00 I'm fighting two elites and a tide of normals. At 4:30 a warning chime sounds — the Boss is coming. At 5:00, the world shifts: the Boss arrives, normal spawns thin out, and it's just me vs. it. When the Boss falls, the run is over."

When Stage Director works invisibly, the player feels:
- **Earned escalation** — every minute feels meaningfully harder than the last
- **Anticipated peaks** — the Demon Seal at 2:00 and Boss warning at 4:30 are telegraphed events, not surprises
- **Bounded effort** — a run has a defined end. 5 minutes is the contract.
- **Decision points** — Demon Seal (risk/reward) and Elite arrival (priority threat) create cognitive load beats

Anti-fantasy: a run that never ends (infinite waves) — drains tension. Pressure that doesn't escalate — boring. Phase transitions that feel arbitrary (sudden spawn rate doubling with no signal).

## Detailed Rules

### Core Rules

1. **Stage runs for exactly `stage_duration = 300` seconds** (5 minutes) from `elapsed_time = 0` to 300. After 300s, Boss spawns; run continues until Boss dies (`stage_cleared`) or Player dies (`stage_failed`). No infinite mode in v0.4.

2. **Time advances per `_process(delta)`**: `elapsed_time = min(elapsed_time + delta, stage_duration)`. Time clamps at duration (cannot exceed 300s, so Boss-phase time-checks remain stable).

3. **Phase transitions are time-gated, one-shot, flag-guarded**. Each event has a `_is_X_spawned` flag (e.g. `_is_boss_warning_started`, `_is_demon_seal_spawned`); once true, the trigger doesn't re-fire. Safety against double-spawn if frame timing aligns.

4. **5 wave configurations** (indexed 0-4) drive Enemy Spawning. At each phase transition, `_get_wave_config_index()` reads `elapsed_time` and returns the current index:
   - **Wave 0** (0:00-1:00): paper_doll + wandering_soul; 1.35s interval, 18 cap
   - **Wave 1** (1:00-2:00): + fox_spirit + ghost_flame; 1.08s interval, 24 cap
   - **Wave 2** (2:00-3:00): + stone_golem; 0.90s interval, 32 cap
   - **Wave 3** (3:00-4:30): same pool, 0.72s interval, 42 cap
   - **Wave 4** (4:30-5:00): same pool, 0.55s interval, 56 cap (Boss warning phase)

5. **Time-gated named spawns**:
   - **2:00** — Demon Seal spawns at random ring position (200-280 px from Player + ±30 px jitter)
   - **3:00** — First Shanxiao Elite spawns with Iron Bones affix (`shanxiao_elite_archetype + ["iron_bones"]`)
   - **4:00** — Second Shanxiao Elite spawns with Swift affix
   - **4:30** — Boss warning signal fires (`boss_warning_started.emit(30.0)` — 30s lead time)
   - **5:00** — Boss spawns at random ring (420 px from Player) using FamineBeastBoss scene

6. **Demon Seal "pressure mode"**: while the player is sealing (Demon Seal emits `seal_progress_changed(progress, required, is_sealing=true)`), Stage Director reconfigures the spawner via `_set_demon_seal_pressure_active(true)` — multiply spawn_interval by 0.65 (~50% faster spawns), add +6 to max_enemies. Pressure releases on `seal_progress_changed(_, _, is_sealing=false)` or `seal_completed`. **This is the risk side of Demon Seal's risk/reward design** (Combat GDD §Pressure Curve §Risk/Reward 2:00-3:00 phase).

7. **Demon Seal completion reward**: when `seal_completed(demon_seal)` fires, Stage Director spawns 8 ExperienceOrbs in a 54 px radius around the seal's position (`demon_seal_reward_orb_count = 8`, `demon_seal_reward_radius = 54.0`, `demon_seal_reward_xp_value = 6.0` each, total 48 XP). Orbs are arranged at `TAU × i / 8` angles for visual symmetry.

8. **Boss phase clamps the spawner**: at 5:00 Boss spawn, `_apply_boss_phase_spawn_pressure()` caps spawner at `min(current_max, 8)` and sets `spawn_interval = max(current, 2.5s)`. This reduces normal-enemy pressure so the player can focus on Boss. Boss has `xp_drop_value = 0` (no XP orb on Boss death per Combat GDD AC-18).

9. **Two terminal states**:
   - `stage_cleared(elapsed_time)` — fired when Boss dies; spawner disabled
   - `stage_failed(elapsed_time)` — fired when Player dies; pressure released
   Both states freeze Stage Director (`_process` returns early after either flag is true).

10. **Debug acceleration** (`spawn_interval_multiplier`, `max_enemies_multiplier`): two `@export` knobs let QA accelerate spawn rate for fast testing without code change. Defaults 1.0 (no effect). W214 QA Checklist uses these.

### Phase Transition Map

| Time | Event | Signal Fired | Spawner Change |
|---|---|---|---|
| 0:00 | Stage start, Wave 0 applied | `stage_time_changed(0, 300)` | interval=1.35, max=18, pool=[PaperDoll, WanderingSoul] weights [4, 3] |
| 1:00 | Wave 1 transition | `stage_time_changed(60, 300)` | interval=1.08, max=24, pool=[+FoxSpirit, +GhostFlame] |
| 2:00 | Wave 2 transition + Demon Seal spawn | `stage_time_changed(120, 300)`, `demon_seal_spawned(seal)` | interval=0.90, max=32, pool=[+StoneGolem] |
| 3:00 | Wave 3 + First Elite (Iron Bones) | `stage_time_changed(180, 300)`, `elite_spawned(elite, ["iron_bones"])` | interval=0.72, max=42 |
| 4:00 | Second Elite (Swift) | `elite_spawned(elite, ["swift"])` | (no wave change) |
| 4:30 | Wave 4 + Boss warning | `stage_time_changed(270, 300)`, `boss_warning_started(30.0)` | interval=0.55, max=56 |
| 5:00 | Boss spawn + pressure clamp | `stage_time_changed(300, 300)`, `boss_spawned(boss)` | interval=max(current, 2.5), max=min(current, 8) |
| 5:00+ | Boss dies → `stage_cleared` | `stage_cleared(elapsed)` | spawner disabled |
| any | Player dies → `stage_failed` | `stage_failed(elapsed)` | (pressure released) |

### Interactions with Other Systems

| System | Direction | Interface |
|---|---|---|
| **Enemy Spawning** (FT-01, Approved pending review) | Stage Director → Spawner | Calls `apply_wave_config(interval, max, pool, weights)` at phase transitions + on Demon Seal pressure; calls `spawn_elite_at(archetype, pos, affixes)` for elite spawns |
| **Enemy** (C-04, Approved) | Stage Director instantiates Boss | Directly instantiates `FamineBeastBoss.tscn`. **Boss stats come from the archetype `.tres`** (entities.yaml famine_beast: max_hp=360, damage=18, move_speed=68, body_scale=1.7) — see Boss System GDD §Detailed Rules + entities.yaml. **The Stage Director export block (`boss_max_hp=260`, `boss_damage=16`, etc., line 206-207 below) is DEAD-CODE FALLBACK** — it only applies if `boss.archetype == null`, which never happens for shipped FamineBeastBoss.tscn. |
| **Player** (C-01, Approved) | Stage Director observes | Subscribes to `Player.died` to fire `stage_failed`; reads Player position for spawn-distance calculations |
| **Demon Seal** (FT-08, future GDD) | Stage Director ↔ Demon Seal | Instantiates seal at 2:00; subscribes to `seal_progress_changed` (drives pressure mode) and `seal_completed` (spawns reward orbs) |
| **Experience & Progression** (FT-04, Approved) | Stage Director → Experience | Spawns 8 ExperienceOrbs as Demon Seal completion reward |
| **Run State** (F-03, Approved) | Bidirectional | Run State subscribes to `stage_cleared` and `stage_failed` for run-end transitions |
| **HUD** (P-01, future) | Stage Director → HUD | HUD subscribes to `stage_time_changed` (timer display), `boss_warning_started` (warning UI), `demon_seal_progress_changed` (progress bar) |

9 signals emitted by Stage Director (revision-0 review N-1 fix):
- `stage_time_changed(elapsed, duration)` — every frame
- `boss_warning_started(lead_time)` — at 4:30, one-shot
- `boss_spawned(boss)` — at 5:00, one-shot
- `elite_spawned(elite, affixes)` — at 3:00 + 4:00, two-shot
- `demon_seal_spawned(seal)` — at 2:00, one-shot
- `demon_seal_progress_changed(progress, required, is_sealing)` — relayed from seal
- `demon_seal_completed(seal)` — relayed from seal
- `stage_cleared(elapsed)` — Boss death, one-shot terminal
- `stage_failed(elapsed)` — Player death, one-shot terminal

## Formulas

### Formula 1: Wave config index from elapsed time

```
if elapsed_time >= 270:    return 4    # 4:30+
if elapsed_time >= 180:    return 3    # 3:00+
if elapsed_time >= 120:    return 2    # 2:00+
if elapsed_time >= 60:     return 1    # 1:00+
return 0                                # 0:00-1:00
```

Hardcoded thresholds match Combat GDD §Pressure Curve §Per-Phase boundaries. Simple step function, easy to grok.

### Formula 2: Per-wave spawner config

| Wave | Interval (s) | Max Enemies | Pool size | Description |
|---|---|---|---|---|
| 0 | 1.35 | 18 | 2 | Familiarisation |
| 1 | 1.08 | 24 | 4 | First pressure |
| 2 | 0.90 | 32 | 5 | Demon Seal phase |
| 3 | 0.72 | 42 | 5 | Elite pressure |
| 4 | 0.55 | 56 | 5 | Boss warning |

Spawn rate roughly **doubles** from 0:00 to 4:30 (1.35 → 0.55 → 2.45× faster). Max enemies roughly **triples** (18 → 56). Combined effective enemy-flux is ~7× higher at 4:30 vs 0:00.

### Formula 3: Demon Seal pressure modifier

When player is sealing:
```
wave_spawn_interval *= 0.65        # ~54% faster spawning
wave_max_enemies += 6              # +6 simultaneous threats
```

Layered on top of current wave config. Example at Wave 2 (interval 0.90, max 32):
- Without sealing: 0.90s interval, 32 max
- With sealing: 0.585s interval, 38 max

This is the "you're vulnerable while sealing" balance — Combat Pressure Curve §Risk/Reward depends on this being meaningful.

### Formula 4: Boss + Elite spawn position (random ring)

```
angle = randf_range(0, TAU)              # 0 to 2π
distance = boss_spawn_distance           # 420 px default
spawn_position = player.global_position + Vector2.RIGHT.rotated(angle) * distance
```

Boss spawns at random angle, fixed 420 px ring around Player. Elite uses same formula with 420 px ring (`elite_spawn_distance`). Demon Seal uses 200-280 px range + ±30 px jitter — closer than Boss/Elite so it's reachable but still requires positioning.

### Formula 5: Debug acceleration

```
wave_spawn_interval *= max(spawn_interval_multiplier, 0.01)
wave_max_enemies *= max(max_enemies_multiplier, 0.1) (rounded)
```

Defaults 1.0 / 1.0 (no effect). QA uses 0.3 / 2.0 for accelerated testing per W214 checklist. **Floor on multipliers prevents accidental zero-division / zero-cap**.

## Edge Cases

- **If `_player == null` at `_ready()`** (character-select hasn't completed): Stage Director silently proceeds — wave configs apply (via `_enemy_spawner != null` check), but `Player.died` subscription is skipped. Player must be wired up before timer ticks meaningfully.
- **If `_enemy_spawner == null`** (Main.tscn misconfigured): Stage Director runs the timer normally but skips `apply_wave_config` calls. Elites also can't spawn (logged via `push_warning`). Defensive — single-Spawner architecture assumption.
- **If Boss is killed before 5:00** (impossible in v0.4 — Boss only spawns AT 5:00 — but defensively): `_on_boss_died` fires `stage_cleared` regardless of elapsed_time. Acceptable — Boss death is the win condition.
- **If Player dies during Demon Seal pressure**: `_on_player_died` fires `stage_failed`, which calls `_set_demon_seal_pressure_active(false)` — pressure releases. Spawner left in wave-config state (not reset), but `is_spawning_enabled = false` was NOT called here (it should be for cleanliness — see Open Questions OQ-5).
- **If two phase events trigger in the same frame** (e.g. WAVE_FOUR_START_TIME and DEMON_SEAL_PROGRESS callback): each has its own flag, both fire independently. No race condition.
- **If `boss_warning_lead_time` is set > stage_duration**: clamped to `stage_duration` in `_ready()`. Boss warning would fire at t=0 — weird but stable.
- **If Player + Boss are at same position when Boss spawns**: Boss is placed at Player + 420 px ring, can never coincide. Edge case avoided by design.
- **If `boss_spawn_distance` is set below MIN_SPAWN_DISTANCE (80)**: clamped. Boss won't spawn ON player.
- **If `apply_wave_config` is called but `_is_boss_spawned`**: skipped. Boss phase locks the spawner.
- **If a wave config has empty pool**: Enemy Spawner falls back to its own default (per Enemy Spawning GDD Edge Cases). Defensive layer.
- **If Demon Seal completes but Stage Director is in cleared/failed state**: ⚠️ **CODE-TRUTH DEFECT** (surfaced by Demon Seal GDD revision-1 review B-2). `_on_demon_seal_completed` (`stage_director.gd:426-433`) has NO `_is_stage_failed` guard — if seal completes after player death, **8 XP reward orbs WILL still spawn around a corpse**. The "_on_demon_seal_progress_changed" handler at line 418 DOES early-return on `_is_stage_failed`, but the completion handler does not. **Resolution candidates** (tracked in Demon Seal GDD OQ-4): (a) add `_is_stage_failed` guard to `_on_demon_seal_completed`; OR (b) add `DemonSeal.set_inactive()` method that Stage Director calls on `stage_failed` to drop `_players_in_range` to 0. **Target**: v0.4.x patch. **Owner**: systems-designer + lead-programmer.
- **If `demon_seal_reward_orb_count = 1`**: orbs spawn at exact center (distance=0 special-cased). Otherwise N orbs in a circle.
- **If Player dies between Boss spawn and Boss death** (rare but possible if Boss damage is high): `stage_failed` wins the race — `stage_cleared` won't fire even if Boss subsequently dies. Both terminal flags guard against double-fire.

## Dependencies

| Dependency | Type | Direction | Interface |
|---|---|---|---|
| **Run State** (F-03, Approved) | Hard | Bidirectional | Stage Director's `stage_cleared` / `stage_failed` signal Run State to transition runs |
| **Player** (C-01, Approved) | Hard | Stage Director observes | Subscribes to `Player.died`; reads `Player.global_position` |
| **Enemy Spawning** (FT-01, Approved pending) | Hard | Stage Director → Spawner | Primary consumer of `apply_wave_config()` and `spawn_elite_at()` APIs |
| **Enemy** (C-04, Approved) | Hard | Stage Director instantiates Boss | Directly instantiates `FamineBeastBoss.tscn` |
| **Resource Data Framework** (F-02, Approved) | Hard | Stage Director reads | 5 archetype `.tres` + Boss scene + Demon Seal scene |
| **Demon Seal** (FT-08, future GDD) | Hard | Bidirectional | Stage Director spawns + subscribes; Demon Seal emits progress signals |
| **Experience & Progression** (FT-04, Approved) | Soft | Stage Director → Experience | Spawns 8 reward orbs after seal completes |
| **HUD** (P-01, future) | Soft | Stage Director → HUD | Time + warning signals for UI |

**Bidirectional check:**
- Run State GDD lists Stage Director as upstream ✅ (Run State subscribes to terminal signals)
- Enemy Spawning GDD lists Stage Director as Soft dependency ✅ (apply_wave_config consumer)
- Combat GDD §Pressure Curve depends on Stage Director's escalation curve ⏳ (verify on /consistency-check)

## Tuning Knobs

| Knob | Owner | Design-safe range | Default | Effect at extremes |
|---|---|---|---|---|
| `stage_duration` | StageDirector.tscn | 60 – 600 s | 300 (5 min) | <60 = trivial; >600 = endurance |
| `boss_warning_lead_time` | StageDirector.tscn | 10 – 60 s | 30 | <10 = no time to prepare; >60 = pre-arrival anticipation drags |
| `boss_spawn_distance` | StageDirector.tscn | 200 – 600 px | 420 | <200 = Boss appears too close; >600 = invisible at spawn |
| ~~`boss_max_hp`~~ **[DEAD-CODE-FALLBACK]** | StageDirector.tscn | (n/a) | 260 | **Not used in shipping code** — only applies if `boss.archetype == null`. Canonical Boss HP is 360 from entities.yaml famine_beast archetype. Per C-B1/C-B2 resolution in /review-all-gdds 2026-05-27. Keep export for safety but treat as unreachable in normal play. Per Boss System GDD §Detailed Rules. |
| `demon_seal_spawn_time` | StageDirector.tscn | 60 – 240 s | 120 (2:00) | Earlier = early risk; later = mid-run beat |
| `demon_seal_min/max_spawn_distance` | StageDirector.tscn | 100 – 400 px | 200/280 | <100 = on top of player; >400 = forced long detour |
| `demon_seal_required_seconds` | StageDirector.tscn | 4 – 16 s | 8 | <4 = trivial; >16 = punishing |
| `demon_seal_pressure_interval_multiplier` | StageDirector.tscn | 0.4 – 1.0 | 0.65 | <0.4 = unplayable; >1.0 = no pressure |
| `demon_seal_pressure_max_enemy_bonus` | StageDirector.tscn | 0 – 12 | 6 | (+0 = no pressure; +12 = chaos) |
| `demon_seal_reward_*` | StageDirector.tscn | (orb count 1-16, xp 3-12, radius 30-100) | 8 / 6.0 / 54.0 | Total reward 48 XP — must offset 8s of seal risk |
| `first_elite_spawn_time` / `second_elite_spawn_time` | StageDirector.tscn | 120 – 270 s | 180 / 240 (3:00 / 4:00) | Earlier than 2:00 = no Demon Seal phase; later than 4:30 = overlaps Boss |
| `elite_spawn_distance` | StageDirector.tscn | 300 – 600 px | 420 | Match Boss; longer = more lead-time for Player |
| `boss_phase_spawn_interval` | StageDirector.tscn | 1.5 – 5.0 | 2.5 | Clamps spawner during Boss; <1.5 = chaos; >5 = empty |
| `boss_phase_max_enemies` | StageDirector.tscn | 4 – 16 | 8 | Clamps active count |
| `spawn_interval_multiplier` (DEBUG) | StageDirector.tscn | 0.01 – 5.0 | 1.0 | Production = 1.0 always |
| `max_enemies_multiplier` (DEBUG) | StageDirector.tscn | 0.1 – 5.0 | 1.0 | Production = 1.0 always |
| Per-wave (interval/max/pool/weights) | hardcoded in `_get_wave_*()` | — | (per Formula 2 table) | Currently NOT data-driven — see OQ-2 |

**Interaction warnings**:
- Lowering `stage_duration` below 300 cascades — Demon Seal at 2:00 may overlap Boss; elites at 3:00 / 4:00 may not fit. Use staged adjustments.
- Combining `spawn_interval_multiplier = 0.5` + Boss phase `boss_phase_spawn_interval = 2.5` — debug multiplier wins (math: 2.5 × 0.5 = 1.25). Debug knob is post-clamp.
- `boss_max_hp = 260` in StageDirector overrides `entities.yaml famine_beast max_hp = 360` — verify which is canonical in OQ-1.

## Acceptance Criteria

**AC-01** **GIVEN** `_ready()` runs, **WHEN** scene loads, **THEN** `stage_time_changed(0, 300)` is emitted exactly once AND default wave 0 config is applied to EnemySpawner (interval 1.35, max 18, pool=[PaperDoll, WanderingSoul]).

**AC-02** **GIVEN** `elapsed_time = 60.0`, **WHEN** `_process(delta)` runs, **THEN** wave config index transitions 0 → 1 AND `apply_wave_config(1.08, 24, [PaperDoll, WanderingSoul, FoxSpirit, GhostFlame], [3.6, 3.0, 0.8, 0.6])` is called.

**AC-03** **GIVEN** `elapsed_time = 120.0` (Demon Seal spawn time), **WHEN** `_process(delta)` runs, **THEN** a Demon Seal Area2D is instantiated at a position 200-280 px from Player AND `demon_seal_spawned(seal)` signal fires AND `_is_demon_seal_spawned` flag is set to prevent re-spawn.

**AC-04** **GIVEN** `elapsed_time = 180.0`, **WHEN** `_process(delta)` runs, **THEN** First Elite (Shanxiao Elite) spawns 420 px from Player with `["iron_bones"]` affix AND `elite_spawned(elite, ["iron_bones"])` fires.

**AC-05** **GIVEN** `elapsed_time = 240.0`, **WHEN** `_process(delta)` runs, **THEN** Second Elite spawns with `["swift"]` affix.

**AC-06** **GIVEN** `elapsed_time = 270.0` (boss warning), **WHEN** `_process(delta)` runs, **THEN** `boss_warning_started(30.0)` signal fires AND wave config transitions to wave 4 (interval 0.55, max 56).

**AC-07** **GIVEN** `elapsed_time = 300.0`, **WHEN** `_process(delta)` runs, **THEN** FamineBeastBoss is instantiated at 420 px from Player AND `boss_spawned(boss)` fires AND `_apply_boss_phase_spawn_pressure()` clamps spawner (interval max(current, 2.5), max min(current, 8)).

**AC-08** **GIVEN** Demon Seal emits `seal_progress_changed(2.0, 8.0, true)` (player is sealing), **WHEN** Stage Director receives, **THEN** `_set_demon_seal_pressure_active(true)` activates AND spawner is reconfigured (interval × 0.65, max +6).

**AC-09** **GIVEN** Demon Seal completes (`seal_completed(seal)`), **WHEN** Stage Director receives, **THEN** 8 ExperienceOrbs spawn in a ring around seal position (radius 54 px, angles 0, π/4, π/2, ...) AND each orb has `xp_value = 6.0`.

**AC-10** **GIVEN** Boss dies (`boss.died.emit()`), **WHEN** `_on_boss_died` receives, **THEN** `_is_stage_cleared = true` AND spawner disabled AND `stage_cleared(elapsed_time)` signal fires.

**AC-11** **GIVEN** Player dies before Boss spawn, **WHEN** `_on_player_died` receives, **THEN** `_is_stage_failed = true` AND `stage_failed(elapsed_time)` signal fires AND further `_process()` calls early-return.

**AC-12** **GIVEN** `spawn_interval_multiplier = 0.5` (debug acceleration), **WHEN** wave 2 config applies, **THEN** effective spawn_interval = 0.90 × 0.5 = 0.45s (faster than designed; debug-only).

**AC-13** **GIVEN** the stage is in cleared OR failed state, **WHEN** `_process(delta)` is called, **THEN** function early-returns without updating `elapsed_time` or firing any signals (frozen).

## Open Questions

- **OQ-1** (Boss HP / damage divergence: StageDirector vs entities.yaml): StageDirector exports `boss_max_hp = 260, boss_damage = 16, boss_move_speed = 70, boss_scale = 1.8`, but only applies them `if boss.archetype == null` (line 195). When `FamineBeastBoss.tscn` is instantiated, it likely has the famine_beast archetype attached, which per `entities.yaml` is `max_hp = 360, damage = 18, move_speed = 68, body_scale = 1.7`. **Which is canonical?** **Resolution candidate**: archetype values (entities.yaml) are canonical; StageDirector overrides are vestigial defaults from a pre-archetype era. Remove the override block OR keep it as documented fallback. **Owner**: systems-designer + game-designer. **Target**: verify in playtest; reconcile before v0.5.
- **OQ-2** (Wave configs hardcoded — extract to `.tres`): the 5 wave configs (interval, max, pool, weights) are hardcoded in `_get_wave_*()` match statements. Per Resource Data Framework GDD Pillar-4 audit, this is a "wave compositions: NON-COMPLIANT" entry. **Resolution candidate**: create `resources/waves/wave_0.tres` ... `wave_4.tres` as `WaveConfig` Resource subclass; StageDirector loads them. Frees designers to tune without code edits. **Owner**: systems-designer + lead-programmer. **Target**: pre-v0.5 polish.
- **OQ-3** (Demon Seal pressure interaction with Boss phase): if Player starts sealing at 4:55 (5 seconds before Boss), seal completes at 5:03 — overlapping with Boss spawn at 5:00. The `_apply_boss_phase_spawn_pressure()` and `_set_demon_seal_pressure_active(false)` may fight for spawner state. **Resolution candidate**: lock Demon Seal availability after t > stage_duration - demon_seal_required_seconds (i.e. seal can't be initiated after 4:52 if 8s required). Add explicit grace check. **Owner**: game-designer. **Target**: playtest reveal.
- **OQ-4** (Boss spawn distance vs viewport): 420 px is just outside the visible playfield (Camera GDD says ~626 px visible half-height at zoom 1.15) — Boss is visible immediately. Is this intentional or should Boss spawn off-screen and walk in? **Resolution candidate**: leave as-is for v0.4 (Boss-as-spectacle); revisit if playtest reveals "Boss appears" feels abrupt. **Owner**: ux-designer + level-designer.
- **OQ-5** (Player-death cleanup): on `stage_failed`, spawner is NOT explicitly disabled (only `_set_demon_seal_pressure_active(false)`). Spawner continues spawning until scene transitions. **Resolution candidate**: add `_enemy_spawner.set_spawning_enabled(false)` to `_on_player_died` for cleanliness. **Owner**: lead-programmer. **Target**: bug-fix sprint.
- **OQ-6** (Random seed not exposed): StageDirector's `_rng.randomize()` randomizes per `_ready()` call — not deterministic per `random_seed` like EnemySpawner. Inconsistent. **Resolution candidate**: add `@export var random_seed: int = 1701` for reproducibility. **Owner**: lead-programmer. **Target**: pre-v0.5.

## Registry Updates Recorded

**New constant candidates** (consider registering — these appear in multiple GDDs):
- `stage_duration_seconds = 300` (already registered in entities.yaml per earlier batch)
- `demon_seal_spawn_time = 120` (already registered)
- `demon_seal_required_seconds = 8` (already registered)
- `boss_warning_lead_time = 30` (NEW — used by HUD warning UI when authored)
- `wave_transition_times = [0, 60, 120, 180, 270]` (NEW — composite constant; could register as 5 entries)

**Cross-doc consistency**:
- Combat GDD §Pressure Curve §Per-Phase TTK targets MUST align with the 5 wave configs ⏳ (verify on next /consistency-check — should align if Stage Director ramps as Combat anticipates)
- Enemy Spawning GDD bidirectionally cited ✅
- Boss values divergence (OQ-1) needs reconciliation with entities.yaml famine_beast

## Revision Log

| Revision | Date | Trigger | Summary |
|---|---|---|---|
| 0 | 2026-05-25 | Initial reverse-doc | First pass from `stage_director.gd` (300 lines, full read). 8 required CCGS sections + Open Questions + Registry Updates. Documents 5-wave config, 5 timed beats (1:00 / 2:00 / 3:00 / 4:00 / 4:30 / 5:00), Demon Seal pressure mode, Boss phase clamp, debug acceleration knobs. 13 ACs cover wave transitions, Demon Seal spawn, Elite spawns, Boss spawn, pressure mode, reward orbs, terminal states, debug multipliers, freeze on terminal. 6 OQs include Boss HP divergence (OQ-1), wave-config Pillar-4 violation (OQ-2), Demon-Seal-vs-Boss overlap (OQ-3), Boss spawn visibility (OQ-4), Player-death cleanup gap (OQ-5), missing random_seed (OQ-6). |
