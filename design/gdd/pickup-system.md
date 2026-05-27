# Pickup System

> **Status**: Designed (revision-0, awaiting independent /design-review)
> **Author**: claude (reverse-documented from `scripts/system/experience_orb.gd` dual-detection pattern; Pickup is a planned service abstraction not yet centralized in code)
> **Last Updated**: 2026-05-25
> **Implements Pillar**: Pillar 2 (auto-battle — pickups auto-collect, player just walks; no manual interaction)
> **TR Coverage**: TR-core-003 (auto-collect when player enters pickup radius)
> **Layer**: Feature (depends on Player position + radius bonus)

## Overview

The Pickup System is the **proximity-based auto-collection service** that turns any "collectable" world object (XP orbs today; future health pickups, gold drops) into player-acquired resources. The contract: a "Pickup" is anything in the scene tree with a position and a value that auto-collects when the Player walks within a calculated effective radius.

**Honest current-state finding (revision-0 reverse-doc audit, 2026-05-25)**: There is **no centralized Pickup service** in the v0.4 code. The only pickup type that exists (`ExperienceOrb` per Experience GDD FT-04) implements its own dual-detection mechanism. This GDD's design intent is the eventual contract: a `Pickup` interface (or AutoLoad service) that future pickup types (HealthOrb, GoldDrop) can implement consistently. The v0.4 code has not yet been refactored to that abstraction.

This is **OK for v0.4** — there's only one pickup type (XP orbs), so the duplication-risk doesn't exist yet. The GDD locks the *contract* so when HealthOrb / GoldDrop are added, the pattern is pre-agreed.

Reference: ADR-0001 (Godot 4.x — Area2D + groups), Experience GDD (FT-04 — the only consumer in v0.4).

## Player Fantasy

Pickup is the **invisible reward delivery layer**. The player walks through the battlefield; little orbs / drops appear in their wake and disappear into them as they pass. The player never thinks "I need to press F to pick up" — they just move, and the rewards happen.

When Pickup works invisibly, the player feels:
- **Movement is its own reward** — every step has potential value to grab
- **Loss aversion** — orbs near a far edge create gentle pulls; the player wants to chase them
- **Effortless growth** — XP and (future) other resources accrue without conscious effort

Anti-fantasy: pickups that require button-press, orbs that "stick" to enemies and require precise positioning, or pickup radius that feels stingy.

## Detailed Rules

### Core Rules

1. **A Pickup is any node satisfying the Pickup contract**: positioned in world space, has a payload value, auto-collects when Player enters effective radius. Currently the only implementing class is `ExperienceOrb` (per Experience GDD FT-04).

2. **Auto-collection happens via dual detection** (matching v0.4 ExperienceOrb pattern):
   - **Engine signal**: Pickup's Area2D `body_entered(body)` fires when Player's collision shape enters
   - **Per-frame scan**: Pickup's `_process(delta)` calls a radius check for Players in scene-tree group `"player"`
   Both paths needed — signal catches collision-precise entry, scan catches expanded `pickup_radius_bonus` upgrade case.

3. **Pickup eligibility check** (Player-side guards): a body is a valid pickup target if:
   - `body.is_in_group("player")` AND
   - `body.has_method(collection_method_name)` (currently `"gain_experience"`; future would be `"gain_health"`, `"gain_gold"`)

4. **One-shot collection guard**: each Pickup tracks `_is_collected: bool`. Once true, all subsequent collection attempts silently no-op. After collection, Pickup `queue_free`s immediately.

5. **Pickup radius is sum of pickup-side and Player-side** (per Experience GDD Formula 2): `effective_radius = pickup.pickup_radius + max(player.get_pickup_radius_bonus(), 0)`. Clamped `MIN_PICKUP_RADIUS = 1.0`.

6. **Pickup lifetime is per-instance**: each pickup has `lifetime_seconds`. If not collected, `queue_free` without crediting. Currently 30s for XP orbs.

7. **Pickups are scene-tree-bound** — on scene transition, all uncollected pickups destroyed with parent scene.

8. **Pickup spawn is owned by the producer system**, not Pickup itself. ExperienceOrb spawned by Enemy.died → Experience GDD logic. Pickup System defines only the collection contract; spawn is each producer's responsibility.

### Pickup Type Inventory

| Pickup Type | Spawned By | Effect | Implementation |
|---|---|---|---|
| `ExperienceOrb` (FT-04) | Enemy.died | `Player.gain_experience(xp_value)` | ✅ Implemented in `experience_orb.gd` |
| `HealthOrb` (planned) | Elite/Boss death OR `.tres` drop table | `Player.gain_health(amount)` | ❌ Not implemented; future Loot GDD |
| `GoldOrb` (planned, post-MVP economy) | All enemies (drop chance) | `Player.gain_gold(amount)` | ❌ Not implemented |
| `WeaponPickup` (speculative) | Special event spawns | Replace active weapon | ❌ Speculative |

### Interactions with Other Systems

