# Experience & Progression System

> **Status**: Approved (revision-0 — first-try PASS, 0 blockers; 2 RECOMMENDED + 2 NICE-TO-HAVE noted but deferred to Pickup GDD authoring)
> **Author**: claude (reverse-documented from `scripts/system/experience_orb.gd`, `scenes/system/ExperienceOrb.tscn`, `scripts/player/player.gd` gain_experience pipeline, + Player GDD Formulas 3/4)
> **Last Updated**: 2026-05-25
> **Implements Pillar**: Pillar 2 (auto-battle with meaningful build choices — XP is the currency that gates 升级 / construction choices)
> **TR Coverage**: TR-core-004 (level-up + 3-choice UI pause/resume cadence — owned upstream by Level Up GDD); supports TR-core-001 by chaining "kill → drop → pickup → level" feedback loop
> **Layer**: Progression / Feature (depends on Enemy for drop trigger, Player for XP accrual)

## Overview

The Experience & Progression System is the **kill-to-grow feedback loop**. When an Enemy dies (per Combat GDD Core Rule 4), it spawns an Experience Orb at its position; when the Player walks within pickup radius, the orb auto-collects and credits XP to Player. Player accumulates XP across `gain_experience()` calls; when accumulated XP crosses the level threshold (per Player GDD Formula 3), Player emits `level_reached(N)` which opens the Level Up panel (owned by Level Up & Upgrade Pool GDD, FT-05).

This system is the **temporal binding** between three other systems:
1. Enemy GDD's `died(payload)` signal (the spawn trigger)
2. Pickup System (FT-12)'s radius-detection mechanic (the collection trigger)
3. Player GDD's `gain_experience()` pipeline (the application sink)

Without Experience & Progression, the kill action has no consequence — no growth, no upgrade panel, no fantasy of getting stronger. With it, every 5-10 seconds the player feels a tiny dopamine pulse as orbs disappear into them, building toward the bigger pulse of a level-up.

Reference: Combat GDD Core Rule 4 (data-death triggers `died` signal), Player GDD Formula 3 (XP threshold curve), Player GDD Formula 4 (XP gain with multiplier), Enemy GDD (enemy `xp_drop_value` field).

## Player Fantasy

XP is the **drumbeat of progression**. The player's loop:

> "I move. My talismans fire. An enemy dies — a small green orb appears. I drift toward it; it disappears into me with a soft chime. A few more, a few more — the XP bar fills, the screen pauses, three upgrade options appear. I pick one. The bar empties; the next drumbeat begins."

When Experience works invisibly, the player feels:
- **Immediate cause-and-effect** — kill an enemy, see an orb, watch it come to you
- **Building anticipation** — each orb collected nudges the XP bar visibly closer to the next level
- **Rewarded curiosity** — chasing orbs (especially far ones) is its own movement game-within-the-game
- **No "wasted" kills** — every defeated enemy drops something (except Boss which has its own victory state per Combat GDD AC-18)

Anti-fantasy: orbs that disappear silently, XP that vanishes without a level-up cue, level-up pauses that don't feel earned (player didn't know they were close), or orbs that timeout and lost-value-feel ("I was just about to grab that").

## Detailed Rules

### Core Rules

1. **Each Enemy that dies spawns exactly one Experience Orb** (per Enemy GDD's `died(payload)` signal). The orb's `xp_value` is read from the dying Enemy's `xp_drop_value` field (per `entities.yaml` registered values — Paper Doll 3.5, Wandering Soul 5.5, Fox Spirit 6.0, Ghost Flame 6.0, Stone Golem 12.0, Shanxiao Elite 22.0, Famine Beast 0).

2. **Boss death does NOT spawn an XP orb** (`xp_drop_value = 0` on `famine_beast.tres`). Boss reward is the victory transition, not XP. Consumer-side filter: `if payload.xp_drop_value > 0: spawn_orb`.

3. **Experience Orbs are `Area2D` nodes** with their own collision shape (`CircleShape2D radius 34 px`). They detect player overlap via:
   - **Engine signal `body_entered`** — fires when Player collision shape enters orb's Area2D
   - **Per-frame radius scan** — `_try_collect_players_in_radius()` runs in `_process()` to handle Player's expanded pickup radius (when `pickup_radius_bonus > 0` from Player upgrades, the effective radius can exceed the orb's own collision shape — the per-frame scan catches the difference)

