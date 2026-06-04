# Merit System (功德系统 — Meta Progression)

> **Status**: In Design (revision-1 — design-review NEEDS REVISION resolved: 5 blockers fixed — heading→Detailed Rules, Formula 2 cost curve removed (table is authoritative), merit_multiplier stacking made explicit, Run Metrics Contract added (total_kills→Player, etc.), bidirectional propagation to 5 GDDs done. boss_defeated→count, pity floor added to Formula 1.)
> **Author**: user + claude
> **Last Updated**: 2026-06-02
> **Implements Pillar**: Pillar 5 (先完成小型 MVP — Merit turns a one-session prototype into a replayable game loop) + supports Pillar 2 (meaningful construction choices — unlocks expand the decision space across runs)
> **Layer**: Progression / Persistence (NEW system — not in original 25-system scope)
> **Target**: v0.5 alongside Five Phases Synergy

## Overview

The Merit System is the **between-run persistence layer** that transforms MythSurvivor from a single-session experience into a replayable roguelite. At the end of every run (win or lose), the player earns **功德 (Merit)** — a permanent currency calculated from run performance. Merit is spent on a **linear unlock chain** (功德簿 — the Merit Ledger) that permanently expands starting conditions and available options for future runs.

At the player-facing level, the system answers "why play again?" — every run, even a failed one, contributes progress toward the next unlock. Each unlock changes what's available in future runs: new weapons enter the upgrade pool, Ghost Market gains new stall types, starting stats improve, element-specific upgrades appear, and eventually difficulty modifiers become available.

At the infrastructure level, the system owns: (1) run-end performance scoring (Merit calculation); (2) persistent unlock state (save/load via Godot `ConfigFile`); (3) the Merit Ledger data structure (ordered list of unlock nodes with costs and effects); (4) integration hooks to Player (starting conditions), Level Up Pool (pool expansion), and Ghost Market (new stall types).

This is the **first system to require save/load persistence** — its implementation establishes the save file format that future systems (settings, cosmetics, statistics) will extend.

## Player Fantasy

The Merit System is **directly felt** — the end-of-run screen and the unlock moments are core emotional beats.

> "I died at 4:20 — didn't even reach the Boss. But the results screen shows I earned 45 功德 from my kill count and the combo I activated. I look at the Merit Ledger: the next unlock is '解封·雷法' — Thunder Law enters the upgrade pool. It costs 60 功德; I have 38 saved up. One more run. ONE more run and I'll have a new weapon available forever. I hit 'Play Again' immediately."

When the system works, the player feels:
- **No wasted run**: even a 90-second death earns SOME merit — every attempt contributes
- **Visible progress**: the Merit Ledger shows exactly what's next and how close they are
- **Expanding possibility space**: each unlock doesn't make them stronger — it makes the GAME bigger. New options, not bigger numbers
- **Earned mastery**: late-chain unlocks (difficulty modifiers, element upgrades) are trophies of investment

Anti-fantasy: unlocks that are pure stat inflation ("start with +5 HP" ×20 times), a grind wall so steep the player can't see progress, or unlocks so impactful that early runs feel incomplete/broken without them.

*`creative-director` not consulted — Lean mode. Review manually before production.*

## Detailed Rules

### Core Rules

1. **Merit is earned at end-of-run only.** When Run State transitions to `stage_cleared` or `stage_failed`, the Merit calculation runs. No mid-run merit earning, no mid-run spending.

2. **Merit is a single permanent currency.** It persists across runs via save file. It can only increase (earned) or decrease (spent on unlocks). It cannot be lost, stolen, or reset (unless the player manually resets progression — see Edge Cases).

3. **Merit Ledger is a strictly ordered linear chain.** Unlocks must be purchased in sequence — node N cannot be purchased until node N-1 is purchased. This ensures all players experience the same unlock progression (important for balance and onboarding).

4. **Each unlock node has a fixed Merit cost.** Costs escalate along the chain (see Formula 2). The player can save across multiple runs to afford expensive nodes.

5. **Spending is explicit and manual.** After a run ends, the player sees the results screen with Merit earned. They can then open the Merit Ledger and purchase the next available unlock if they have sufficient Merit. Unlocks are NOT automatic — the player chooses when to spend.

6. **Unlocks take effect on the NEXT run.** Purchasing "解封·雷法" during the post-run screen means Thunder Law appears in the upgrade pool starting from the player's next run. The current run is already over.

