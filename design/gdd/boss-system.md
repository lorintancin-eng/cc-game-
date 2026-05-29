# Boss System

> **Status**: Approved revision-1 (Famine Beast); **revision-2 (2026-05-29) adds Stage 2 Boss 鬼市判官 — pending /design-review**
> **Author**: claude (rev-1 reverse-doc from `famine_beast_boss.gd`; rev-2 forward-design of Ghost Market Judge for Stage 2)
> **Last Updated**: 2026-05-29 (revision-2: Ghost Market Judge)
> **Implements Pillar**: Pillar 1 (final pressure peak), Pillar 3 (mythological focal point)
> **TR Coverage**: TR-enemy-003 (Boss spawn + victory)
> **Layer**: Feature/Vertical Slice (depends on Stage Director, Enemy, Combat)

## Overview

Boss System is **the run's lethal climax** — at 5:00, Stage Director spawns the FamineBeastBoss (荒年兽) at 420 px from Player. Boss extends Enemy with 3 abilities (charge, burst, summon) on independent cooldowns. On Boss death, `Combat GDD AC-18` triggers — no XP orb spawn, `payload.is_boss = true`, Stage Director's `stage_cleared` fires.

v0.4 ships 1 Boss (Famine Beast). v0.4+ each level adds a new Boss (per 03_CORE §7 plans: Ghost Market Judge for level 2, Cracked Realm Mountain Lord for level 3).

Reference: Combat GDD §AC-18, Stage Director GDD §Boss phase (clamps spawner), `famine_beast.tres` (HP 360, damage 18, etc.).

## Player Fantasy

The Boss is **the only enemy worth running from AND toward**. The 4:30 warning chime tells the player "this is it." At 5:00 the Boss arrives — bigger sprite, distinct silhouette, abilities the player has never seen.

> "I survive the seal at 2:00, kite the elites at 3:00 + 4:00. At 4:30 the warning fires — my hands tighten. At 5:00 the Famine Beast spawns — it charges, sweeping a horizontal danger zone. I dodge, my Bagua Array eats it; it bursts a damage cloud, I'm in it, taking 18 / second. I retreat, my Flying Sword finishes the kill. The run is over. I won."

Anti-fantasy: a Boss that's just a "big enemy" with more HP. The defining mechanic must differ from normal enemies.

## Detailed Rules

1. **FamineBeastBoss extends Enemy** — inherits HP, damage, movement, signals. Adds 3 abilities + Enrage mechanic + BossState machine. On `_ready`, adds itself to `bosses` group (line 50) and forces `xp_drop_value = 0`.

2. **Spawn at 5:00 (`stage_duration`) by Stage Director** — `boss_spawn_distance = 420 px`, random angle around Player.