4. **Orbs have a finite lifetime: 30 seconds default.** If not collected by `lifetime_seconds`, the orb `queue_free()`s — XP is lost. This prevents orb accumulation in long-running scenes (memory + visual clutter); 30s is far longer than typical engagement so designers don't worry about "missed" drops.

5. **Orb collection is one-shot per orb.** `_is_collected` flag guards against double-credit if both detection mechanisms fire in the same frame. After `gain_experience()` is called, the orb immediately `queue_free()`s — no animation delay, no held state.

6. **Collection requires Player conformance**: the body must be in scene-tree group `"player"` AND implement `gain_experience` method. Defensive guard against accidentally collecting orbs onto enemies or other Node2Ds.

7. **Pickup radius is the sum of orb-side and Player-side**: `effective_radius = orb.pickup_radius + max(player.get_pickup_radius_bonus(), 0)`. Per Player GDD Formula 5 — `CharacterBase.pickup_radius` is the Player's base (default 50 px for 修行者), Player upgrades stack `pickup_radius_bonus` on top. The orb's own `pickup_radius` (34 px) is the floor — even at zero Player bonus, the orb has a generous self-detection range.

8. **XP application is delegated to Player** — orbs call `Player.gain_experience(xp_value)`. Player owns the application pipeline (XP multiplier, level threshold check, signal emission). Per Player GDD Formula 4.

### Orb State Machine

| State | Transition trigger | Next state | Side effect |
|---|---|---|---|
| `SPAWNED` (just created, `_is_collected = false, _elapsed_lifetime = 0`) | `_ready()` connects `body_entered`; calls `_try_collect_overlapping_bodies()` once | `IDLE` | Engine detects any overlapping body immediately (spawn-into-player case) |
| `IDLE` (waiting for player) | Each frame, `_process(delta)` increments `_elapsed_lifetime` AND calls `_try_collect_players_in_radius()` | `IDLE` (most frames) OR `COLLECTED` (if player in range) OR `EXPIRED` (if lifetime exceeded) | Visible green orb |
| `IDLE` | `body_entered(player)` signal fires | `COLLECTED` | Player's `gain_experience()` is called |
| `IDLE` | `_elapsed_lifetime >= lifetime_seconds` | `EXPIRED` | `queue_free()` |
| `COLLECTED` (`_is_collected = true`) | Synchronous in same frame as transition | `(freed)` | `queue_free()` — orb removed from scene |

Note: `COLLECTED` and `EXPIRED` both lead to `queue_free()`; the difference is whether the Player received the XP (COLLECTED) or not (EXPIRED).

### Interactions with Other Systems

| System | Direction | Interface |
|---|---|---|
| **Enemy** (C-04, Approved) | Enemy → Experience | On `died(payload)` signal, Experience spawns an orb at `payload.position` with `payload.xp_drop_value` (per Combat GDD payload contract) |
| **Player** (C-01, Approved) | Experience → Player | Orb calls `Player.gain_experience(xp_value)`; Player owns the XP-to-level pipeline (Player GDD Formula 4) |
| **Pickup System** (FT-12, future) | Pickup → Experience | Pickup GDD will own the unified "any-pickup-radius detection" service; Experience Orb currently implements its own detection (see OQ-1) |
| **Run State** (F-03, Approved) | Independent | Orbs are scene-bound; on run end, they're naturally destroyed with the scene tree |
| **Level Up & Upgrade Pool** (FT-05, future) | Player → Level Up | When `Player.gain_experience` triggers `level_reached(N)`, Level Up panel opens — Experience's role ends at the `gain_experience` call |
| **HUD** (P-01, future) | Player → HUD | HUD subscribes to Player's `experience_changed` signal (NOT to orbs directly) |

`Experience` is the **transformation layer** between Enemy death and Player XP — both ends are owned by other systems; Experience owns the orb-as-intermediate-object.

## Formulas

### Formula 1: Orb spawn

```
on enemy.died(payload):
    if payload.xp_drop_value > 0:
        var orb := preload("res://scenes/system/ExperienceOrb.tscn").instantiate()
        orb.xp_value = payload.xp_drop_value
        orb.global_position = payload.position
        get_tree().current_scene.add_child(orb)
```

**Variables:**