7. **Run performance metrics are collected via a RunMetrics snapshot at run-end.** The Merit System does NOT track metrics during the run (except `combos_activated`, see below) — each metric has a designated owner system that exposes it. At run-end (`stage_cleared` / `stage_failed`), the Merit System reads all 6 metrics into a `RunMetrics` snapshot, computes Formula 1, and displays the results screen. The owner and access path of each metric is specified in **§Run Metrics Contract** below. This closes the "no metric source" gap (cross-review C-03/C-04, design-review B-5/R-1/R-2).

8. **Save file format: Godot `ConfigFile`** (`.cfg`). Path: `user://merit_save.cfg`. Contains: `[merit] total=N`, `[unlocks] node_0=true, node_1=true, ...`, `[stats] total_runs=N, total_merit_earned=N, best_survival_time=N`. ConfigFile is human-readable, easy to debug, and natively supported by Godot without JSON parsing.

9. **Save triggers: on unlock purchase and on merit earn.** Save occurs at two moments: (a) when Merit is added after a run, and (b) when an unlock is purchased. No periodic autosave needed — state only changes at these two discrete events.

10. **No IAP, no premium currency, no real-money interaction.** Merit is earned exclusively through gameplay. This is a design principle, not a suggestion.

### Merit Ledger: Unlock Chain (v0.5)

The chain has **15 nodes** in v0.5, designed to take ~8-12 hours (30-50 runs) to fully unlock. Nodes are grouped into tiers that expand different aspects of the game:

| Node | Name (zh) | Name (en) | Cost | Effect | Category |
|------|-----------|-----------|------|--------|----------|
| 1 | 初心护体 | Beginner's Ward | 20 | Start each run with +10 max HP | Starting Stat |
| 2 | 解封·飞剑 | Unseal: Flying Sword | 40 | Flying Sword can appear in upgrade pool from run start (no unlock upgrade needed) | Pool Expansion |
| 3 | 灵光一闪 | Spark of Insight | 60 | First level-up offers 4 choices instead of 3 (one-time per run) | Upgrade Quality |
| 4 | 解封·雷法 | Unseal: Thunder Law | 80 | Thunder Law can appear in upgrade pool from run start | Pool Expansion |
| 5 | 身法精进 | Movement Mastery | 100 | Start each run with +8% move speed | Starting Stat |
| 6 | 解封·八卦阵 | Unseal: Bagua Array | 120 | Bagua Array can appear in upgrade pool from run start | Pool Expansion |
| 7 | 五行灵珠·开放 | Phase Bead Unlocked | 150 | 五行灵珠 stall type appears in Ghost Market | Market Expansion |
| 8 | 解封·爆裂符 | Unseal: Explosive Talisman | 180 | Explosive Talisman can appear in upgrade pool from run start | Pool Expansion |
| 9 | 功德回向 | Merit Reflection | 200 | +15% Merit earned per run (multiplicative) | Meta Boost |
| 10 | 解封·山印 | Unseal: Mountain Seal | 220 | Mountain Seal can appear in upgrade pool from run start | Pool Expansion |
| 11 | 元素感应 | Elemental Attunement | 250 | Start each run with +1 to a random element (enables earlier combo activation) | Element Boost |
| 12 | 鬼市信誉 | Market Reputation | 280 | Ghost Market stalls offer one additional trade option (4 choices instead of 3) | Market Expansion |
| 13 | 修为加持 | Cultivation Blessing | 320 | Start each run with 1 free random upgrade already applied | Starting Power |
| 14 | 天劫试炼 | Tribulation Trial | 360 | Unlocks Hard Mode toggle (enemies ×1.3 HP/dmg, Merit earned ×1.5) | Difficulty |
| 15 | 渡劫飞升 | Ascension | 400 | Unlocks Ascension Mode toggle (enemies ×1.6 HP/dmg, Merit earned ×2.0, unique cosmetic aura) | Difficulty |

**Total Merit to fully unlock**: 2,780

**Design rationale for ordering**:
- Nodes 1-6 (cost 20-120): rapid unlocks during first ~10 runs. Every 2-3 runs the player gets something new. Weapons unlock in DPS-variety order (pierce → AoE → aura → explosion → heavy).
- Nodes 7-10 (cost 150-220): mid-game unlocks that deepen the Five Phases and Ghost Market systems. Player has seen the base game and is ready for more complexity.
- Nodes 11-15 (cost 250-400): late-game unlocks that change how runs play. Element boost, free upgrade, and difficulty modifiers are for experienced players who've mastered the base game.

