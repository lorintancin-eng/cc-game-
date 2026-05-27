# Enemy Spawning System

> **Status**: Approved (revision-0 — first-try PASS, 0 blockers; 4 minor advisory observations on notation only)
> **Author**: claude (reverse-documented from `scripts/system/enemy_spawner.gd` — 200 lines, full read)
> **Last Updated**: 2026-05-25
> **Implements Pillar**: Pillar 1 (清晰的生存压力 — Enemy Spawning IS the pressure-curve enforcer)
> **TR Coverage**: TR-core-002 (5-minute stage; spawn modulates threat over time), supports Combat Pressure Curve TTK budgets
> **Layer**: Feature (depends on Run State + Enemy)

## Overview

The Enemy Spawning System is the **threat-injection engine**. Every 1.25 seconds (default), it spawns an enemy at a random off-screen edge, drawn from a weighted archetype pool. It caps simultaneous enemies (default 18), wires the new enemy's `died` signal to its own kill counter, and exposes a `apply_wave_config()` API for Stage Director to swap pools and intervals mid-run as the threat ramps.

Spawning is **deterministic** when `random_seed` is fixed (default 1301), enabling /balance-check replay. Spawn positions use viewport-aware off-screen offsetting (4 edges × random position along edge × `spawn_margin = 80 px` outside camera view), so enemies appear to "arrive from beyond" rather than pop into existence on-screen.

Reference: Combat GDD §Pressure Curve §Survival Budget (the demand this system supplies threats against), Enemy GDD (the archetypes being spawned), Stage Director GDD (FT-02, future — owns the wave-progression that drives `apply_wave_config()`).

## Player Fantasy

Spawning is the **invisible pacing director** that makes a 5-minute run feel "earned" rather than "endured". Players don't think about a spawner script; they feel:

> "It's quiet at first — only a couple of paper dolls drifting in. By minute 2 they're coming from all sides; I can't outrun them all, so I have to thin them out. By minute 4 a stone golem cuts in — I see it from far away and reposition. Around 5:00 the boss arrives and everything else stops mattering."