| System | Direction | Interface |
|---|---|---|
| **Experience & Progression** (FT-04) | Experience → Pickup | Spawns ExperienceOrbs; Pickup's collection triggers `Player.gain_experience()` |
| **Player** (C-01, Approved) | Pickup → Player | Reads `Player.get_pickup_radius_bonus()`; calls type-specific method |
| **Enemy** (C-04, Approved) | Enemy → Experience → Pickup | Indirect — Enemy death triggers orb spawn via Experience system |
| **Run State** (F-03, Approved) | Independent | Pickups are scene-bound, destroyed on scene end |

## Formulas

### Formula 1: Effective pickup radius (delegated to Experience GDD Formula 2)

```
effective_radius = pickup.pickup_radius + max(player.get_pickup_radius_bonus(), 0)
effective_radius_squared = effective_radius²
```

Same formula as Experience GDD Formula 2. When other pickup types are added, this stays canonical.

### Formula 2: Dual-detection state transitions

```
on _ready():
    body_entered.connect(_on_body_entered)
    call_deferred(_try_collect_overlapping_bodies)   # spawn-into-player case

on body_entered(body):
    _try_collect(body, require_radius_check=false)

on _process(delta):
    if _is_collected: return
    _elapsed_lifetime += delta
    if _elapsed_lifetime >= lifetime_seconds:
        queue_free(); return
    for player in get_tree().get_nodes_in_group("player"):
        _try_collect(player, require_radius_check=true)

on _try_collect(body, require_radius_check):
    if _is_collected: return
    if not body.is_in_group("player"): return
    if not body.has_method(collection_method_name): return
    if require_radius_check:
        if distance_squared > effective_radius_squared(body):
            return
    _is_collected = true
    body.call(collection_method_name, value)
    queue_free()
```

The canonical Pickup pattern. Future pickup types implement this same shape, varying only `collection_method_name` and `value` fields.

## Edge Cases

- **If Player walks past a Pickup faster than collision detection** (high speed + small Player collision shape): per-frame radius scan catches it next frame. Dual-detection is robust.
- **If two Pickups stacked at same position**: each has own `_is_collected` guard; both collect independently.
- **If a Pickup spawns directly on the Player**: `call_deferred(_try_collect_overlapping_bodies)` in `_ready()` triggers collection next frame.
- **If Player `_is_dead = true` when Pickup triggers**: Pickup calls collection method; Player-side method early-returns; Pickup still `queue_free`s. Per Player GDD AC-12.
- **If Pickup's `pickup_radius = 0`**: clamped to `MIN_PICKUP_RADIUS = 1.0`. Defensive minimum.
- **If `lifetime_seconds = 0` or negative**: clamped to `MIN_LIFETIME_SECONDS = 0.1`. Effectively no-op spawn.
- **If non-Player Node2D in collision shape**: filtered by `is_in_group("player")` guard. No collection, no error.
- **If future pickup type's collection method doesn't exist on Player**: `has_method` guard prevents call. Silent skip (could add push_warning in dev builds).
- **If 100+ pickups exist simultaneously** (mass spawn): each runs `_process(delta)` per frame. ~500 ops total, negligible at 60 FPS. Pooling deferred per Experience GDD OQ-3.

## Dependencies

| Dependency | Type | Direction | Interface |
|---|---|---|---|
| **Player** (C-01, Approved) | Hard | Pickup → Player | `get_pickup_radius_bonus()`, type-specific collection methods |
| **Experience & Progression** (FT-04, Approved) | Hard | Bidirectional | Experience spawns ExperienceOrbs; Pickup's collection triggers Experience pipeline |
| **Resource Data Framework** (F-02, Approved) | Soft | Pickup reads | Future pickup `.tres` definitions |
| **Godot 4.6 engine** | Hard | (implicit) | Area2D, CircleShape2D, body_entered signal |

**Downstream consumers:**

| Consumer | Status | Interface |
|---|---|---|
| **ExperienceOrb** (FT-04) | ✅ Currently implementing Pickup pattern | Hard-coded; will refactor to Pickup contract when service extracted |
| **HealthOrb** (future) | ⏳ Will implement | Same dual-detection, different collection method |
| **GoldOrb** (post-MVP) | ⏳ Will implement | Same |

**Bidirectional check:**
- Experience GDD lists Pickup as "Pickup System (FT-12, future) | Soft (current)" ✅ — this GDD resolves Experience's OQ-1
- Player GDD lists "Pickup System (FT-12) | Soft | Pickup → Player | Reads `get_pickup_radius_bonus()`" ✅

## Tuning Knobs

| Knob | Owner | Design-safe range | Default | Effect at extremes |
|---|---|---|---|---|
| `Pickup.pickup_radius` (per-instance) | Each pickup `.tres` or scene | 20 – 80 px | 34 (ExperienceOrb) | <20 = sticky-only; >80 = trivializes |
| `Pickup.lifetime_seconds` | Each pickup | 10 – 60 s | 30 (ExperienceOrb) | <10 = stress; >60 = clutter |
| `Player.pickup_radius_bonus` | Player.tscn / upgrades | 0 – 100 px | 0 | Stacks via upgrades (per Player GDD Formula 5) |
| `MIN_PICKUP_RADIUS` | engine constant | 1.0 | 1.0 | NOT a tuning knob; floor |
| `MIN_LIFETIME_SECONDS` | engine constant | 0.1 | 0.1 | NOT a tuning knob |