### Interactions with Other Systems

#### → Run State / Stage Director
- **Interface**: Merit System subscribes to `stage_cleared` and `stage_failed` signals from StageDirector.
- **Data consumed**: `elapsed_time`, `total_kills` (from a kill counter — may need to be added to StageDirector or Player), `boss_defeated` flag, `stages_cleared` count.
- **Timing**: Merit calculation runs AFTER the run-end signal but BEFORE the results screen displays.

#### → Player
- **Interface**: Player reads unlock state at run start (`_ready()`) and applies starting condition modifiers.
- **Data consumed**: `starting_hp_bonus`, `starting_speed_bonus`, `starting_element_bonus`, `starting_upgrade` — all derived from purchased unlock nodes.
- **No runtime coupling**: Player does not reference the Merit System during a run. All effects are applied once at spawn.

#### → Level Up & Upgrade Pool
- **Interface**: Upgrade Pool reads unlock state when building the available pool.
- **Data consumed**: For each "Unseal" node purchased, the corresponding weapon's upgrades enter the base pool WITHOUT requiring the in-run unlock upgrade. The unlock upgrade (e.g., UPGRADE_UNLOCK_FLYING_SWORD) is removed from the pool entirely for that weapon.
- **Important distinction**: "Unseal" means the weapon is available from run start. The player still needs to find weapon-specific upgrades (damage, cooldown, etc.) through the level-up system. They just skip the "unlock this weapon" gate.

#### → Ghost Market
- **Interface**: Ghost Market reads unlock state to determine available stall types.
- **Data consumed**: Node 7 (五行灵珠) unlocks the Phase Bead stall type. Node 12 (鬼市信誉) adds +1 trade option to each stall.

#### → Five Phases Synergy
- **Interface**: Player reads Node 11 (元素感应) at run start to apply +1 random element.
- **Data consumed**: `starting_element` (random element from {metal, wood, water, fire, earth}). Applied to element_inventory before the first upgrade choice.

#### → Save/Load (NEW)
- **Interface**: Merit System owns the save file. Other systems that need persistence in the future will extend the same ConfigFile.
- **Format**: `user://merit_save.cfg` — sections `[merit]`, `[unlocks]`, `[stats]`. The format is designed to be extended by future systems (e.g. `[settings]`, `[cosmetics]` sections) without conflict.

### Run Metrics Contract

The 6 scoring metrics in Formula 1 are owned and exposed as follows. Each owner tracks its metric during the run and exposes it at run-end; the Merit System reads them into a `RunMetrics` snapshot when the run ends.

| Metric | Owner | Tracking mechanism | Access at run-end | Implementation status |
|--------|-------|-------------------|-------------------|----------------------|
| `survival_time` | RunDirector | Accumulates each stage's `elapsed_time` across the 7-stage run | `RunDirector.get_total_elapsed()` | NEW — RunDirector exposes accumulator |
| `total_kills` | Player | Subscribes to each `enemy.died`; increments `_total_kills` | `Player.total_kills` (public getter) | NEW — Player adds `_total_kills` counter (resolves OQ-1) |
| `bosses_defeated` | RunDirector | Increments on each Boss `died` signal | `RunDirector.get_bosses_defeated()` | NEW — counter |
| `combos_activated` | Merit System (self) | Subscribes to Five Phases `combo_activated(combo_id)`; increments `_combos_count` | internal `_combos_count` | NEW — Merit subscribes during run |
| `ghost_market_trades` | StageDirector | `_trade_count` (already exists, private) | expose via `StageDirector.get_trade_count()` | EXTEND — make `_trade_count` readable |
| `stages_cleared` | RunDirector | Increments on each `stage_cleared` signal | `RunDirector.get_stages_cleared()` | NEW — counter |

**Snapshot timing**: the Merit System connects to `stage_failed` / final `stage_cleared`. On fire, it reads all 6 values into a `RunMetrics` dictionary, computes Formula 1, and shows the results screen. `combos_activated` is the ONLY metric Merit tracks itself (via signal subscription during the run) because the combo count is ephemeral and not naturally owned by RunDirector.

**Multi-stage note**: `survival_time` is the TOTAL across all stages, not a single stage's `elapsed_time`. The per-stage `stage_cleared(elapsed_time)` signal carries only that stage's time; RunDirector accumulates across the 7-stage run. This resolves cross-review N-06.

