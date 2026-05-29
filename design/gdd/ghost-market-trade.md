# Ghost Market Trade (鬼市交易)

> **Status**: revision-1 (2026-05-29) — addresses MAJOR REVISION (2 independent reviews; 10 blockers + 12 recommended)
> **Author**: claude (concept approved by user; economy by economy-designer, mechanics by systems-designer)
> **Last Updated**: 2026-05-29
> **Implements Pillar**: Pillar 2 (自动战斗与有意义的构筑选择) primary; Pillar 1 (清晰的生存压力) secondary
> **Layer**: Gameplay (Feature) | **Priority**: Vertical Slice (Stage 2 content)
> **Introduced for**: Stage 2 (幽都鬼市 / Netherworld Ghost Market)

## Overview

The Ghost Market Trade is Stage 2's signature risk/reward system and the mechanical counterpart to Stage 1's Demon Seal. Periodically a **ghost merchant stall (鬼商摊)** — an `Area2D` zone — appears near the player. Stepping inside and **holding still for ~1.0s** opens a **3-choice trade panel** (pausing gameplay with a visible burning-fuse timer) where the player spends a run resource — **permanent max-HP reduction** or **修为 (XP)** — for a power buff. Every completed trade **"angers the market"**, spawning a burst **demon tide** of Stage-2 enemies. The panel shows each offer's demon tide so the gamble is always informed. Where the Demon Seal is *defensive and time-based*, the Trade is *offensive and permanent-cost* — a Faustian exchange of long-term survivability for immediate power. It is the sharpest build-decision moment in the game.

## Player Fantasy

**The forbidden bargain.** Standing before a spectral stall in the rolling fog of the ghost market, the cultivator weighs a Faustian deal: carve off your own maximum lifeblood — permanently — for power *right now*, knowing the market's wrath will descend moments after the deal is struck. The intended emotion is **tense, transgressive, gambler's adrenaline** — distinct from the level-up panel's clean optimism. A level-up is a gift; a trade is a *price*. Each stall is a fork in the run: walk past and stay safe, or pay in blood/soul and gamble that your new strength outpaces the tide you just summoned. Yin Debt earns its name: the speed is yours immediately, but the debt arrives ~12-15 seconds later with a warning — you knew it was coming, and you spent the gift time wisely or you didn't. This is the most direct expression of Pillar 2 — construction choices with genuine, permanent stakes.

Tone language (per `design/narrative/01_STORY_BIBLE.md` 文白夹杂 style): the stalls speak in cold, archaic merchant cant — "以血换力，可愿？" ("Blood for power — do you consent?"). Dark 志怪, never whimsical.

## Detailed Rules

### Core Rules

