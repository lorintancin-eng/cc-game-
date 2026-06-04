# Ghost Market Trade (鬼市交易)

> **Status**: revision-2 (2026-05-30) — **synced to implementation**: trade is now a calm INTERLUDE between combat stages (not a Stage-2 combat mechanic). revision-1 (2026-05-29) remains the design-intent record; this revision documents the as-built reality and marks every divergence.
> **Author**: claude (concept approved by user; economy by economy-designer, mechanics by systems-designer; revision-2 implementation-sync by claude)
> **Last Updated**: 2026-05-30
> **Implements Pillar**: Pillar 2 (自动战斗与有意义的构筑选择) primary; Pillar 1 (清晰的生存压力) secondary
> **Layer**: Gameplay (Feature) | **Priority**: Vertical Slice (Ghost Market content)
> **Introduced for**: 幽都鬼市 / Netherworld Ghost Market (originally Stage 2; now the trade interludes interleaved through the run)

> **⚠️ 实现同步说明 (2026-05-30)**：本系统已落地，但落地形态与 revision-1 设计有结构性差异。最大的变化：**鬼市交易从「Stage 2 战斗关里的摊位机制」改成了「战斗关之间的平静交易间隙 (trade interlude)」**。幽都 (Stage 2) 现在是纯战斗关（判官 Boss + 5 个鬼市敌人），交易摊位搬到了独立的 `is_interlude` 关卡（`GhostMarketInterludeConfig`）。三个交易档位的 buff 也做了 MVP 简化。本文档保留 revision-1 的完整设计意图作为参照，并在每处分歧用 **[已实现 / AS BUILT]** 与 **[简化 vs revision-1]** 明确标注，使偏差被记录而非被隐藏。架构背景见 ADR-0004 的 2026-05-30 implementation-sync 注记。

## Overview

The Ghost Market Trade is the run's signature build-decision risk/reward system and the offensive counterpart to the Demon Seal. **[AS BUILT 2026-05-30]** It now plays out in **calm trade interludes** woven between the combat stages of the 7-stage run (荒山 → **鬼市间隙** → 幽都 → **鬼市间隙** → 荒山·再临 → **鬼市间隙** → 幽都·深渊). An interlude is a short (~25s) room with **no boss and no passive enemy spawning**; three **ghost merchant stalls (鬼商摊)** — `Area2D` zones — appear early and the player roams freely between them. Standing in a stall's zone for ~1s opens a **3-choice trade panel** (pausing gameplay) where the player spends a run resource — **permanent max-HP** or **修为 (XP)** — for a power buff. Every completed trade **"angers the market"**, summoning a **demon tide** of Ghost Market enemies into the otherwise-empty room (the tide IS the threat — there is no other pressure). The panel shows each offer's demon tide so the gamble is always informed. Where the Demon Seal is *defensive and time-based*, the Trade is *offensive and permanent-cost* — a Faustian exchange of long-term survivability for immediate power.

> **[Divergence from revision-1]** Revision-1 placed the stalls *inside* the Stage-2 combat stage (alongside its waves, the Judge boss, and the 怪浪 swarm), so a trade's tide stacked on top of ongoing combat. The shipped design pulls trading into its own calm interlude: the buffs and costs are unchanged in spirit, but the *context* is a quiet room whose only danger is the tide you choose to summon. This makes the trade a clean, deliberate decision beat between combat bursts rather than a mid-fight gamble.

## Player Fantasy

**The forbidden bargain.** Standing before a spectral stall in the rolling fog of the ghost market, the cultivator weighs a Faustian deal: carve off your own maximum lifeblood — permanently — for power *right now*, knowing the market's wrath will descend moments after the deal is struck. The intended emotion is **tense, transgressive, gambler's adrenaline** — distinct from the level-up panel's clean optimism. A level-up is a gift; a trade is a *price*. Each stall is a fork: walk past and stay safe, or pay in blood/soul and gamble that your new strength outpaces the tide you just summoned. Yin Debt earns its name: the speed is yours immediately, but the debt arrives ~13.5 seconds later, in a calm room you must now survive alone. This is the most direct expression of Pillar 2 — construction choices with genuine, permanent stakes.

**[AS BUILT 2026-05-30]** The interlude framing sharpens this fantasy: the ghost market is now a literal *place you enter between battles* — the combat falls silent, the fog rolls in, and three merchants wait. The room is calm **until you deal**. Choosing to trade is choosing to break the calm; the tide that answers is a pressure entirely of your own making. Walking past all three stalls and letting the interlude auto-advance is the genuinely safe (if power-starved) line — the market only "remembers" via a light `market_unease` nudge.

Tone language (per `design/narrative/01_STORY_BIBLE.md` 文白夹杂 style): the stalls speak in cold, archaic merchant cant — "以血换力，可愿？" ("Blood for power — do you consent?"). Dark 志怪, never whimsical.

## Detailed Rules

> **[AS BUILT 2026-05-30]** The rules below are restated to match the shipped
> interlude design. The original revision-1 rules (Stage-2 combat-stage stalls,
> 4 per run at 90/150/210/255s, etc.) are preserved verbatim in the **revision-1
> rules (superseded)** sub-block immediately after, so the design history is intact.

### Core Rules (as built)

1. **Trade happens in calm interludes, not a combat stage.** The Ghost Market is a
   `StageConfig` with `is_interlude = true` (`GhostMarketInterludeConfig`), inserted
   between combat stages by the RunDirector. An interlude has **no boss, no Demon
   Seal, and no passive enemy spawning** (`EnemySpawner.set_spawning_enabled(false)`).
   It lasts `stage_duration ≈ 25s` and **auto-advances** to the next combat stage
   (`_end_interlude`) — there is no boss to kill. The room is empty and quiet until
   a trade summons a tide.
2. **Three stalls per interlude, spawned early.** `StageDirector._check_trade_stall_spawns`
   spawns **3** ghost merchant stalls at `stall_spawn_times = [2.0, 6.0, 10.0]`s, each
   lingering `stall_linger_seconds = 20s` — all reachable inside the calm room.
   Spawn positions are offset from the player (Demon-Seal-style ring).
3. **One trade per stall.** A stall offers exactly one transaction. After a completed
   trade it transitions to `SPENT` and `queue_free()`s. An ignored stall expires after
   its linger and is removed silently; each expired-without-trade stall adds +1 to
   `market_unease` (Rule 8).
4. **Three offers per stall.** When opened, the panel presents the **3 fixed archetypes**
   (Blood Pact / Soul Codex / Yin Debt — see below) plus a **Leave** button.
   **[Divergence from revision-1]** The three are always the same three (not sampled
   from a larger pool). Unaffordable / stack-capped / empty-pool offers are shown
   **disabled**, never hidden. **Each offer card shows the demon-tide it will summon**
   (e.g. "潮汐 5怪" or "潮汐 5怪 +1精英"), so the gamble is always informed (Pillar 1).
5. **Ownership split** (mirrors Demon Seal): `TradeStall` (Area2D) owns its state
   machine, zone collision, and the in-zone hold. `StageDirector` owns *when/where/
   how-many* stalls spawn, builds the offers (`_build_trade_offers`), drives the
   `TradePanel`, applies the buff via the Player, and spawns the demon tide on a
   completed trade.
6. **Every completed trade angers the market — as a sustained tide, not a single burst.**
   **[AS BUILT — replaces the revision-1 "spawn-interval multiplier" model]** Because
   an interlude has no passive spawning, a spawn-interval multiplier would be moot.
   Instead each completed trade fires `spawn_demon_tide`: an **initial burst** of
   Ghost Market enemies + Impermanence elites, **plus two smaller follow-up bursts**
   scheduled at 0.45× and 0.85× of the tide window (each ≈ `max(normal/2, 2)` normals).
   The result is rolling pressure across the window rather than one spike. Yin Debt's
   tide is **delayed ≈13.5s** (the "debt"); Blood Pact / Soul Codex tides fire
   immediately on unpause.