3. **Boss stats** — **CANONICAL VALUES are from the archetype `.tres` (entities.yaml famine_beast)**, per Enemy GDD §EnemyArchetype contract:
   - `max_hp = 360` (NOT 260 — StageDirector's 260 only applies if `boss.archetype == null`, but FamineBeastBoss.tscn always has the archetype, so the 260 is dead code per OQ-1 closure)
   - `damage = 18` (NOT 16)
   - `move_speed = 68` (NOT 70)
   - `body_scale = 1.7` (NOT 1.8)
   - `xp_drop_value = 0` (forced in `_ready` line 51 regardless of archetype)
   - OQ-1 **RESOLVED in revision-1**: archetype values are canonical; the Stage Director export block is fallback-only for archetype-null edge case.

4. **BossState machine** (per code lines 4-9, 96-104):
   ```
   enum BossState { CHASE, CHARGE_WINDUP, CHARGE, CHARGE_RECOVERY }
   ```
   - **CHASE** (default): chases player; counts down charge_timer / burst_timer; triggers windup when charge_timer ≤ 0
   - **CHARGE_WINDUP** (0.7s): velocity = 0; charge_telegraph visible (Line2D pointing at player); direction locked
   - **CHARGE** (0.55s): velocity = charge_direction × 390 px/s; telegraph hidden
   - **CHARGE_RECOVERY** (0.35s): velocity = 0; transitions back to CHASE
   - Burst is **independent of BossState** — fires from CHASE based on burst_timer; spawns burst markers that detonate after warning + linger
   - Summon is **independent of BossState** — fires from CHASE based on summon_timer

5. **3 abilities on independent cooldowns**:
   - **Charge** (`charge_cooldown = 4.8s`): 0.7s windup (telegraph visible) → 0.55s charge at 390 px/s along charge_direction → 0.35s recovery
   - **Burst** (`burst_cooldown = 5.8s`): 1.05s warning (translucent red circle radius 58 at player's position-at-cast) → detonation (deals 18 dmg to player if within radius) → 0.18s linger (bright orange explosion polygon visible)
   - **Summon** (`summon_cooldown = 7.0s`): spawns `summon_batch_count = 2` enemies per cast, alternating **Paper Doll** (even index) + **Wandering Soul** (odd index) — NOT Fox Spirit (revision-0 error). Capped at `summon_max_alive = 6` concurrent summons.

6. **Summon cap rule**: `_clean_summoned_enemies` runs every frame; on `_on_summoned_enemy_died`, the enemy is removed from `_summoned_enemies` array; new summons rejected if `summon_max_alive - _summoned_enemies.size() ≤ 0` (lines 281-284).

7. **Enrage mechanic** (the **defining mechanic** that distinguishes Boss from "big enemy" — addresses Player Fantasy anti-fantasy):
   - **Trigger**: `current_hp / max_hp ≤ enrage_health_ratio (default 0.3)` — checked in `take_damage` override (line 113-114)
   - **One-way** (`_is_enraged` flag; `_enter_enrage` early-returns if already enraged)
   - **Effects** (line 322-330):
     - `move_speed × 1.35` (`enrage_speed_multiplier`)
     - `charge_speed × 1.35`
     - All 3 skill cooldowns × 0.65 (`enrage_skill_interval_multiplier`), AND remaining timers clamped to current × 0.5 (skills fire sooner)
     - Body color → `Color(0.78, 0.14, 0.08, 1.0)` (dark cinnabar-red — distinct from base body)
     - `_enraged_aura: Polygon2D` becomes visible (radius 34, 24-point circle — a halo around Boss)

8. **Boss-phase Stage Director clamp**: at Boss spawn, EnemySpawner is reconfigured to `interval ≥ 2.5s`, `max ≤ 8` — normal enemies thin out so player focuses on Boss + Boss's own summons.

9. **Boss death triggers victory** (Combat GDD AC-18): `xp_drop_value = 0` (no XP orb), `payload.is_boss = true`, Stage Director's `_on_boss_died` sets `_is_stage_cleared` and emits `stage_cleared`. `_die` override (line 117-120) also calls `_clear_boss_effects` to clean up telegraph + burst markers + remove all summoned minions.

10. **Boss is interrupt-immune** (per OQ-2 resolution): Boss takes damage during CHARGE_WINDUP / CHARGE / CHARGE_RECOVERY but the BossState machine does NOT transition out on damage. Vampire Survivors-style — bosses are inevitable.

### Interactions

| System | Interface |
|---|---|
| **Stage Director** (FT-02) | Spawns at 5:00; subscribes to Boss death |
| **Enemy** (C-04) | FamineBeastBoss extends Enemy class |
| **Combat** (C-03) | Boss takes/deals damage per Combat contract |
| **Enemy Spawning** (FT-01) | Clamped during Boss phase |

## Formulas

### Formula 1: Charge ability damage projection
```
charge_total_time = windup (0.7) + charge (0.55) + recovery (0.35) = 1.6s total
charge_distance = charge_speed (390) × charge_duration (0.55) = 214.5 px
damage on hit = boss_damage (16 or 18)
```

### Formula 2: Burst ability AoE
```
total_burst_time = warning (1.05) + linger (0.18) = 1.23s
damage = burst_damage (18) on all enemies in burst_radius (58 px)
```

### Formula 3: Summon ability
```
# code: lines 280-307
summon_batch_count = 2 (enemies per summon)
available_slots = summon_max_alive (6) - _summoned_enemies.size()
spawn_count = min(summon_batch_count, available_slots)
for index in spawn_count:
    archetype = PAPER_DOLL_ARCHETYPE if (base_count + index) % 2 == 0 else WANDERING_SOUL_ARCHETYPE
    angle = TAU * index / spawn_count
    minion.global_position = boss.global_position + Vector2.RIGHT.rotated(angle) * summon_spawn_radius (86)
    minion.died.connect(_on_summoned_enemy_died)
```
**Archetypes**: Paper Doll (`res://resources/enemies/paper_doll.tres`) + Wandering Soul (`res://resources/enemies/wandering_soul.tres`) — alternating, NOT Fox Spirit.

### Formula 4: Enrage trigger + effects (the defining mechanic)
```
# code: lines 109-115, 322-330
on take_damage(amount):
    super.take_damage(amount)
    if _is_dead or _is_enraged: return
    if current_hp / max_hp <= enrage_health_ratio (0.3):
        _enter_enrage()

func _enter_enrage():
    _is_enraged = true
    move_speed *= 1.35
    charge_speed *= 1.35
    _charge_timer = min(_charge_timer, charge_cooldown × 0.65 × 0.5)  # fire faster
    _burst_timer  = min(_burst_timer,  burst_cooldown  × 0.65 × 0.5)
    _summon_timer = min(_summon_timer, summon_cooldown × 0.65 × 0.5)
    body.color = Color(0.78, 0.14, 0.08, 1.0)  # dark cinnabar
    _enraged_aura.visible = true
```

### Formula 5: Telegraph timing (VFX contract per VFX GDD revision-1 lines 44-45)
```
charge_telegraph: Line2D visible during CHARGE_WINDUP (0.7s)
    points = [Vector2.ZERO, charge_direction × charge_warning_length (240)]
burst_warning:    translucent red Polygon2D radius 58 visible during burst_warning_time (1.05s)
burst_explosion:  bright orange Polygon2D radius 58×1.08 visible during burst_linger_time (0.18s)
```
These are the player-facing **fairness rules** — every attack telegraphs before damage application.

## Edge Cases
- **Boss takes damage during CHARGE_WINDUP / CHARGE / CHARGE_RECOVERY**: charge still resolves (Rule 10 — interrupt-immune per OQ-2 resolution; Vampire Survivors-style)
- **Boss summons enemies that would exceed summon_max_alive**: rejected at `_summon_minions` line 281-284. Stage Director's global `max_enemies` clamp (Rule 8) is independent.
- **Player dies during Boss fight**: Stage Director's `_on_player_died` → `stage_failed`; Boss continues existing but no victory possible
- **Boss survives until end of level**: not possible in v0.4 (level ends with Boss death); Boss has no time limit
- **Enrage re-entry**: `_is_enraged` is a one-way flag; if Boss HP regenerates above 30% (impossible in v0.4, no regen), Enrage does NOT deactivate
- **Burst marker spawns at player's position-at-cast**: if player moves before warning expires (1.05s), the detonation happens at the OLD position (player can dodge by moving away during warning)
- **Charge direction lock during WINDUP**: `_update_charge_direction` runs every frame of WINDUP, so the charge direction tracks player movement up until CHARGE state begins, then locks

## Dependencies
| Dep | Type | Interface |
|---|---|---|
| **Stage Director** (FT-02) | Hard | Owns Boss spawn + phase clamp + victory trigger |
| **Enemy** (C-04) | Hard | FamineBeastBoss extends Enemy |
| **Combat** (C-03) | Hard | Damage application |
| **Enemy Spawning** (FT-01) | Soft | Clamped during Boss phase |

## Tuning Knobs
| Knob | Range | Default | Effect |
|---|---|---|---|
| `max_hp` (archetype) | 200 – 800 | **360** (entities.yaml famine_beast — canonical) | TTK at 5:00 |
| `damage` (archetype) | 5 – 30 | **18** | Lethality per hit |
| `move_speed` (archetype) | 40 – 150 | **68** | Pursuit pressure |
| `body_scale` (archetype) | 1.0 – 2.5 | **1.7** | Visual presence |
| `charge_cooldown` | 3 – 10s | 4.8 | Frequency of charge attacks |
| `charge_windup_time` | 0.3 – 1.5s | 0.7 | Telegraph window — affects fairness |
| `charge_duration` | 0.3 – 1.0s | 0.55 | Charge phase length |
| `charge_recovery_time` | 0.1 – 0.8s | 0.35 | Punish window for player |
| `charge_speed` | 200 – 600 | 390 | Charge velocity |
| `charge_warning_length` | 100 – 400 px | 240 | Telegraph line visual length |
| `burst_cooldown` | 4 – 12s | 5.8 | AOE rhythm |
| `burst_warning_time` | 0.5 – 2.0s | 1.05 | Telegraph window — affects fairness |
| `burst_radius` | 30 – 120 px | 58 | AOE size |
| `burst_damage` | 5 – 40 | 18 | AOE damage |
| `burst_linger_time` | 0.1 – 0.5s | 0.18 | Explosion visual duration (no damage during linger) |
| `summon_cooldown` | 5 – 15s | 7.0 | Summon frequency |
| `summon_batch_count` | 1 – 5 | 2 | Summons per use |
| `summon_max_alive` | 0 – 10 | 6 | Concurrent summon cap |
| `summon_spawn_radius` | 40 – 200 px | 86 | Summon distance from Boss |
| `enrage_health_ratio` | 0.1 – 0.5 | 0.3 | HP fraction triggering Enrage |
| `enrage_speed_multiplier` | 1.0 – 2.0 | 1.35 | Speed boost on Enrage |
| `enrage_skill_interval_multiplier` | 0.3 – 1.0 | 0.65 | Cooldown reduction on Enrage |

## Acceptance Criteria

**AC-01** **GIVEN** Stage Director `elapsed_time = 300`, **WHEN** boss-spawn phase fires, **THEN** FamineBeastBoss instance spawned at 420 px from Player (random angle) AND added to `bosses` group AND `xp_drop_value = 0`.

**AC-02** **GIVEN** Boss at HP=360, **WHEN** Boss takes total damage ≥ 360, **THEN** `Enemy.died` emits with `payload.is_boss = true` AND no ExperienceOrb spawned (Combat AC-18) AND `_clear_boss_effects` runs (charge telegraph + burst markers + summons all cleaned up).

**AC-03** **GIVEN** Boss died, **WHEN** Stage Director's `_on_boss_died` fires, **THEN** `_is_stage_cleared = true` AND `stage_cleared(elapsed_time)` signal emits AND EnemySpawner disabled.

**AC-04** **GIVEN** Boss in CHASE with `_charge_timer ≤ 0`, **WHEN** `_start_charge_windup` fires, **THEN** BossState → CHARGE_WINDUP for 0.7s (telegraph visible, velocity=0) → CHARGE for 0.55s (velocity=charge_direction × 390 px/s, telegraph hidden) → CHARGE_RECOVERY for 0.35s (velocity=0) → CHASE.

**AC-05** **GIVEN** Boss in CHASE with `_burst_timer ≤ 0`, **WHEN** `_start_burst_marker` fires, **THEN** translucent red Polygon2D radius 58 spawns at player's position-at-cast → after 1.05s detonates (player within radius takes 18 damage) → bright orange Polygon2D visible for 0.18s → marker `queue_free`.

**AC-06** **GIVEN** Boss in CHASE with `_summon_timer ≤ 0` AND `_summoned_enemies.size() < 6`, **WHEN** `_summon_minions` fires, **THEN** up to 2 enemies spawn at `summon_spawn_radius = 86 px` from Boss in even-distributed angles, alternating Paper Doll + Wandering Soul archetypes.

**AC-07** **GIVEN** Boss at HP > 30% × max_hp (108 HP), **WHEN** Boss takes damage dropping HP/max_hp to ≤ 0.3, **THEN** `_enter_enrage` fires: `move_speed *= 1.35` AND `charge_speed *= 1.35` AND all 3 skill timers clamped to current × 0.5 AND body color = `Color(0.78, 0.14, 0.08, 1.0)` AND `_enraged_aura` visible.

**AC-08** **GIVEN** Boss already enraged (`_is_enraged = true`), **WHEN** Boss takes additional damage, **THEN** `_enter_enrage` early-returns (no re-entry — Enrage is one-way).

**AC-09** **GIVEN** Boss in CHARGE_WINDUP, **WHEN** Boss takes damage, **THEN** BossState remains CHARGE_WINDUP (interrupt-immune per Rule 10 / OQ-2 resolution).

**AC-10** **GIVEN** Boss with `_summoned_enemies.size() == 6`, **WHEN** `_summon_timer ≤ 0`, **THEN** `_summon_minions` rejects spawn (available_slots = 0); `_summon_timer` resets but no new minions appear.

---

## Stage 2 Boss: 鬼市判官 (Ghost Market Judge)

> Added revision-2 (2026-05-29) for Stage 2 (幽都鬼市). The Judge is a **peer** of
> the Famine Beast — same structural contract (extends Enemy, BossState machine,
> 3 abilities on independent cooldowns + one-way Enrage), themed for the
> netherworld court. Tuned tougher because Stage 2 is reached sequentially (the
> player arrives mid-game). All values are `judge.tres`-canonical (same archetype
> contract as the Famine Beast).

### Identity & Player Fantasy

The 判官 holds the 生死簿 (Book of Life and Death) and the 判笔 (Vermilion Judgment
Brush). Where the Famine Beast is a feral charging calamity, the Judge is a cold,
deliberate magistrate passing sentence: it writes a verdict on the ground (delayed
AOE), summons souls from its ledger, and hooks the condemned with soul-chains. The
intended feeling shifts from "dodge the beast" to "you have been judged, and the
sentence is being written" — slower, more inevitable, more dread.

### Stats (canonical from `resources/enemies/judge.tres`)

| Field | Value | vs Famine Beast |
|---|---|---|
| `max_hp` | 480 | +120 (mid-game build) |
| `damage` | 40 | +4 |
| `move_speed` | 64 | -4 (more deliberate) |
| `body_scale` | 1.85 | +0.15 |
| `xp_drop_value` | 0 | same (defeat = run end) |
| `body_color` | (0.30, 0.22, 0.42, 1) dusk-violet magistrate | — |

TTK at a mid-game ~40 single-target DPS build ≈ 12s (480/40), inside the
combat-system.md 12-18s boss-window target.

### Ability Kit (3 abilities + Enrage — parallels Famine's charge/burst/summon)

1. **勾魂锁链 Soul-Hook Chain** (charge analog). `chain_cooldown = 5.2s`.
   0.8s windup (a `Line2D` soul-chain telegraph locks toward the player) → 0.5s
   dash at `chain_speed = 360 px/s` along the locked direction → 0.4s recovery.
   Contact during the dash deals boss `damage` (40). Distinct from Famine's charge
   (390 px/s / 0.55s): slower dash, longer windup — more readable, more dread.

2. **判笔 Judgment Brush** (burst analog — a slower, larger delayed AOE).
   `brush_cooldown = 6.0s`. Writes a vermilion verdict glyph at the player's
   position-at-cast → **1.3s** warning (translucent 朱砂-red ring, `brush_radius = 66`)
   → detonation deals `brush_damage = 24` to the player if within radius → 0.2s
   bright-ink linger. Longer telegraph + bigger radius than Famine's burst
   (1.05s / 58 / 18) — the "sentence being written" beat.

3. **生死簿召唤 Summon from the Book** (summon analog). `summon_cooldown = 6.5s`.
   Spawns `summon_batch_count = 2` Stage-2 souls per cast, alternating **怨婴
   Resentful Infant** (even index) + **灯笼鬼 Lantern Ghost** (odd index), at
   `summon_spawn_radius = 90 px`, capped at `summon_max_alive = 6`. Reuses the
   Famine summon structure with the Stage-2 roster (`resentful_infant.tres` /
   `lantern_ghost.tres`).

4. **审判终结 Final Judgment** (Enrage — same one-way mechanic as Famine).
   Trigger: `current_hp / max_hp ≤ 0.3`. Effects: `move_speed × 1.35`,
   `chain_speed × 1.35`, all 3 cooldowns × 0.65 (timers clamped to current × 0.5),
   body color → spectral pale-blue `Color(0.55, 0.62, 0.95, 1.0)` (distinct from
   Famine's cinnabar), `_enraged_aura` visible. **Judge-specific enrage flourish**:
   `brush_radius` grows ×1.2 (66 → 79) — the final sentence widens.

### Architecture (resolves OQ-3)

Implement via the OQ-3 refactor: extract the shared scaffolding from
`FamineBeastBoss` into a **`BossBase`** (`scripts/enemy/boss_base.gd`) that owns the
`BossState` machine, the 3-ability cooldown loop, the Enrage trigger/flag, summon-cap
bookkeeping, telegraph helpers, and the `_die` → `_clear_boss_effects` + victory
contract. `FamineBeastBoss` and `GhostMarketJudge` both `extend BossBase`, overriding
only their ability params + visuals + the ability implementations (charge vs
soul-hook are both "locked-direction dash"; burst vs judgment-brush are both
"delayed-radius AOE"; summon differs only in archetype list). This keeps the Judge
~80% reused code and makes Boss #3 (昆仑残境 Mountain Lord) a third subclass.

### Judge-Specific Formulas

- **Soul-Hook dash distance**: `chain_speed (360) × dash_duration (0.5) = 180 px`
  (vs Famine charge 214.5 px — shorter, more telegraphed).
- **Judgment Brush detonation**: same shape as Famine Formula 2 (Burst), with
  `brush_radius = 66` (→ 79 enraged), `brush_damage = 24`, warning `1.3s`.
- **Enrage**: identical structure to Formula 4, plus `brush_radius *= 1.2`.

### Judge-Specific Acceptance Criteria

- **AC-J1** **GIVEN** StageConfig boss_scene = GhostMarketJudge and Stage 2
  elapsed_time reaches boss-spawn, **WHEN** boss-spawn fires, **THEN** a
  GhostMarketJudge spawns (max_hp=480, damage=40), added to `bosses` group,
  `xp_drop_value=0`.
- **AC-J2** **GIVEN** Judge in CHASE with `_chain_timer ≤ 0`, **WHEN** Soul-Hook
  fires, **THEN** 0.8s windup (chain telegraph) → 0.5s dash @ 360 px/s → 0.4s
  recovery → CHASE.
- **AC-J3** **GIVEN** Judge `_brush_timer ≤ 0`, **WHEN** Judgment Brush fires,
  **THEN** a glyph spawns at player position-at-cast → 1.3s warning (radius 66) →
  detonation deals 24 to a player within radius → 0.2s linger → `queue_free`.
- **AC-J4** **GIVEN** Judge summon fires, **THEN** up to 2 souls spawn alternating
  Resentful Infant + Lantern Ghost at 90 px, capped at 6 concurrent.
- **AC-J5** **GIVEN** Judge HP/max_hp drops to ≤ 0.3, **WHEN** Enrage fires, **THEN**
  speed ×1.35, cooldowns ×0.65, body pale-blue, aura visible, AND `brush_radius`
  grows to 79.
- **AC-J6** **GIVEN** Judge dies, **THEN** Combat AC-18 victory contract fires
  identically to the Famine Beast (no XP orb, `is_boss=true`, `stage_cleared`).

## Open Questions

- **OQ-1** ✅ RESOLVED in revision-1 — archetype values are canonical (max_hp=360, damage=18, move_speed=68, body_scale=1.7); Stage Director's 260/16/70/1.8 exports are dead-code fallback. Stage Director GDD should clean up the unused export block in a future cross-doc fix.
- **OQ-2** ✅ RESOLVED in revision-1 — Boss is interrupt-immune (Rule 10); Vampire Survivors-style commitment. Re-open only if playtest reveals frustration.
- **OQ-3** ✅ RESOLVED (direction set, revision-2): Stage 2 lands the 2nd Boss (Ghost Market Judge). Resolution = refactor `FamineBeastBoss` → `BossBase` (shared BossState machine, ability-cooldown loop, Enrage, summon-cap, telegraph helpers, victory contract) + `FamineBeastBoss` + `GhostMarketJudge`, both subclasses. See "Architecture (resolves OQ-3)" above. Implementation tracked in the Stage 2 StageConfig + boss epic. Owner: systems-designer + lead-programmer.
- **OQ-4** (Enrage visual fairness): the body color change + aura appearing at 30% HP is a binary cue. Should there be a gradient cue (e.g. progressively redder above 30%, fully enraged at 30%) so players see the threshold approaching? **Owner**: ux-designer + technical-artist. **Target**: VFX GDD revision when Boss VFX polish lands.

## Registry Updates

- `famine_beast` already registered in entities.yaml (Boss tier, max_hp=360, xp_drop_value=0)
- `ghost_market_judge` to register on revision-2 acceptance (Boss tier, max_hp=480, damage=40, xp_drop_value=0) — added below.

## Revision Log

| Rev | Date | Trigger | Summary |
|---|---|---|---|
| 0 | 2026-05-25 | Initial reverse-doc | First pass from FamineBeastBoss (extends Enemy) + Stage Director boss-spawn block. 6 ACs cover spawn, victory, 3 abilities (charge/burst/summon). 3 OQs: HP divergence (same as Stage Director OQ-1), interrupt-immunity, multi-Boss base class. |
| 1 | 2026-05-27 | /design-review revision-0 MAJOR REVISION (4 BLOCKERS + 5 RECOMMENDED + 4 NICE-TO-HAVE) | **B-1 closed**: Enrage mechanic documented (Rule 7 + Formula 4 + AC-07/AC-08 + Tuning Knobs `enrage_*`) — HP ≤ 0.3 trigger, ×1.35 speed, ×0.65 cooldowns, dark-cinnabar body + aura. This is the defining mechanic the Player Fantasy anti-fantasy required. **B-2 closed**: summon archetypes corrected from "Paper Doll or Fox Spirit" to **Paper Doll + Wandering Soul** alternating (per code `PAPER_DOLL_ARCHETYPE` + `WANDERING_SOUL_ARCHETYPE` preloads line 12-13). **B-3 closed**: HP OQ-1 locked — canonical = archetype (max_hp=360, damage=18, move_speed=68, body_scale=1.7); Stage Director exports are dead-code fallback. **B-4 closed**: telegraphs documented in Formula 5 (charge: Line2D 240px for 0.7s; burst: translucent red poly radius 58 for 1.05s + bright orange linger 0.18s). **R-1 closed**: BossState enum documented in Rule 4. **R-2 closed**: `summon_max_alive = 6` cap rule documented (Rule 6 + AC-10). **R-3 closed**: AC-04/05 reworded for testability (BossState transitions observable). **R-4 closed**: Tuning Knobs expanded from 7 to 22 knobs (charge/burst/summon/enrage all enumerated). **R-5 closed**: AC-09 added for interrupt-immunity. **N-3 closed**: source_kind = ENEMY (per Combat damage tuple) implied for all boss damage events. |
| 2 | 2026-05-29 | Stage 2 content — add 2nd Boss | **Added Ghost Market Judge (鬼市判官)** as a peer of the Famine Beast (max_hp 480, damage 40). 3 themed abilities paralleling charge/burst/summon: 勾魂锁链 Soul-Hook (locked dash), 判笔 Judgment Brush (1.3s-telegraph delayed AOE r66/24dmg), 生死簿召唤 (summons 怨婴+灯笼鬼). 审判终结 Enrage (same one-way mechanic + brush radius ×1.2). **OQ-3 RESOLVED**: BossBase refactor (FamineBeastBoss → BossBase + 2 subclasses). 6 judge ACs (AC-J1..J6). Pending /design-review. Implementation in Stage 2 epic. |