## Formulas

### Formula 1: Merit Earned Per Run

The merit_earned formula is defined as:

`merit_earned = max(floor((time_score + kill_score + boss_bonus + combo_bonus + trade_bonus + stage_bonus) × merit_multiplier), MERIT_PITY_FLOOR)`

> The `max(…, MERIT_PITY_FLOOR)` wrapper (MERIT_PITY_FLOOR = 1) guarantees every run earns at least 1 merit — see Edge Cases and AC-13. The worked examples below omit the wrapper because all exceed the floor.

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| survival_time | t | float | 0 – ~840 s | Seconds survived (across all stages in multi-stage run) |
| time_score | t_s | float | 0 – 42 | `survival_time / 20.0` — 1 merit per 20 seconds survived |
| total_kills | k | int | 0 – ~500 | Total enemies killed this run |
| kill_score | k_s | float | 0 – 50 | `total_kills / 10.0` — 1 merit per 10 kills |
| bosses_defeated | b | int | 0 – 4 | Number of Bosses killed this run (a multi-stage run has up to 4 Boss encounters) |
| boss_bonus | b_b | float | 0 – 60 | `bosses_defeated × 15` — 15 merit per Boss defeated |
| combos_activated | c | int | 0 – 5 | Five Phases generating combos activated |
| combo_bonus | c_b | float | 0 – 25 | `combos_activated × 5` — 5 merit per combo |
| ghost_market_trades | g | int | 0 – ~12 | Ghost Market trades completed |
| trade_bonus | g_b | float | 0 – 12 | `ghost_market_trades × 1` — 1 merit per trade |
| stages_cleared | s | int | 0 – 4 | Combat stages cleared (max 4 in 7-stage run) |
| stage_bonus | s_b | float | 0 – 40 | `stages_cleared × 10` — 10 merit per stage cleared |
| merit_multiplier | m | float | 1.0 – 2.3 | `merit_multiplier = node9_mult × difficulty_mult`. `node9_mult` = 1.15 if Node 9 (功德回向) purchased, else 1.0. `difficulty_mult` = 1.5 (Hard) / 2.0 (Ascension) / 1.0 (Normal). Only ONE difficulty mode is active at a time (mutually exclusive). Max = 1.15 × 2.0 = 2.3 |

**Output Range:** 1 to ~180 merit per run at default multiplier. Typical run outcomes:
- Quick death (60s, 20 kills, no boss): floor((3 + 2 + 0 + 0 + 0 + 0) × 1.0) = **5 merit**
- Average run (180s, 80 kills, 1 combo, 2 trades, 1 stage): floor((9 + 8 + 0 + 5 + 2 + 10) × 1.0) = **34 merit**
- Good run (360s, 150 kills, 1 boss, 2 combos, 4 trades, 2 stages): floor((18 + 15 + 15 + 10 + 4 + 20) × 1.0) = **82 merit**
- Full clear (600s+, 300 kills, 2 bosses, 3 combos, 8 trades, 4 stages): floor((30 + 30 + 30 + 15 + 8 + 40) × 1.0) = **153 merit**
- Full clear + Ascension Mode: floor(153 × 2.0) = **306 merit**

**Example:** Player survives 240s, kills 100 enemies, no Boss, activates 1 combo, completes 3 Ghost Market trades, clears 1 stage. time_score = 240/20 = 12. kill_score = 100/10 = 10. boss_bonus = 0. combo_bonus = 5. trade_bonus = 3. stage_bonus = 10. merit_earned = floor((12 + 10 + 0 + 5 + 3 + 10) × 1.0) = **40 merit**.

### Formula 2: Unlock Node Cost (authoritative table — NOT a generative formula)

Node costs are **hand-defined in the Merit Ledger table** (Detailed Rules §Merit Ledger). That table is the single source of truth — there is NO generative formula. An implementer must store the 15 costs as a constant array / `.tres` data file and read them directly; do not compute them.

The costs follow a roughly linear-with-tier-jumps *shape* for design intuition, but each value is hand-tuned for clean player-facing numbers and balance:

| Tier | Nodes | Cost values | Shape |
|------|-------|-------------|-------|
| Early | 1-6 | 20, 40, 60, 80, 100, 120 | +20 per node — rapid unlocks in the first ~10 runs |
| Mid | 7-10 | 150, 180, 200, 220 | +20-30 per node — deepening systems |
| Late | 11-15 | 250, 280, 320, 360, 400 | +30-40 per node — endgame investment |