7. **Death / stage-end guard** (mirrors the Demon Seal OQ-4 fix): trade resolution
   and every tide burst (immediate, follow-up, and delayed) are skipped if
   `player._is_dead`, `_is_stage_failed`, or `_is_stage_cleared` are set. A late tide
   can never spawn enemies onto a corpse or after the interlude has advanced.
8. **Non-engagement cost (market unease).** Each stall that expires **without** a
   trade increments a run-scoped `market_unease` by 1 (`clamp_market_unease`, capped
   at **3**). The *next* tide adds at most **+1 normal enemy** (`MARKET_UNEASE_TIDE_BONUS`).
   Ignoring all stalls is not strictly free — the market remembers — but the pressure
   is light, not punitive. **[Note vs revision-1]** revision-1 framed this as a
   walk-past FOMO cost; as built it is keyed to stall *expiry*, so deliberately
   declining (Leave) without letting a stall expire does not feed unease.

> **[Difficulty-escalation context, 2026-05-30]** Interludes themselves do **not**
> scale with `difficulty_multiplier` (they are calm by design). Escalation lives in
> the combat stages that bracket them: the remix combat stages (荒山·再临 ×1.4,
> 幽都·深渊 ×1.7) raise wave volume and enemy/boss stats (ADR-0004). So a later
> interlude is reached by a stronger build that just survived a harder fight — the
> trade decisions stay constant, but their stakes rise against the escalating run.

<details>
<summary><b>revision-1 Core Rules (superseded 2026-05-30 — design-intent record)</b></summary>