| Variable | Type | Range | Description |
|---|---|---|---|
| `payload.xp_drop_value` | float | 0 – 30 (per Enemy GDD tuning) | Enemy-defined XP yield |
| `payload.position` | Vector2 | world coordinates | Enemy's position at moment of death |

**Output:** zero or one new Experience Orb in the scene tree. Boss death (xp_drop_value = 0) explicitly does NOT spawn.

### Formula 2: Effective pickup radius

```
effective_radius = orb.pickup_radius + max(player.get_pickup_radius_bonus(), 0)
```

**Variables:**

| Variable | Type | Range | Description |
|---|---|---|---|
| `orb.pickup_radius` | float | 1 – 100 px (clamped MIN_PICKUP_RADIUS = 1.0) | Per-orb pickup detection range (default 34 px from ExperienceOrb.tscn) |
| `player.get_pickup_radius_bonus()` | float | 0 – 100 px (upgrade-stacked) | Player upgrade bonus (per Player GDD Formula 5) |

**Output Range:** typically 34 – 134 px during a run; 修行者 with 0 upgrades = 34, with +100 from upgrade stack = 134.

**Example:** Player has `pickup_radius_bonus = 30`; an orb spawns. Effective radius = `34 + 30 = 64 px`. Player anywhere within 64 px of orb (squared distance ≤ 4096) auto-collects.

**Note:** This formula slightly differs from Player GDD Formula 5 (`effective_pickup_radius = CharacterBase.pickup_radius + pickup_radius_bonus`). The current code uses the **orb's** `pickup_radius` (34) plus the Player's bonus — NOT the Player's CharacterBase pickup_radius (50). This is a code/spec divergence flagged in OQ-2.

### Formula 3: Level-up cascade (delegated to Player GDD Formula 4)

```
on Player.gain_experience(amount):
    # delegated entirely — see Player GDD Formula 4 for the level-up loop
    pass
```

Experience does not own this formula — it is fully owned by Player. Experience's contract ends at the `gain_experience()` call.

### Formula 4: Orb expiration

```
on _process(delta):
    if _is_collected:
        return
    _elapsed_lifetime += delta
    if _elapsed_lifetime >= lifetime_seconds:
        queue_free()
        return
    # ... continue to per-frame radius scan
```

**Variables:**

| Variable | Type | Range | Description |
|---|---|---|---|
| `_elapsed_lifetime` | float | 0 – `lifetime_seconds` | Time since orb spawn |
| `lifetime_seconds` | float | 0.1 (clamp) – 60 (design-safe) | Total orb lifetime; default 30s |

**Output:** orb removes itself at `t = lifetime_seconds` if uncollected.

## Edge Cases

