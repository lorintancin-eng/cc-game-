# Boss System

> **Status**: Designed (revision-0)
> **Author**: claude (reverse-doc from `scripts/enemy/famine_beast_boss.gd` + Stage Director boss-phase logic + Combat GDD Boss AC-18)
> **Last Updated**: 2026-05-25
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

1. **FamineBeastBoss extends Enemy** — inherits HP, damage, movement, signals. Adds 3 abilities.
2. **Spawn at 5:00 (`stage_duration`) by Stage Director** — `boss_spawn_distance = 420 px`, random angle around Player.
3. **Boss stats** (per StageDirector exports, may diverge from `entities.yaml` famine_beast — see OQ-1):
   - boss_max_hp: 260 (StageDirector) vs 360 (entities.yaml) — divergence
   - boss_damage: 16 vs 18
   - boss_move_speed: 70 vs 68
   - boss_scale: 1.8 vs 1.7
4. **3 abilities on independent cooldowns**:
   - **Charge** (cooldown 4.8s): 0.7s windup → 0.55s charge at 390 px/s along a 240 px danger line → 0.35s recovery
   - **Burst** (cooldown 5.8s): 1.05s warning → AOE damage at radius 58 → 0.18s linger
   - **Summon** (cooldown 7.0s): spawns 2 enemies (`summon_batch_count`)
5. **Boss-phase Stage Director clamp**: at Boss spawn, EnemySpawner is reconfigured to `interval ≥ 2.5s`, `max ≤ 8` — normal enemies thin out so player focuses on Boss.
6. **Boss death triggers victory** (Combat GDD AC-18): `xp_drop_value = 0` (no XP orb), `payload.is_boss = true`, Stage Director's `_on_boss_died` sets `_is_stage_cleared` and emits `stage_cleared`.

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
summon_batch_count = 2 (enemies per summon)
type = enemy_archetype (typically Paper Doll or Fox Spirit per design)
spawn position = Boss.global_position + offset
```

## Edge Cases
- **Boss takes damage during charge windup**: charge still resolves (boss continues attack pattern; not interruptible in v0.4)
- **Boss summons enemies that would exceed max_enemies cap**: spawner enforces cap; summons may be rejected
- **Player dies during Boss fight**: Stage Director's `_on_player_died` → `stage_failed`; Boss continues existing but no victory possible
- **Boss survives until end of level**: not possible in v0.4 (level ends with Boss death); Boss has no time limit

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
| `boss_max_hp` | 200 – 800 | 260 (sd) / 360 (yaml — see OQ-1) | TTK at 5:00 |
| `boss_damage` | 5 – 30 | 16 / 18 | Lethality per hit |
| `boss_move_speed` | 40 – 150 | 70 / 68 | Pursuit pressure |
| `charge_cooldown` | 3 – 10s | 4.8 | Frequency of charge attacks |
| `burst_cooldown` | 4 – 12s | 5.8 | AOE rhythm |
| `summon_cooldown` | 5 – 15s | 7.0 | Summon frequency |
| `summon_batch_count` | 1 – 5 | 2 | Summons per use |

## Acceptance Criteria

**AC-01** Stage Director elapsed_time = 300 → FamineBeastBoss instance spawned at 420 px from Player (random angle).
**AC-02** Boss takes total damage = boss_max_hp → Enemy.died emits with `payload.is_boss = true` AND no ExperienceOrb spawned (Combat AC-18).
**AC-03** Boss died → Stage Director `_on_boss_died` fires AND `stage_cleared(elapsed_time)` signal emits AND EnemySpawner disabled.
**AC-04** Boss charge ability: windup 0.7s → charge 0.55s at 390 px/s → recovery 0.35s.
**AC-05** Boss burst ability: warning 1.05s → damage 18 to enemies in radius 58 → linger 0.18s.
**AC-06** Boss summon: 2 enemies spawn per cast.

## Open Questions

- **OQ-1** (Boss HP divergence): Stage Director exports `boss_max_hp = 260` but applies only if `boss.archetype == null` (line 195). When FamineBeastBoss.tscn has the famine_beast archetype, max_hp = 360 (entities.yaml). **Resolution**: archetype values are canonical; remove StageDirector override block OR rename to `boss_*_fallback` for clarity. Owner: systems-designer. Same finding as Stage Director GDD OQ-1.
- **OQ-2** (Boss is interrupt-immune): currently charge windup proceeds even if Boss takes damage during it. Should heavy damage interrupt the charge? **Resolution**: keep current (Vampire Survivors-style — bosses are inevitable). Defer if playtest reveals issue.
- **OQ-3** (Multi-Boss support): v0.4 has 1 Boss. Levels 2 + 3 plan additional Bosses (per 03_CORE §7). FamineBeastBoss-as-base-class for future Bosses? **Resolution**: when level 2 lands, refactor FamineBeastBoss → BossBase + FamineBeastBoss + GhostMarketJudge. Owner: systems-designer + lead-programmer.

## Registry Updates

- `famine_beast` already registered in entities.yaml (Boss tier, max_hp=360, xp_drop_value=0)

## Revision Log

| Rev | Date | Trigger | Summary |
|---|---|---|---|
| 0 | 2026-05-25 | Initial reverse-doc | First pass from FamineBeastBoss (extends Enemy) + Stage Director boss-spawn block. 6 ACs cover spawn, victory, 3 abilities (charge/burst/summon). 3 OQs: HP divergence (same as Stage Director OQ-1), interrupt-immunity, multi-Boss base class. |
