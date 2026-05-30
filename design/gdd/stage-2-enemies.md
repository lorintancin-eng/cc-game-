# Stage 2 Enemy Roster — 幽都鬼市 (Netherworld Ghost Market)

> **Status**: revision-1 (2026-05-30 — **synced to implementation**); revision-0 authored 2026-05-29
> **Author**: claude (forward-design; balance per combat-system.md Pressure Curve + enemy-system.md schema; revision-1 implementation-sync)
> **Last Updated**: 2026-05-30
> **Type**: Content roster (data spec) — implemented as `resources/enemies/*.tres` against the existing `EnemyArchetype` contract
> **Owns (system)**: none new — extends Enemy System (C-04) with 5 new archetypes
> **Implements Pillar**: Pillar 1 (清晰的生存压力), Pillar 3 (原创神话气质)

> **⚠️ 实现同步说明 (2026-05-30)**：这 5 个敌人已落地为 `.tres`。两处与 revision-0 的差异：
> (1) **出场语境扩展**——它们现在既出现在 **幽都 (Stage 2) 纯战斗关**（判官 Boss 的常规波次 + 召唤），也出现在 **鬼市交易间隙的恶魔潮汐**（trade demon-tide，含黑白无常精英）。鬼市交易已从「Stage 2 关内机制」重构为「战斗关之间的平静交易间隙」，见 `ghost-market-trade.md` revision-2。
> (2) **`xp_drop_value` 整体上调约 ×1.5**（见下表 [已实现] 列），且关卡时长压缩到 **3 分钟**（怪浪在 2:00）。逐处用 **[已实现 / AS BUILT]** 标注。

## Overview

Five new enemy archetypes for Stage 2 (幽都鬼市). They reuse the existing
`EnemyArchetype` resource contract (no code change — pure `.tres` data) and the
existing movement modes (CHASE / WAVE_CHASE). The roster mirrors Stage 1's tier
structure (filler / swarm / fast / tank / elite) but is **tuned ~30-40% above
Stage 1 equivalents**, because Stage 2 is reached **sequentially** — the player
arrives mid-game (~Level 8-12, multi-weapon build, ~120-160 HP after max_hp
upgrades), not from a fresh start.

## Player Fantasy

Descending from the open mountain path into a claustrophobic spectral night
market, the player should feel the realm shift: faster, more numerous, more
oppressive. The enemies are the dead doing market business — bailiffs hunting
debtors, lanterns drifting in fog, the soul-takers come to collect. Dark 志怪,
never whimsical (per `design/narrative/01_STORY_BIBLE.md` tone).

## Roster (full `.tres`-ready stats)

> Schema = every `@export` field of `scripts/enemy/enemy_archetype.gd`. Balance
> anchors: Stage 1 spread was filler 10 / normal 12-16 / tank 24 / elite 30 dmg
> at HP 14-110. Stage 2 shifts up for mid-game entry.