- **If a Player has `_is_dead = true` when `gain_experience` is called** (orb collected at the exact moment of player death): per Player GDD AC-12 (revision-2), `gain_experience` early-returns; XP is silently lost. This is consistent with Player GDD's code-true behavior; the orb still `queue_free()`s (`_is_collected = true` is set before the call). No double-collect risk.
- **If an orb spawns at the exact position of the Player** (Boss death spawn while player is in melee range): the spawn-time `_try_collect_overlapping_bodies()` (called from `_ready()` via `call_deferred`) catches this immediately — Player collects on the very next frame.
- **If 100+ orbs spawn in a 5-second window** (massive AOE Boss kill): each is an Area2D with `_process()` running per-frame. Currently no pooling — could become a perf concern at extreme densities. OQ-3 tracks.
- **If the Player walks past an orb at high speed without entering its collision shape**: the `body_entered` signal may not fire if the player's collision shape is small and the orb is brief — that's why the per-frame `_try_collect_players_in_radius()` (Formula 2) exists as a fallback.
- **If `pickup_radius_bonus` is negative** (no upgrade currently does this, but defensively): the orb's `_get_pickup_radius_squared` uses `max(bonus, 0.0)` clamping. Effective radius never drops below the orb's own `pickup_radius`.
- **If two orbs are stacked at the same position** (rare but possible if two enemies die in the same frame): both `body_entered` fires on player entry. Each orb's `_is_collected` guard prevents double-credit on its own orb; both are collected independently.
- **If the orb is `queue_free`'d in the middle of its own `_process()`**: Godot's safe-defer pattern ensures the node is cleaned up at end of frame. No null reference errors.
- **If the scene transitions while orbs exist** (Player dies mid-collection): orbs are destroyed with their scene parent. No XP is credited from any uncollected orb. (Acceptable — run ended; level-up wouldn't matter.)
- **If `xp_value` is 0 but the orb still spawns** (Formula 1 has the `> 0` guard, so this shouldn't happen — but defensively): the orb appears, gets collected, calls `gain_experience(0)` — Player handles gracefully (`if amount <= 0.0: return` per player.gd:140). No level-up triggers; no visual feedback. Effectively a no-op.

## Dependencies

| Dependency | Type | Direction | Interface |
|---|---|---|---|
| **Enemy** (C-04, Approved) | Hard | Enemy → Experience | `died(payload)` signal triggers orb spawn; `payload.xp_drop_value` + `payload.position` are consumed |
| **Player** (C-01, Approved) | Hard | Experience → Player | Calls `Player.gain_experience(amount)`; Player's `_is_dead` guard handles post-death case |
| **Resource Data Framework** (F-02, Approved) | Hard | Experience reads | Enemy `xp_drop_value` is sourced from `.tres` files (per Pillar 4) |
| **Godot 4.6 engine** | Hard | (implicit) | Area2D, CircleShape2D, body_entered signal, call_deferred |
| **Pickup System** (FT-12, future) | Soft (current) | Experience currently does its own pickup | Future: extract radius-detection into Pickup service; Experience just emits XP-bearing collectables |
| **Level Up & Upgrade Pool** (FT-05, future) | Soft (downstream) | Player → Level Up | When Player's accumulated XP crosses threshold, Level Up panel opens — Experience's role already complete |
| **HUD** (P-01, future) | Soft (downstream) | Player → HUD | HUD reads `Player.experience_changed` for XP bar; Experience doesn't talk to HUD directly |
| **Run State** (F-03, Approved) | None (independent) | — | Orbs are scene-bound; run-end destroys them via scene tree |

**Bidirectional check:**
- Enemy GDD must list Experience as downstream (consumer of `died` signal for orb spawn) — ✅ Enemy GDD §Dependencies already includes "Experience System (FT-04, future)" — verify on next /consistency-check
- Player GDD lists Experience at "Experience & Progression (FT-04) | Soft | Pickup → Player | Pickup calls `gain_experience(amount)`" ✅
- Pickup System GDD (future) MUST list Experience as a consumer when authored

## Tuning Knobs

| Knob | Owner | Design-safe range | Default | Effect at extremes |
|---|---|---|---|---|
| `Enemy.xp_drop_value` | Per-enemy `.tres` | 0 – 30 | varies (3.5 - 22) | <2 = drops feel valueless; >30 = trivial leveling, breaks Pressure Curve |
| `ExperienceOrb.lifetime_seconds` | ExperienceOrb.tscn / runtime override | 10 – 60 | 30 | <10 = stress-collecting feels punishing; >60 = orbs clutter long fights |
| `ExperienceOrb.pickup_radius` | ExperienceOrb.tscn / runtime override | 20 – 80 | 34 | <20 = orbs feel sticky-only; >80 = trivializes pickup |
| `Player.pickup_radius_bonus` | Player.tscn / upgrades | 0 – 100 | 0 | (stacks via upgrades, per Player GDD Formula 5) |
| `Player.xp_gain_multiplier` | Player.tscn / upgrades | 1.0 – 3.0 | 1.0 | (per Player GDD Formula 4) |
| `Player.initial_xp_to_next_level` | Player.tscn | 10 – 30 | 18 | (per Player GDD Formula 3) |
| `Player.xp_growth_multiplier` | Player.tscn | 1.10 – 1.40 | 1.28 | (per Player GDD Formula 3) |
| `Player.xp_growth_flat` | Player.tscn | 0 – 15 | 6 | (per Player GDD Formula 3) |

Most XP-related tuning is owned by Player GDD (curve definition) or Enemy GDD (drop values). Experience-system-owned tuning is just orb lifetime and base pickup radius.

**Interaction warnings**:
- Raising `xp_drop_value` for Paper Dolls breaks Pressure Curve §Per-Phase TTK budget — Paper Dolls are the filler tier and should NOT trigger frequent level-ups
- Lowering `lifetime_seconds` below ~10 makes orbs feel grabby; players will path-plan to grab orbs before they expire (positive design) but at <5s causes frustration
- Stacking `Player.pickup_radius_bonus` past 100 makes orbs feel magnetic — verify in playtest before approving stacked upgrades

## Acceptance Criteria

### AC group: Orb spawn (Formula 1)

**AC-01** **GIVEN** an Enemy with `xp_drop_value = 5.5` (Wandering Soul) at world position (100, 200), **WHEN** that Enemy emits `died(payload)`, **THEN** exactly one ExperienceOrb is added to the scene tree with `orb.xp_value = 5.5` AND `orb.global_position = (100, 200)`.

**AC-02** **GIVEN** a Famine Beast Boss with `xp_drop_value = 0` dies, **WHEN** the died payload is processed, **THEN** NO ExperienceOrb is spawned (per Formula 1's `xp_drop_value > 0` guard).

### AC group: Orb collection (Formula 2 + Core Rule 7)

**AC-03** **GIVEN** an ExperienceOrb at world (50, 50) with `pickup_radius = 34` AND Player at world (60, 60) (distance ≈ 14.14 px), **WHEN** Player's `pickup_radius_bonus = 0`, **THEN** Player's collision shape entering the orb's Area2D triggers `body_entered` → `_try_collect()` → `Player.gain_experience(5.5)` fires AND orb `queue_free`s.

**AC-04** **GIVEN** Player at world (150, 150) AND ExperienceOrb at world (90, 90) (distance ≈ 84.85 px) AND Player's `pickup_radius_bonus = 60`, **WHEN** `_try_collect_players_in_radius()` runs in orb's `_process(delta)`, **THEN** effective_radius = `34 + 60 = 94`, squared distance check (`84.85² ≈ 7200 ≤ 94² = 8836`) passes AND collection fires.

**AC-05** **GIVEN** the same setup as AC-04 but Player at (130, 130) (distance ≈ 56.6 px), `pickup_radius_bonus = 60`, **WHEN** scan runs, **THEN** collection fires (well within range).

**AC-06** **GIVEN** Player at (300, 300) AND ExperienceOrb at (50, 50) (distance ≈ 354 px), `pickup_radius_bonus = 60`, **WHEN** scan runs, **THEN** NO collection (effective_radius 94 << 354).

### AC group: Lifetime expiration (Formula 4)

**AC-07** **GIVEN** an ExperienceOrb with `lifetime_seconds = 30`, **WHEN** 30 seconds elapse without any Player coming within pickup radius, **THEN** orb `queue_free`s AND NO `gain_experience` call is made AND the XP value is lost.

**AC-08** **GIVEN** an ExperienceOrb with `lifetime_seconds = 30` AND a player walks into its pickup radius at `t = 25`, **WHEN** collection fires, **THEN** XP is credited normally AND lifetime expiration is irrelevant (the orb is already `_is_collected = true` AND `queue_free`d).

### AC group: One-shot collection guard (Core Rule 5)

**AC-09** **GIVEN** an ExperienceOrb AND a Player whose collision shape overlaps the orb (triggering `body_entered`) AND simultaneously Player is in the per-frame radius scan range, **WHEN** both detection paths fire in the same frame, **THEN** Player receives `gain_experience(xp_value)` exactly ONCE (not twice), due to `_is_collected` flag guard.

### AC group: Defensive filters (Core Rule 6)

**AC-10** **GIVEN** an ExperienceOrb AND a non-Player Node2D in the orb's collision shape (e.g. a stray enemy projectile that somehow has Area2D detection), **WHEN** `body_entered` fires, **THEN** NO collection AND NO error (filtered by `is_in_group("player") AND has_method("gain_experience")`).

**AC-11** **GIVEN** a Player in `_is_dead = true` state AND an ExperienceOrb in collection range, **WHEN** orb attempts collection, **THEN** the orb DOES call `gain_experience()`, but Player's gain_experience early-returns (per Player GDD AC-12) AND the orb still `queue_free`s (orb-side `_is_collected = true` is set before the call). NO XP credited.

### AC group: Cross-system integration

**AC-12** **GIVEN** a Wandering Soul dies → orb spawns → Player collects → `gain_experience(5.5)` fires → Player has cumulative XP that crosses level threshold, **WHEN** the full chain completes within ~2 frames, **THEN** Player emits `level_reached(N)` AND Level Up panel opens (per Player GDD Formula 4 + Level Up GDD when authored).

## Open Questions

- **OQ-1** (Centralize Pickup mechanism — refactor coordination with FT-12 Pickup System GDD): The orb implements its own dual-detection (signal + per-frame scan); the future Pickup System GDD (FT-12) should own this as a generic "pickup detection" service consumed by both XP orbs and any future health/buff orbs. **Resolution candidate**: when Pickup GDD is authored, refactor `experience_orb.gd` to declare itself as a `Pickup` and let the central system handle player-radius detection. **Owner**: lead-programmer + systems-designer. **Target**: Pickup System GDD (FT-12) authoring.
- **OQ-2** (Pickup radius formula divergence — Player GDD vs Experience GDD): Player GDD Formula 5 says `effective_pickup_radius = CharacterBase.pickup_radius + pickup_radius_bonus` (e.g. 50 + 30 = 80 for default 修行者). This Experience GDD's Formula 2 says `effective_radius = orb.pickup_radius + pickup_radius_bonus` (e.g. 34 + 30 = 64). **The two GDDs describe different radii**. Player GDD's formula describes "Player's reach"; Experience GDD's formula describes "orb's reach assisted by Player's bonus". Currently the code uses Experience's interpretation (orb-side 34 + Player bonus). **Resolution candidate**: clarify in revision-1 OR reconcile in Pickup System GDD (FT-12) which will own the unified formula. **Owner**: systems-designer. **Target**: revision-1 of this GDD if reviewer flags, or Pickup GDD authoring.
- **OQ-3** (Orb pooling for AOE Boss spawns): At extreme densities (100+ orbs spawning in a Boss-summon AOE), each orb's `_process()` per-frame radius scan becomes O(N×P) where P = number of Players (always 1 in this game, so O(N)). Cost is still low (~100 ops/frame at N=100), but instantiation/free churn could thrash. **Resolution candidate**: introduce an ObjectPool for ExperienceOrb if `/perf-profile` shows orb churn in top hot-paths. **Owner**: performance-analyst. **Target**: post-`/perf-profile`.
- **OQ-4** (Lost-XP feedback): if an orb expires (Formula 4, 30s lifetime exceeded), there's no visual cue to the player ("you let one go"). Add a fade-out or shrink animation in the last 2-3 seconds of lifetime to telegraph imminent expiration? **Resolution candidate**: yes, add subtle alpha fade in last 3s. Owned by Combat Feedback or VFX GDD when those land. **Owner**: ux-designer + technical-artist. **Target**: VFX GDD (PL-02) when authored.
- **OQ-5** (XP magnet upgrade): a common Survivor-genre upgrade is "all orbs on screen rush to player". Currently no such mechanic exists; could be a high-tier upgrade in the Level Up pool. Would require an explicit "magnet active" state on each orb. **Resolution candidate**: defer to Level Up & Upgrade Pool GDD (FT-05) authoring. **Owner**: economy-designer + game-designer. **Target**: Level Up GDD.

---

## Registry Updates Recorded

**Cross-doc consistency**:
- Enemy `xp_drop_value` values per `entities.yaml`: Paper Doll 3.5 ✅, Wandering Soul 5.5 ✅, Fox Spirit 6.0 ✅, Ghost Flame 6.0 ✅, Stone Golem 12.0 ✅, Shanxiao Elite 22.0 ✅, Famine Beast 0 ✅ — all match `.tres` files
- ExperienceOrb defaults: `xp_value = 5.0` (overridden per-spawn), `lifetime_seconds = 30.0`, `pickup_radius = 34.0` — code constants, not in entities.yaml (consider registering if cross-doc references emerge)

No new `entities.yaml` formulas added (the formulas here are simple extensions of Player GDD's already-registered formulas).

## Revision Log

| Revision | Date | Trigger | Summary |
|---|---|---|---|
| 0 | 2026-05-25 | Initial reverse-doc by /design-system | First pass authored from `scripts/system/experience_orb.gd` (76 lines, full read) + `ExperienceOrb.tscn` config + Player GDD Formula 3/4 references + Combat GDD Core Rule 4 (died signal contract). 8 required CCGS sections + Open Questions + Registry Updates. Documents dual-detection mechanism (body_entered signal + per-frame radius scan) honestly. Flags 5 OQs including the Pickup System refactor (OQ-1) and the pickup-radius formula divergence with Player GDD (OQ-2). 12 ACs cover spawn, collection (both detection paths), lifetime expiration, one-shot guard, defensive filters, cross-system integration. |
