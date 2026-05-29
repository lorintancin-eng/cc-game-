# Ghost Market Trade (鬼市交易)

> **Status**: In Design (revision-0 — authored 2026-05-29; pending /design-review)
> **Author**: claude (concept approved by user; economy by economy-designer, mechanics by systems-designer)
> **Last Updated**: 2026-05-29
> **Implements Pillar**: Pillar 2 (自动战斗与有意义的构筑选择) primary; Pillar 1 (清晰的生存压力) secondary
> **Layer**: Gameplay (Feature) | **Priority**: Vertical Slice (Stage 2 content)
> **Introduced for**: Stage 2 (幽都鬼市 / Netherworld Ghost Market)

## Overview

The Ghost Market Trade is Stage 2's signature risk/reward system and the mechanical counterpart to Stage 1's Demon Seal. Periodically a **ghost merchant stall (鬼商摊)** — an `Area2D` zone — appears near the player. Stepping into it opens a **3-choice trade panel** (pausing gameplay, like the level-up panel) where the player spends a run resource — **current 气血 (HP)** or **修为 (XP)** — for a power buff. But every completed trade **"angers the market"**, immediately spawning a burst **demon tide** (a wave of tougher enemies). Where the Demon Seal is *defensive and time-based* ("stand in danger to earn XP"), the Trade is *offensive and resource-based* ("spend what you have to grow stronger now, and weather the consequence"). It is the sharpest build-decision moment in the game.

## Player Fantasy

**The forbidden bargain.** Standing before a spectral stall in the rolling fog of the ghost market, the cultivator weighs a Faustian deal: carve off your own lifeblood or hard-won cultivation for power *right now*, knowing the market's wrath will descend the instant the deal is struck. The intended emotion is **tense, transgressive, gambler's adrenaline** — distinct from the level-up panel's clean optimism. A level-up is a gift; a trade is a *price*. Each stall is a fork in the run: walk past and stay safe, or pay in blood/soul and gamble that your new strength outpaces the tide you just summoned. This is the most direct expression of Pillar 2 — a construction choice with genuine stakes, because the currency is your own survival.

Tone language (per `design/narrative/01_STORY_BIBLE.md` 文白夹杂 style): the stalls speak in cold, archaic merchant cant — "以血换力，可愿？" ("Blood for power — do you consent?"). Dark 志怪, never whimsical.

## Detailed Rules

### Core Rules