| Field | 灯笼鬼 Lantern Ghost | 怨婴 Resentful Infant | 鬼差 Ghost Bailiff | 镇墓兽 Tomb Guardian | 黑白无常 Impermanence (elite) |
|---|---|---|---|---|---|
| **tier / role** | filler / drifting | swarm / fast-fragile | fast hunter | tank | elite |
| `display_name` | "Lantern Ghost" | "Resentful Infant" | "Ghost Bailiff" | "Tomb Guardian" | "Impermanence" |
| `max_hp` | 28.0 | 14.0 | 36.0 | 100.0 | 135.0 |
| `move_speed` | 96.0 | 150.0 | 124.0 | 58.0 | 80.0 |
| `damage` | 16.0 | 12.0 | 20.0 | 28.0 | 34.0 |
| `damage_interval` | 0.8 | 0.7 | 0.85 | 1.0 | 0.9 |
| `xp_drop_value` (revision-0) | 5.0 | 3.0 | 8.0 | 14.0 | 24.0 |
| `xp_drop_value` **[AS BUILT]** | **8.0** | **5.0** | **12.0** | **21.0** | **36.0** |
| `movement_mode` | WAVE_CHASE (1) | CHASE (0) | CHASE (0) | CHASE (0) | CHASE (0) |
| `wave_amplitude` | 0.6 | — | — | — | — |
| `wave_frequency` | 0.9 | — | — | — | — |
| `wave_phase` | 0.0 | — | — | — | — |
| `body_color` | (0.95, 0.85, 0.45, 0.9) lantern-gold | (0.80, 0.78, 0.70, 0.95) pallid | (0.18, 0.16, 0.30, 1) indigo-black | (0.40, 0.50, 0.45, 1) jade-stone | (0.92, 0.92, 0.95, 1) bone-white |
| `body_scale` | 0.9 | 0.6 | 1.05 | 1.4 | 1.5 |
| `collision_radius` | 9.0 | 6.0 | 11.0 | 16.0 | 17.0 |
| `damage_radius` | 13.0 | 9.0 | 15.0 | 21.0 | 23.0 |
| `health_bar_y` | -22.0 | -14.0 | -25.0 | -32.0 | -36.0 |
| `is_elite` | false | false | false | false | **true** |
| `elite_affixes` | [] | [] | [] | [] | ["swift"] (default; iron_bones variant possible) |

> File names: `resources/enemies/lantern_ghost.tres`, `resentful_infant.tres`,
> `ghost_bailiff.tres`, `tomb_guardian.tres`, `impermanence_elite.tres`.

> **[AS BUILT 2026-05-30] XP raised ~1.5×.** Every archetype's `xp_drop_value` was
> lifted ~1.5× from the revision-0 spec (8/5/12/21/36 vs 5/3/8/14/24). Rationale: the
> shipped combat stages are **3 minutes** (was 5; `StageTwoConfig.stage_duration = 180`),
> so per-kill XP rose to keep the mid-game build's level pace intact over the shorter,
> denser timeline. The relative tier spacing is unchanged — every value scaled by the
> same factor — so the contact-DPS table below (which depends on `damage`/`damage_interval`,
> not XP) is unaffected. All other stat fields (`max_hp`, `move_speed`, `damage`,
> `damage_interval`, `body_*`, elite affix) match the revision-0 table exactly.

> **[AS BUILT] Where these enemies appear.** Two contexts, both shipped:
> 1. **幽都 (Stage 2) combat stage** — `StageTwoConfig` waves (0:00 / 0:40 / 1:20, then
>    the 2:00 怪浪 swarm at `spawn_interval 0.3`, `max_enemies 84`) + the 判官 boss's
>    summons (怨婴 + 灯笼鬼). One scheduled 黑白无常 elite at 1:40.
> 2. **Ghost Market trade interludes** — the demon-tide a completed trade summons draws
>    from this roster (`GhostMarketInterludeConfig` pool: 灯笼鬼/怨婴/鬼差/镇墓兽 + 黑白无常
>    elite). See `ghost-market-trade.md` Formula 4.
>
> They also reappear (rescaled by `difficulty_multiplier`) in the remix combat stage
> **幽都·深渊 ×1.7** — `max_hp`/`damage` scaled by `1 + (mult−1)×0.5` per ADR-0004.

## Per-Enemy Identity & Behavior

- **灯笼鬼 Lantern Ghost** (filler, drifting): a ghost that carries the market's
  only light. Uses WAVE_CHASE so it drifts unpredictably toward the player —
  the Stage-2 "Paper Doll", but tougher (28 HP) and harder-hitting (16). Highest
  filler XP because killing it "snuffs a light". Thematic VFX: a bobbing lantern glow.
- **怨婴 Resentful Infant** (swarm): dead infants, small (scale 0.6) and very fast
  (150). Low HP (14), comes in numbers — pure swarm pressure that punishes
  standing still. Low XP (3) so farming them isn't optimal. Creepy 志怪 silhouette.