1. **Stall spawning (StageDirector owns).** Stage 2 spawns **4 ghost merchant stalls** per run at approximately **1:30, 2:30, 3:30, 4:15** (seconds 90, 150, 210, 255 — see Tuning Knobs). This gives the player 90 seconds to orient among the 5 new Stage-2 enemies before the first trade opportunity. Spawn positions are offset from the player (similar to Demon Seal's spawn ring). Stalls do **not** spawn during the boss phase (`_is_boss_spawned == true` suppresses spawning; any `AVAILABLE` stall is force-expired when the boss spawns).
2. **One trade per stall.** A stall offers exactly one trade transaction. After a trade is completed it transitions to `SPENT` and is removed. A stall the player ignores expires after a **25-second** linger and is removed silently. Each expired stall that was never traded adds +1 to `market_unease` (see Rule 8).
3. **Three offers per stall.** When opened, the panel presents 3 offers sampled from the trade-archetype pool (Blood Pact / Soul Codex / Yin Debt — see below) plus a **Leave** button. Unaffordable or stack-capped offers are shown **disabled**, never hidden, so the player always sees what was on offer. **Each offer card displays the demon-tide it will summon** (tier label, enemy count, and elite flag — e.g. "Tide: 5 normal enemies" or "Tide: 5 normals + 1 Impermanence Elite"), so the gamble is always informed (Pillar 1).
4. **Ownership split** (mirrors Demon Seal): `TradeStall` (Area2D) owns its own state machine, zone collision, offer list, and self-removal. `StageDirector` owns *when/where/how-many* stalls spawn and *applies the demon-tide penalty* on `trade_completed`.
5. **Every completed trade angers the market.** After a trade resolves, StageDirector spawns a **demon-tide burst** whose size escalates with the number of trades completed this run (see Demon-Tide table + Formula 4). Yin Debt's tide is **delayed ~12-15s** with an on-screen warning when it fires (see below).
6. **Blood Pact cost is permanent max-HP reduction.** A Blood Pact permanently reduces `player.max_hp` by **15 / 20 / 25** (by global trade number `n`, clamped to last). `current_hp` is immediately clamped to not exceed the new `max_hp`. The offer is **locked (disabled)** when accepting it would reduce `max_hp` below the hard floor of **40**. The max-HP reduction persists across the Stage 1→2 transition (it is the same Player node per ADR-0004). There is no current-HP floor guard for Blood Pact — the permanent reduction is the cost.
7. **Death / stage-end guard** (mirrors the Demon Seal OQ-4 fix): trade resolution and demon-tide spawning are skipped if `player._is_dead`, `_is_stage_failed`, or `_is_stage_cleared` are set. A late trade can never spawn enemies onto a corpse or a victory screen.
8. **Non-engagement cost (market unease).** Each stall that expires **without** a trade increments a run-scoped counter `market_unease` by 1. The demon-tide tier for the *next* stall opened is elevated by `market_unease` (capped at +1 tier — equivalent to "add 1 extra normal enemy to the burst"). Ignoring all stalls is not strictly free: the market remembers. This is a light FOMO pressure, not a severe punishment (see Tuning Knobs).

### Hold-Threshold Entry (Pillar 2 — "movement is the only input")

The trade panel does **not** open on first contact with a stall zone. Instead:

- While the player is inside a stall's `Area2D` and `state == AVAILABLE`, a **fill indicator** (a brief ~1.0s charge bar) begins filling.
- If the player remains stationary (position delta < `stall_entry_threshold_px` = 4 px per frame) for the full `stall_entry_hold_seconds` (default 1.0s), the panel opens.
- Any movement during the hold **resets** the fill indicator to 0 — the player must hold still again.
- This prevents an accidental dodge-into-stall from hijacking positioning. No new interact key is introduced — movement remains the sole input.
- Re-entering the zone after leaving **also resets** the hold indicator (no saved progress — anti-exploit and consistent with the reset-on-exit rule).

### Decision Moment — Timed Pause With Visible Fuse

- The panel pauses the scene tree (same as the level-up panel).
- A **burning-fuse timer** (visible on the panel UI, default **5s**) counts down. If it expires before the player chooses, the panel auto-closes — treated as a **Decline** (no trade, no cost, no tide). This restores time pressure even while paused.
- **Destructive trades** (Blood Pact — permanent max-HP cost) require a **confirm step**: after selecting the offer, a secondary "以血换力 — 确认?" prompt appears before the spend executes. The fuse continues running during this confirm step.

### States and Transitions

`TradeStall` state machine:

| State | Entry Condition | Exit → | Visible / Collision |
|---|---|---|---|
| **DORMANT** | StageDirector spawns the stall node | warm-up timer elapses → AVAILABLE | No / disabled |
| **AVAILABLE** | warm-up elapses | hold-threshold reached → TRADING; 25s linger elapses → EXPIRED; boss spawns → EXPIRED | Yes (idle spectral glow) / enabled |
| **TRADING** | hold-threshold met inside zone (passes all step-1 guards) | offer chosen → SPENT; Leave button OR fuse auto-close → AVAILABLE | Yes (panel open, tree paused) |
| **SPENT** | player confirms a trade offer | terminal — `queue_free()` after "sold" visual | brief visual then removed |
| **EXPIRED** | linger timer elapses OR boss spawns with no trade | terminal — `queue_free()` after fade | fade then removed |

**Notes:**
- `body_exited` is **not** a decline path (Godot physics halts while the tree is paused; the signal is dead code in TRADING state). Leave button and fuse auto-close are the only two decline paths from TRADING.
- After a decline (Leave or fuse), the stall returns to AVAILABLE. Same 3 offers are preserved; the linger timer **continues** (not reset — anti-exploit).
- After re-entry from AVAILABLE, the hold-threshold fill resets to 0.

**Signals emitted by `TradeStall`:**
```
signal trade_opened(stall: Area2D)
signal trade_completed(stall: Area2D, offer_id: StringName, resource_type: StringName, resource_cost: float)
signal trade_declined(stall: Area2D)
signal stall_expired(stall: Area2D)
```
StageDirector connects `trade_completed` to its demon-tide handler — exactly as it connects DemonSeal's `seal_completed` today.

### The Three Trade Archetypes

| Trade | Cost (by global trade # `n` — see Formulas 2/3) | Benefit | Cap / Guardrail |
|---|---|---|---|
| **血契 Blood Pact** | **Permanent max-HP reduction** (15 / 20 / 25 by `n`, clamped) | **+15% weapon damage per stack** (applied to base damage only — see Formula 1), permanent for the run | Max **3 stacks** per run; **locked when `max_hp - cost` would drop below 40** |
| **魂典 Soul Codex** | Spend **XP** (60 / 80 / 110 / 150 by `n`, clamped) — deducted from current XP bar (never de-levels) | **Unlock a specific locked weapon** OR **+1 projectile** to a specific owned weapon — resolved at stall-generation time (card shows the exact outcome: "Unlock: Flying Sword" or "+1 Talisman projectile") | Locked when `current_xp < cost`; respects D-B2 stack caps; if all weapons are maxed, the +projectile option is not generated (bad-luck protection) |
| **阴债 Yin Debt** | **Free now** — demon-tide debt paid ~12-15s later | **+20% move speed for 45s** | Tide is delayed (not instant); on-screen warning fires when the tide lands; non-damage buff (no source-modifier ceiling interaction) |

### Trigger and Panel Flow

1. Player body enters a stall's `Area2D`. The stall checks: `state == AVAILABLE` AND `not _is_stage_cleared` AND `not _is_stage_failed` AND `is_instance_valid(player)` AND `not player._is_dead` AND `not player._is_selecting_upgrade` AND `not player._is_in_trade`. If any fail, ignore.
2. Fill indicator starts (hold-threshold flow). If player moves before 1.0s, fill resets. If full 1.0s stationary: continue.
3. Stall → TRADING, emits `trade_opened(self)`.
4. Player saves `_was_tree_paused_before_trade = get_tree().paused`, sets `_is_in_trade = true`, sets `get_tree().paused = true`. Fuse timer starts.
5. Player shows the `TradePanel` (a `PROCESS_MODE_WHEN_PAUSED` CanvasLayer) with the 3 pre-validated offers + Leave + fuse indicator; focus grabs the first enabled option.
6a. **Blood Pact selected** → confirm step fires; player confirms → proceed to spend/buff sequence. Stall → SPENT.
6b. **Non-destructive offer selected** → proceed directly to spend/buff sequence. Stall → SPENT.
6c. **Decline** (Leave button OR fuse expires) → hide panel, unpause, clear `_is_in_trade`, stall → AVAILABLE (same offers preserved, linger continues).
7. StageDirector receives `trade_completed`, applies the demon-tide penalty (delayed for Yin Debt).

### Spend → Buff → Penalty Ordering (synchronous, while paused)

```
A. Re-validate: affordability + buff stack-cap + max-HP floor (panel was open; defensive re-check)
   → if now invalid / dead / stage-ended: abort, close, unpause, stall→EXPIRED, no side effects
B. Spend resource:
     Blood Pact: player.max_hp -= cost; player.current_hp = minf(player.current_hp, player.max_hp)
                 emit health_changed
     XP:         current_xp = maxf(current_xp - cost, 0.0); emit experience_changed (no level-up)
     Yin Debt:   no immediate resource cost
C. Apply buff (player._apply_upgrade(buff_id) or direct field mutation); emit upgrade_applied
D. Stall emits trade_completed(...)
E. StageDirector schedules demon-tide:
     Blood Pact / Soul Codex: spawn immediately after unpause
     Yin Debt: schedule delayed spawn (yin_debt_tide_delay_seconds ≈ 13.5s); emit tide_warning signal
               at delay-2s so HUD can show the on-screen warning
F. Unpause: get_tree().paused = _was_tree_paused_before_trade; clear _is_in_trade
```
Buff applies (C) before unpause (F) so the player's improved stats are live when the tide arrives.

### Interactions with Other Systems

| System | Interaction |
|---|---|
| **Player** | Owns `get_tree().paused`, `_is_in_trade` flag, resource fields (`max_hp`, `current_hp`, `current_xp`), buff application via `_apply_upgrade`. Trade panel reuses the level-up pause/choice pattern. Blood Pact mutates `max_hp` directly. |
| **Level Up & Upgrade Pool** | Trade panel and level-up panel share the pause token → mutually exclusive (`_is_in_trade` / `_is_selecting_upgrade` guards). Trade buffs respect the **D-B2 `_upgrade_pick_count` stack caps** — a capped buff is excluded/disabled, never silently no-op'd for full cost. |
| **Combat** | Blood Pact damage buff is bounded by the `minf` ceiling clamp in Formula 1 (source-modifier side ≤ 5× base). 火眼金睛's `crit_multiplier` (1.2–1.55×) is a **separate** multiplicative pipeline stage — it is pre-existing Combat behavior, outside this ceiling, and NOT introduced by Blood Pact. See Formula 1 note. |
| **Stage Director** | Owns stall spawning + demon-tide penalty; suppresses stalls during boss phase. Demon tide stacks additively with any active Demon Seal pressure on the EnemySpawner. StageDirector holds the Yin Debt delayed-tide timer. |
| **Demon Seal** | Sibling risk/reward system; both can be active simultaneously in Stage 2. Pressure effects stack on the spawner (already the designed Stage 2 model). |
| **Enemy Spawner** | Demon-tide burst spawns through the existing spawner via `spawn_enemy_burst` / `spawn_elite_at`; tide enemies obey the aggregate **4-attacker contact ceiling** (enforced player-side), so a 6-enemy burst still only lets 4 damage at once. |
| **Run State** | Stage 2 is reached sequentially after clearing Stage 1; build/level/HP (including any prior max-HP reductions) carry over → trades are tuned for a **mid-game** entry build (~L8-12, ~120-160 HP). |
| **HUD** | The Trade panel creates a distinct pause state. `hud.md` must add a **Trade-pause state** so the low-HP red-edge overlay and the angered-market pulse do not layer incoherently during the panel. See cross-doc note in Dependencies. |

## Formulas

### Formula 1 — Blood Pact damage buff (ceiling-safe with structural clamp)

```
weapon_damage_after_pact = minf(
    stacked_weapon_damage + base_weapon_damage × 0.15 × blood_pact_stacks,
    base_weapon_damage × 5.0
)
```

| Symbol | Type | Range | Description |
|---|---|---|---|
| `base_weapon_damage` | float | 6.0–16.0 (v0.4 baseline ~8.0) | The weapon's base damage value before any upgrades |
| `stacked_weapon_damage` | float | base–(base+30) | Damage after D-B2-capped level-up upgrades (max +30 from 3 damage upgrade stacks) |
| `blood_pact_stacks` | int | 0–3 | Number of Blood Pacts taken this run (stack cap enforced by D-B2 system) |
| `weapon_damage_after_pact` | float | base–(base×5.0) | Final weapon damage to submit to the combat pipeline as source input |

**Output Range:** Clamped at `base_weapon_damage × 5.0` — this is the source-modifier ceiling defined in combat-system.md. The `minf` clamp is structural: it holds for **any** base value, including low bases (e.g. base=6 → ceiling = 30.0; stacked 36 + 6×0.15×3 = 38.7 → clamped to 30.0).

**Worked example (base-8, typical):** 1 damage upgrade (+10 → `stacked = 18`), 2 Blood Pacts: `minf(18 + 8 × 0.15 × 2, 8 × 5.0) = minf(18 + 2.4, 40.0) = minf(20.4, 40.0) = 20.4`.

**Worked example (base-6, low-base ceiling check):** max upgrades (+30 → `stacked = 36`), 3 Blood Pacts: `minf(36 + 6 × 0.15 × 3, 6 × 5.0) = minf(36 + 2.7, 30.0) = minf(38.7, 30.0) = 30.0` — ceiling holds.

**火眼金睛 note (implementer clarity):** The 5× ceiling above bounds the `source_modifier` stage only (this GDD's scope). 火眼金睛's `crit_multiplier` (range 1.2–1.55×, per combat-system.md) is a **separate downstream multiplicative stage** — it multiplies the result of Formula 1, not the base. That downstream multiplier is pre-existing Combat behavior and is **intentionally outside** this ceiling. Implementers should NOT try to include crit in the `minf` clamp — doing so would misrepresent the combat pipeline.

### Formula 2 — Blood Pact max-HP cost escalation

`blood_pact_max_hp_cost(n) = [15, 20, 25][clamp(n, 0, 2)]`

where `n` = the **global trade counter** (cumulative trades completed this run, 0-indexed, regardless of archetype), clamped to the last array index (2).

| Symbol | Type | Range | Description |
|---|---|---|---|
| `n` | int | 0–∞ (clamped to 2) | Global 0-indexed trade counter for this run (cumulative across all archetypes) |
| `blood_pact_max_hp_cost` | int | 15–25 | Permanent max-HP reduction applied to player.max_hp |

**Output Range:** 15–25. Cumulative cost across all 3 stacks (max allowed): `15 + 20 + 25 = 60 HP`. On a base 100 HP player, 3 Blood Pacts cost 60 max-HP, leaving 40 max-HP — exactly the floor, making triple-pact possible only on a player who has taken max-HP upgrades. Floor lock engages before the spend would push below 40.

**Lock condition:** offer is disabled when `player.max_hp - blood_pact_max_hp_cost(n) < 40`.

### Formula 3 — Soul Codex XP cost escalation

`soul_codex_xp_cost(n) = [60, 80, 110, 150][clamp(n, 0, 3)]`

where `n` = the **global trade counter** (cumulative trades completed this run, 0-indexed), clamped to the last array index (3).

| Symbol | Type | Range | Description |
|---|---|---|---|
| `n` | int | 0–∞ (clamped to 3) | Global 0-indexed trade counter for this run (cumulative across all archetypes) |
| `soul_codex_xp_cost` | int | 60–150 | XP deducted from `current_xp` (never de-levels; never goes below 0) |

**Output Range:** 60–150 XP. Calibrated against the Demon Seal reward (48 XP) — a Soul Codex costs slightly more than a Seal pays, reflecting the direct build power of a weapon unlock. At mid-game (~L10, threshold ~358 XP), 60 XP ≈ 17% of a level; by trade 4, 150 XP ≈ 42% of a level — a real sacrifice.

### Formula 4 — Demon-tide penalty intensity per trade

`demon_tide(n)` where `n` = **global trade counter** (cumulative trades this run, 1-indexed for the table; clamped at `n ≥ 4`). All enemies are drawn from the **Stage-2 roster** (lantern_ghost, resentful_infant, ghost_bailiff, tomb_guardian, impermanence_elite) — **not** Stage-1 Shanxiao.

| n (cumulative trades) | Normal burst | Elite added | Spawn-interval modifier | Tide window | Tide type |
|---|---|---|---|---|---|
| 1 | 5 normals (Stage-2 pool) | 0 | ×0.75 for 12s | 12s | Immediate |
| 2 | 5 normals | 0 | ×0.75 for 12s | 12s | Immediate |
| 3 | 5 normals | +1 Impermanence Elite | ×0.75 for 12s | 12s | Immediate |
| 4+ | 6 normals | +1 Impermanence Elite | ×0.65 for 20s | 20s | Immediate |

**Yin Debt tide**: same table as above but spawns **~12-15s after the trade** (`yin_debt_tide_delay_seconds`), with a 2-second advance on-screen warning.

**Survival-budget calibration (real Stage-2 DPS, mid-game player ~130-160 HP):**

Contact DPS per archetype (from stage-2-enemies.md):

| Enemy | contact_dps |
|---|---|
| lantern_ghost | 20.0 |
| resentful_infant | 17.1 |
| ghost_bailiff | 23.5 |
| tomb_guardian | 28.0 |
| impermanence_elite (post-swift affix) | 39.1 / 0.9 ≈ 43.4 |

Under the **4-attacker contact ceiling** (`MAX_CONTACT_ATTACKERS = 4`), peak simultaneous DPS:

- **Trade 1-2 (5 normals):** Worst-case 4 attackers, realistic mix (ghost_bailiff × 2 + lantern_ghost + tomb_guardian) = 23.5 + 23.5 + 20.0 + 28.0 = **95.0 aggregate ceiling DPS**. With active kiting (average 2 attackers in contact at once during movement) → effective ~47.5 DPS → 130 HP player loses ~57 HP over 12s → **56% HP at risk** (high pressure, survivable with skill). 
- **Trade 3 (5 normals + 1 elite):** 4-attacker ceiling with 1 elite + 3 normals realistic: 43.4 + 28.0 + 23.5 + 20.0 = **114.9 ceiling DPS**. Kiting brings effective to ~55-65 DPS → 130 HP player loses ~66-78 HP over 12s → **51-60% HP at risk** (punishing; expects HP upgrades by trade 3).
- **Trade 4+ (6 normals + 1 elite):** Ceiling remains 4 attackers; realistic 1 elite + 3 normals = ~115 DPS ceiling. With 20s window and kiting: effective ~60-70 DPS → 140 HP player loses ~72-84 HP → **51-60% HP at risk** (matches target of 30-50% HP loss with active kiting — players below ~120 HP at this stage are accepting high risk).

**Old calibration note (stale, replaced):** The revision-0 figure of "~16 DPS, survives at 7 HP" used pre-D-B1 Stage-1 stats and Shanxiao elites — both wrong for Stage 2. The trade-2 "2 Impermanence Elites = ~107 DPS = death in 0.69s at 35 HP" (review flag) is resolved by (a) removing double-elite from trade-2 (now 0/0/1/1 elite schedule) and (b) aligning to actual mid-game HP range (~120-160).

## Edge Cases

- **If the player dies while the trade panel is open**: tree is paused so enemies cannot damage them; only a script path could kill. Step A checks `player._is_dead` → if true, close panel, unpause, stall → EXPIRED, no spend / no buff / no tide.
- **If the boss dies (stage clears) while the panel is open**: signals still fire while paused; `_on_boss_died` sets `_is_stage_cleared`. Step A detects it → close panel, unpause (lets the victory screen proceed), stall → EXPIRED, no side effects.
- **If the player triggers a stall while a previous trade's demon tide is still active**: permitted by design — no "active tide" flag is tracked; the new burst stacks on top. Linger timers make back-to-back trading a deliberate high-risk choice.
- **If two stall zones overlap and the hold-threshold fires for both simultaneously**: the `_is_in_trade` flag gates the second (step-1 guard rejects it). When the first trade resolves and clears `_is_in_trade`, the player runs `_check_overlapping_stalls()` (queries `get_overlapping_areas()` filtered to group `trade_stall` + state AVAILABLE) and re-enters the hold-threshold flow for the next stall.
- **If an XP-cost offer is selected with insufficient XP**: impossible — the offer is `disabled` during validation (`cost > current_xp`). XP subtraction is `maxf(current_xp - cost, 0.0)` and never triggers a level-up.
- **If a Blood Pact would reduce max_hp below the floor of 40**: offer locked (disabled) during validation. The clamp `max_hp - cost < 40` is re-checked in step A. No partial reduction is ever applied.
- **If a buff's D-B2 stack cap is reached between stall spawn and panel open** (e.g. a level-up during the AVAILABLE window filled it): step A re-validates the cap; a capped buff is treated as unaffordable (disabled), preventing a full-cost no-op trade.
- **If all 3 offers are unaffordable/capped**: panel opens with all 3 disabled; the player can only press Leave or let the fuse expire. (Economy tuning aims to make total lockout rare.)
- **If a Soul Codex "+1 projectile" would target a weapon already at D-B2 projectile stack cap (3)**: the bad-luck filter at stall-generation time excludes this result from the offer pool. The card is never generated in this configuration (see Rule 3 + Archetype table).
- **If `body_exited` fires while in TRADING state**: this is dead code (Godot physics halts on `get_tree().paused = true`). The decline path is Leave button or fuse auto-close only. No transition triggered by `body_exited` in TRADING.
- **If the Yin Debt delayed tide fires after the player has died or the stage has cleared**: StageDirector's tide handler checks `_is_dead` / `_is_stage_cleared` before spawning, same as immediate tides. Delayed spawn is silently skipped.
- **If `market_unease` accumulates to maximum before any trade**: `market_unease` is capped at 3 (adds at most +1 normal enemy to the next tide, not a cascade). This prevents ignoring all 4 stalls from creating an oppressive 6th-stall-equivalent scenario.

## Dependencies

| Dependency | Type | Interface |
|---|---|---|
| **Player** (C-04) | Hard Bidirectional | Owns pause, `_is_in_trade` flag, `max_hp`/`current_hp`/`current_xp` fields, `_apply_upgrade`, `health_changed`/`experience_changed`/`upgrade_applied` signals. Blood Pact mutates `max_hp` directly. |
| **Level Up & Upgrade Pool** (FT-13) | Hard Bidirectional | Shared pause token (mutual exclusion); shared D-B2 `_upgrade_pick_count` stack caps |
| **Stage Director** (FT-10) | Hard Bidirectional | Owns stall spawning + demon-tide penalty (immediate + delayed); suppresses during boss phase; holds `market_unease` counter; holds Yin Debt delayed-tide timer |
| **Combat** (C-06) | Hard | Blood Pact buff bounded by `minf` source-modifier clamp in Formula 1; 火眼金睛 crit pipeline is separate (see Formula 1 note) |
| **Enemy Spawner** (FT-09) | Hard | Demon-tide burst spawns via `spawn_enemy_burst` / `spawn_elite_at` (Stage-2 archetypes); obeys 4-attacker ceiling |
| **Demon Seal** (FT-16) | Soft (sibling) | Coexists in Stage 2; pressure stacks on spawner |
| **Run State** (C-03) | Hard | Sequential stage progression; build + max-HP reductions carry over (ADR-0004: same Player node) |
| **HUD** (UI-02) | Hard | `hud.md` must add a **Trade-pause state** to prevent the low-HP red-edge overlay and angered-market pulse from layering incoherently during the trade panel. **Cross-doc action:** this revision adds a note to `hud.md` as an OQ (OQ-3 below). |
| **Godot Area2D** | Hard (engine) | Stall zone collision detection; hold-threshold uses `body_entered`/position polling (not `body_exited` for TRADING) |

> Bidirectional note: Player, Level Up Pool, and Stage Director GDDs must add "depended on by Ghost Market Trade" when this GDD is approved. hud.md must add a Trade-pause UI state.

## Tuning Knobs

| Knob | Default | Safe Range | Effect / What breaks at extremes |
|---|---|---|---|
| `stall_count_per_run` | 4 | 2–6 | <3 trivial scarcity; >5 degenerate accumulation |
| `stall_spawn_times` | [90, 150, 210, 255]s | within stage_duration (300s) | <90s = player has no time to orient to Stage-2 enemies; >270s = too late to benefit from buff |
| `stall_linger_seconds` | 25 | 15–40 | too long = safe parking; too short = unfair miss |
| `stall_entry_hold_seconds` | 1.0 | 0.5–2.0 | <0.5 = accidental entry likely; >2.0 = punishes deliberate entry |
| `stall_entry_threshold_px` | 4 | 2–8 | lower = requires near-perfect stillness; higher = movement during hold permitted |
| `trade_panel_fuse_seconds` | 5.0 | 3.0–8.0 | too short = not enough time to read offers; too long = negates time pressure |
| `blood_pact_hp_costs` | [15, 20, 25] | per-step ≥ 10 | too cheap = glass-cannon spam; too dear = never used |
| `blood_pact_hp_floor` | 40 | 30–55 | below 30 = near-suicidal triple-pact; above 55 = second pact rarely available |
| `blood_pact_damage_per_stack` | 0.15 (+15%) | 0.10–0.20 | >0.20 approaches `minf` ceiling earlier; <0.10 makes pact feel weak |
| `blood_pact_max_stacks` | 3 | 2–3 | >3 would require raising ceiling clamp |
| `soul_codex_xp_costs` | [60, 80, 110, 150] | ≥ Demon Seal reward (48) | too cheap trivializes weapon unlock pacing |
| `yin_debt_speed_bonus` | 0.20 (+20%) | 0.10–0.30 | too high trivializes the delayed debt by kiting |
| `yin_debt_speed_duration` | 45s | 30–60 | too long outruns the delayed debt entirely; 45s chosen so buff expires ~at or just before the tide lands |
| `yin_debt_tide_delay_seconds` | 13.5 | 10–18 | too short = self-negation (speed irrelevant before penalty); too long = trivializes debt |
| `yin_debt_tide_warning_lead_seconds` | 2.0 | 1.0–3.0 | warning before delayed tide fires; less than 1s is unfair |
| `demon_tide_normal_count` | 5 (trade 4+: 6) | 3–8 | calibrated to 4-attacker ceiling survival budget |
| `demon_tide_interval_mult` | 0.75 (0.65 @ trade 4+) | 0.6–0.85 | lower = more lethal sustained pressure |
| `demon_tide_window_seconds` | 12 (20 @ trade 4+) | 8–24 | survival-window length |
| `demon_tide_elite_schedule` | [0, 0, 1, 1] by trade | [0,0,0,1] to [0,1,1,2] | reduce if early-stage survival rate <50%; increase for veteran pressure |
| `market_unease_max` | 3 | 1–4 | caps FOMO pressure; >4 = punitive cascade; 0 = remove feature |
| `market_unease_tide_bonus` | +1 normal enemy | +0 to +2 normals | light pressure, not severe punishment |

## Visual / Audio Requirements

> Brief at GDD stage; full spec via `/asset-spec system:ghost-market-trade` after the art bible covers Stage 2.

- **Stall visual**: a spectral merchant stall — hanging ghost-lantern, tattered banner, faint 朱砂/青铜 palette (consistent with the established VFX palette). Idle: slow pulse glow. AVAILABLE + player inside hold zone: fill-bar indicator visible near the stall. SPENT: brief "sold" stamp + dissolve. EXPIRED: silent fade.
- **Hold-threshold indicator**: a subtle ~1.0s radial fill bar (or stall-glow intensification) anchored to the stall, visible while the player holds still. Must be legible without a new interact key prompt.
- **Trade panel**: darker, more ominous theme than the level-up panel — fog border, archaic-cant merchant line per offer. Each offer card shows the **demon-tide summary** (e.g. "潮汐: 5怪 ×0.75 12s" / "潮汐: 5怪+无常精英"). Burning-fuse timer prominent in the UI. Blood Pact confirm step uses a distinct destructive-action style (red tint).
- **"Angered market" cue**: a distinct audio sting + screen-edge red pulse the instant a trade resolves, telegraphing the incoming tide (Combat Feedback + Audio own the actual sting/visual; this system fires the trigger).
- **Yin Debt delayed-tide warning**: ~2s before the tide lands, an on-screen warning fires ("阴债将至" / "Debt arrives"). Design for legibility while the player is kiting.
- **Demon-tide telegraph**: brief spawn-direction indicator so the burst isn't a blind ambush (consistent with fair-pressure Pillar 1).

> **HUD cross-doc flag**: Trade panel introduces a distinct pause state. The HUD's low-HP red-edge overlay and the post-trade angered-market red pulse must not visually conflict. `hud.md` must specify a Trade-pause state that suppresses the low-HP overlay while the panel is open (or z-orders them intentionally).

📌 **Asset Spec** — after the art bible covers Stage 2, run `/asset-spec system:ghost-market-trade`.
📌 **UX Flag** — the Trade panel is a new screen. In Pre-Production run `/ux-design` for `design/ux/trade-panel.md` before writing trade stories; stories should cite that UX spec, not this GDD.

## Acceptance Criteria

- **AC-01** **GIVEN** Stage 2 is running and `elapsed_time` reaches 90s (first stall spawn time), **WHEN** the warm-up elapses, **THEN** a TradeStall transitions DORMANT→AVAILABLE and becomes visible + collision-enabled exactly once.
- **AC-02-hold** **GIVEN** an AVAILABLE stall and the player moves inside the zone, **WHEN** the player holds still for ≥1.0s (position delta < 4px per frame), **THEN** the panel opens; **AND WHEN** the player moves within 1.0s, the fill resets and the panel does not open.
- **AC-02-reentry** **GIVEN** the player entered a stall zone, the fill indicator reached 0.6s, the player left and re-entered, **WHEN** the fill restarts from 0, **THEN** the panel does not open until a fresh 1.0s uninterrupted hold completes (no saved progress).
- **AC-03** **GIVEN** the panel is open with a Blood Pact offer (trade n=0, cost=15) and `max_hp = 100`, **WHEN** the player selects and confirms it, **THEN** `max_hp = 85`, `current_hp = min(current_hp, 85)`, weapon base damage gains +15%, `upgrade_applied` emits, and the tree unpauses.
- **AC-03b-ceiling** **GIVEN** a weapon with `base_weapon_damage = 6`, max level-up upgrades applied (stacked = 36), and 3 Blood Pacts taken, **WHEN** Formula 1 is evaluated, **THEN** `weapon_damage_after_pact = minf(36 + 6×0.15×3, 6×5.0) = minf(38.7, 30.0) = 30.0` — ceiling clamp holds for low-base weapons.
- **AC-04-floor** **GIVEN** `max_hp = 54` and Blood Pact cost at trade n=0 is 15, **WHEN** a stall panel opens, **THEN** the Blood Pact offer is enabled (54 - 15 = 39 < 40 → DISABLED); **AND GIVEN** `max_hp = 56`, **THEN** Blood Pact is enabled (56 - 15 = 41 ≥ 40).
- **AC-05** **GIVEN** a Soul Codex offer costing 60 XP and `current_xp = 40`, **WHEN** the panel opens, **THEN** the offer is `disabled` and cannot be selected.
- **AC-05b-specific** **GIVEN** a Soul Codex offer generated at stall spawn time for a player who has not yet unlocked Flying Sword, **WHEN** the panel opens, **THEN** the offer card reads "Unlock: Flying Sword" (the specific outcome, not a generic label). **GIVEN** all unlockable weapons are already owned and all are at projectile max, **THEN** no Soul Codex offer is generated for that stall (bad-luck protection).
- **AC-06-tide1** **GIVEN** trade_count = 1 (first completed trade), **WHEN** `trade_completed` fires, **THEN** StageDirector spawns exactly 5 Stage-2 normal enemies and sets spawn-interval modifier to ×0.75 for 12s. `EnemySpawner._tide_interval_override` is set and `_tide_window_remaining = 12.0`.
- **AC-06-tide2** **GIVEN** trade_count = 2, **WHEN** `trade_completed` fires, **THEN** StageDirector spawns exactly 5 Stage-2 normal enemies and ×0.75 interval for 12s; **0 elites spawned**.
- **AC-06-tide3** **GIVEN** trade_count = 3, **WHEN** `trade_completed` fires, **THEN** StageDirector spawns 5 Stage-2 normals **+ 1 impermanence_elite** via `spawn_elite_at`; ×0.75 for 12s.
- **AC-06-tide4** **GIVEN** trade_count ≥ 4, **WHEN** `trade_completed` fires, **THEN** StageDirector spawns 6 Stage-2 normals **+ 1 impermanence_elite**; ×0.65 for 20s.
- **AC-07** **GIVEN** 3 Blood Pacts already taken (`blood_pact_stacks == 3`), **WHEN** a new stall opens, **THEN** Blood Pact IS present in the offer list but is shown **disabled** (stack cap reached — shown, not hidden).
- **AC-08** **GIVEN** max upgrades + 3 Blood Pacts, `base_weapon_damage = 8`, **WHEN** weapon damage is computed, **THEN** `weapon_damage_after_pact = minf(38 + 8×0.15×3, 8×5.0) = minf(38+3.6, 40.0) = 40.0` — at ceiling.
- **AC-09a** **GIVEN** `player._is_dead = true` is injected while a trade panel is open, **WHEN** step A executes, **THEN**: (1) no resource is spent, (2) no buff applies, (3) no demon tide spawns, (4) panel hides, (5) tree unpauses, (6) stall transitions to EXPIRED, (7) `_is_in_trade = false`.
- **AC-09b** **GIVEN** `_is_stage_cleared = true` is injected while a trade panel is open (boss died mid-panel), **WHEN** step A executes, **THEN**: same 7 postconditions as AC-09a.
- **AC-10** **GIVEN** the boss has spawned (`_is_boss_spawned = true`), **WHEN** any stall is AVAILABLE, **THEN** it transitions to EXPIRED and no new stalls spawn for the rest of the run.
- **AC-11** **GIVEN** a stall is AVAILABLE and the player never trades, **WHEN** 25s elapse, **THEN** the stall transitions to EXPIRED, `queue_free()`s, emits `stall_expired`, and `market_unease` increments by 1.
- **AC-12** **GIVEN** the player opens a stall and presses Leave (or the fuse expires), **WHEN** the panel closes, **THEN** the tree unpauses, `_is_in_trade = false`, the stall returns to AVAILABLE with the **same 3 offers**, and the linger timer has **not** reset (continues from wherever it was).
- **AC-13-yin-speed** **GIVEN** a Yin Debt trade is completed, **WHEN** the trade resolves, **THEN** `player.move_speed_bonus` increases by +20% and a 45s expiry timer starts; at t=45s the bonus is removed.
- **AC-13-yin-delay** **GIVEN** a Yin Debt trade is completed (trade_count = 2), **WHEN** `yin_debt_tide_delay_seconds` (≈13.5s) elapses, **THEN** StageDirector spawns the tide matching trade_count=2 (5 normals, 0 elites) — **not** at trade completion time; **AND** an on-screen warning fires at t = delay - 2s.
- **AC-14-fuse** **GIVEN** the panel is open and the player takes no action, **WHEN** 5s elapse (fuse expires), **THEN** the panel closes, treated as Decline (no spend, no buff, no tide, stall → AVAILABLE, linger continues).
- **AC-15-hud** **GIVEN** a trade panel is open (tree paused), **WHEN** the HUD renders, **THEN** the Trade-pause state is active, the low-HP red-edge overlay is suppressed, and the angered-market pulse does not layer with it (or is explicitly z-ordered per hud.md spec).

## Open Questions

- **OQ-1** (Blood Pact ceiling assertion): add a runtime `push_error()` assertion if any weapon's `weapon_damage_after_pact / base_weapon_damage > 5.0` after a trade? The `minf` clamp should prevent this, but a redundant assert catches implementation errors. **Owner**: systems-designer + lead-programmer. **Target**: implementation.
- **OQ-2** ~~(current-HP vs max-HP cost)~~ **RESOLVED** (2026-05-29 — owner decision): Blood Pact cost is permanent max-HP reduction (15/20/25 by global trade n). Old current-HP model removed. Max-HP floor is 40. Reduction persists across Stage 1→2 (same Player node, ADR-0004).
- **OQ-3** (HUD Trade-pause state): the trade panel creates a distinct pause state that must not layer incoherently with the low-HP overlay and post-trade pulse. `hud.md` must add an explicit Trade-pause UI state. **Owner**: UI designer. **Target**: Pre-Production UX pass (before `/team-ui` implementation stories).
- **OQ-4** (Soul Codex projectile fallback): resolved in Detailed Rules (bad-luck filter: if all weapons are at max projectile stack, the +projectile card is not generated). Confirm the fallback behavior (generate a different offer or show the stall with only 2 cards) before implementation. **Owner**: systems-designer. **Target**: implementation.
- **OQ-5** ~~(Yin Debt duration 60s)~~ **RESOLVED** (2026-05-29 — revision-1): duration reduced to 45s so it does not fully outlast the delayed tide. Delay set to ~13.5s. Kiting balance: playtest flag if speed trivializes the debt even at 45s — reduce to 35s if so.

## Revision Log

| Rev | Date | Trigger | Summary |
|---|---|---|---|
| 0 | 2026-05-29 | Initial design (Stage 2 content) | User-approved concept; economy by economy-designer (4 stalls, 3 trades, escalating cost, demon-tide curve, guardrails); mechanics by systems-designer (stall state machine, panel flow, ordering, 9 edge cases). 12 ACs, 5 OQs. Pending /design-review. |
| 1 | 2026-05-29 | MAJOR REVISION — 2 independent /design-review verdicts (10 blockers + 12 recommended) | **B-1** Blood Pact cost → permanent max-HP reduction (15/20/25), floor 40, current_hp clamped. **B-2** Yin Debt tide delayed ~13.5s with on-screen warning; speed duration 45s (not 60s) to prevent self-negation. **B-3** Stall entry → hold-threshold ~1.0s fill indicator (no accidental entry; preserves movement-only input). **B-4** Decision moment → timed fuse timer (~5s auto-close = decline); Blood Pact confirm step. **B-5** Each offer card shows demon-tide details (tier/count/elites) so gamble is informed (Pillar 1). **B-6** Blood Pact buff raised to +15%/stack, Formula 1 gains structural `minf(…, base×5.0)` clamp valid for any base value; 火眼金睛 crit pipeline documented as separate stage, out of scope. **B-7** `body_exited` removed as a TRADING-state decline path (dead code while paused); Leave button + fuse only. **B-8** Soul Codex pre-resolves outcome at generation time; bad-luck filter excludes +projectile if all weapons maxed. **B-9** Non-engagement cost: expired stalls increment `market_unease`; light +1-normal bonus on next tide (capped at 3). **B-10** Formula 4 recalibrated with real Stage-2 DPS; Shanxiao → Impermanence Elite; elite schedule 0/0/1/1; first stall at 1:30 (t=90s); survival-budget worked example with mid-game HP. AC section fully rewritten (15 ACs, all Given/When/Then with measurable observables). OQ-2 + OQ-5 closed; OQ-3 (HUD Trade-pause) added. |