1. **Stall spawning (StageDirector owns).** Stage 2 spawns **4 ghost merchant stalls** per run at approximately **0:30, 1:30, 2:30, 3:30** (see Tuning Knobs). Spawn positions are offset from the player (similar to Demon Seal's spawn ring). Stalls do **not** spawn during the boss phase (`_is_boss_spawned == true` suppresses spawning; any `AVAILABLE` stall is force-expired when the boss spawns).
2. **One trade per stall.** A stall offers exactly one trade transaction. After a trade is completed it transitions to `SPENT` and is removed. A stall the player ignores expires after a **25-second** linger and is removed silently.
3. **Three offers per stall.** When opened, the panel presents 3 offers sampled from the trade-archetype pool (Blood Pact / Soul Codex / Yin Debt — see below) plus a **Leave** button. Unaffordable or stack-capped offers are shown **disabled**, never hidden, so the player always sees what was on offer.
4. **Ownership split** (mirrors Demon Seal): `TradeStall` (Area2D) owns its own state machine, zone collision, offer list, and self-removal. `StageDirector` owns *when/where/how-many* stalls spawn and *applies the demon-tide penalty* on `trade_completed`.
5. **Every completed trade angers the market.** Immediately after a trade resolves, StageDirector spawns a **demon-tide burst** whose size escalates with the number of trades completed this run (see Demon-Tide table + Formula 4).
6. **Resource floors are absolute.** A Blood Pact can never reduce the player to a lethal state: it is **locked when current HP ≤ 20** (one Paper Doll hit), and the HP spend is floored so it cannot reach 0. XP spend never de-levels and never goes below 0.
7. **Death / stage-end guard** (mirrors the Demon Seal OQ-4 fix): trade resolution and demon-tide spawning are skipped if `player._is_dead`, `_is_stage_failed`, or `_is_stage_cleared` are set. A late trade can never spawn enemies onto a corpse or a victory screen.

### States and Transitions

`TradeStall` state machine:

| State | Entry Condition | Exit → | Visible / Collision |
|---|---|---|---|
| **DORMANT** | StageDirector spawns the stall node | warm-up timer elapses → AVAILABLE | No / disabled |
| **AVAILABLE** | warm-up elapses | player `body_entered` → TRADING; 25s linger elapses → EXPIRED; boss spawns → EXPIRED | Yes (idle spectral glow) / enabled |
| **TRADING** | player body enters the zone (passes all step-1 guards) | offer chosen → SPENT; declined / `body_exited` → AVAILABLE | Yes (panel open, tree paused) |
| **SPENT** | player selects an offer | terminal — `queue_free()` after "sold" visual | brief visual then removed |
| **EXPIRED** | linger timer elapses OR boss spawns with no trade | terminal — `queue_free()` after fade | fade then removed |

**Signals emitted by `TradeStall`:**
```
signal trade_opened(stall: Area2D)
signal trade_completed(stall: Area2D, offer_id: StringName, resource_type: StringName, resource_cost: float)
signal trade_declined(stall: Area2D)
signal stall_expired(stall: Area2D)
```
StageDirector connects `trade_completed` to its demon-tide handler — exactly as it connects DemonSeal's `seal_completed` today.

### The Three Trade Archetypes

| Trade | Cost (escalates by trade # — see Formula 2/3) | Benefit | Cap / Guardrail |
|---|---|---|---|
| **血契 Blood Pact** | Sacrifice **current HP** (15 / 20 / 30 / 45 by trade #) | **+8% weapon damage** (applied to base damage only — see Formula 1), permanent for the run | Max **3 stacks** per run; **locked when current HP ≤ 20** |
| **魂典 Soul Codex** | Spend **XP** (60 / 80 / 110 / 150 by trade #), deducted from current XP bar (never de-levels) | **Unlock a locked weapon** OR **+1 projectile** to an owned weapon | Locked when `current_xp < cost`; respects D-B2 stack caps (capped weapon → offer disabled / fallback) |
| **阴债 Yin Debt** | **Free now** | **+20% move speed for 60s** | Incurs an escalated demon-tide "debt wave" (see Formula 4); non-damage buff (no 5× ceiling interaction) |

### Trigger and Panel Flow

1. Player body enters a stall's `Area2D`. The stall checks: `state == AVAILABLE` AND `not _is_stage_cleared` AND `not _is_stage_failed` AND `is_instance_valid(player)` AND `not player._is_dead` AND `not player._is_selecting_upgrade` AND `not player._is_in_trade`. If any fail, ignore.
2. Stall → TRADING, emits `trade_opened(self)`.
3. Player saves `_was_tree_paused_before_trade = get_tree().paused`, sets `_is_in_trade = true`, sets `get_tree().paused = true` (same pattern as `_show_next_upgrade_choice`).
4. Player shows the `TradePanel` (a `PROCESS_MODE_WHEN_PAUSED` CanvasLayer, like `LevelUpPanel`) with the 3 pre-validated offers + Leave; focus grabs the first enabled option.
5a. **Pick** → spend → buff → `trade_completed` → demon tide → unpause (full ordering in Formula/Detailed below). Stall → SPENT.
5b. **Decline** (Leave button or `body_exited`) → hide panel, unpause, clear `_is_in_trade`, stall → AVAILABLE (re-enterable until linger expires).
6. StageDirector receives `trade_completed`, applies the demon-tide penalty.

### Spend → Buff → Penalty Ordering (synchronous, while paused)

```
A. Re-validate affordability + buff stack-cap (panel was open; defensive re-check)
   → if now invalid / dead / stage-ended: abort, close, unpause, stall→EXPIRED, no side effects
B. Spend resource:  HP: current_hp = maxf(current_hp - cost, 1.0); emit health_changed
                    XP: current_xp = maxf(current_xp - cost, 0.0); emit experience_changed (no level-up)
C. Apply buff (player._apply_upgrade(buff_id) or direct field mutation); emit upgrade_applied
D. Stall emits trade_completed(...)
E. StageDirector spawns demon-tide burst (StageDirector guards _is_stage_failed/_is_stage_cleared first)
F. Unpause: get_tree().paused = _was_tree_paused_before_trade; clear _is_in_trade
```
Buff applies (C) before unpause (F) so the player's improved stats are live when the tide arrives.

### Interactions with Other Systems

| System | Interaction |
|---|---|
| **Player** | Owns `get_tree().paused`, `_is_in_trade` flag, resource fields, buff application via `_apply_upgrade`. Trade panel reuses the level-up pause/choice pattern. |
| **Level Up & Upgrade Pool** | Trade panel and level-up panel share the pause token → mutually exclusive (`_is_in_trade` / `_is_selecting_upgrade` guards). Trade buffs respect the **D-B2 `_upgrade_pick_count` stack caps** — a capped buff is excluded/disabled, never silently no-op'd for full cost. |
| **Combat** | Blood Pact damage buff must keep the weapon's total source multiplier **≤ 5×** (Core Rule). Applied to base damage only (Formula 1). |
| **Stage Director** | Owns stall spawning + demon-tide penalty; suppresses stalls during boss phase. Demon tide stacks additively with any active Demon Seal pressure on the EnemySpawner. |
| **Demon Seal** | Sibling risk/reward system; both can be active simultaneously in Stage 2. Pressure effects stack on the spawner (already the designed Stage 2 model). |
| **Enemy Spawner** | Demon-tide burst spawns through the existing spawner; tide enemies obey the aggregate **4-attacker contact ceiling** (enforced player-side), so a 6-enemy burst still only lets 4 damage at once. |
| **Run State** | Stage 2 is reached sequentially after clearing Stage 1; build/level/HP carry over → trades are tuned for a **mid-game** entry build (~L8-12), not a fresh start. |

## Formulas

### Formula 1 — Blood Pact damage buff (ceiling-safe)

`weapon_damage_after_pact = stacked_weapon_damage + (base_weapon_damage × 0.08 × blood_pact_stacks)`

| Variable | Type | Range | Description |
|---|---|---|---|
| `base_weapon_damage` | float | 8.0 (v0.4 weapons) | The weapon's base damage before upgrades |
| `stacked_weapon_damage` | float | 8–38 | Damage after D-B2-capped upgrades (max +30 from 3 damage stacks) |
| `blood_pact_stacks` | int | 0–3 | Number of Blood Pacts taken this run |

**Output Range:** at the worst case (max upgrades + 3 pacts): `38 + (8 × 0.08 × 3) = 38 + 1.92 = 39.92`. As a multiplier over base: `39.92 / 8 = 4.99×` — **just under the Combat 5× ceiling**.
**Example:** base-8 weapon, 1 damage upgrade (+10 → 18), 2 Blood Pacts: `18 + (8 × 0.08 × 2) = 18 + 1.28 = 19.28`.
**⚠️ Ceiling guard:** apply the +8% to **base damage only**, not to the stacked value. If a future change applies it to stacked damage, the ceiling breaks — recommend a runtime `push_error()` assertion if any weapon's effective multiplier exceeds 5.0× after a trade (see Open Questions OQ-1).

### Formula 2 — Blood Pact HP cost escalation

`blood_pact_hp_cost(n) = [15, 20, 30, 45][n]`  where `n` = 0-indexed trade number this run (clamped to last entry).

**Output Range:** 15–45 HP. Total for 3 pacts (the stack cap): `15 + 20 + 30 = 65 HP`. On base 100 HP this leaves 35 — survivable but punishing; reaching 3 pacts effectively requires HP upgrades. **Floor:** spend is clamped so `current_hp ≥ 1`, and the offer is locked entirely when `current_hp ≤ 20`.

### Formula 3 — Soul Codex XP cost escalation

`soul_codex_xp_cost(n) = [60, 80, 110, 150][n]`  where `n` = 0-indexed trade number this run.

**Output Range:** 60–150 XP. Calibrated against the Demon Seal reward (48 XP) — a Soul Codex costs slightly more than a Seal pays, reflecting the direct build power of a weapon unlock. At mid-game (~L10, threshold ~358 XP) 60 XP ≈ 17% of a level; by trade 4, 150 XP feels like "almost a level."

### Formula 4 — Demon-tide penalty intensity per trade

`demon_tide(trade_count)`:

| trade_count (cumulative) | Burst | Spawn-interval modifier | Elites added |
|---|---|---|---|
| 1 | 6 normals (current wave pool) | ×0.75 for 12s | 0 |
| 2 | 6 normals | ×0.75 for 12s | +1 Shanxiao Elite |
| 3 | 6 normals | ×0.75 for 12s | +2 Shanxiao Elites |
| 4 | 6 normals | ×0.65 for 20s | +2 Shanxiao Elites |

**Calibration:** anchored to Demon Seal pressure (×0.65 interval + 6 max enemies for 8s). The burst is *shape-different* (one-shot spike vs sustained). The 4-attacker contact ceiling guarantees even a 6+ enemy burst cannot instakill (theoretical 4 × ~16 DPS, throttled by `damage_interval` → ~48 damage over ~2s → a 55 HP player survives at ~7 HP). **Playtest flag:** the Trade-2 Elite may be too harsh at Stage 2 entry DPS (see OQ-3).

## Edge Cases

- **If the player dies while the trade panel is open**: tree is paused so enemies can't damage them; only a script path could kill. Step A checks `player._is_dead` → if true, close panel, unpause, stall → EXPIRED, no spend / no buff / no tide.
- **If the boss dies (stage clears) while the panel is open**: signals still fire while paused; `_on_boss_died` sets `_is_stage_cleared`. Step A detects it → close panel, unpause (lets the victory screen proceed), stall → EXPIRED, no side effects.
- **If the player triggers a stall while a previous trade's demon tide is still active**: permitted by design — no "active tide" flag is tracked; the new burst stacks on top. Linger timers make back-to-back trading a deliberate high-risk choice.
- **If two stall zones overlap and `body_entered` fires for both on one frame**: the `_is_in_trade` flag gates the second (step-1 guard rejects it). When the first trade resolves and clears `_is_in_trade`, the player runs `_check_overlapping_stalls()` (queries `get_overlapping_areas()` filtered to group `trade_stall` + state AVAILABLE) and opens the next — analogous to `_pending_upgrade_choices` queuing.
- **If an XP-cost offer is selected with insufficient XP**: impossible — the offer is `disabled` during validation (`cost > current_xp`). XP subtraction is `maxf(current_xp - cost, 0.0)` and never triggers a level-up (level-ups come only from `gain_experience` additions).
- **If a Blood Pact would reduce HP to ≤ 0**: impossible — offer locked when `current_hp ≤ 20`; spend floored to `current_hp ≥ 1`.
- **If a buff's D-B2 stack cap is reached between stall spawn and panel open** (e.g. a level-up during the AVAILABLE window filled it): step A re-validates the cap; a capped buff is treated as unaffordable (disabled), preventing a full-cost no-op trade.
- **If all 3 offers are unaffordable/capped**: panel opens with all 3 disabled; the player can only press Leave. (Economy tuning aims to make total lockout rare.)
- **If a Soul Codex "+1 projectile" targets a weapon already at the projectile stack cap (D-B2 = 3)**: fall back to an alternate offer or an XP refund (resolution pending — OQ-4).

## Dependencies

| Dependency | Type | Interface |
|---|---|---|
| **Player** (C-04) | Hard Bidirectional | Owns pause, `_is_in_trade`, resource fields, `_apply_upgrade`, `health_changed`/`experience_changed`/`upgrade_applied` signals |
| **Level Up & Upgrade Pool** (FT-13) | Hard Bidirectional | Shared pause token (mutual exclusion); shared D-B2 `_upgrade_pick_count` stack caps |
| **Stage Director** (FT-10) | Hard Bidirectional | Owns stall spawning + demon-tide penalty; suppresses during boss phase |
| **Combat** (C-06) | Hard | Blood Pact buff must respect the 5× source-modifier ceiling |
| **Enemy Spawner** (FT-09) | Hard | Demon-tide burst spawns via `spawn_enemy_burst` / `spawn_elite_at`; obeys 4-attacker ceiling |
| **Demon Seal** (FT-16) | Soft (sibling) | Coexists in Stage 2; pressure stacks on spawner |
| **Run State** (C-03) | Hard | Sequential stage progression; build carryover sets mid-game tuning context |
| **Godot Area2D** | Hard (engine) | Stall zone collision detection |

> Bidirectional note: Player, Level Up Pool, and Stage Director GDDs must add "depended on by Ghost Market Trade" when this GDD is approved.

## Tuning Knobs

| Knob | Default | Safe Range | Effect / What breaks at extremes |
|---|---|---|---|
| `stall_count_per_run` | 4 | 2–6 | <3 trivial; >5 collapses scarcity → degenerate accumulation |
| `stall_spawn_times` | [30, 90, 150, 210]s | within stage_duration | too early = no build to spend; too late = no time to benefit |
| `stall_linger_seconds` | 25 | 15–40 | too long = safe parking; too short = unfair miss |
| `blood_pact_hp_costs` | [15,20,30,45] | per-step ≥ 10 | too cheap = glass-cannon spam; too dear = never used |
| `blood_pact_damage_per_stack` | 0.08 (+8%) | 0.05–0.10 | >0.10 risks 5× ceiling breach (Formula 1) |
| `blood_pact_max_stacks` | 3 | 2–3 | >3 breaches ceiling |
| `blood_pact_hp_lock_floor` | 20 | 15–30 | below 15 enables near-suicide trades |
| `soul_codex_xp_costs` | [60,80,110,150] | ≥ Demon Seal reward (48) | too cheap trivializes weapon unlock pacing |
| `yin_debt_speed_bonus` | 0.20 (+20%) | 0.10–0.30 | too high trivializes the debt wave by kiting |
| `yin_debt_speed_duration` | 60s | 30–75 | too long outruns the debt; too short = no benefit |
| `demon_tide_base_count` | 6 | 4–10 | calibrated to Demon Seal +6 anchor |
| `demon_tide_interval_mult` | 0.75 (0.65 @ trade 4) | 0.6–0.85 | lower = more lethal |
| `demon_tide_window_seconds` | 12 (20 @ trade 4) | 8–24 | survival-window length |

## Visual / Audio Requirements

> Brief at GDD stage; full spec via `/asset-spec system:ghost-market-trade` after the art bible covers Stage 2.

- **Stall visual**: a spectral merchant stall — hanging ghost-lantern, tattered banner, faint 朱砂/青铜 palette (consistent with the established VFX palette). Idle: slow pulse glow. AVAILABLE→player-near: banner unfurls. SPENT: brief "sold" stamp + dissolve. EXPIRED: silent fade.
- **Trade panel**: darker, more ominous theme than the level-up panel — fog border, archaic-cant merchant line per offer.
- **"Angered market" cue**: a distinct audio sting + screen-edge red pulse the instant a trade resolves, telegraphing the incoming tide (Combat Feedback + Audio own the actual sting/visual; this system fires the trigger).
- **Demon-tide telegraph**: brief spawn-direction indicator so the burst isn't a blind ambush (consistent with fair-pressure Pillar 1).

📌 **Asset Spec** — after the art bible covers Stage 2, run `/asset-spec system:ghost-market-trade`.
📌 **UX Flag** — the Trade panel is a new screen. In Pre-Production run `/ux-design` for `design/ux/trade-panel.md` before writing trade stories; stories should cite that UX spec, not this GDD.

## Acceptance Criteria

- **AC-01** **GIVEN** Stage 2 is running and elapsed_time reaches a stall spawn time, **WHEN** the warm-up elapses, **THEN** a TradeStall transitions DORMANT→AVAILABLE and becomes visible + collision-enabled exactly once.
- **AC-02** **GIVEN** an AVAILABLE stall, **WHEN** the player body enters and all step-1 guards pass, **THEN** the tree pauses, `_is_in_trade=true`, and the TradePanel shows exactly 3 offers + Leave.
- **AC-03** **GIVEN** the panel is open with a Blood Pact offer and `current_hp = 50`, **WHEN** the player selects it (cost 15), **THEN** `current_hp = 35`, weapon base damage gains +8%, `upgrade_applied` emits, and the tree unpauses.
- **AC-04** **GIVEN** `current_hp = 20`, **WHEN** a stall panel opens, **THEN** the Blood Pact offer is `disabled` (HP-lock floor) and cannot be selected.
- **AC-05** **GIVEN** a Soul Codex offer costing 60 XP and `current_xp = 40`, **WHEN** the panel opens, **THEN** the offer is `disabled`; selecting it is impossible.
- **AC-06** **GIVEN** a completed trade (trade_count=1), **WHEN** `trade_completed` fires, **THEN** StageDirector spawns 6 normal enemies and applies ×0.75 spawn interval for 12s, and (trade_count=2) additionally spawns 1 Shanxiao Elite.
- **AC-07** **GIVEN** 3 Blood Pacts already taken, **WHEN** a new stall opens, **THEN** Blood Pact does not appear among the offers (stack cap = 3).
- **AC-08** **GIVEN** max upgrades + 3 Blood Pacts, **WHEN** weapon damage is computed, **THEN** the effective multiplier over base is ≤ 5.0× (Formula 1 ceiling).
- **AC-09** **GIVEN** the player dies or the boss dies while a trade panel is open, **WHEN** the player attempts to confirm a trade, **THEN** no resource is spent, no buff applies, no demon tide spawns, and the panel closes + unpauses.
- **AC-10** **GIVEN** the boss has spawned, **WHEN** any stall is AVAILABLE, **THEN** it transitions to EXPIRED and no new stalls spawn for the rest of the run.
- **AC-11** **GIVEN** a stall is AVAILABLE and the player never enters it, **WHEN** 25s elapse, **THEN** the stall transitions to EXPIRED and `queue_free()`s, emitting `stall_expired`.
- **AC-12** **GIVEN** the player declines a stall (Leave), **WHEN** the panel closes, **THEN** the tree unpauses, `_is_in_trade=false`, and the stall returns to AVAILABLE (re-enterable until linger).

## Open Questions

- **OQ-1** (Blood Pact ceiling assertion): the 4.99× headroom is tight. Add a runtime `push_error()` assert if any weapon's effective multiplier exceeds 5.0× after a trade? **Owner**: systems-designer + lead-programmer. **Target**: implementation.
- **OQ-2** (current-HP vs max-HP cost): this design spends *current* HP (recoverable only via max_hp upgrades, with a floor). An alternative is *max-HP reduction* for a more permanent glass-cannon "blood pact" fantasy. **Resolution**: playtest both; current-HP chosen as the safer default. **Owner**: game-designer.
- **OQ-3** (Trade-2 Elite difficulty): a Shanxiao Elite (110 HP / 30 dmg) at the 2nd trade may be oppressive for a Stage-2-entry build. If playtest survival < 50% on trade 2, move the first Elite to trade 3. **Owner**: economy-designer + playtest.
- **OQ-4** (Soul Codex projectile fallback): if "+1 projectile" targets a weapon already at the projectile stack cap (D-B2 = 3), define the fallback (alternate upgrade vs XP refund) before implementation. **Owner**: systems-designer.
- **OQ-5** (Yin Debt duration): 60s speed buff may outrun the debt wave (trivializing it) or expire before the next stall. Start at 45s if kiting proves too strong. **Owner**: playtest.

## Revision Log

| Rev | Date | Trigger | Summary |
|---|---|---|---|
| 0 | 2026-05-29 | Initial design (Stage 2 content) | User-approved concept; economy by economy-designer (4 stalls, 3 trades, escalating cost, demon-tide curve, guardrails); mechanics by systems-designer (stall state machine, panel flow, ordering, 9 edge cases). 12 ACs, 5 formulas, 13 tuning knobs, 5 OQs. Pending /design-review. |