Pickup-system-owned tuning is just floor constants. Per-pickup defaults owned by each pickup type's GDD.

## Acceptance Criteria

**AC-01** **GIVEN** Pickup at (50, 50) with `pickup_radius = 34` AND Player at (60, 60), **WHEN** Player's collision enters Pickup's Area2D, **THEN** `body_entered` fires → collection method called → Pickup `queue_free`s.

**AC-02** **GIVEN** Pickup at (100, 100) AND Player at (170, 100) (distance 70 px) AND Player's `pickup_radius_bonus = 50`, **WHEN** `_process` runs, **THEN** effective_radius = `84`, distance check passes, collection fires via radius-scan path.

**AC-03** **GIVEN** Pickup at (200, 200) AND Player at (400, 400) (~283 px), `pickup_radius_bonus = 50`, **WHEN** scan runs, **THEN** NO collection (effective_radius 84 << 283).

**AC-04** **GIVEN** simultaneous `body_entered` + per-frame scan in same frame, **WHEN** both attempt collection, **THEN** collection method called exactly ONCE (per `_is_collected` flag).

**AC-05** **GIVEN** Pickup with `lifetime_seconds = 30`, **WHEN** 30s elapse without collection, **THEN** Pickup `queue_free`s AND collection method NEVER called.

**AC-06** **GIVEN** non-Player Node2D in Pickup's collision, **WHEN** `body_entered` fires, **THEN** Pickup does NOT collect (per `is_in_group("player")` guard) AND no error.

**AC-07** **GIVEN** future pickup with `collection_method = "gain_health"` AND Player without `gain_health` method, **WHEN** collection attempts, **THEN** `has_method` guard catches missing method AND Pickup does NOT call AND does NOT `queue_free`.

**AC-08** **GIVEN** Wandering Soul dies → ExperienceOrb spawns → Player walks into radius → Pickup → `gain_experience(5.5)` → Player crosses level threshold, **WHEN** chain completes, **THEN** `level_reached(N)` fires per Player GDD Formula 4 AND Pickup `queue_free`d AND HUD updates.

**AC-09** **GIVEN** Pickup spawns directly under Player's collision shape, **WHEN** `_ready()` `call_deferred`s `_try_collect_overlapping_bodies`, **THEN** on next frame Pickup detects overlap and collects.

**AC-10** (reserved — activates when HealthOrb/GoldOrb added): **GIVEN** central Pickup service (OQ-1) extracted, **WHEN** new pickup types are added, **THEN** they implement same Formula 2 pattern with only `collection_method_name` and `value` varying.

## Open Questions

- **OQ-1** (Extract central Pickup service): dual-detection pattern is currently inline in `experience_orb.gd`. When HealthOrb / GoldOrb added, should not re-implement 60 lines. **Resolution**: create `scripts/system/pickup_base.gd` (`class_name PickupBase extends Area2D`) with detection logic; ExperienceOrb and future pickups extend it. **Owner**: lead-programmer. **Target**: when second pickup type added.
- **OQ-2** (Pickup radius formula divergence with Player GDD): Player GDD Formula 5 says `CharacterBase.pickup_radius + bonus` (50 + bonus for 修行者). This GDD's Formula 1 says `pickup.pickup_radius + bonus` (34 + bonus). The two GDDs describe different radii. **Resolution**: clarify in revision-1 OR resolve in Pickup service extraction. **Owner**: systems-designer.
- **OQ-3** (XP magnet upgrade): common Survivor upgrade "all orbs rush to player". Currently no Pickup movement. **Resolution**: in future Pickup service as opt-in behavior; triggered by Player-emitted `magnet_active` signal. **Owner**: economy-designer.
- **OQ-4** (Pickup pool): mass spawn churn. Same as Experience OQ-3. **Resolution**: ObjectPool if `/perf-profile` shows churn.
- **OQ-5** (Health/Gold/Weapon types): placeholders; future Loot GDD authoring.

## Registry Updates Recorded

No new `entities.yaml` entries — Pickup is infrastructure; entity values are owned by producing systems' GDDs.

**Cross-doc consistency**: Experience GDD lists Pickup as Soft dependency ✅. Player GDD Formula 5 + Experience GDD Formula 2 + Pickup GDD Formula 1 all describe same pattern (with OQ-2 divergence noted).

## Revision Log

| Revision | Date | Trigger | Summary |
|---|---|---|---|
| 0 | 2026-05-25 | Initial reverse-doc | First pass from `experience_orb.gd` dual-detection pattern. 8 required sections + Open Questions + Registry Updates. **Honest finding**: no centralized Pickup service; pattern lives inline in ExperienceOrb. OQ-1 tracks future refactor; OQ-2 acknowledges formula divergence with Player GDD. 10 ACs cover collection contract, one-shot guard, lifetime, type guards, cross-system integration, future-pickup placeholder. Resolves Experience GDD OQ-1. |