When Enemy Spawning works invisibly, the player feels:
- **Gradient of escalation** — spawn rate + variety scales over the run (driven by Stage Director's `apply_wave_config()` calls)
- **Spatial fairness** — enemies always arrive from the edges, never spawn on top of the player
- **Earned breathing room** — `max_enemies = 18` cap means the world can't avalanche into a wipe; once 18 are alive, the spawner waits

Anti-fantasy: enemies popping into existence mid-screen (immersion break), or a "spawn flood" that overflows the cap so suddenly the player has no reaction time.

## Detailed Rules

### Core Rules

1. **Spawning is timer-driven, not event-driven.** Every `spawn_interval` seconds (default 1.25s), `_try_spawn_enemy()` fires. No spawn happens on enemy death, kill streak, or player action — it's purely time-based. Stage Director can change interval mid-run via `apply_wave_config()`.

2. **Spawn cap is hard**: if `current_enemy_count >= max_enemies` (default 18), the spawner silently skips. The timer still ticks; once an enemy dies (`_on_enemy_died` decrements the counter), the next timer tick can spawn again. **The cap acts as a back-pressure mechanism**.

3. **Spawn position is always off-screen**: viewport size × camera zoom determines visible bounds; spawn picks one of 4 edges (top / bottom / left / right) randomly, places enemy `spawn_margin = 80 px` outside that edge at a random position along it. **Enemies always walk into view**, never appear in it.

4. **Spawn requires a Player**: `get_first_node_in_group("player")` must return non-null. During character-select, before Player exists, spawner silently skips. Once Player exists, spawning resumes.

5. **Archetype selection is weighted random**: `enemy_archetype_pool: Array[Resource]` + `enemy_archetype_weights: Array[float]`. Default pool (`_ensure_default_archetype_pool()`): wandering_soul (weight 3.0), paper_doll (4.0), fox_spirit (1.6), stone_golem (0.8), ghost_flame (1.2). Total weight = 10.6; ratios determine spawn probability. **Note**: Shanxiao Elite + Famine Beast Boss are NOT in default pool — they require explicit `spawn_elite_at()` calls or Stage Director-driven wave swaps.

6. **Determinism via `random_seed`** (default 1301): `RandomNumberGenerator` seeded once in `_ready()`. Two runs with the same seed produce identical spawn timing + position + archetype sequence. Pairs with Player's `upgrade_random_seed = 2401` for full /balance-check replay.

7. **Wave configuration is hot-swappable**: `apply_wave_config(interval, max, pool, weights)` lets Stage Director mutate the spawner mid-run without restarting it. Clears old pool, validates non-null entries, falls back to default if pool becomes empty.

8. **Elite spawn is explicit, not random**: `spawn_elite_at(archetype, position, affixes)` API lets Stage Director (or future Boss intro) place named enemies at known positions, with elite affixes applied via `enemy.configure_elite(affixes)`.

9. **Signal emission on enemy death**: spawner subscribes to each spawned enemy's `died` signal. On death: decrements `current_enemy_count`, increments `defeated_enemy_count`, emits `enemy_killed(enemy)` (per-kill) AND `enemy_defeated(total_count)` (cumulative). Downstream consumers (HUD kill counter, Stage Director kill-based events) subscribe to these.

### Default Pool Composition (v0.4)

| Archetype | Weight | Share | Role |
|---|---|---|---|
| Paper Doll | 4.0 | 37.7% | Filler — weakest, most common |
| Wandering Soul | 3.0 | 28.3% | Normal — baseline threat |
| Fox Spirit | 1.6 | 15.1% | Pressure — fastest, hardest to kite |
| Ghost Flame | 1.2 | 11.3% | Variety — wave-chase movement |
| Stone Golem | 0.8 | 7.5% | Tank — slow, high HP/damage |
| **Total** | **10.6** | 100% | |

**Notably absent from default pool** (require explicit Stage Director swap or spawn_elite_at):
- Shanxiao Elite — Elite tier, designed for 3:00-4:30 phase
- Famine Beast Boss — Boss spawn at 5:00, owned by Stage Director / Boss System GDD

### Interactions with Other Systems

| System | Direction | Interface |
|---|---|---|
| **Enemy** (C-04, Approved) | Spawner → Enemy | Instantiates Enemy.tscn; sets `enemy.archetype`; subscribes to `died` signal |
| **Resource Data Framework** (F-02, Approved) | Spawner reads | All 5 default archetypes are `.tres` Resources (per Pillar 4) |
| **Player** (C-01, Approved) | Spawner depends on | `get_first_node_in_group("player")` for spawn origin reference |
| **Camera** (C-02, Approved) | Spawner reads | Camera zoom + viewport size determine spawn bounds (Formula 1) |
| **Run State** (F-03, Approved) | Spawner controlled by | `set_spawning_enabled(false)` toggles spawning on/off (e.g. paused during Level Up panel) |
| **Stage Director** (FT-02, Approved) | Stage Director → Spawner | Calls `apply_wave_config()` to swap pool/interval at phase transitions (0:00 / 2:00 / 3:00 / 4:30 / 5:00) |
| **HUD** (P-01, future) | Spawner → HUD | HUD subscribes to `enemy_defeated(count)` signal for kill counter display |
| **Experience & Progression** (FT-04, Approved) | Spawner → Enemy → Experience | When an Enemy dies (which Spawner is wired to), Experience spawns XP orb at the enemy's position |

## Formulas

### Formula 1: Spawn position selection

```
viewport_size = get_viewport_rect().size
camera_zoom = camera.zoom (Vector2.ONE if no camera)
half_visible = viewport_size * 0.5 / camera_zoom

side = randi_range(0, 3)   # 0=left, 1=right, 2=top, 3=bottom
match side:
    0: offset = (-half_visible.x - spawn_margin, randf_range(-half_visible.y, half_visible.y))
    1: offset = (half_visible.x + spawn_margin, randf_range(-half_visible.y, half_visible.y))
    2: offset = (randf_range(-half_visible.x, half_visible.x), -half_visible.y - spawn_margin)
    3: offset = (randf_range(-half_visible.x, half_visible.x), half_visible.y + spawn_margin)

spawn_position = player.global_position + offset
```

**Variables:**

| Variable | Type | Range | Description |
|---|---|---|---|
| `viewport_size` | Vector2 | typically (1280, 720) | Window pixel size |
| `camera_zoom` | Vector2 | (1.15, 1.15) per Camera GDD v0.4 default | Camera2D zoom factor |
| `half_visible` | Vector2 | ~(556, 313) at default zoom | Half of visible playfield extent |
| `spawn_margin` | float | 50 – 200 (design-safe) | Distance outside visible edge |
| `side` | int | 0 – 3 | Random edge selection (uniform) |

**Output:** spawn_position is always outside visible playfield, ensuring enemies arrive from off-screen. At default config, spawn ring is ~(636 × 393) px outside visible edges.

**Example:** Player at (0, 0), camera zoom (1.15, 1.15), viewport (1280, 720), spawn_margin 80, side = 1 (right). half_visible = (556, 313). Offset = (556 + 80, randf_range(-313, 313)) = (636, ~140). Enemy spawns at (636, 140) — 636 px right of player, just off-screen right.

### Formula 2: Weighted archetype selection

```
total_weight = sum of all non-null archetype weights
roll = randf_range(0, total_weight)
running = 0
for index in pool:
    if pool[index] != null:
        running += weights[index]
        if roll <= running:
            return pool[index]
return null  # fallback
```

**Variables:**

| Variable | Type | Range | Description |
|---|---|---|---|
| `pool` | Array[Resource] | size 1 – 10 typical | EnemyArchetype `.tres` files |
| `weights` | Array[float] | each ≥ 0 (clamped) | Relative spawn probability |
| `total_weight` | float | 0.1 – 100 typical | Sum of weights |
| `roll` | float | [0, total_weight) | Uniform random selection |

**Output:** one archetype Resource, probability proportional to its weight. With default pool (total 10.6), Paper Doll's 4.0 weight = 4.0/10.6 = 37.7% spawn rate.

**Example:** Default pool roll = 5.0. Cumulative: paper_doll (4.0 → 4.0), wandering_soul (3.0 → 7.0). Roll 5.0 ≤ 7.0 → returns wandering_soul.

### Formula 3: Spawn rate effective DPS-equivalent

For balance analysis:

```
spawn_dps_equivalent = (average_enemy_threat_dps) / spawn_interval × cap_efficiency
cap_efficiency = (max_enemies / time_to_fill_cap) … typically 0.7-1.0 mid-run
```

This is informational — actual incoming-damage to player is bounded by Combat Core Rule 8 (MAX_CONTACT_ATTACKERS = 4). Spawn rate alone doesn't translate 1:1 to damage; it shapes the *visual* and *positional* pressure.

**Variables:**

| Variable | Type | Description |
|---|---|---|
| `average_enemy_threat_dps` | float | mean of (enemy.damage / damage_interval) across pool, weighted by spawn weights |
| `spawn_interval` | float | seconds between spawns (default 1.25) |
| `cap_efficiency` | float | how often the cap is hit (1.0 = always full) |

**Default pool calculation**:
- Paper Doll (37.7%): damage 5 / interval 0.85 = 5.88 dps
- Wandering Soul (28.3%): 8 / 0.8 = 10.0 dps
- Fox Spirit (15.1%): 7 / 0.75 = 9.33 dps
- Ghost Flame (11.3%): 6 / 0.8 = 7.5 dps
- Stone Golem (7.5%): 12 / 1.0 = 12.0 dps
- Weighted average ≈ 7.85 dps per enemy

At 18-enemy cap, theoretical total = 18 × 7.85 = 141 dps. Combat aggregate ceiling (4 attackers) bounds incoming to ~31 dps. Spawn pressure is therefore VISUAL/SPATIAL, not damage.

## Edge Cases

- **If `enemy_scene == null`** (Spawner misconfigured): `_try_spawn_enemy` silently returns. No spawn, no error. Defensive — but a `push_warning` in `_ready()` would help diagnostics.
- **If `max_enemies == 0`**: `_process` skips entirely (no timer countdown). Useful for debug / "disable spawn" without unsetting `is_spawning_enabled`.
- **If `max_enemies` is lowered below `current_enemy_count` mid-run** (via `apply_wave_config()`): no enemies are removed — they finish their lives naturally. Spawner just won't spawn new ones until count drops below cap.
- **If `spawn_interval < 0.1`**: clamped to 0.1 via `_spawn_timer += maxf(spawn_interval, 0.1)`. Minimum interval = 100ms = 10 Hz spawn rate.
- **If Player is destroyed mid-run** (e.g. died and removed): spawner silently skips next spawn ticks; no error. Spawner gracefully waits for Player to re-spawn (which doesn't happen in v0.4 — DEFEATED is terminal).
- **If all archetype weights are 0**: `total_weight = 0` → `_select_archetype` returns null → `_create_enemy(null)` is called → Enemy is spawned with null archetype (uses Enemy.tscn defaults). This is a defensive fallback but visually wrong (Enemy with no archetype displays as default Wandering Soul). Tracked as OQ-2.
- **If `apply_wave_config()` is called with empty pool**: spawner re-loads default pool (`_ensure_default_archetype_pool()`). Stage Director cannot accidentally "empty" the spawner.
- **If two spawn ticks fire in the same frame** (very low spawn_interval + high frame time): only one spawn per frame — the timer subtracts delta once per `_process`, can only fire once. Multi-spawn-per-frame requires explicit loop (not in v0.4).
- **If `random_seed` is changed at runtime**: spawner's RNG is seeded ONCE in `_ready()`. Runtime changes have no effect. To re-seed, requires `_rng.seed = new_seed` external call (not exposed in v0.4).
- **If camera is missing** (Main.tscn loaded without Player+Camera): `camera_zoom = Vector2.ONE` fallback. Spawn calculation uses raw viewport size. Acceptable degradation — debug scenes only.

## Dependencies

| Dependency | Type | Direction | Interface |
|---|---|---|---|
| **Enemy** (C-04, Approved) | Hard | Spawner instantiates | `Enemy.tscn` PackedScene + `EnemyArchetype` Resource subclass |
| **Player** (C-01, Approved) | Hard | Spawner reads | `get_first_node_in_group("player")` for spawn origin |
| **Resource Data Framework** (F-02, Approved) | Hard | Spawner reads | 5 default `.tres` archetypes; future Stage Director wave configs |
| **Camera** (C-02, Approved) | Hard | Spawner reads | Camera zoom + viewport size for off-screen calculation |
| **Run State** (F-03, Approved) | Soft | Run State controls | `set_spawning_enabled(false)` during pause |
| **Stage Director** (FT-02, Approved) | Soft | Stage Director → Spawner | `apply_wave_config()` for phase-based pool/interval changes; `spawn_elite_at()` for elite injection |
| **Experience & Progression** (FT-04, Approved) | Soft | (indirect) | Enemy.died → Experience spawns XP orb — Spawner just propagates |
| **HUD** (P-01, future) | Soft | Spawner → HUD | `enemy_defeated(count)` for kill counter |

**Bidirectional check:**
- Enemy GDD lists Spawner as upstream ⏳ (verify on /consistency-check)
- Stage Director GDD lists Spawner as Hard dependency for wave control ✅ (Stage Director GDD calls `apply_wave_config`)
- Experience GDD has no direct mention of Spawner — relationship is via Enemy.died signal

## Tuning Knobs

| Knob | Owner | Design-safe range | Default | Effect at extremes |
|---|---|---|---|---|
| `EnemySpawner.spawn_interval` | EnemySpawner.tscn or Stage Director config | 0.5 – 3.0 s | 1.25 | <0.5 = swarm; >3.0 = sparse |
| `EnemySpawner.max_enemies` | EnemySpawner.tscn or Stage Director config | 8 – 50 | 18 | <8 = empty; >50 = perf + visual overload |
| `EnemySpawner.spawn_margin` | EnemySpawner.tscn | 50 – 200 px | 80 | <50 = enemies pop on-screen; >200 = enemies invisible at spawn, long travel |
| `EnemySpawner.random_seed` | EnemySpawner.tscn (dev only) | any int | 1301 | dev determinism; production randomizes per run |
| `enemy_archetype_pool` (default vs Stage Director) | EnemySpawner.tscn OR `apply_wave_config()` | 1 – 10 archetypes | 5 (default pool) | empty = falls back to default; large pool = variety at cost of recognizable enemy identity |
| `enemy_archetype_weights` | same as above | each ≥ 0 (no upper) | 4.0/3.0/1.6/1.2/0.8 | extreme imbalance (e.g. one weight 100×) reduces variety |

**Interaction warnings**:
- Raising `max_enemies` past 30 stresses pathfinding and rendering — verify with `/perf-profile` first
- Setting `spawn_interval` below `damage_interval` of any pool enemy creates spawn-faster-than-kill pressure
- Combining 0.8s `spawn_interval` + 30 `max_enemies` floods the player; reserve for elite/Boss phase only

## Acceptance Criteria

**AC-01** **GIVEN** Spawner with default config (interval 1.25s, max 18, default pool), **WHEN** 3 seconds elapse with no enemies dying, **THEN** at least 2 enemies (possibly 3) have been spawned (3 / 1.25 = 2.4 → 2 or 3 ticks depending on phase alignment).

**AC-02** **GIVEN** `current_enemy_count == max_enemies` (cap hit), **WHEN** timer tick fires, **THEN** NO new enemy spawns AND `_spawn_timer` resets normally (no infinite-spawn loop).

**AC-03** **GIVEN** an enemy dies (`died` signal fires) AND `current_enemy_count` was at cap, **WHEN** `_on_enemy_died` callback runs, **THEN** `current_enemy_count -= 1` AND next timer tick can spawn AND `enemy_defeated(total)` signal fires with cumulative count AND `enemy_killed(enemy)` fires with the dead enemy reference.

**AC-04** **GIVEN** Player at world (0, 0) AND camera zoom (1.15, 1.15) AND viewport (1280, 720) AND `spawn_margin = 80`, **WHEN** `_get_spawn_position()` is called with `side=0` (left), **THEN** offset.x = -636 (= -1280/2/1.15 - 80) AND offset.y ∈ [-313, 313]. Spawn position is Player + offset.

**AC-05** **GIVEN** default pool with weights [4.0, 3.0, 1.6, 1.2, 0.8] (total 10.6), **WHEN** 1000 archetype selections are made (with seeded RNG for determinism), **THEN** Paper Doll appears ~377 times (±20), Wandering Soul ~283 (±20), Fox Spirit ~151, Ghost Flame ~113, Stone Golem ~75 (statistical distribution within ±2σ).

**AC-06** **GIVEN** the same `random_seed`, **WHEN** two runs are started, **THEN** the spawn sequence (archetype + position + timing) is identical between runs (determinism for /balance-check replay).

**AC-07** **GIVEN** Player does not yet exist (during character-select), **WHEN** spawn timer ticks, **THEN** `_try_spawn_enemy` silently returns AND NO enemy is created AND NO error fires.

**AC-08** **GIVEN** `set_spawning_enabled(false)` was called (Run State pause), **WHEN** `_process(delta)` runs, **THEN** `_process` returns immediately AND timer doesn't decrement AND no spawn happens.

**AC-09** **GIVEN** `apply_wave_config(0.8, 25, [shanxiao_elite_archetype], [1.0])` is called (Stage Director phase transition), **WHEN** the next spawn tick fires, **THEN** the spawned enemy is a Shanxiao Elite AND `spawn_interval` is now 0.8s AND `max_enemies` is 25.

**AC-10** **GIVEN** `apply_wave_config(1.0, 20, [], [])` is called (empty pool), **WHEN** the call completes, **THEN** the spawner re-loads the default 5-archetype pool (defensive fallback) AND continues spawning.

**AC-11** **GIVEN** `spawn_elite_at(shanxiao_elite, (200, 200), ["iron_bones"])` is called (Stage Director elite injection), **WHEN** the call completes, **THEN** a Shanxiao Elite spawns at (200, 200) AND `configure_elite(["iron_bones"])` was invoked AND `elite_spawned(elite, ["iron_bones"])` signal fires.

## Open Questions

- **OQ-1** (Default pool composition vs Pressure Curve): Current default pool has Stone Golem at 7.5% (one in ~13 spawns) but Combat GDD §Pressure Curve §Per-Phase TTK budget expects Stone Golem encounters to feel rare in the 0:00-2:00 phase. At 1.25s interval × 18 cap, the player could see a Stone Golem in the first 13s — possibly too aggressive for opening. **Resolution candidate**: Stage Director should overwrite default pool at 0:00 with [paper_doll, wandering_soul, fox_spirit, ghost_flame] only — no Stone Golem until 1:30+. **Owner**: game-designer + level-designer. **Target**: Stage Director GDD (FT-02) wave-table definition.
- **OQ-2** (Null archetype defensive fallback): if all weights = 0, `_select_archetype` returns null, then `_create_enemy(null)` produces an Enemy with no archetype — likely renders as default Wandering Soul (Enemy.tscn defaults match). This is a silent semantic bug — the player sees "wrong-looking" enemies. **Resolution candidate**: emit `push_warning` and skip the spawn (rather than spawn null-archetype). **Owner**: lead-programmer. **Target**: pre-release polish.
- **OQ-3** (`max_enemies` upper bound for v0.4 performance): default 18 is conservative; Combat GDD §性能预期 targets 50-100 enemies simultaneously. Why 18? Either tech debt (early tuning) or intentional MVP gentleness. **Resolution candidate**: stage-aware caps — Stage Director should ramp `max_enemies` from 18 (opening) → 30 (mid) → 50 (pre-Boss) → 80 (Boss phase if elites/summons). **Owner**: game-designer + performance-analyst. **Target**: Stage Director GDD wave-table + `/perf-profile` validation.
- **OQ-4** (Spawn-on-player-side adjustment): currently 4 edges are equiprobable. If the player runs in one direction, half the spawns are behind them (irrelevant). Should spawn weighting favor the direction the player is moving? **Resolution candidate**: too clever for MVP; current uniform distribution is "fair" and creates pressure from all sides. Revisit if playtest complains. **Owner**: game-designer.
- **OQ-5** (`random_seed` per-run vs per-build): currently a `@export` constant. Production should randomize per run for variety (and call /balance-check with explicit seed for repro). **Resolution candidate**: Add `randomize_seed_on_start: bool = true` Player.tscn-level toggle; when true, `_ready()` does `_rng.randomize()` instead of `_rng.seed = random_seed`. **Owner**: lead-programmer. **Target**: pre-release polish.

## Registry Updates Recorded

**New constant candidates** (consider registering):
- `default_spawn_interval = 1.25` (referenced by EnemySpawner + future Stage Director wave configs)
- `default_max_enemies = 18` (Stage Director will override per-phase)
- `default_spawn_margin = 80` (Camera GDD-adjacent value)

Default pool composition is too specific to register as one entry; it lives in `enemy_spawner.gd:_ensure_default_archetype_pool()` and will be replaced by Stage Director wave-tables.

**Cross-doc consistency**:
- Enemy GDD references match: 5 archetypes in default pool all exist in `entities.yaml` ✅
- Combat GDD §Pressure Curve assumes incoming-DPS-shape that this spawner produces; Stage Director will own the per-phase tuning
- Stage Director GDD lists `apply_wave_config` and `spawn_elite_at` as its primary API into this spawner ✅

## Revision Log

| Revision | Date | Trigger | Summary |
|---|---|---|---|
| 0 | 2026-05-25 | Initial reverse-doc | First pass from `enemy_spawner.gd` (200 lines). 8 required CCGS sections + Open Questions + Registry Updates. Documents default 5-archetype weighted pool, 18-enemy cap, 1.25s interval, off-screen 4-edge spawn position formula, deterministic RNG (seed 1301). 11 ACs cover spawn timing, cap enforcement, position calculation, weighted selection, determinism, signal emission, wave-config swap, elite injection. 5 OQs include default-pool-too-aggressive-at-0:00, null-archetype defensive fallback, max_enemies upper bound, spawn-direction bias, runtime seed randomization. |