1. **Stall spawning (StageDirector owns).** Stage 2 spawns **4 ghost merchant stalls** per run at approximately **1:30, 2:30, 3:30, 4:15** (seconds 90, 150, 210, 255 — see Tuning Knobs). This gives the player 90 seconds to orient among the 5 new Stage-2 enemies before the first trade opportunity. Spawn positions are offset from the player (similar to Demon Seal's spawn ring). Stalls do **not** spawn during the boss phase (`_is_boss_spawned == true` suppresses spawning; any `AVAILABLE` stall is force-expired when the boss spawns).
2. **One trade per stall.** A stall offers exactly one trade transaction. After a trade is completed it transitions to `SPENT` and is removed. A stall the player ignores expires after a **25-second** linger and is removed silently. Each expired stall that was never traded adds +1 to `market_unease` (see Rule 8).
3. **Three offers per stall.** When opened, the panel presents 3 offers sampled from the trade-archetype pool (Blood Pact / Soul Codex / Yin Debt — see below) plus a **Leave** button. Unaffordable or stack-capped offers are shown **disabled**, never hidden, so the player always sees what was on offer. **Each offer card displays the demon-tide it will summon** (tier label, enemy count, and elite flag — e.g. "Tide: 5 normal enemies" or "Tide: 5 normals + 1 Impermanence Elite"), so the gamble is always informed (Pillar 1).
4. **Ownership split** (mirrors Demon Seal): `TradeStall` (Area2D) owns its own state machine, zone collision, offer list, and self-removal. `StageDirector` owns *when/where/how-many* stalls spawn and *applies the demon-tide penalty* on `trade_completed`.
5. **Every completed trade angers the market.** After a trade resolves, StageDirector spawns a **demon-tide burst** whose size escalates with the number of trades completed this run (see Demon-Tide table + Formula 4). Yin Debt's tide is **delayed ~12-15s** with an on-screen warning when it fires (see below).
6. **Blood Pact cost is permanent max-HP reduction.** A Blood Pact permanently reduces `player.max_hp` by **15 / 20 / 25** (by global trade number `n`, clamped to last). `current_hp` is immediately clamped to not exceed the new `max_hp`. The offer is **locked (disabled)** when accepting it would reduce `max_hp` below the hard floor of **40**. The max-HP reduction persists across the Stage 1→2 transition (it is the same Player node per ADR-0004). There is no current-HP floor guard for Blood Pact — the permanent reduction is the cost.
7. **Death / stage-end guard** (mirrors the Demon Seal OQ-4 fix): trade resolution and demon-tide spawning are skipped if `player._is_dead`, `_is_stage_failed`, or `_is_stage_cleared` are set. A late trade can never spawn enemies onto a corpse or a victory screen.
8. **Non-engagement cost (market unease).** Each stall that expires **without** a trade increments a run-scoped counter `market_unease` by 1. The demon-tide tier for the *next* stall opened is elevated by `market_unease` (capped at +1 tier — equivalent to "add 1 extra normal enemy to the burst"). Ignoring all stalls is not strictly free: the market remembers. This is a light FOMO pressure, not a severe punishment (see Tuning Knobs).

</details>

### In-Zone Hold Entry (Pillar 2 — "movement is the only input")

The trade panel does **not** open on first contact with a stall zone. Instead:

- While the player is inside a stall's `Area2D` and `state == AVAILABLE`, a **fill indicator** (a brief ~1.0s charge bar) begins filling.
- **[AS BUILT — presence-based, NOT "stand perfectly still"]** The fill accumulates as long as the player simply **stays inside the zone** (`accumulate_hold(delta, moved=false)`). Once an uninterrupted in-zone hold reaches `stall_entry_hold_seconds` (default **1.0s**), the panel opens. **Leaving the zone** resets the fill to 0 (`reset_hold`); standing-but-jostling does **not** reset it.
- **[Divergence from revision-1 — and why]** revision-1 required the player to hold *perfectly still* (position delta < 4 px/frame) for 1s. In practice the player and enemies share a collision layer and physically push each other, so during a tide a swarm makes strict stillness unachievable — the stall could never be opened. The shipped rule mirrors the DemonSeal's proven presence-based hold: stay in the zone for ~1s. This keeps "movement is the only input" (no interact key) while being swarm-push-proof.
- The `moved`-resets-fill path still exists in `TradeStallState.accumulate_hold` (the state machine supports it), but the live `TradeStall` node passes `moved = false` — only zone *exit* resets the fill. `stall_entry_threshold_px` is therefore not wired in the shipped build (kept as a dormant knob).
- Re-entering the zone after leaving **resets** the hold (no saved progress — anti-exploit, consistent with the reset-on-exit rule).

### Decision Moment — Timed Pause With Visible Fuse

**[AS BUILT — `trade_panel.gd`]**

- The panel pauses the scene tree (same as the level-up panel); it is a `CanvasLayer` with `PROCESS_MODE_WHEN_PAUSED`. The `TradePanel` is a **dumb presenter** — `StageDirector` builds the offers and applies the chosen buff; the panel only shows offers + fuse and emits the choice (`offer_chosen` / `declined`).
- A **burning-fuse timer** (`FUSE_SECONDS = 5.0`, shown as "引线 %.1fs") counts down while paused. On expiry the panel auto-closes — treated as a **Decline** (no trade, no cost, no tide).
- **Destructive trade confirm (Blood Pact) = lightweight double-press.** **[Divergence from revision-1]** Instead of a separate "以血换力 — 确认?" modal, the first press on the Blood Pact card **arms** it (the card relabels to "⚠ 再按一次以确认 · 以血换力"); a second press commits. Non-destructive offers commit on the first press. The fuse keeps running during the armed state. Same safety intent (no accidental permanent-HP spend), lighter UI.

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

**[AS BUILT] Signals emitted by `TradeStall`:**
```gdscript
signal trade_requested(stall: TradeStall)   # in-zone hold completed → open the panel
signal stall_expired(stall: TradeStall)     # linger elapsed / boss-or-interlude-end force-expire
```
**[Divergence from revision-1]** The richer `trade_opened` / `trade_completed(offer_id, resource_type, resource_cost)` / `trade_declined` signal set was not needed: the StageDirector already holds the active stall + offers, so the stall only signals "open the panel" (`trade_requested`) and "I expired" (`stall_expired`). StageDirector drives the terminal transitions directly via the stall's methods — `mark_spent()`, `return_to_available()`, `abort_trade()`, `notify_boss_spawned()` — and applies the buff + tide itself (`_on_trade_offer_chosen` → `Player.execute_*` → `spawn_demon_tide`). The decline/spend/abort *state-machine* transitions (`on_trade_confirmed` / `on_decline` / `on_trade_aborted` / `on_boss_spawned`) live in the tested `TradeStallState`.

### The Three Trade Archetypes

**[AS BUILT 2026-05-30 — `player.gd` `execute_blood_pact` / `execute_soul_codex` / `execute_yin_debt` + `trade_formulas.gd`]**

| Trade | Cost (by global trade # `n` — see Formulas 2/3) | Benefit (as implemented) | Cap / Guardrail |
|---|---|---|---|
| **血契 Blood Pact** | **Permanent max-HP reduction** (15 / 20 / 25 by `n`, clamped) | **×1.15 to each OWNED weapon's current damage, per stack** (multiplies the weapon's live `damage` field directly). Permanent for the run. | Max **3 stacks** (`BLOOD_PACT_MAX_STACKS`); **locked when `max_hp − cost < 40`** (`BLOOD_PACT_HP_FLOOR`). `current_hp` clamped to the new max. |
| **魂典 Soul Codex** | Spend **XP** (60 / 80 / 110 / 150 by `n`, clamped) — deducted from the current-XP bar (never de-levels, never below 0) | **One upgrade picked from the level-up pool** (a weapon unlock or a weapon boost), pre-resolved at panel-open via `Player.pick_trade_upgrade()` and shown on the card; applied via the normal `_apply_upgrade` path on pick. | Locked when `current_xp < cost`; respects the D-B2 `_upgrade_pick_count` caps; **empty pool ⇒ no offer** (card shows "（暂无可习）", disabled) — bad-luck protection. |
| **阴债 Yin Debt** | **Free now** — demon-tide debt paid ≈13.5s later | **+20% move speed for 45s** (`apply_yin_debt_speed(0.2, 45.0)`), held in a field SEPARATE from the transform speed multiplier so 七十二变 and Yin Debt never clash. | Tide is delayed (not instant); non-damage buff (no source-modifier ceiling interaction). A fresh Yin Debt overwrites (refreshes, not stacks) any active one. |

> **[Simplifications vs revision-1 — documented, not hidden]**
> - **Blood Pact**: revision-1's Formula 1 added `base_weapon_damage × 0.15 × stacks` *additively on top of the base* and clamped to a `base × 5.0` source-modifier ceiling. The shipped MVP instead multiplies each owned weapon's *current* `damage` by `1.15` per stack — simpler, applied at trade time, and not (yet) routed through the `minf(…, base × 5.0)` structural clamp. `TradeFormulas.weapon_damage_after_pact` (the ceiling-safe additive formula) exists and is unit-tested, but `Player.execute_blood_pact` does not call it — the additive-on-base + ceiling model remains the intended later refinement. **Implication**: with multiplicative stacking on top of level-up damage upgrades, the 5× ceiling is currently *not enforced* on the Blood-Pact path; flag for a balance/ceiling pass.
> - **Soul Codex**: revision-1 specified a *specific* outcome ("unlock Flying Sword" OR "+1 Talisman projectile") chosen at stall-generation. As built it generalizes to **one pick from the existing level-up upgrade pool** (which already includes weapon unlocks and per-weapon boosts), reusing `_get_random_upgrade_options` (D-B2 caps + bad-luck filter). Functionally equivalent build power; the card simply shows whatever the pool surfaced.
> - **Yin Debt**: matches revision-1 (+20% / 45s, delayed debt). The only refinement: the bonus lives in a dedicated `_yin_debt_speed_bonus` field, multiplicative with the transform speed multiplier — `velocity = move_speed × _speed_multiplier × (1 + _yin_debt_speed_bonus)`.

<details>
<summary><b>revision-1 archetype table (superseded 2026-05-30)</b></summary>

| Trade | Cost (by global trade # `n`) | Benefit | Cap / Guardrail |
|---|---|---|---|
| **血契 Blood Pact** | Permanent max-HP reduction (15 / 20 / 25 by `n`, clamped) | +15% weapon damage per stack (applied to base damage only — see Formula 1), permanent for the run | Max 3 stacks; locked when `max_hp - cost` would drop below 40 |
| **魂典 Soul Codex** | Spend XP (60 / 80 / 110 / 150 by `n`, clamped) — deducted from current XP bar (never de-levels) | Unlock a specific locked weapon OR +1 projectile to a specific owned weapon — resolved at stall-generation time | Locked when `current_xp < cost`; respects D-B2 stack caps; bad-luck protection if all weapons maxed |
| **阴债 Yin Debt** | Free now — demon-tide debt paid ~12-15s later | +20% move speed for 45s | Tide delayed; on-screen warning; non-damage buff |

</details>

### 五行灵珠 (Phase Bead) Stall — v0.5

> **[ADDITIVE 2026-06-02 — propagated from `elements-five-phases.md` + `merit-system.md`]**
> The Five Phases Synergy System adds a **fourth trade archetype** to the Ghost Market:
> the **五行灵珠 (Phase Bead)**. This is purely additive — it joins the pool of
> archetypes a stall slot can present; it does **not** replace or alter the existing
> three (Blood Pact / Soul Codex / Yin Debt), nor add a 4th physical stall to a room.
> All values below are NEW; nothing above this subsection changes.

| Trade | Cost | Benefit | Cap / Guardrail |
|---|---|---|---|
| **五行灵珠 Phase Bead** | **40 XP flat** (`phase_bead_xp_cost = 40`, does NOT escalate with global trade `n`) — deducted from `current_xp` (never de-levels, never below 0) | **+1 to a specific Five Phases element count** in the player's element inventory, with **NO stat buff** — a pure combo-enabler that pushes a Five Phases synergy toward its threshold. The element offered is **random, weighted toward the player's WEAKEST element** (the one with the lowest current count). | Locked (disabled) when `current_xp < 40`. **Availability-gated**: only appears if **Merit System Node 7 (五行灵珠)** is unlocked (see below). |

- **Cost is flat, not escalating.** Unlike Blood Pact (Formula 2) and Soul Codex
  (Formula 3), the Phase Bead cost is a constant **40 XP** regardless of the global
  trade counter `n`. Registry / tuning key: `phase_bead_xp_cost = 40` (see Tuning Knobs).
- **Pure combo-enabler — no stat buff.** A Phase Bead grants **no** damage, speed, HP,
  or other stat change. Its only effect is **+1 to one Five Phases element count** in the
  player's element inventory (per `elements-five-phases.md`). Its value is entirely in
  advancing a Five Phases synergy threshold; it is worthless to a player ignoring the
  Five Phases system, and decisive to one chasing a synergy.
- **Element selection — weighted toward the weakest.** The offered element is chosen
  **randomly, weighted toward the player's WEAKEST element** (lowest current count), so a
  Phase Bead tends to shore up the element a build is short on rather than pile onto an
  already-strong one. The card displays the specific element it will grant (the Five
  Phases element icon — see *Element Tags on Existing Stalls* below).
- **Stall behavior — a normal stall.** A Phase Bead behaves as a **normal stall** in the
  shared SPENT/EXPIRED state machine (DORMANT → AVAILABLE → TRADING → SPENT). It uses the
  **same presence-based in-zone hold** as the other archetypes (stay in the zone for
  `stall_entry_hold_seconds ≈ 1.0s`; leaving resets the fill), the same fuse-timed panel,
  the same Leave / fuse decline paths, and the same linger / `market_unease`-on-expiry
  rule. It is **not** a destructive trade, so it commits on the **first press** (no
  Blood-Pact-style double-press confirm).
- **Tide behavior — NO demon tide.** Purchasing a Phase Bead does **NOT** anger the market
  — **no demon tide is summoned** (immediate, follow-up, or delayed). It is a **calm, costed
  trade** like Blood Pact / Soul Codex in spend-but-unlike-Yin-Debt in that it carries no
  tide debt at all. The XP cost is the entire price; the room stays quiet.
- **Availability gate — Merit Node 7.** The Phase Bead archetype **only appears if Merit
  System Node 7 (五行灵珠) is unlocked**. Until Node 7 is purchased it **never spawns** and
  is **never** one of a stall's candidate offers — the stall pool is the original three.
  Once Node 7 is unlocked it becomes eligible (subject to affordability and the
  weakest-element roll).
- **Stall count — joins the pool, does NOT add a 4th stall.** When available, the Phase
  Bead is **one of the candidate archetypes a stall slot can roll**, alongside Blood Pact /
  Soul Codex / Yin Debt. It does **not** add a 4th physical stall to the interlude
  (`stall_count_per_run` stays 3) — it joins the **archetype pool** that each stall's offer
  slots draw from. (See *Merit Node 12 — 4 Trade Options* below for how many offer slots a
  stall presents.)

### Element Tags on Existing Stalls — v0.5

> **[ADDITIVE 2026-06-02 — propagated from `elements-five-phases.md` §Integration with
> Ghost Market]** This is **display + targeting metadata only**. It does **not** change the
> existing Blood Pact / Soul Codex costs, buffs, caps, or any value above.

- **Blood Pact and Soul Codex stalls now display a Five Phases element icon** on their
  offer cards. This surfaces the Five Phases element each offer is associated with, so a
  player chasing a synergy can read it at a glance.
- **Blood Pact**: the displayed element **determines which weapon's damage buff applies** —
  i.e. the element tag is the targeting metadata that picks the buffed weapon (per
  `elements-five-phases.md`). The buff magnitude (`×1.15`/stack on the targeted weapon's
  live damage) and the permanent max-HP cost are **unchanged**; the element tag only
  selects which owned weapon receives the buff.
- **Soul Codex**: the card **shows the element of the offered upgrade** (the Five Phases
  element of the weapon unlock / boost `pick_trade_upgrade()` surfaced). This is purely
  informational; the upgrade itself and the XP cost are unchanged.
- **Phase Bead**: likewise shows the Five Phases element icon of the element it will grant
  (its display tag IS its effect target — the element whose count goes +1).

### Merit Node 12 — 4 Trade Options — v0.5

> **[ADDITIVE 2026-06-02 — propagated from `merit-system.md` Node 12 (鬼市信誉)]** This
> **appends** to the "Three offers per stall" rule (Detailed Rules Rule 4); it does **not**
> change the existing 3-offer default.

- **If Merit Node 12 (鬼市信誉) is purchased, each stall presents 4 archetype offers
  instead of 3** (+ Leave button). The **4th slot draws from the available archetype pool**
  (including the Phase Bead if Node 7 is **also** unlocked). Without Node 12 the stall
  presents the default **3** offers (+ Leave) exactly as specified in Rule 4.
- The 4th offer obeys the same rules as the other slots: unaffordable / stack-capped /
  empty-pool offers are shown **disabled, never hidden**, and each card shows the demon-tide
  it will summon (the Phase Bead card shows **no tide**, per its subsection above).

### Trigger and Panel Flow

**[AS BUILT]**

1. The player stands inside a stall's `Area2D`. `TradeStall._can_trade(player)` gates: `state == AVAILABLE` AND `not player._is_dead` AND `not player.is_in_trade()` AND `not player._is_selecting_upgrade`. (Stage-cleared/failed is re-checked by the StageDirector at `_on_trade_requested`.) If any fail, the hold does not progress.
2. The in-zone fill accumulates while the player stays in the zone (presence-based). Leaving resets it.
3. On a full ~1s hold the stall → TRADING and emits `trade_requested(self)`.
4. `StageDirector._on_trade_requested` records the active stall, builds the 3 offers (`_build_trade_offers`), calls `Player.begin_trade()` (saves `_was_tree_paused_before_trade`, sets `_is_in_trade = true`, pauses the tree), and calls `trade_panel.show_offers(...)`. The fuse starts.
5. `TradePanel` shows the 3 pre-validated offers + Leave + fuse; focus grabs the first enabled option (or Leave if all are locked).
6a. **Blood Pact selected** → first press arms the double-press confirm; second press emits `offer_chosen`. Stall → SPENT on success.
6b. **Non-destructive offer selected** → emits `offer_chosen` immediately. Stall → SPENT on success.
6c. **Decline** (Leave button OR fuse expires) → `declined` → `_on_trade_declined` returns the stall to AVAILABLE (same offers, linger continues), then `_close_trade` hides the panel and ends the trade.
7. `StageDirector._on_trade_offer_chosen` applies the buff via `Player.execute_*`, marks the stall SPENT, increments `_trade_count`, and spawns the tide (immediate for Blood Pact / Soul Codex; scheduled ≈13.5s for Yin Debt).

### Spend → Buff → Penalty Ordering (synchronous, while paused)

**[AS BUILT — `StageDirector._on_trade_offer_chosen` + `Player.execute_*`]**

```
A. Guard: if _is_stage_cleared / _is_stage_failed / player._is_dead → stall.abort_trade()
   (TRADING→EXPIRED), close trade, no spend / no buff / no tide.
B+C. Spend + apply buff together, inside the Player method (atomic per archetype):
     Blood Pact (execute_blood_pact): re-check is_blood_pact_locked → if locked, return false
        (stall returns to AVAILABLE); else max_hp -= cost, clamp current_hp, ×1.15 each owned
        weapon's damage per stack, emit health_changed + upgrade_applied.
     Soul Codex (execute_soul_codex): re-check affordability → spend XP (emit experience_changed),
        bump _upgrade_pick_count, _apply_upgrade(id), emit upgrade_applied.
     Yin Debt (execute_yin_debt): apply_yin_debt_speed(0.2, 45.0), emit upgrade_applied (free).
D. On success: stall.mark_spent() (→SPENT), _trade_count += 1.
E. Tide:
     Blood Pact / Soul Codex: spawn_demon_tide(_trade_count, _market_unease) immediately
        (initial burst + 2 scheduled follow-ups).
     Yin Debt: push a single delayed tide {remaining: 13.5, ...} onto _pending_tides.
F. _close_trade(): hide panel, Player.end_trade() (restores the pre-trade pause state),
   clear the active stall/offers.
```
The buff applies *before* the tide and before unpause, so the player's improved stats
are live when the tide arrives.

> **[Divergence from revision-1]** revision-1 kept spend (B), buff (C), and the
> `trade_completed` signal (D) as separate steps with a `tide_warning` signal at
> delay−2s for an on-screen "阴债将至" warning. As built, spend+buff are fused inside
> the per-archetype `Player.execute_*` method (which also re-validates), and the Yin
> Debt **warning signal is not yet wired** — the delayed tide simply fires after 13.5s.
> The 2s-lead HUD warning remains a TODO (see Open Questions).

### Interactions with Other Systems

| System | Interaction |
|---|---|
| **Player** | Owns `get_tree().paused`, the `_is_in_trade` flag (`begin_trade`/`end_trade`/`is_in_trade`), resource fields (`max_hp`, `current_hp`, `current_xp`), the `_blood_pact_stacks` counter, the `_yin_debt_speed_bonus` field, and the three `execute_*` methods that perform spend+buff atomically. Blood Pact mutates `max_hp` directly. |
| **Level Up & Upgrade Pool** | Trade panel and level-up panel share the pause token → mutually exclusive (`_is_in_trade` / `_is_selecting_upgrade` guards). Soul Codex draws from the same pool via `pick_trade_upgrade()` → `_get_random_upgrade_options` and respects the **D-B2 `_upgrade_pick_count` stack caps** — a capped/empty pool yields a disabled offer, never a silent full-cost no-op. |
| **Combat** | **[AS BUILT]** Blood Pact's shipped `×1.15`-per-stack buff is applied directly to each owned weapon's `damage` and is **not** currently routed through Formula 1's `minf(…, base × 5.0)` source-modifier ceiling (see archetype-table simplification note). 火眼金睛's `crit_multiplier` (1.2–1.55×) is a separate downstream multiplicative stage, unaffected either way. The ceiling-safe additive model (`TradeFormulas.weapon_damage_after_pact`) is the intended later refinement. |
| **Stage Director** | Owns stall spawning, offer building, panel driving, buff application, and the demon-tide (immediate + the `_pending_tides` follow-up/delayed scheduler via `_tick_pending_tides`). For an **interlude** it disables passive spawning, treats `stage_duration` as the interlude length, and auto-advances; any AVAILABLE stall is force-expired when a combat boss would otherwise spawn (`notify_boss_spawned`). Holds `_market_unease` and `_trade_count`. |
| **Demon Seal** | Sibling risk/reward system, used in the **combat** stages (Stage 1's `DemonSealConfig`). Interludes have **no** Demon Seal — so the two are not simultaneously active in the same room; they alternate across the run instead. |
| **Enemy Spawner** | Demon-tide bursts spawn through the spawner via `spawn_burst` (normals from the active pool) + `spawn_elite_at` (Impermanence elites with the `swift` affix). Tide enemies obey the aggregate **4-attacker contact ceiling** (enforced player-side). In an interlude the spawner's passive spawning is OFF — the tide is the only spawn source. |
| **Run State** | **[AS BUILT]** Interludes sit between combat stages in the 7-stage sequence; build/level/HP (including any prior max-HP reductions and Blood Pact damage) carry over on a single life. Trades are still tuned for a mid-game build; later interludes are reached by stronger builds that just cleared escalated (×1.4 / ×1.7) combat stages. |
| **HUD** | The Trade panel creates a distinct pause state. `hud.md` should add a **Trade-pause state** so the low-HP red-edge overlay and the angered-market pulse do not layer incoherently during the panel. See cross-doc note in Dependencies. |

## Formulas

### Formula 1 — Blood Pact damage buff (ceiling-safe with structural clamp)

> **[AS BUILT 2026-05-30 — IMPORTANT DIVERGENCE]** This ceiling-safe additive formula
> is **defined and unit-tested** (`TradeFormulas.weapon_damage_after_pact`) but is
> **NOT the path the shipped Blood Pact takes.** `Player.execute_blood_pact` instead
> applies a per-stack **multiplier on the weapon's live damage**:
> `weapon.damage = weapon.damage × (1 + BLOOD_PACT_DAMAGE_PER_STACK)` with
> `BLOOD_PACT_DAMAGE_PER_STACK = 0.15`, i.e. `×1.15` per stack, compounding with prior
> stacks and with level-up damage upgrades. **The `minf(…, base × 5.0)` source-modifier
> ceiling is therefore not enforced on this path.** Treat the formula below as the
> *intended* model (a later refinement); the shipped behavior is the multiplicative MVP.
> The worked examples below describe the intended additive model, not the live numbers.

```
# intended (not yet wired into execute_blood_pact):
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

`demon_tide(n)` where `n` = **global trade counter** (cumulative trades this run, 1-indexed for the table; clamped at `n ≥ 4`). All enemies are drawn from the **Ghost Market roster** (lantern_ghost, resentful_infant, ghost_bailiff, tomb_guardian, impermanence_elite) — **not** Stage-1 Shanxiao.

The table values below match the shipped constants exactly (`TradeFormulas.DEMON_TIDE_NORMALS = [5,5,5,6]`, `DEMON_TIDE_ELITES = [0,0,1,1]`, `DEMON_TIDE_INTERVAL_MULTS = [0.75,0.75,0.75,0.65]`, `DEMON_TIDE_WINDOWS = [12,12,12,20]`):

| n (cumulative trades) | Normal burst | Elite added | Interval mult (`interval_mult`) | Tide window | Tide type |
|---|---|---|---|---|---|
| 1 | 5 normals | 0 | ×0.75 | 12s | Immediate |
| 2 | 5 normals | 0 | ×0.75 | 12s | Immediate |
| 3 | 5 normals | +1 Impermanence Elite | ×0.75 | 12s | Immediate |
| 4+ | 6 normals | +1 Impermanence Elite | ×0.65 | 20s | Immediate |

`market_unease` (0–3) adds at most **+1** to `normal_count` (`demon_tide(n, market_unease)`).

> **[AS BUILT — burst-and-follow-up delivery, replaces the "interval multiplier" model]**
> The `interval_mult` / `window` columns above are still computed into the `DemonTideSpec`,
> but because an **interlude has no passive spawning**, there is no ongoing spawn cadence
> for a multiplier to modulate. `StageDirector.spawn_demon_tide` instead delivers the tide
> as discrete bursts: an **initial burst** of `normal_count` normals + `elite_count` elites,
> then **two follow-up bursts** of `max(normal_count / 2, 2)` normals each, scheduled at
> **0.45×** and **0.85×** of `window_seconds` (via `_pending_tides` / `_tick_pending_tides`).
> So `window_seconds` defines the duration over which the follow-ups land; `interval_mult`
> is effectively dormant on the interlude path (it stays in the spec for the combat-stage
> tide model the original design assumed).

**Yin Debt tide**: same `demon_tide(n)` result, but pushed as a single **delayed** burst
that fires **≈13.5s after the trade** (`_pending_tides` entry `{remaining: 13.5}`).
**[AS BUILT]** The Yin Debt path queues only the *delayed initial* burst (no follow-ups),
and the **2-second advance warning is not yet wired** (see Open Questions / OQ-6).

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

> **[AS BUILT notes 2026-05-30]** The edge cases below hold as written, with these
> interlude-context mappings: (1) "boss dies / stage clears mid-panel" → in an
> interlude there is no boss, but the same `_is_stage_cleared` / `_is_stage_failed`
> guards fire if the interlude ends or the player dies; `abort_trade()` (TRADING→EXPIRED)
> is the shipped abort path. (2) "boss spawns → stalls force-expire" → applies to the
> bracketing **combat** stages (`notify_boss_spawned`); within an interlude the stalls
> simply expire on their linger or when the interlude auto-advances. (3) The
> `_check_overlapping_stalls()` re-entry helper described below is **not** separately
> implemented — the next stall is opened by the player walking into it and holding again
> (presence-based), since `is_in_trade()` gates the second stall while the first panel
> is open. (4) `market_unease` is keyed to stall **expiry**, not walk-past.
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
| **Five Phases Synergy** (`elements-five-phases.md`) | Hard Bidirectional | **[v0.5]** Depended-on-by: provides the **Phase Bead** stall archetype (+1 element count, 40 XP, weighted to weakest element, no tide) and the **element tags** on Blood Pact / Soul Codex / Phase Bead cards (Blood Pact's element selects the buffed weapon; Soul Codex / Phase Bead display the offered/granted element). |
| **Merit System** (`merit-system.md`) | Hard Bidirectional | **[v0.5]** Depended-on-by: **Node 7 (五行灵珠)** unlocks (gates) the Phase Bead archetype — until unlocked it never spawns; **Node 12 (鬼市信誉)** makes each stall present **4** archetype offers instead of 3 (the 4th slot draws from the available pool, including Phase Bead if Node 7 is also unlocked). |

> Bidirectional note: Player, Level Up Pool, and Stage Director GDDs must add "depended on by Ghost Market Trade" when this GDD is approved. hud.md must add a Trade-pause UI state.
>
> **[v0.5 ADDITIVE 2026-06-02]** Ghost Market Trade is now **depended on by** the Five
> Phases Synergy system (Phase Bead stall + element tags) and the Merit System (Node 7
> unlocks the Phase Bead archetype; Node 12 adds a 4th offer). `elements-five-phases.md`
> and `merit-system.md` must list Ghost Market Trade as a dependency in return.

## Tuning Knobs

> **[AS BUILT 2026-05-30]** The shipped defaults for the **interlude** stalls live in
> `GhostMarketInterludeConfig._stalls()` (not a `.tres` yet). Where they differ from
> revision-1's Stage-2-combat defaults, the **Default** column below shows the
> shipped value with the revision-1 value in (parens). Cost/buff/tide constants live
> in `TradeFormulas` and match revision-1.

| Knob | Default (as built) | Safe Range | Effect / What breaks at extremes |
|---|---|---|---|
| `stall_count_per_run` | **3** (was 4) | 2–4 | one calm interlude holds 3 reachable stalls; >4 crowds the small room |
| `stall_spawn_times` | **[2, 6, 10]s** (was [90,150,210,255]) | within interlude `stage_duration` (~25s) | spawned early so all 3 are reachable in the calm window before auto-advance |
| `stall_linger_seconds` | **20** (was 25) | 12–25 | must be < interlude length so an ignored stall expires (and feeds unease) before advance |
| `stall_entry_hold_seconds` | 1.0 | 0.5–2.0 | <0.5 = accidental entry likely; >2.0 = punishes deliberate entry |
| `stall_entry_threshold_px` | **— (dormant)** | n/a | **[AS BUILT]** not wired — hold is presence-based (zone exit resets), not stillness-based |
| `trade_panel_fuse_seconds` (`FUSE_SECONDS`) | 5.0 | 3.0–8.0 | too short = not enough time to read offers; too long = negates time pressure |
| `blood_pact_hp_costs` (`BLOOD_PACT_HP_COSTS`) | [15, 20, 25] | per-step ≥ 10 | too cheap = glass-cannon spam; too dear = never used |
| `blood_pact_hp_floor` (`BLOOD_PACT_HP_FLOOR`) | 40 | 30–55 | below 30 = near-suicidal triple-pact; above 55 = second pact rarely available |
| `blood_pact_damage_per_stack` (`BLOOD_PACT_DAMAGE_PER_STACK`) | 0.15 (×1.15/stack) | 0.10–0.20 | **[AS BUILT]** multiplicative on live damage (no ceiling); >0.20 compounds fast |
| `blood_pact_max_stacks` (`BLOOD_PACT_MAX_STACKS`) | 3 | 2–3 | >3 would require raising the ceiling clamp (when the ceiling path is restored) |
| `soul_codex_xp_costs` (`SOUL_CODEX_XP_COSTS`) | [60, 80, 110, 150] | ≥ Demon Seal reward (48) | too cheap trivializes upgrade pacing |
| `phase_bead_xp_cost` | **[v0.5]** 40 (flat, no `n` escalation) | 30–60 | too cheap = trivial element farming; too dear = Five Phases synergies never reachable. Gated on Merit Node 7 |
| `yin_debt_speed_bonus` | 0.20 (+20%) | 0.10–0.30 | too high trivializes the delayed debt by kiting |
| `yin_debt_speed_duration` | 45s | 30–60 | too long outruns the delayed debt entirely |
| `yin_debt_tide_delay_seconds` | 13.5 (hardcoded in `_on_trade_offer_chosen`) | 10–18 | too short = self-negation; too long = trivializes debt |
| `yin_debt_tide_warning_lead_seconds` | **— (not wired)** | 1.0–3.0 | **[AS BUILT]** the advance warning is a TODO (OQ-6) |
| `demon_tide_normal_count` (`DEMON_TIDE_NORMALS`) | [5,5,5,6] | 3–8 | calibrated to 4-attacker ceiling survival budget |
| `demon_tide_interval_mult` (`DEMON_TIDE_INTERVAL_MULTS`) | [0.75,0.75,0.75,0.65] | 0.6–0.85 | **[AS BUILT]** dormant on the interlude burst path (no passive cadence to modulate) |
| `demon_tide_window_seconds` (`DEMON_TIDE_WINDOWS`) | [12,12,12,20] | 8–24 | window over which the 2 follow-up bursts (at 0.45×/0.85×) land |
| `demon_tide_elite_schedule` (`DEMON_TIDE_ELITES`) | [0, 0, 1, 1] by trade | [0,0,0,1] to [0,1,1,2] | reduce if survival rate <50%; increase for veteran pressure |
| `market_unease_max` (`MARKET_UNEASE_MAX`) | 3 | 1–4 | caps FOMO pressure; >4 = punitive cascade; 0 = remove feature |
| `market_unease_tide_bonus` (`MARKET_UNEASE_TIDE_BONUS`) | +1 normal enemy | +0 to +2 normals | light pressure, not severe punishment |

> **Interlude-only TradeStallConfig knobs (`GhostMarketInterludeConfig`):** the interlude
> sets `demon_tide_base_count = 5`, `demon_tide_interval_mult = 0.75`,
> `demon_tide_window_seconds = 12`, `demon_tide_elite_counts = [0,0,1,1]`,
> `demon_tide_elite_archetype = IMPERMANENCE_ELITE`. These `TradeStallConfig` fields are
> the editor-facing tide knobs; where they overlap `TradeFormulas`, the formulas are the
> canonical schedule (and express the trade-4 escalation the flat config cannot).

## Visual / Audio Requirements

> Brief at GDD stage; full spec via `/asset-spec system:ghost-market-trade` after the art bible covers the Ghost Market.

- **Stall visual**: a spectral merchant stall — hanging ghost-lantern, tattered banner, faint 朱砂/青铜 palette (consistent with the established VFX palette). Idle: slow pulse glow. AVAILABLE + player inside hold zone: fill-bar indicator visible near the stall. SPENT: brief "sold" stamp + dissolve. EXPIRED: silent fade.
- **In-zone hold indicator**: a subtle ~1.0s fill bar anchored to the stall, visible while the player stands in the zone (presence-based — fills as long as the player stays inside, resets on exit). Must be legible without a new interact key prompt. **[AS BUILT]** the shipped stall renders a simple `FillBar` polygon driven by `hold_progress_ratio()`.
- **Trade panel**: darker, more ominous theme than the level-up panel — fog border, archaic-cant merchant line per offer. Each offer card shows title — description, "代价:" (cost), and "潮汐:" (tide) (e.g. "潮汐 5怪 +1精英"). Burning-fuse timer ("引线 %.1fs") prominent. **[AS BUILT]** the Blood Pact confirm is a double-press relabel ("⚠ 再按一次以确认 · 以血换力") rather than a separate red modal — a destructive-action visual style is still a polish opportunity.
- **"Angered market" cue**: a distinct audio sting + screen-edge red pulse the instant a trade resolves, telegraphing the incoming tide (Combat Feedback + Audio own the actual sting/visual; this system fires the trigger). **[AS BUILT]** not yet wired — the tide currently spawns without a dedicated cue.
- **Yin Debt delayed-tide warning**: ~2s before the tide lands, an on-screen warning ("阴债将至" / "Debt arrives") should fire. **[AS BUILT — NOT YET WIRED, OQ-6]** the delayed tide currently fires at 13.5s with no advance warning.
- **Demon-tide telegraph**: brief spawn-direction indicator so the burst isn't a blind ambush (consistent with fair-pressure Pillar 1).

> **HUD cross-doc flag**: Trade panel introduces a distinct pause state. The HUD's low-HP red-edge overlay and the post-trade angered-market red pulse must not visually conflict. `hud.md` must specify a Trade-pause state that suppresses the low-HP overlay while the panel is open (or z-orders them intentionally).

📌 **Asset Spec** — after the art bible covers the Ghost Market, run `/asset-spec system:ghost-market-trade`.
📌 **UX Flag** — the Trade panel is a new screen. In Pre-Production run `/ux-design` for `design/ux/trade-panel.md` before writing trade stories; stories should cite that UX spec, not this GDD.

## Acceptance Criteria

> **[AS BUILT note 2026-05-30]** These ACs were authored for the revision-1 Stage-2-combat
> design. The ones below are updated to the shipped interlude behavior where load-bearing;
> the rest still hold conceptually with the Edge-Cases interlude mappings. The largest
> changes: AC-01 (interlude spawn time), AC-02-hold (presence-based, not stillness),
> AC-03 / AC-03b (multiplicative buff, ceiling not enforced), AC-05b (pool pick, not a
> specific named outcome), AC-06-tide* (burst + 2 follow-ups, not a spawn-interval override),
> AC-13-yin-delay (no advance warning yet). Existing automated coverage:
> `tests/unit/system/trade_formulas_test.gd`, `trade_stall_state_test.gd`,
> `tests/unit/player/player_trade_test.gd`, `player_yin_debt_test.gd`.

- **AC-01** **[AS BUILT]** **GIVEN** a Ghost Market **interlude** is running, **WHEN** the warm-up elapses for a stall spawned at `stall_spawn_times` (≈2/6/10s), **THEN** that TradeStall transitions DORMANT→AVAILABLE and becomes visible + collision-enabled exactly once. (revision-1: Stage 2, first stall at 90s.)
- **AC-02-hold** **[AS BUILT]** **GIVEN** an AVAILABLE stall, **WHEN** the player stays inside the zone for ≥1.0s (presence-based; `accumulate_hold(delta, moved=false)`), **THEN** the panel opens; **AND WHEN** the player leaves the zone before 1.0s, the fill resets and the panel does not open. (revision-1 required holding *still*; the shipped rule is zone-presence, swarm-push-proof.)
- **AC-02-reentry** **GIVEN** the player entered a stall zone, the fill reached 0.6s, then **left and re-entered**, **WHEN** the fill restarts from 0, **THEN** the panel does not open until a fresh 1.0s in-zone hold completes (no saved progress).
- **AC-03** **[AS BUILT]** **GIVEN** the panel is open with a Blood Pact offer (trade n=0, cost=15) and `max_hp = 100`, **WHEN** the player selects it (double-press confirm) and it succeeds, **THEN** `max_hp = 85`, `current_hp = min(current_hp, 85)`, **each owned weapon's `damage` is multiplied by 1.15**, `_blood_pact_stacks` increments, `upgrade_applied(&"blood_pact")` + `health_changed` emit, and the trade closes. (revision-1: "+15% to base damage".)
- **AC-03b-ceiling** **[AS BUILT — currently FAILS the live path]** Formula 1's `minf(…, base×5.0)` ceiling is unit-tested on `TradeFormulas.weapon_damage_after_pact` (`minf(36 + 6×0.15×3, 6×5.0) = 30.0`), **but `Player.execute_blood_pact` does not call it** — the live ×1.15 multiplier can exceed `base×5.0`. This AC documents the *intended* ceiling; restoring it on the live path is a tracked refinement (Open Questions).
- **AC-04-floor** **GIVEN** `max_hp = 54` and Blood Pact cost at trade n=0 is 15, **WHEN** a stall panel opens, **THEN** the Blood Pact offer is enabled (54 - 15 = 39 < 40 → DISABLED); **AND GIVEN** `max_hp = 56`, **THEN** Blood Pact is enabled (56 - 15 = 41 ≥ 40).
- **AC-05** **GIVEN** a Soul Codex offer costing 60 XP and `current_xp = 40`, **WHEN** the panel opens, **THEN** the offer is `disabled` and cannot be selected.
- **AC-05b-specific** **[AS BUILT]** **GIVEN** a Soul Codex offer for a player whose level-up pool is non-empty, **WHEN** the panel opens, **THEN** the offer card shows the **specific upgrade `pick_trade_upgrade()` surfaced** (a weapon unlock or boost title). **GIVEN** the pool is empty (all weapons owned + all caps hit), **THEN** the card shows "（暂无可习）" and is **disabled** (bad-luck protection). (revision-1: a specific "Unlock: Flying Sword" / "+1 projectile" outcome; as built it is whatever the shared pool yields.)
- **AC-06-tide1** **[AS BUILT]** **GIVEN** `_trade_count = 1` after a completed Blood Pact / Soul Codex trade, **WHEN** `spawn_demon_tide(1, unease)` runs, **THEN** it emits an **initial burst** of 5 normals (`spawn_burst(5)`) + 0 elites, **and queues 2 follow-up bursts** of `max(5/2,2)=2` normals at `0.45×12=5.4s` and `0.85×12=10.2s`. (revision-1 set a spawn-interval override; the interlude has no passive spawning to override.)
- **AC-06-tide2** **GIVEN** `_trade_count = 2`, **WHEN** the tide fires, **THEN** initial burst of 5 normals, **0 elites**, + 2 follow-ups of 2.
- **AC-06-tide3** **GIVEN** `_trade_count = 3`, **WHEN** the tide fires, **THEN** initial burst of 5 normals **+ 1 impermanence_elite** (`spawn_elite_at`, `swift` affix) + 2 follow-ups of 2.
- **AC-06-tide4** **GIVEN** `_trade_count ≥ 4`, **WHEN** the tide fires, **THEN** initial burst of 6 normals **+ 1 impermanence_elite**; window 20s → follow-ups at 9s / 17s of `max(6/2,2)=3`.
- **AC-07** **GIVEN** 3 Blood Pacts already taken (`blood_pact_stacks() == 3`), **WHEN** a new stall opens, **THEN** the Blood Pact offer IS present but **disabled** (`is_blood_pact_locked` stack-cap branch — shown, not hidden).
- **AC-08** **[AS BUILT — intended-model AC]** Documents the Formula 1 ceiling (`minf(38 + 8×0.15×3, 8×5.0) = 40.0`) for `TradeFormulas.weapon_damage_after_pact`. The live `execute_blood_pact` path does not yet route through this (see AC-03b).
- **AC-09a** **[AS BUILT]** **GIVEN** `player._is_dead = true` while a panel is open, **WHEN** `_on_trade_offer_chosen` runs, **THEN**: (1) no resource spent, (2) no buff, (3) no tide, (4) `abort_trade()` → stall EXPIRED, (5) panel hidden + trade ended (pause restored), (6) `_is_in_trade = false`.
- **AC-09b** **GIVEN** `_is_stage_cleared = true` while a panel is open (interlude ended / final boss died mid-panel), **WHEN** the guard executes, **THEN**: same postconditions as AC-09a.
- **AC-10** **[AS BUILT]** **GIVEN** a combat boss would spawn (bracketing combat stage) OR the interlude auto-advances, **WHEN** a stall is AVAILABLE, **THEN** `notify_boss_spawned()` / interlude-end force-expires it (EXPIRED) and no further trading occurs in that room.
- **AC-11** **[AS BUILT]** **GIVEN** a stall is AVAILABLE and never traded, **WHEN** `stall_linger_seconds` (20s) elapse, **THEN** the stall → EXPIRED, `queue_free()`s, emits `stall_expired`, and `_market_unease` increments (clamped at 3).
- **AC-12** **GIVEN** the player opens a stall and presses Leave (or the fuse expires), **WHEN** the panel closes, **THEN** trade ends (pause restored), `_is_in_trade = false`, `return_to_available()` keeps the **same offers**, and the linger has **not** reset (frozen while TRADING, continues after).
- **AC-13-yin-speed** **[AS BUILT]** **GIVEN** a Yin Debt trade completes, **WHEN** `execute_yin_debt()` runs, **THEN** `_yin_debt_speed_bonus = 0.2` and `_yin_debt_remaining = 45.0`; effective speed = `move_speed × _speed_multiplier × 1.2`; at t≈45s `_tick_yin_debt` clears the bonus.
- **AC-13-yin-delay** **[AS BUILT — warning not yet wired]** **GIVEN** a Yin Debt trade completes at `_trade_count = 2`, **WHEN** ≈13.5s elapse (a `_pending_tides` entry), **THEN** the tide for n=2 (5 normals, 0 elites) fires — **not** at trade time. **The 2s advance warning is NOT yet implemented** (OQ-6); revise this AC's warning clause when wired.
- **AC-14-fuse** **GIVEN** the panel is open and the player takes no action, **WHEN** 5s elapse (fuse expires), **THEN** the panel closes, treated as Decline (no spend, no buff, no tide, stall → AVAILABLE, linger continues).
- **AC-15-hud** **GIVEN** a trade panel is open (tree paused), **WHEN** the HUD renders, **THEN** the Trade-pause state is active, the low-HP red-edge overlay is suppressed, and the angered-market pulse does not layer with it (or is explicitly z-ordered per hud.md spec).

## Open Questions

- **OQ-1** (Blood Pact ceiling) **[REOPENED 2026-05-30 by implementation-sync]**: the shipped `execute_blood_pact` applies a `×1.15`-per-stack multiplier on the weapon's live damage and **does not enforce the `minf(…, base×5.0)` source-modifier ceiling** (it does not call `TradeFormulas.weapon_damage_after_pact`). Decide whether to (a) route the live path through the ceiling-safe additive formula, or (b) add a `minf` clamp to the multiplicative path + a `push_error` assert. Until then the 5× ceiling can be exceeded by stacked Blood Pacts. **Owner**: systems-designer + lead-programmer. **Target**: balance/ceiling pass.
- **OQ-6** (Yin Debt advance warning) **[NEW 2026-05-30]**: the delayed Yin Debt tide currently fires at ≈13.5s with **no on-screen warning** (revision-1 specified a 2s-lead "阴债将至" cue + a `tide_warning` signal). Wire the warning (a `_pending_tides` entry could emit a signal at `remaining ≤ 2.0`) so the debt is fair per Pillar 1. The "angered market" sting/pulse for *immediate* tides is likewise unwired. **Owner**: ux-designer + systems-designer. **Target**: polish pass.
- **OQ-2** ~~(current-HP vs max-HP cost)~~ **RESOLVED** (2026-05-29 — owner decision): Blood Pact cost is permanent max-HP reduction (15/20/25 by global trade n). Old current-HP model removed. Max-HP floor is 40. Reduction persists across Stage 1→2 (same Player node, ADR-0004).
- **OQ-3** (HUD Trade-pause state): the trade panel creates a distinct pause state that must not layer incoherently with the low-HP overlay and post-trade pulse. `hud.md` must add an explicit Trade-pause UI state. **Owner**: UI designer. **Target**: Pre-Production UX pass (before `/team-ui` implementation stories).
- **OQ-4** (Soul Codex projectile fallback): resolved in Detailed Rules (bad-luck filter: if all weapons are at max projectile stack, the +projectile card is not generated). Confirm the fallback behavior (generate a different offer or show the stall with only 2 cards) before implementation. **Owner**: systems-designer. **Target**: implementation.
- **OQ-5** ~~(Yin Debt duration 60s)~~ **RESOLVED** (2026-05-29 — revision-1): duration reduced to 45s so it does not fully outlast the delayed tide. Delay set to ~13.5s. Kiting balance: playtest flag if speed trivializes the debt even at 45s — reduce to 35s if so.

## Revision Log

| Rev | Date | Trigger | Summary |
|---|---|---|---|
| 0 | 2026-05-29 | Initial design (Stage 2 content) | User-approved concept; economy by economy-designer (4 stalls, 3 trades, escalating cost, demon-tide curve, guardrails); mechanics by systems-designer (stall state machine, panel flow, ordering, 9 edge cases). 12 ACs, 5 OQs. Pending /design-review. |
| 1 | 2026-05-29 | MAJOR REVISION — 2 independent /design-review verdicts (10 blockers + 12 recommended) | **B-1** Blood Pact cost → permanent max-HP reduction (15/20/25), floor 40, current_hp clamped. **B-2** Yin Debt tide delayed ~13.5s with on-screen warning; speed duration 45s (not 60s) to prevent self-negation. **B-3** Stall entry → hold-threshold ~1.0s fill indicator (no accidental entry; preserves movement-only input). **B-4** Decision moment → timed fuse timer (~5s auto-close = decline); Blood Pact confirm step. **B-5** Each offer card shows demon-tide details (tier/count/elites) so gamble is informed (Pillar 1). **B-6** Blood Pact buff raised to +15%/stack, Formula 1 gains structural `minf(…, base×5.0)` clamp valid for any base value; 火眼金睛 crit pipeline documented as separate stage, out of scope. **B-7** `body_exited` removed as a TRADING-state decline path (dead code while paused); Leave button + fuse only. **B-8** Soul Codex pre-resolves outcome at generation time; bad-luck filter excludes +projectile if all weapons maxed. **B-9** Non-engagement cost: expired stalls increment `market_unease`; light +1-normal bonus on next tide (capped at 3). **B-10** Formula 4 recalibrated with real Stage-2 DPS; Shanxiao → Impermanence Elite; elite schedule 0/0/1/1; first stall at 1:30 (t=90s); survival-budget worked example with mid-game HP. AC section fully rewritten (15 ACs, all Given/When/Then with measurable observables). OQ-2 + OQ-5 closed; OQ-3 (HUD Trade-pause) added. |
| 2 | 2026-05-30 | **Synced to implementation** (no design review; doc-sync batch) | **Structural**: trade moved from a Stage-2 combat mechanic to a **calm trade INTERLUDE** (`is_interlude` StageConfig / `GhostMarketInterludeConfig`) between combat stages in the 7-stage run; 幽都 is now a pure combat stage (judge + 5 enemies, no stalls). **Stalls**: 3 per interlude, spawned at 2/6/10s, 20s linger (was 4 at 90/150/210/255s, 25s). **Hold**: presence-based (stay in zone ~1s, swarm-push-proof) instead of "stand perfectly still". **Confirm**: Blood Pact double-press relabel instead of a separate modal. **Buffs simplified**: Blood Pact = ×1.15/stack on each owned weapon's live damage (NOT the additive-on-base Formula 1; **ceiling not enforced** — OQ-1 reopened); Soul Codex = one pick from the level-up pool (NOT a specific named unlock/+projectile); Yin Debt unchanged (+20%/45s, delayed ~13.5s). **Tide**: initial burst + 2 follow-up bursts over the window (replaces the moot spawn-interval multiplier in a no-passive-spawn room); `market_unease` keyed to stall *expiry*. **Signals**: `trade_requested` / `stall_expired` only; StageDirector drives the rest. **Not yet wired**: Yin Debt 2s advance warning + "angered market" cue (OQ-6); HUD Trade-pause (OQ-3). revision-1 design intent preserved in collapsed `<details>` blocks + parenthetical comparisons. |
| 3 | 2026-06-02 | **Dependency propagation** (additive only; v0.5 systems) | Propagated Five Phases (Phase Bead stall type + element tags) and Merit System (Node 7 gate, Node 12 4-offer) dependencies. Additive only — existing 3 archetypes and costs unchanged. **Added**: 五行灵珠 (Phase Bead) Stall subsection — new 4th **archetype** (40 XP flat `phase_bead_xp_cost`, +1 to weakest-weighted Five Phases element, no stat buff, **no demon tide**, gated on Merit Node 7, joins the archetype pool without adding a 4th physical stall). Element Tags on Existing Stalls (Blood Pact element selects buffed weapon; Soul Codex / Phase Bead show offered/granted element — display + targeting metadata only). Merit Node 12 — 4 Trade Options note (4 offers instead of 3 when 鬼市信誉 purchased; 4th slot draws from the available pool incl. Phase Bead if Node 7 also unlocked). Bidirectional Dependencies rows for Five Phases Synergy and Merit System. |