**Total cost to fully unlock:** 20+40+60+80+100+120+150+180+200+220+250+280+320+360+400 = **2,780 merit** (matches `merit_total_unlock_cost` in entities.yaml).

**Why no formula:** an earlier draft proposed `node_cost(i) = 20 + i×15 + floor(i/5)×30`, but that curve diverges from the hand-tuned table by up to 110 merit (14 of 15 nodes differ). It was removed to avoid implementers generating wrong costs. The table is the spec.

### Formula 3: Time-to-Full-Unlock Estimation

`total_cost = sum(all node costs) = 2,780 merit`
`average_merit_per_run = ~40 merit (average run estimate)`
`runs_to_full_unlock = total_cost / average_merit_per_run = ~70 runs`
`time_per_run = ~10 minutes (5-7 min gameplay + 3 min menus/results)`
`hours_to_full_unlock = runs_to_full_unlock × time_per_run / 60 = ~11.7 hours`

This lands within the 8-12 hour target. Early nodes (20-80 merit) are reachable in 1-2 runs; late nodes (320-400) require 8-10 good runs of saving.

## Edge Cases

- **If player earns 0 merit** (died instantly, 0 kills, 0 time): minimum merit = 1 (pity floor). No run should feel completely wasted.
- **If save file is corrupted or missing**: create a fresh save with all unlocks = false, total merit = 0. Log a `push_warning()`. Do NOT crash.
- **If save file is manually edited** (player edits `.cfg` to set merit = 99999): no server-side validation (single-player game). Accept the value. This is the player's choice.
- **If player quits mid-run** (closes game without dying or winning): no merit earned. Merit only grants on `stage_cleared` or `stage_failed` signals. The partial run is lost.
- **If Node 11 (元素感应) grants +1 random element that the player's starting weapon already covers**: valid — it gives +1 to an element they already have ≥1 of, which helps combo scaling (not wasted, just less impactful for activation). The random selection does NOT avoid the starting weapon's element.
- **If Node 13 (修为加持) grants a random upgrade that would normally be locked behind an unsealed weapon**: the free upgrade only draws from the UNLOCKED pool (respects existing pool filter rules from Level Up Pool GDD Rule 3). It cannot grant a locked weapon's upgrade.
- **If player purchases an unlock while results screen is showing**: save immediately. If the game crashes between purchase and the next run, the unlock persists (save triggers on purchase per Rule 9).
- **If all 15 nodes are purchased and the player earns more merit**: merit continues to accumulate but has nothing to spend on in v0.5. The counter displays normally. v0.6 will add the Destiny Tree (天命树) that consumes excess merit. See OQ-4.
- **If Hard Mode or Ascension Mode is toggled ON**: the merit multiplier applies to ALL merit sources (time, kills, boss, combos, trades, stages). The mode toggle persists in save file — it stays on until manually toggled off.
- **If player has Hard Mode unlocked but not enough skill to clear a run**: they can toggle it off at any time from the pre-run screen. No penalty for toggling.
- **If two difficulty modes could stack** (Hard + Ascension): they do NOT stack. Ascension replaces Hard. Only one difficulty modifier is active at a time.

## Dependencies

| System | Direction | Type | Interface |
|---|---|---|---|
| **Run State / Stage Director** | Upstream (hard) | Signal → Merit | `stage_cleared` / `stage_failed` signals trigger merit calculation. Provides `elapsed_time` and run metadata. |
| **Player** | Upstream (hard) | Data → Player | Player reads unlock state at `_ready()` to apply starting bonuses (HP, speed, element, free upgrade). |
| **Level Up & Upgrade Pool** | Downstream (hard) | Data → Pool | "Unseal" unlocks add weapons to base pool; remove corresponding unlock upgrades. Node 3 (灵光一闪) changes first level-up to 4 choices. |
| **Ghost Market** | Downstream (soft) | Data → Market | Node 7 unlocks Phase Bead stall. Node 12 adds +1 trade option. Market works without these. |
| **Five Phases Synergy** | Downstream (soft) | Data → Synergy | Node 11 adds +1 starting element. Synergy works without this. |
| **Enemy System** | Downstream (soft) | Data → Enemy | Hard/Ascension mode applies HP/dmg multipliers to all enemies at run start. |
| **Save/Load (NEW)** | Internal (hard) | Owns persistence | Merit System owns `user://merit_save.cfg`. First consumer of persistence. |
| **HUD / Results Screen** | Downstream (soft) | Signal → UI | Results screen shows merit earned breakdown. Merit Ledger is a separate UI screen. |