- **鬼差 Ghost Bailiff** (fast hunter): netherworld constable with soul-chains,
  hunts relentlessly. Faster (124) and harder (20) than Stage 1's Fox Spirit —
  the "you cannot simply outrun me" pressure enemy.
- **镇墓兽 Tomb Guardian** (tank): ancient tomb construct. Slow (58), massive
  (scale 1.4), 100 HP, heavy 28-damage slams. Stage 2's Stone Golem analog —
  a moving wall that forces routing decisions. High XP reward (14).
- **黑白无常 Impermanence** (elite): the famed soul-takers (谢必安 / 范无救). The
  Stage-2 elite, tougher than Shanxiao (135 HP, 34 dmg), fast for an elite (80).
  Ships as one archetype (bone-white 白无常) with the `swift` affix; an
  `iron_bones` black variant (黑无常) is a trivial second `.tres` if a paired
  spawn is desired later.

## Formulas

No new formulas — these archetypes feed the **existing** Combat formulas
(`damage_application_formula`, `damage_interval_throttle`) and Enemy elite
multipliers (`_apply_elite_modifiers`). Effective contact DPS per enemy:

`contact_dps = damage / damage_interval`

| Enemy | contact_dps | hits-to-kill @ player HP 130 |
|---|---|---|
| 灯笼鬼 | 16 / 0.8 = 20.0 | ~8 hits (6.4s) |
| 怨婴 | 12 / 0.7 = 17.1 | ~11 hits (7.6s) — but swarms |
| 鬼差 | 20 / 0.85 = 23.5 | ~7 hits (5.5s) |
| 镇墓兽 | 28 / 1.0 = 28.0 | ~5 hits (5.0s) |
| 黑白无常 | 34 / 0.9 = 37.8 | ~4 hits (3.4s) |

Elite (黑白无常) with `swift` affix: `move_speed = 80 × 1.05 (elite) × 1.3 (swift)
= 109.2`; `max_hp = 135 × 1.25 = 168.75`; `damage = 34 × 1.15 = 39.1` — per the
existing `_apply_elite_modifiers` (verified in `enemy_elite_modifiers_test.gd`).

## Edge Cases

- **If 怨婴 swarm exceeds the 4-attacker contact ceiling**: only 4 deal damage per
  frame (Combat Core Rule 8 / `MAX_CONTACT_ATTACKERS`); the rest crowd but wait.
  This keeps a 怨婴 swarm threatening-but-survivable — by design.
- **If 镇墓兽 and a Demon Seal/Trade demon-tide coincide**: the tank's slow speed
  means it rarely reaches the seal in time; no special handling — standard contact rules.
- **If 黑白无常 spawns via a Trade demon-tide** (per ghost-market-trade Formula 4):
  it uses the same `spawn_elite_at` path as Stage 1's Shanxiao; affix applied at spawn.
- **WAVE_CHASE 灯笼鬼 at screen edge**: wave offset can push it briefly off-screen;
  existing camera/cull handles this — no new behavior.

## Dependencies