## Tuning Knobs

| Knob | Default | Safe Range | Affects | Breaks If |
|---|---|---|---|---|
| MERIT_PER_20_SECONDS | 1 | 0.5 – 2 | Time-based merit income | >2: survival alone earns too much; <0.5: time doesn't matter |
| MERIT_PER_10_KILLS | 1 | 0.5 – 2 | Kill-based merit income | >2: farming weak enemies is optimal; <0.5: kills don't matter |
| BOSS_MERIT_BONUS | 15 | 10 – 30 | Incentive to reach/kill Boss | >30: Boss kill dominates all other sources; <10: Boss not worth the risk |
| COMBO_MERIT_BONUS | 5 | 3 – 10 | Incentive to activate Five Phases combos | >10: combo-hunting overshadows survival; <3: combos not worth planning |
| STAGE_CLEAR_BONUS | 10 | 5 – 20 | Incentive to clear full stages | >20: stage clears dominate; <5: no reason to push past Boss |
| MERIT_PITY_FLOOR | 1 | 1 – 3 | Minimum merit per run | >3: dying instantly is too rewarding; =0: some runs feel wasted |
| BASE_UNLOCK_COST | 20 | 10 – 40 | Cost of first node | >40: first unlock takes 4+ runs (too slow); <10: trivially fast |
| COST_STEP | 15 | 10 – 25 | Linear cost increase per node | >25: late nodes become extreme grinds; <10: chain completes too fast |
| MERIT_REFLECTION_MULT | 1.15 | 1.10 – 1.25 | Node 9 merit multiplier bonus | >1.25: snowballs too fast with difficulty mults; <1.10: not noticeable |
| HARD_MODE_ENEMY_MULT | 1.3 | 1.2 – 1.5 | Hard Mode enemy HP/dmg multiplier | >1.5: unplayable for average player; <1.2: not challenging enough |
| HARD_MODE_MERIT_MULT | 1.5 | 1.3 – 2.0 | Hard Mode merit earning multiplier | >2.0: trivializes remaining unlock costs; <1.3: not worth the difficulty |
| ASCENSION_ENEMY_MULT | 1.6 | 1.4 – 2.0 | Ascension Mode enemy multiplier | >2.0: requires perfect play; <1.4: not distinct from Hard |
| ASCENSION_MERIT_MULT | 2.0 | 1.5 – 3.0 | Ascension Mode merit multiplier | >3.0: remaining nodes unlock in 2-3 runs; <1.5: not worth the pain |
| FIRST_LEVELUP_EXTRA_CHOICES | 1 | 0 – 2 | Node 3 extra choices on first level-up | >2: 6 choices is overwhelming; =0: node feels empty |
| STARTING_HP_BONUS | 10 | 5 – 20 | Node 1 starting HP | >20: trivializes early-game pressure; <5: unnoticeable |
| STARTING_SPEED_BONUS | 0.08 (8%) | 0.05 – 0.15 | Node 5 starting move speed | >0.15: movement feels too fast from start; <0.05: unnoticeable |

## Visual/Audio Requirements

### Results Screen (Merit Earned)
- **Layout**: after run-end (death or victory), display a **Merit Breakdown** panel showing each scoring category and its contribution (time, kills, boss, combos, trades, stages) as a stacked bar or line items
- **Merit counter animation**: total merit earned animates upward (counting up sound + number rolling) over 1.5 seconds. Satisfying "cha-ching" cadence
- **Audio**: soft chime per scoring category revealed; final total gets a resonant bell strike (bronze bell — 功德 is a Buddhist concept, temple bell fits)
- **Total Merit display**: shows "功德: [current total] (+[earned this run])" with the earned amount in gold text

### Merit Ledger Screen
- **Layout**: vertical scroll list of 15 unlock nodes. Purchased nodes glow gold with a checkmark. The next unpurchased node is highlighted with a pulsing border. Future nodes are dimmed/locked
- **Node visual**: each node is a circular seal (印) with the unlock icon inside. Connected by a vertical golden thread (功德线)
- **Purchase animation**: when the player buys a node, the seal glows, cracks open, and the unlock effect text appears with a burst of golden particles
- **Audio**: purchase = temple bell + sutra chant snippet (2s). Background: quiet ambient chanting (optional, can be toggled)
- **Accessibility**: all node effects have text descriptions; no information conveyed by color alone

### Difficulty Mode Indicators
- **Hard Mode**: red border on the run HUD timer; "天劫" text badge in top-right
- **Ascension Mode**: gold border + shimmer effect on HUD timer; "飞升" text badge

📌 **Asset Spec** — Visual/Audio requirements are defined. After the art bible is approved, run `/asset-spec system:merit-system` to produce per-asset visual descriptions, dimensions, and generation prompts from this section.

## UI Requirements

### Results Screen: Merit Breakdown
- **Location**: replaces or extends the existing game-over screen
- **Format**: left column = scoring categories (生存时间, 斩杀, 首领, 相生, 交易, 通关), right column = merit earned per category. Bottom row = total with multiplier shown
- **Interaction**: "继续" button → opens Merit Ledger. "再来一局" button → starts new run. "返回" button → main menu

### Merit Ledger Screen
- **Access**: from Results Screen ("查看功德簿" button) OR from Main Menu ("功德簿" button)
- **Format**: scrollable vertical list of 15 nodes. Each node shows: name, icon, cost, effect description, purchased/available/locked state
- **Purchase flow**: tap available node → confirmation dialog ("花费 [N] 功德 解封 [name]?") → purchase → animation → node marked as purchased
- **Merit balance**: always visible at top of Ledger screen ("当前功德: [N]")
- **Progress indicator**: "[X/15] 已解封" and a progress bar

### Pre-Run Screen: Difficulty Toggle
- **Location**: below the "开始" (Start) button on run-start screen
- **Format**: toggle switches for Hard Mode and Ascension Mode (only visible if unlocked). Toggling shows the multiplier effect ("敌人 ×1.3 / 功德 ×1.5")
- **Mutual exclusion**: toggling Ascension ON automatically turns Hard OFF (and vice versa)

### HUD Integration
- **No HUD presence during run**: Merit is a between-run system. No merit counter, no progress bar during gameplay. Clean HUD
- **Exception**: difficulty mode badge (天劫/飞升) in top-right if active

📌 **UX Flag — Merit System**: This system has significant UI requirements (Results Screen, Merit Ledger, Difficulty Toggle). In Phase 4 (Pre-Production), run `/ux-design` to create a UX spec for each screen **before** writing epics.

## Acceptance Criteria

**AC-01** — **GIVEN** player dies after 120s with 50 kills, 0 bosses, 1 combo, 2 trades, 0 stages cleared, **WHEN** run ends, **THEN** merit_earned = floor((6 + 5 + 0 + 5 + 2 + 0) × 1.0) = 18. Results screen displays 18 merit breakdown.

**AC-02** — **GIVEN** player has 0 total merit and earns 18 merit, **WHEN** results screen shows, **THEN** total merit = 18. Save file updated with `total=18`.

**AC-03** — **GIVEN** player has 25 merit and Node 1 costs 20, **WHEN** player opens Merit Ledger and purchases Node 1, **THEN** merit decreases to 5, Node 1 is marked purchased, save file updated, and starting HP bonus = +10 takes effect next run.

**AC-04** — **GIVEN** Node 1 is purchased but Node 2 is not, **WHEN** player views Merit Ledger, **THEN** Node 2 is highlighted as "available" and Node 3+ are dimmed as "locked".

**AC-05** — **GIVEN** player has 30 merit and Node 2 costs 40, **WHEN** player attempts to purchase Node 2, **THEN** purchase is blocked. UI shows "功德不足" (insufficient merit).

**AC-06** — **GIVEN** Node 2 (解封·飞剑) is purchased, **WHEN** player starts a new run, **THEN** Flying Sword upgrades appear in the base upgrade pool WITHOUT requiring UPGRADE_UNLOCK_FLYING_SWORD. The unlock upgrade is removed from the pool.

**AC-07** — **GIVEN** Node 3 (灵光一闪) is purchased, **WHEN** player reaches first level-up in a new run, **THEN** LevelUpPanel shows 4 options instead of 3. Subsequent level-ups show 3 as normal.

**AC-08** — **GIVEN** Node 7 (五行灵珠) is purchased, **WHEN** player enters Ghost Market interlude, **THEN** Phase Bead stall type can appear among the available stalls.

**AC-09** — **GIVEN** Node 11 (元素感应) is purchased, **WHEN** player starts a new run, **THEN** element_inventory has +1 to a random element. If the random element is Fire and player starts with Talisman (Fire), element_inventory.fire = 2.