| Dependency | Type | Interface |
|---|---|---|
| **Enemy System** (C-04) | Hard | New archetypes implement the existing `EnemyArchetype` resource; no schema change |
| **Combat** (C-06) | Hard | Damage/throttle formulas + 4-attacker ceiling apply unchanged |
| **Enemy Spawning** (FT-09) | Hard | Spawned via `apply_wave_config` pools + `spawn_elite_at` (elite) |
| **Stage Director / StageConfig** (FT-10) | Hard | 幽都 combat-stage wave pools reference these archetypes; the difficulty-remix stage (幽都·深渊 ×1.7) rescales their `max_hp`/`damage` (ADR-0004) |
| **Ghost Market Trade** (#26) | Soft | The **trade-interlude** demon-tide draws from this roster (incl. 黑白无常 elite via `spawn_elite_at`). See ghost-market-trade.md Formula 4 |

> Bidirectional: enemy-system.md should note these 5 archetypes as Stage-2 extensions.

## Tuning Knobs

Every field above is a per-`.tres` tuning knob. Primary balance levers:
- `max_hp` / `damage` per enemy — tune to the mid-game entry build (playtest).
- `黑白无常` affix choice (`swift` vs `iron_bones`) — speed-pressure vs hp-wall.
- `怨婴` swarm count — controlled by Stage 2 wave weights (StageConfig), not the archetype.

Safe ranges (per combat-system.md tiers): filler HP 20-35 / dmg 14-18; swarm HP
10-18 / dmg 10-14; fast HP 30-45 / dmg 18-24; tank HP 80-120 / dmg 24-30; elite
HP 110-150 / dmg 30-38.

## Acceptance Criteria

- **AC-01** **GIVEN** `lantern_ghost.tres` loaded, **WHEN** an Enemy applies it,
  **THEN** the enemy has max_hp=28, damage=16, movement_mode=WAVE_CHASE, and drifts
  with a sine offset (wave_amplitude 0.6 — a unit-relative weave multiplier on the
  movement direction per enemy.gd `_get_move_direction`, NOT a pixel value; cf.
  Ghost Flame's 0.55. revision-0 wrongly listed 24, which would force near-pure
  sideways motion).
- **AC-02** **GIVEN** `impermanence_elite.tres` (is_elite=true, swift), **WHEN**
  spawned via `spawn_elite_at`, **THEN** post-modifier stats are max_hp≈169,
  damage≈39, move_speed≈109 (per `_apply_elite_modifiers`).
- **AC-03** **GIVEN** 6+ 怨婴 in contact, **WHEN** a frame resolves, **THEN** at most
  4 apply contact damage (aggregate ceiling holds for the new swarm enemy).
- **AC-04** **GIVEN** a mid-game player (HP 130), **WHEN** standing in one 镇墓兽's
  contact, **THEN** time-to-death ≈ 5s (28 dmg / 1.0s × 5 ≈ 140) — within the
  Stage-2 tank pressure target.
- **AC-05** **GIVEN** all 5 `.tres` files exist, **WHEN** `/consistency-check` runs,
  **THEN** each is registered in `entities.yaml` with matching stats.

## Open Questions

- **OQ-1** (黑白无常 paired spawn): ship as one elite now; a 黑无常 (iron_bones)
  twin for synchronized pairs is deferred — worth it only if playtest finds the
  single elite underwhelming. **Owner**: game-designer + playtest.
- **OQ-2** (怨婴 swarm size): the swarm's threat is entirely in its count, set by
  Stage 2 wave weights, not the archetype. Final count tuned in the StageConfig
  pass + playtest. **Owner**: economy-designer.
- **OQ-3** (灯笼鬼 light mechanic): if Stage 2 ever adds the "ghost fog / limited
  vision" environmental hook (considered then deferred in the Stage-2 brainstorm —
  we chose the Trade hook instead), the lantern could become a literal light
  source. For now it is purely thematic VFX. **Owner**: game-designer.

## Revision Log

| Rev | Date | Trigger | Summary |
|---|---|---|---|
| 0 | 2026-05-29 | Stage 2 content design | 5 archetypes (灯笼鬼/怨婴/鬼差/镇墓兽/黑白无常) tuned ~30-40% above Stage 1 for mid-game sequential entry. Full `.tres`-ready stats, contact-DPS table, 5 ACs. Pending /design-review. |
| 1 | 2026-05-30 | **Synced to implementation** (doc-sync batch) | `.tres` files shipped. **`xp_drop_value` raised ~1.5×** (8/5/12/21/36 vs 5/3/8/14/24) to match the **3-minute** compressed combat stage (`stage_duration 180`). Documented the **two as-built contexts**: the 幽都 pure-combat stage (waves + 判官 summons) AND the Ghost Market **trade-interlude** demon-tides (the trade restructured from a Stage-2 mechanic to a between-stages interlude — see ghost-market-trade.md r2). Noted the difficulty-remix rescale (幽都·深渊 ×1.7). All combat stats (`max_hp`/`damage`/`move_speed`/etc.) unchanged from r0. |