**AC-10** — **GIVEN** Node 14 (天劫试炼) is purchased, **WHEN** player views pre-run screen, **THEN** Hard Mode toggle is visible. Toggling ON shows "敌人 ×1.3 / 功德 ×1.5".

**AC-11** — **GIVEN** Hard Mode is ON, **WHEN** run starts, **THEN** all enemy max_hp and damage are multiplied by 1.3. Merit earned at run-end is multiplied by 1.5.

**AC-12** — **GIVEN** Ascension Mode is ON, **WHEN** player attempts to also enable Hard Mode, **THEN** Ascension turns OFF and Hard Mode turns ON (mutual exclusion).

**AC-13** — **GIVEN** player dies instantly (0 kills, 1 second survived), **WHEN** run ends, **THEN** merit_earned = max(floor(...), 1) = 1 (pity floor).

**AC-14** — **GIVEN** save file does not exist (first launch), **WHEN** game starts, **THEN** a new save file is created with total=0, all unlocks=false. No error displayed.

**AC-15** — **GIVEN** save file is corrupted (invalid format), **WHEN** game attempts to load, **THEN** `push_warning()` is logged, fresh save is created, and player starts with no unlocks. No crash.

**AC-16** — **GIVEN** all 15 nodes are purchased and player earns 50 merit, **WHEN** results screen shows, **THEN** merit is added to total normally. Merit Ledger shows all nodes purchased with "功德圆满" (Merit Complete) banner. No spending option available.

**AC-17** — **GIVEN** Node 9 (功德回向) is purchased, **WHEN** player completes a run earning base 40 merit, **THEN** merit_earned = floor(40 × 1.15) = 46.

**AC-18** — **GIVEN** Node 13 (修为加持) is purchased, **WHEN** player starts a new run, **THEN** one random upgrade from the available pool is auto-applied to Player before the first enemy spawns. The upgrade respects all pool filters (weapon lock, stack cap).

*`qa-lead` not consulted — Lean mode. Review manually before production.*

## Open Questions

- **OQ-1** (Kill counter ownership): Run State / Stage Director doesn't currently expose `total_kills` as a tracked metric. Need to add a kill counter — should it live in StageDirector, Player, or a separate analytics node? Smallest change: Player tracks `_total_kills` and increments on each `enemy.died` signal.
- **OQ-2** (Mid-run quit): Current design gives 0 merit for quits. Should there be partial merit for mid-run quits (e.g., 50% of what would have been earned)? Risk: incentivizes quitting over dying.
- **OQ-3** (Node rebalancing post-playtest): The 15-node chain and costs are starting values. After v0.5 playtest, the curve will almost certainly need adjustment. The hand-tuned costs should be easy to tweak in a single data file (or at worst a single match statement).
- **OQ-4** (Post-chain content): When all 15 nodes are purchased, merit accumulates with nothing to spend on. v0.6 plan: Destiny Tree (天命树) with branching paths. For v0.5, the "功德圆满" banner and difficulty modes are the endgame content.
- **OQ-5** (Progression reset): Should there be a "reset all progress" option? Useful for players who want a fresh start. Low priority — can be a main menu option that clears the save file after confirmation dialog.
- **OQ-6** (Statistics screen): The save file tracks `total_runs`, `total_merit_earned`, `best_survival_time`. Should there be a Statistics screen accessible from the main menu? Nice-to-have for v0.5, not blocking.

## Revision Log

| Rev | Date | Trigger | Summary |
|---|---|---|---|
| 0 | 2026-06-02 | Roguelike depth initiative | Initial design: 15-node linear unlock chain, merit formula with 6 scoring categories, save via ConfigFile, difficulty modes as late-chain unlocks. Designed as v0.5 system alongside Five Phases Synergy. |
| 1 | 2026-06-02 | /design-review NEEDS REVISION + cross-review | Fixed 5 blockers: (B-1) heading `Detailed Design`→`Detailed Rules`; (B-2) removed broken Formula 2 cost curve — Ledger table is now authoritative; (B-3) merit_multiplier stacking made explicit (`node9_mult × difficulty_mult`); (B-4) bidirectional propagation to Run State/Player/Level Up Pool/Ghost Market/Enemy done; (B-5) added Run Metrics Contract resolving all 6 metric sources (total_kills→Player counter). Also: boss_defeated→bosses_defeated count, pity floor added to Formula 1, save format extensibility noted. |
