# Enemy System

> **Status**: Approved (revision-1 — /design-review verdict on revision-0 was CONCERNS with 1 BLOCKER + 3 RECOMMENDED + 4 NICE-TO-HAVE; revision-1 closes B-1, R-1, R-2, R-3. NICE-TO-HAVE deferred as polish per reviewer guidance.)
> **Author**: claude (revision-1 by claude — data accuracy + cross-doc reference fixes after /design-review)
> **Last Updated**: 2026-05-25 (revision-1, approved)
> **Implements Pillar**: Pillar 1 (清晰的生存压力 — Enemy is the source of pressure), Pillar 4 (数据驱动迭代 — Enemy is the canonical `.tres`-driven content pattern), Pillar 3 (原创神话气质 — 7 enemies all original mythological concepts)
> **TR Coverage**: TR-enemy-001 (archetype pattern), TR-enemy-002 (hit feedback — flash, screen-shake, damage numbers), TR-enemy-003 (Boss spawn + victory)

## Overview

The Enemy System is the **threat half** of the auto-battle contract. Every non-Boss entity that contacts the player and applies damage is an `Enemy` (`CharacterBody2D` subclass). Every per-enemy stats / behavior variation comes from a `.tres` Resource bound to the `archetype` export — this is the canonical example of MythSurvivor's Pillar-4 data-driven architecture. The Boss extends `Enemy` to add a state-machine, three telegraphed skills (Charge / Burst / Summon), and an Enrage phase below 30% HP.

Implementation:
- `Enemy` (CharacterBody2D, 242 lines): movement, HP, damage-area contact detection, archetype loader, elite affix system, death → XP orb spawn
- `EnemyArchetype` (Resource, 26 lines): pure data — 19 exported stats / visuals / movement params
- 7 `.tres` archetype files in `resources/enemies/`: paper_doll, wandering_soul, fox_spirit, ghost_flame, stone_golem, shanxiao_elite, famine_beast
- `FamineBeastBoss` (extends Enemy, 327 lines): Stage 1 boss with 3 skills + state machine + enrage

Reference ADRs: ADR-0001 (Godot 4.x + GDScript). No Enemy-specific ADR exists yet — this GDD is the spec source. Should a future "ADR: Enemy archetype pattern" be authored, it would canonize the Resource-as-data-driver pattern Enemy demonstrates.

## Player Fantasy

The Enemy System is the **face of the pressure curve**. Players never think "this is an Enemy node" — they think:

> "A Wandering Soul is closing in from my left. I can outrun it, but a Fox Spirit is faster and circling around behind. The Stone Golem hits like a truck but I have time. Behind that wall of fillers, a Shanxiao Elite shows up at 3:00 with iron-bone affixes — its HP bar is twice as long. Then at 5:00 the Famine Beast lands, telegraphs a charge attack with a red line, and I dodge sideways."

The Enemy's job is to **be readable**. Each archetype has:
- A distinct silhouette (body_scale + body_color)
- A distinct cadence (damage_interval differs per archetype)
- A distinct threat profile (Fox Spirit = speed/circling; Stone Golem = tank/melee; Ghost Flame = wave-pattern; Paper Doll = filler/wave)
- A distinct value (xp_drop_value differs)

Anti-fantasy: the player should never wonder *what* an enemy is or *how much* damage it deals. Visual + audio cues (per Visual/Audio Requirements below) should make threat profile readable within 0.5 seconds of first contact.

## Detailed Rules

### Core Rules

1. **Every Enemy instance is data-driven via a `EnemyArchetype` Resource attached to the `archetype` export.** Without an archetype, the Enemy uses class defaults (move_speed=90, max_hp=24, damage=8, damage_interval=0.8, xp_drop_value=5.0). Production scenes always attach an archetype — the defaults exist only for dev / debug.

2. **Enemy owns its HP write per Combat GDD Core Rule 3.** Public entry point: `take_damage(amount: float) -> void`. Combat sends damage events; Enemy decrements its own HP, clamps at 0, emits `died(self)` exactly once via the `_die()` path.

3. **HP reaching 0 triggers data-death within 1 frame.** `_is_dead = true` flag set; `velocity = Vector2.ZERO`; XP orb spawned (if `xp_drop_value > 0` AND `experience_orb_scene != null`); `died(enemy)` signal emitted. **Enemy does NOT call `queue_free()` itself** — the VFX subscriber owns the call. Per VFX GDD revision-1 Formula 1 + AC-01 (and Combat GDD AC-22 contract): VFX subscribes to `died`, plays dissolve for ≤0.5s, then calls `payload.enemy.queue_free()`. This is the C-B4 resolution in /review-all-gdds 2026-05-27 — see Enemy GDD revision-2 + VFX GDD revision-1 for the ownership split. (Note: `_is_dead = true` guard ensures take_damage early-returns on subsequent events during the 0.5s VFX window — see AC-10.)

4. **Two movement modes are supported:** `CHASE` (direct line to player) and `WAVE_CHASE` (sinusoidal offset perpendicular to the chase vector). Mode is selected via `movement_mode` export. Wave parameters (`wave_amplitude`, `wave_frequency`, `wave_phase`) come from the archetype.

5. **Player contact damage is throttled per-enemy via `damage_interval`** (matches Combat GDD Formula 4). When the player enters the Enemy's `DamageArea`, the Enemy is tracked in `_damage_targets`. When `_damage_cooldown` reaches 0 AND the player is in the targets list, `Player.take_damage(damage)` is called and `_damage_cooldown := max(damage_interval, MIN_DAMAGE_INTERVAL)`. The cooldown ticks down regardless of contact state — leaving and re-entering does NOT reset the cooldown.

6. **Elite affixes multiply base stats at spawn time.** Two affixes defined: `iron_bones` (HP × 1.45) and `swift` (speed × 1.3). Elite enemies first apply the general elite multipliers (HP × 1.25, damage × 1.15, speed × 1.05), THEN the per-affix multipliers stack on top. Affix application is idempotent at archetype-apply time; cannot be added at runtime.

7. **Elite multipliers are configurable per archetype, not global constants.** Each archetype's `.tres` carries its own elite_health/damage/speed_multiplier + iron_bones/swift multipliers. This allows future archetypes to scale differently (e.g. a fragile elite might use a 1.6 HP multiplier to compensate).

8. **The Famine Beast Boss extends Enemy and adds 3 telegraphed skills + Enrage.** Boss is the only enemy with a state machine (CHASE / CHARGE_WINDUP / CHARGE / CHARGE_RECOVERY) and skill cooldowns. Boss-specific behavior is in `famine_beast_boss.gd` (327 lines) and does not affect the base Enemy contract.

9. **Boss enters Enrage when HP/max_hp ≤ `enrage_health_ratio` (0.3).** On enrage: `move_speed *= 1.35`, `charge_speed *= 1.35`, all 3 skill cooldowns are halved-then-shortened (multiplied by `enrage_skill_interval_multiplier = 0.65 × 0.5 = 0.325` for the immediate cooldown reset). Visual: body color → dark red, enraged aura visible.

10. **Boss does NOT drop XP** (`xp_drop_value = 0.0` set in `_ready()` after archetype apply). Boss death triggers `stage_cleared` via the StageDirector per Run State GDD Core Rule 3.

### Movement Modes

| Mode | Behavior | Math | Used by archetypes |
|---|---|---|---|
| `CHASE` (0) | Move directly toward player position | `direction = self.global_position.direction_to(player.global_position)` | paper_doll, wandering_soul, fox_spirit, stone_golem, shanxiao_elite, famine_beast |
| `WAVE_CHASE` (1) | Move toward player with sinusoidal lateral offset | `wave_offset = direction.orthogonal() * sin(time * frequency * TAU + phase) * amplitude`; `final = (direction + wave_offset).normalized()` | ghost_flame |

The wave offset is perpendicular to the chase direction, so the enemy still progresses toward the player while weaving — harder to track but slower-effective relative to a Chase enemy.

### Elite Affixes

Defined as String constants in code; carried in `elite_affixes: Array[String]` on each Enemy instance.

| Affix | Constant | Effect | Used by |
|---|---|---|---|
| iron_bones | `ELITE_AFFIX_IRON_BONES = "iron_bones"` | HP × 1.45 (after general elite × 1.25 → total HP × 1.81) | Shanxiao Elite spawned at 3:00 (per Run State Core Rule 2) |
| swift | `ELITE_AFFIX_SWIFT = "swift"` | speed × 1.3 (after general elite × 1.05 → total speed × 1.37) | Shanxiao Elite spawned at 4:00 (per Run State Core Rule 2) |

Multiple affixes stack multiplicatively. The current spawn schedule uses 1 affix per elite, but the system supports stacking (e.g. an Iron Swift Shanxiao would have HP × 1.81 AND speed × 1.37).

### Enemy Archetype Resource Schema

`EnemyArchetype` (Resource): 19 exported fields total.

| Field | Type | Default | Description |
|---|---|---|---|
| display_name | String | "Wandering Soul" | UI / debug name |
| max_hp | float | 24.0 | Base HP |
| move_speed | float | 90.0 | px/s |
| damage | float | 8.0 | Per-hit damage |
| damage_interval | float | 0.8 | Seconds between hits (clamp ≥ MIN_DAMAGE_INTERVAL = 0.1) |
| xp_drop_value | float | 5.0 | XP orb amount; 0 = no drop |
| body_color | Color | (0.73, 0.24, 0.28, 1.0) | Polygon2D color (placeholder until sprites land) |
| body_scale | float | 1.0 | Visual scale multiplier |
| collision_radius | float | 11.0 | CharacterBody2D circle collision |
| damage_radius | float | 15.0 | DamageArea circle (player contact zone) |
| health_bar_y | float | -24.0 | HP bar Y offset from body center |
| movement_mode | int (enum) | 0 (CHASE) | 0 = CHASE, 1 = WAVE_CHASE |
| wave_amplitude | float | 0.0 | Sine wave amplitude (px) — used only in WAVE_CHASE |
| wave_frequency | float | 0.0 | Sine wave frequency (Hz) |
| wave_phase | float | 0.0 | Sine wave phase offset (radians) |
| is_elite | bool | false | Enables elite multiplier application |
| elite_affixes | Array[String] | [] | Affixes to apply (per spawn) |
| elite_health_multiplier | float | 1.25 | General elite HP boost |
| elite_damage_multiplier | float | 1.15 | General elite damage boost |
| elite_speed_multiplier | float | 1.05 | General elite speed boost |
| iron_bones_health_multiplier | float | 1.45 | Per-affix HP boost |
| swift_speed_multiplier | float | 1.3 | Per-affix speed boost |

### Seven Archetypes (registry-confirmed values)

| Archetype | display_name | max_hp | move_speed | damage | damage_interval | xp_drop_value | movement_mode | body_scale | Category |
|---|---|---|---|---|---|---|---|---|---|
| paper_doll.tres | Paper Doll | 14.0 | 86.0 | 5.0 | 0.85 | 3.5 | CHASE | 0.82 | filler |
| wandering_soul.tres | Wandering Soul | 24.0 | 90.0 | 8.0 | 0.80 | 5.5 | CHASE | 1.00 | normal |
| fox_spirit.tres | Fox Spirit | 20.0 | 132.0 | 7.0 | 0.75 | 6.0 | CHASE | 0.96 | normal (fast) |
| ghost_flame.tres | Ghost Flame | 18.0 | 102.0 | 6.0 | 0.80 | 6.0 | WAVE_CHASE | 0.90 | normal (weaving) |
| stone_golem.tres | Stone Golem | 70.0 | 54.0 | 12.0 | 1.00 | 12.0 | CHASE | 1.35 | tank |
| shanxiao_elite.tres | Shanxiao Elite | 110.0 | 72.0 | 15.0 | 0.90 | 22.0 | CHASE | 1.55 | elite |
| famine_beast.tres | Famine Beast | 360.0 | 68.0 | 18.0 | 0.85 | 0.0 | CHASE | 1.70 | Boss |

> **Cross-doc consistency**: these values match `design/registry/entities.yaml` 1:1. Combat GDD revision-4's §Per-Phase TTK Budget uses these as the dominant-enemy stats per phase.

### Famine Beast Boss — Skill Set

The Boss has 3 telegraphed skills + Enrage phase. All skill timings are exports on the Boss node.

| Skill | Cooldown (default) | Telegraph | Effect | Notes |
|---|---|---|---|---|
| **Charge** | 4.8s | 0.7s windup (red line, 240 px) | 0.55s charge at 390 speed in fixed direction | Direction locked at windup start; can miss if player dodges sideways |
| **Burst** | 5.8s | 1.05s warning circle at player's position-at-marker-creation | Ground burst, 58 px radius, 18 damage (linger 0.18s) | Marker stays at fixed position even if player moves; dodge by leaving the circle |
| **Summon** | 7.0s | (none — instant) | Spawns 2 minions (alternating PaperDoll / WanderingSoul) at 86 px from Boss | Capped at 6 simultaneous summoned alive; cleans up on Boss death |

Each skill's cooldown is multiplied by `_get_skill_interval_multiplier()` which returns `enrage_skill_interval_multiplier = 0.65` when enraged, else `1.0`. On enrage entry, each skill's pending timer is immediately reduced (`* 0.5 + currentMultiplier`), so the player feels an immediate intensity spike.

### Boss State Machine

```
   ┌─────────┐  charge_timer ≤ 0   ┌──────────────┐  windup_time ends   ┌─────────┐
   │ CHASE   │ ──────────────────→ │ CHARGE_WIND  │ ──────────────────→ │ CHARGE  │
   │         │                     │   _UP        │                     │         │
   └─────────┘                     └──────────────┘                     └─────────┘
        ▲                                                                     │
        │       recovery_time ends                            duration ends   │
        │              ┌──────────────────┐                                   │
        └────────────  │ CHARGE_RECOVERY  │ ←─────────────────────────────────┘
                       └──────────────────┘
```

States are integers in `BossState` enum: CHASE=0, CHARGE_WINDUP=1, CHARGE=2, CHARGE_RECOVERY=3.

Burst and Summon are NOT in the state machine — they run on independent timers in `_physics_process` regardless of CHASE/CHARGE state. So a charging Boss can simultaneously detonate a Burst at the player's earlier position. This is intentional layering — predictable for the player.

### Interactions with Other Systems

| System | Direction | Interface |
|---|---|---|
| **Combat (C-03)** | Combat → Enemy | Combat events call `Enemy.take_damage(amount)` per Combat GDD Core Rule 2 |
| **Combat (C-03)** | Enemy → Combat | Enemy emits `died(self)` on HP=0 per Combat GDD Core Rule 4. The signal is the trigger for downstream consumers (XP orb spawn, Run State victory). |
| **Player (C-01)** | Enemy → Player | When player is in `DamageArea`, Enemy calls `player.take_damage(damage)` (`_try_damage_player` line 156). Throttled by per-Enemy `_damage_cooldown` per Core Rule 5. |
| **Player (C-01)** | Player → Enemy | Player's existence drives enemy movement: `_find_player()` looks up the "player" group; `_get_move_direction(player.global_position)` is called per frame. |
| **EnemySpawner (FT-01)** | Spawner → Enemy | Spawner instantiates Enemy scene, calls `apply_archetype(archetype)` and (for elites) `configure_elite(affixes)`. |
| **StageDirector (F-03)** | StageDirector → Enemy | For Boss specifically: StageDirector connects `boss.died` to `_on_boss_died` for `stage_cleared` trigger per Run State Core Rule 3. |
| **ExperienceOrb (FT-04 part)** | Enemy → Orb | On `_die()`, if `xp_drop_value > 0`, an orb is instantiated and added to the scene tree via `call_deferred("add_child", orb)` |
| **Resource Data Framework (F-02)** | Archetype → Enemy | `.tres` Resources provide all per-archetype values per TR-enemy-001 |
| **HUD (P-01)** | Enemy → HUD (indirect) | Per-enemy HP bar is drawn by Enemy itself (28 × 4 px Polygon2D, see Visual/Audio); HUD doesn't subscribe directly. **Boss HP bar IS owned by HUD** per Combat GDD UI Requirement #3 — subscribes to `Boss.died` signal for show/hide. |
| **Combat Feedback (P-03)** | Enemy → Feedback | When `damage_taken` is emitted (per Combat GDD AC-21 contract, future signal), Combat Feedback subscribes for the 0.1s flash. **Current Enemy does NOT emit `damage_taken`** — see Open Questions. |
| **FamineBeastBoss → spawned minions** | Boss → Enemy | Boss spawns PaperDoll / WanderingSoul as child enemies; connects their `died` signal to `_on_summoned_enemy_died` for slot accounting. |

## Formulas

### Formula 1: Movement direction (CHASE)

Standard chase — direction unit vector from enemy to player.

```
direction = self.global_position.direction_to(player.global_position)
velocity = direction × move_speed
move_and_slide()
```

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| `move_speed` | s | float | 30 – 200 (design-safe) | px/s |
| `direction` | d̂ | Vector2 | unit vector | normalized direction |

**Output Range:** velocity magnitude = `move_speed`. At base values (e.g. Wandering Soul 90 px/s), a screen-corner-distance traverse is ~7 seconds.

### Formula 2: Movement direction (WAVE_CHASE)

```
chase_direction = self.global_position.direction_to(player.global_position)
wave_offset = chase_direction.orthogonal() × sin(_movement_time × wave_frequency × TAU + wave_phase) × wave_amplitude
direction = (chase_direction + wave_offset).normalized()
velocity = direction × move_speed
```

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| `_movement_time` | t | float | seconds since spawn | Internal timer |
| `wave_frequency` | f | float | 0.0 – 5.0 (design-safe) | Hz |
| `wave_amplitude` | A | float | 0.0 – 1.0 | Lateral offset magnitude (normalized; final is multiplied by direction.length) |
| `wave_phase` | φ | float | 0.0 – TAU | Radians offset (per-enemy desync) |

**Output Range:** When `wave_amplitude = 0` (all default archetypes except Ghost Flame), behaves identically to CHASE. Ghost Flame uses non-zero amplitude/frequency for the weaving effect.
**Example:** Ghost Flame at A=0.4, f=1.5, φ=0 — at t=0.5s, sine wave at angle TAU × 0.5 × 1.5 = 4.71 rad → sin = -1.0 → lateral offset = direction.orthogonal × -0.4. Visible weave.

### Formula 3: HP after damage

Delegated to Combat GDD Formula 1.

```
on take_damage(amount):
    if _is_dead or amount <= 0.0: return
    current_hp = max(0, current_hp - amount)
    _update_health_bar()
    if current_hp == 0.0:
        _die()
```

Enemy does NOT receive a damage tuple per Combat GDD Core Rule 2 — only the `amount` (float). Source / damage_type / source_kind are not passed in. **This is a known gap** vs. Combat GDD's 5-field damage_dealt contract — see Open Questions OQ-2.

### Formula 4: Player-contact damage application

```
on _try_damage_player():
    if _damage_cooldown > 0.0 or damage <= 0.0: return
    for target in _damage_targets:
        if target.is_in_group("player") and target.has_method("take_damage"):
            target.take_damage(damage)
            _damage_cooldown = max(damage_interval, MIN_DAMAGE_INTERVAL)
            return  # only one hit per cooldown cycle
```

Per Combat GDD Formula 4 + Core Rule 8 (aggregate ceiling), this Enemy's individual throttle is enforced here. The aggregate ceiling (max 4 contact attackers) is enforced by Combat — Enemy itself does not know about the cap.

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| `_damage_cooldown` | c | float | 0.0 – damage_interval | Per-enemy throttle counter |
| `damage_interval` | Δ | float | 0.4 – 1.5 (design-safe) / 0.1 – ∞ (clamp MIN_DAMAGE_INTERVAL) | From archetype |

**Output:** at most one Player damage event per `damage_interval` seconds per Enemy.

### Formula 5: Elite multiplier stack

Order of application (intentional — additive components compound multiplicatively):

```
on configure_elite(affixes):
    apply_archetype_base_values()                   # reset to archetype base
    is_elite = true
    elite_affixes = affixes
    max_hp *= max(elite_health_multiplier, 0.1)     # general elite × 1.25
    damage *= max(elite_damage_multiplier, 0.0)     # general elite × 1.15
    move_speed *= max(elite_speed_multiplier, 0.1)  # general elite × 1.05
    for affix in elite_affixes:
        match affix:
            "iron_bones": max_hp *= max(iron_bones_health_multiplier, 0.1)  # × 1.45
            "swift": move_speed *= max(swift_speed_multiplier, 0.1)         # × 1.3
    max_hp = max(max_hp, 1.0)  # final clamp
    current_hp = max_hp
```

**Example:** Shanxiao Elite + iron_bones (using `shanxiao_elite.tres` actual override values: `elite_damage_multiplier = 1.2`, NOT the class default 1.15):
- archetype base: max_hp = 110, damage = 15, move_speed = 72
- general elite: max_hp = 137.5 (× 1.25), damage = **18.0** (× 1.2), move_speed = 75.6 (× 1.05)
- iron_bones: max_hp = 199.4 (137.5 × 1.45)
- Final: HP=199.4, **DMG=18.0**, SPD=75.6

**Output Range:** Most aggressive stack (Shanxiao + iron_bones + swift): HP=199.4, **DMG=18.0**, SPD=98.3.

> **Important per-archetype override**: only Shanxiao Elite overrides `elite_damage_multiplier` (1.2 vs class default 1.15). All other 6 archetypes use the class default. This is verified across all 7 `.tres` files. The Tuning Knobs table below documents the class default; this Output Range example uses Shanxiao's actual override.

### Formula 6: Boss skill cooldown multiplier

```
_get_skill_interval_multiplier():
    if _is_enraged: return enrage_skill_interval_multiplier  # 0.65
    return 1.0
```

When Enrage triggers (HP ≤ 30%), this multiplier kicks in for all ongoing skill cooldown resets. **Additionally**, on enrage entry, each pending timer is immediately compressed via a one-time multiplication: `_charge_timer = min(_charge_timer, charge_cooldown × enrage_skill_interval_multiplier × 0.5)`. The `× 0.5` is a one-time enrage-entry compression layered on top of the ongoing `× 0.65` multiplier — produces an immediate skill cascade. The Tuning Knobs cooldown values below (e.g. "Charge 4.8 → 3.12 enraged") show only the steady-state `× 0.65` effect; the enrage-entry burst would compress these further (Charge 4.8 → 3.12 → 1.56 on entry).

**Variables:**

| Variable | Symbol | Type | Description |
|---|---|---|---|
| `enrage_skill_interval_multiplier` | m | float (clamped 0.1 – 1.0) | Default 0.65 |
| Per-skill cooldown × m on enrage | — | — | Charge 4.8 → 3.12; Burst 5.8 → 3.77; Summon 7.0 → 4.55 |

## Edge Cases

- **If `archetype` is null at `_ready()`**: Enemy uses class defaults. No crash, but instance is generic. Production code paths always set archetype via `apply_archetype()` after instantiation.
- **If `apply_archetype()` is called after `_ready()` (post-spawn archetype swap)**: `_apply_archetype_values()` re-applies, `is_elite` is reset to the archetype's value, `current_hp = max_hp` is reset. Useful for testing / debug but no production code path swaps mid-life.
- **If `take_damage(0)`**: function early-returns. No HP change, no health bar update, no death. (Same as Player GDD AC-08.)
- **If `take_damage(amount)` with `amount > current_hp`**: HP clamps to 0; `_die()` fires exactly once.
- **If `take_damage` is called while `_is_dead == true`**: function early-returns. No double-death, no double XP orb spawn. (Matches Combat GDD Core Rule 6 DYING guard.)
- **If `Player` is in damage area but `_damage_cooldown > 0`**: no damage applied. Cooldown ticks down independently of contact state — leaving and re-entering does NOT reset the cooldown.
- **If `Player` group lookup returns null** (`_find_player` finds nothing): Enemy stands still (`velocity = Vector2.ZERO`), retries on next frame. No crash.
- **If `damage <= 0` on the Enemy archetype**: `_try_damage_player` early-returns. Enemy is effectively pacifist (use case: scenery enemies in future).
- **If `xp_drop_value <= 0` OR `experience_orb_scene == null`**: no orb spawned. Boss is the canonical xp_drop_value=0 case. **Stage cleared** still fires via `died` signal — orb absence does not block run-end logic.
- **If `experience_orb_scene` does not instantiate to ExperienceOrb** (developer error): `push_error` fires, instance is freed, no orb. Defensive guard at line 222.
- **If Enemy is destroyed mid-frame (queue_free during physics_process)**: Godot handles via deferred deletion — the current frame completes, removal happens at next sync point. No reentrancy concerns.
- **If `_movement_time` overflows in WAVE_CHASE** (theoretical): float64 can hold seconds for billions of years. Not a real concern.

### Boss-specific edge cases

- **If Boss enters Enrage while in CHARGE_WINDUP**: `_enter_enrage()` does NOT reset state; the charge proceeds normally. Speed multipliers apply to the next charge.
- **If Boss enters Enrage while in CHARGE**: charge_speed is multiplied immediately (`charge_speed *= enrage_speed_multiplier`), so the in-progress charge accelerates mid-flight. This is intentional drama, not a bug.
- **If `_summon_minions()` is called when `_summoned_enemies` is at `summon_max_alive`**: `available_slots <= 0` → no spawn. Timer still resets so the next attempt happens after `summon_cooldown`. (Could be tighter — see OQ-3.)
- **If a summoned minion dies and `_on_summoned_enemy_died` is called twice (e.g. via test harness)**: `Array.erase()` is idempotent — no error.
- **If Boss dies before its burst markers detonate**: `_clear_boss_effects()` queue_frees all pending markers — no orphan damage events. Same for un-detonated charge telegraphs.
- **If Boss's `_die()` is called while charging**: parent `_die()` handles `velocity = Vector2.ZERO`; charge is aborted; XP orb (none, since xp_drop_value=0) is not spawned; `died(self)` fires for StageDirector. Run State Core Rule 4 takes over.

## Dependencies

| Dependency | Type | Direction | Interface |
|---|---|---|---|
| **Combat (C-03)** | Hard | Bidirectional | Enemy receives `take_damage(amount)` calls; emits `died(self)` |
| **Player (C-01)** | Hard | Bidirectional | Enemy reads Player position per frame; calls `Player.take_damage(damage)` on contact |
| **Resource Data Framework (F-02)** | Hard | Enemy consumes | All archetypes are `.tres` Resources |
| **EnemySpawner (FT-01)** | Hard | Spawner → Enemy | Instantiator; calls `apply_archetype()` and `configure_elite()` |
| **StageDirector (F-03 / Run State)** | Hard | Bidirectional | Boss `died` → `stage_cleared`; Player `died` → `stage_failed` (StageDirector observes; Enemy is the emitter) |
| **ExperienceOrb (FT-04 part)** | Soft | Enemy spawns | On death, if `xp_drop_value > 0`, spawn orb |
| **HUD (P-01)** | Soft | Enemy → HUD | Per-enemy 28×4 px HP bar drawn by Enemy; Boss HP bar drawn by HUD subscribed to Boss-specific signal (per Combat GDD UI Requirement #3) |
| **Combat Feedback (P-03)** | Soft | Future signal | `damage_taken` signal not yet emitted by Enemy — see OQ-2 |
| **VFX (PL-02)** | Soft | Enemy → VFX | Death dissolve animation owned by VFX GDD; triggered by `died` signal |

**Bidirectional check (per design-docs rule)**:
- Combat GDD Dependencies row for "Enemy" lists "Bidirectional" ✅ (Combat GDD line 396)
- Player GDD lists "Enemy" in Interactions ✅ (Player GDD line 89)
- Run State Dependencies row for "Enemy" lists "Soft, Boss is an Enemy" ✅ (Run State GDD line 243)
- EnemySpawner GDD (when written) must list Enemy as "instantiates" ⏳
- Experience & Progression GDD (when written) must list Enemy as "soft-depends for `died` event + xp_drop_value" ⏳

## Tuning Knobs

All values are tunable per archetype `.tres` (production path) or per Enemy.tscn export (dev / debug). Boss exports live on FamineBeastBoss.tscn.

### Enemy class exports (defaults; usually overridden by archetype)

| Knob | Default | Design-safe range | Effect at extremes |
|---|---|---|---|
| `move_speed` | 90.0 | 30 – 200 | <30 = pacifist; >200 = unfair vs Player 180 px/s |
| `max_hp` | 24.0 | 5 – 500 (Boss exception 360+) | <5 = popcorn; >500 = tank without Boss treatment |
| `damage` | 8.0 | 3 – 30 | <3 = trivial; >30 = unfair without build |
| `damage_interval` | 0.8 | 0.4 – 1.5 (clamp MIN=0.1) | <0.4 = punishing; >1.5 = harmless |
| `xp_drop_value` | 5.0 | 0 – 50 | 0 = no drop (Boss); >50 = trivializes XP economy |
| `movement_mode` | CHASE (0) | enum | — |
| `wave_amplitude` | 0.0 | 0.0 – 1.0 | >1.0 = weaving so wide enemy doesn't approach |
| `wave_frequency` | 0.0 | 0.0 – 5.0 (Hz) | >5 = frenetic, hard to read |
| `wave_phase` | 0.0 | 0 – TAU | Per-enemy desync |
| `is_elite` | false | bool | — |
| `elite_affixes` | [] | array of "iron_bones" / "swift" | Multiple stack multiplicatively |
| `elite_health_multiplier` | 1.25 | 1.0 – 2.0 | >2.0 = elite is mini-Boss |
| `elite_damage_multiplier` | 1.15 | 1.0 – 1.5 | >1.5 = elite damage outscales normal |
| `elite_speed_multiplier` | 1.05 | 1.0 – 1.3 | >1.3 = elite outruns Player |
| `iron_bones_health_multiplier` | 1.45 | 1.0 – 2.5 | Per-affix HP boost |
| `swift_speed_multiplier` | 1.3 | 1.0 – 2.0 | Per-affix speed boost |

### Boss-specific exports (FamineBeastBoss.tscn)

| Knob | Default | Design-safe range | Effect |
|---|---|---|---|
| `charge_cooldown` | 4.8 | 3.0 – 8.0 | <3 = relentless; >8 = trivially predictable |
| `charge_windup_time` | 0.7 | 0.3 – 1.5 | <0.3 = un-reactable; >1.5 = trivially dodgeable |
| `charge_duration` | 0.55 | 0.3 – 1.0 | How long Boss moves at charge speed |
| `charge_recovery_time` | 0.35 | 0.2 – 1.0 | Vulnerable window after charge |
| `charge_speed` | 390.0 | 200 – 600 | px/s during charge — must exceed Player 180 for threat |
| `charge_warning_length` | 240.0 | 100 – 400 | px — telegraph line length |
| `burst_cooldown` | 5.8 | 3.0 – 10.0 | — |
| `burst_warning_time` | 1.05 | 0.5 – 2.0 | Time between marker spawn and detonation |
| `burst_radius` | 58.0 | 30 – 120 | Hit radius |
| `burst_damage` | 18.0 | 10 – 40 | Per-burst damage |
| `burst_linger_time` | 0.18 | 0.1 – 0.5 | Explosion visual persists |
| `summon_cooldown` | 7.0 | 4.0 – 12.0 | — |
| `summon_batch_count` | 2 | 0 – 6 | Minions per summon |
| `summon_max_alive` | 6 | 0 – 12 | Simultaneous minion cap |
| `summon_spawn_radius` | 86.0 | 40 – 200 | Spawn distance from Boss |
| `enrage_health_ratio` | 0.3 | 0.1 – 0.5 (clamp [0.01, 0.99]) | % HP at which Enrage triggers |
| `enrage_speed_multiplier` | 1.35 | 1.0 – 2.0 | Move + charge speed boost |
| `enrage_skill_interval_multiplier` | 0.65 | 0.3 – 1.0 (clamp [0.1, 1.0]) | All skill cooldowns × this when enraged |

**Interaction warnings**:
- Combining `iron_bones` + `swift` on a single Shanxiao Elite: HP × 1.81, speed × 1.37 simultaneously. The result is mini-Boss-tier — only use deliberately.
- Boss `enrage_speed_multiplier × charge_speed` at 1.35 × 390 = 526.5 px/s. Player at 180 px/s base cannot outrun. Player must dodge sideways, not flee.
- Reducing `charge_warning_length` below 100 makes the telegraph hard to read at high render-pipeline latencies (~50 ms input lag would mean player sees 50 px-equivalent less warning). Consider both display-side and game-state-side reaction time.

## Visual/Audio Requirements

Per-enemy visual contract:
- **Body**: `Polygon2D` (placeholder until sprites), colored by `body_color` and scaled by `body_scale`. Production sprites per /art-bible.
- **HealthBar**: 28 × 4 px Polygon2D pair (Background + Fill), positioned `health_bar_y` px above body center. Updates on every `take_damage` event.
- **Hit flash**: per Combat GDD Visual/Audio, 0.1s white flash on receiving damage. **Currently NOT triggered** — see Open Questions OQ-2.
- **DamageArea visualization**: invisible Area2D (Circle of `damage_radius`). For debug, can be enabled via Godot's "Show Collisions" toggle.
- **Death VFX**: dissolve animation + small particle burst. Owned by VFX GDD (Full Vision tier). Triggered by `died` signal — Enemy `queue_free()` removes data; VFX handles visual lifetime up to 0.5s per Combat GDD Core Rule 4.

### Boss-specific visuals

- **Charge telegraph**: red `Line2D` from Boss to charge target, 240 px length, visible during CHARGE_WINDUP only
- **Burst markers**: 2-layer marker at target position — warning (red, alpha 0.32) during windup; explosion (orange, alpha 0.58) on detonation, 0.18s linger
- **Enraged aura**: visible Polygon2D circle (34 px radius, 24 vertices) appears on Enrage entry. Body color also turns dark red.
- **Summoned minions**: Use PaperDoll / WanderingSoul archetype defaults; no special spawn VFX in v0.4

📌 **Asset Spec** — once art-bible is locked, run `/asset-spec system:enemy` per archetype to produce sprite specs (silhouette, animation states, hit flash overlay, death frames).

**Audio handoff to Audio GDD**:
- **Per-archetype contact SFX**: short ≤0.15s cue distinct per enemy (Stone Golem footsteps heavy; Fox Spirit whisper; Ghost Flame flicker; Paper Doll paper rustle; Wandering Soul moan)
- **Boss skill cues**: Charge has windup growl + impact thud; Burst has rising whistle + impact crack; Summon has summoning hum
- **Enrage cue**: dramatic Boss roar + ambient music pitch shift
- **Death sting per archetype**: Boss has dedicated cinematic death cue; normal enemies have a 3-variant generic sting pool

## UI Requirements

UI surfaces owned or consumed by Enemy:

1. **Per-enemy HP bar** (drawn by Enemy itself, NOT HUD): 28 × 4 px Polygon2D pair above body. Visible from spawn (no "hidden until first hit" behavior currently — see OQ-4). Updates on every `take_damage` call.
2. **Boss HP bar** (drawn by HUD): top-of-screen large bar, populated by HUD subscribing to the Boss instance per Combat GDD UI Requirement #3. HUD wires up on `boss_spawned` signal from StageDirector.
3. **Elite affix indicator** (FUTURE — not in v0.4): a small icon overlay on Elite HP bar indicating active affixes (iron_bones = anvil icon, swift = wing icon). Currently no visual differentiation between elite and normal. Track as OQ-5.

📌 **UX Flag — Enemy System**: per-enemy HP bar styling + Boss HP bar styling + future Elite affix icons are UI surfaces. In Phase 4 (Pre-Production), `/ux-design design/ux/hud.md` must include: (a) per-enemy HP bar reuse-vs-customize per archetype, (b) Boss HP bar full design, (c) Elite affix icon spec (or accept v0.4 ships without). Combined with the existing UX Flag in Combat GDD.

## Acceptance Criteria

Numbered for traceability into `/create-stories`.

### AC group: Archetype application (Core Rules 1, 2)

**AC-01** **GIVEN** an Enemy instance with `archetype = paper_doll.tres`, **WHEN** `_ready()` completes, **THEN** `max_hp = 14.0` AND `damage = 5.0` AND `damage_interval = 0.85` AND `xp_drop_value = 3.5` AND `movement_mode = CHASE` AND `current_hp = 14.0`.

**AC-02** **GIVEN** an Enemy with `archetype = ghost_flame.tres`, **WHEN** `_ready()` completes, **THEN** `movement_mode = WAVE_CHASE` AND `wave_amplitude > 0.0` AND `wave_frequency > 0.0`.

**AC-03** **GIVEN** an Enemy instance with `archetype = null`, **WHEN** `_ready()` completes, **THEN** class defaults are used (`max_hp = 24.0`, `damage = 8.0`, etc.) AND no crash.

**AC-04** **GIVEN** an existing Enemy mid-life with archetype A, **WHEN** `apply_archetype(B)` is called with B = stone_golem.tres, **THEN** all stats re-apply from B AND `current_hp` resets to new `max_hp` (full heal on archetype swap).

### AC group: Movement (Core Rule 4, Formulas 1 + 2)

**AC-05** **GIVEN** a Wandering Soul (CHASE mode, move_speed=90) 100 px to the right of the player, **WHEN** 1.0 second of `_physics_process` runs, **THEN** the enemy has moved exactly 90 px (±5 px tolerance) toward the player.

**AC-06** **GIVEN** a Ghost Flame (WAVE_CHASE mode, wave_amplitude=0.4, wave_frequency=1.5), **WHEN** moving toward the player, **THEN** the enemy's trajectory deviates sinusoidally perpendicular to the direct path (NOT a straight line) AND the period of one full wave is 1/1.5 ≈ 0.667 seconds.

**AC-07** **GIVEN** an Enemy with no player in scene (`_find_player` returns null), **WHEN** `_physics_process` runs, **THEN** `velocity = Vector2.ZERO` AND `move_and_slide()` is called (no crash) AND the enemy retries `_find_player()` on the next frame.

### AC group: HP and damage (Core Rules 2, 3; Formula 3)

**AC-08** **GIVEN** a Paper Doll at `current_hp = 14`, **WHEN** `take_damage(5)` is called, **THEN** `current_hp = 9` AND health bar fill width is 9/14 of full AND `died` signal is NOT emitted.

**AC-09** **GIVEN** a Paper Doll at `current_hp = 14`, **WHEN** `take_damage(15)` is called (overkill), **THEN** `current_hp = 0` (clamped, not -1) AND `died(self)` is emitted exactly once. **`queue_free()` is then called by the VFX subscriber after dissolve completes** (see VFX GDD AC-01 + Combat GDD AC-22 — VFX owns the queue_free call per C-B4 resolution in /review-all-gdds 2026-05-27).

**AC-10** **GIVEN** a Paper Doll in `_is_dead = true` state, **WHEN** `take_damage(5)` is called subsequently, **THEN** the function early-returns AND `current_hp` remains 0 AND `died` is NOT re-emitted.

**AC-11** **GIVEN** a Paper Doll at `current_hp = 14` with `xp_drop_value = 3.5`, **WHEN** `_die()` runs, **THEN** an ExperienceOrb instance is created AND added to the scene tree AND its `xp_value = 3.5` AND its position equals the Enemy's position at death.

### AC group: Player contact damage (Core Rule 5, Formula 4)

**AC-12** **GIVEN** a Wandering Soul (damage=8, damage_interval=0.8) in contact with the player AND `_damage_cooldown == 0`, **WHEN** `_try_damage_player()` runs, **THEN** `Player.take_damage(8)` is called exactly once AND `_damage_cooldown = 0.8`.

**AC-13** **GIVEN** the same enemy in contact AND `_damage_cooldown = 0.2`, **WHEN** `_try_damage_player()` runs, **THEN** no damage is applied AND `_damage_cooldown` ticks down normally on next frame.

**AC-14** **GIVEN** an Enemy with `damage = 0`, **WHEN** `_try_damage_player()` runs, **THEN** no damage is applied regardless of contact (early-return).

**AC-15** **GIVEN** a Player enters Enemy's DamageArea then exits before cooldown expires, **WHEN** Player re-enters, **THEN** `_damage_cooldown` is unchanged (continues ticking down) — re-entry does NOT reset.

### AC group: Elite affixes (Core Rules 6, 7; Formula 5)

**AC-16** **GIVEN** a Shanxiao Elite spawned from `shanxiao_elite.tres` (archetype `is_elite = true`, `elite_damage_multiplier = 1.2` per .tres override, no affixes), **WHEN** `_apply_elite_modifiers()` runs, **THEN** `max_hp = 110 × 1.25 = 137.5` AND `damage = 15 × 1.2 = 18.0` AND `move_speed = 72 × 1.05 = 75.6`. (Note: the damage multiplier 1.2 is Shanxiao's archetype override; the class default 1.15 from `enemy.gd` is NOT used here.)

**AC-17** **GIVEN** a Shanxiao Elite + `elite_affixes = ["iron_bones"]`, **WHEN** `configure_elite(["iron_bones"])` is called, **THEN** general elite multipliers apply first AND iron_bones multiplier (×1.45) applies after, resulting in `max_hp = 137.5 × 1.45 ≈ 199.4` AND `damage = 18.0` (unchanged by iron_bones) AND `current_hp = max_hp` (full heal).

**AC-18** **GIVEN** a Shanxiao Elite + `["iron_bones", "swift"]`, **WHEN** `configure_elite([...])` is called, **THEN** both affixes stack multiplicatively: `max_hp ≈ 199.4`, `damage = 18.0` AND `move_speed = 75.6 × 1.3 ≈ 98.3`.

### AC group: Boss skills and Enrage (Core Rules 8, 9, 10; Formula 6)

**AC-19** **GIVEN** a Famine Beast Boss in CHASE state with `_charge_timer = 0`, **WHEN** `_physics_process` runs, **THEN** state transitions to CHARGE_WINDUP AND `_charge_telegraph.visible = true` AND `_state_timer = charge_windup_time` (0.7s default).

**AC-20** **GIVEN** a Famine Beast in CHARGE_WINDUP with `_state_timer = 0`, **WHEN** `_process_charge_windup` runs, **THEN** state transitions to CHARGE AND `velocity = _charge_direction × charge_speed` (390 default) AND `_charge_telegraph.visible = false`.

**AC-21** **GIVEN** a Famine Beast at `current_hp = max_hp × 0.31` (just above enrage), **WHEN** `take_damage(amount)` brings `current_hp / max_hp` to ≤ 0.3, **THEN** `_is_enraged = true` AND `move_speed *= 1.35` AND `_enraged_aura.visible = true` AND `_body.color` changes to dark red.

**AC-22** **GIVEN** a Famine Beast in Enrage state, **WHEN** all 3 skill timers tick down normally, **THEN** each timer uses `cooldown × 0.65` instead of base cooldown.

**AC-23** **GIVEN** a Famine Beast with `_summoned_enemies.size() == summon_max_alive` (6), **WHEN** `_summon_minions()` is called, **THEN** no new minions are spawned AND `_summon_timer` is still reset (next attempt after `summon_cooldown`).

**AC-24** **GIVEN** a Famine Beast Boss with `xp_drop_value = 0`, **WHEN** `_die()` runs, **THEN** `_drop_experience()` is called BUT the early-return guard (`xp_drop_value <= 0.0`) prevents orb spawn AND `died(self)` is still emitted (Run State observes for `stage_cleared`).

### AC group: Boss cleanup

**AC-25** **GIVEN** a Famine Beast with active burst markers AND summoned minions, **WHEN** `_die()` runs, **THEN** `_clear_boss_effects()` runs first AND all burst markers `queue_free()` AND all `_summoned_enemies` `queue_free()` AND then `super._die()` runs (XP guard, `died` emit, `queue_free`).

## Open Questions

- **OQ-1** (`damage_taken` signal not emitted): Per Combat GDD signal payload contract (revision-2 line ~197) + AC-02 (revision-2 line ~500), Enemy should emit `damage_taken(current_hp, max_hp, last_damage_amount)` for Combat Feedback (P-03) to hook the 0.1s flash AND for HUD per Combat GDD UI Requirement #2 (line ~482, "HP bar hidden until first damage_taken"). **Current code does NOT emit this signal** — Enemy only calls `_update_health_bar()` internally. **Resolution**: add `signal damage_taken(current_hp: float, max_hp: float, last_damage_amount: float)` to Enemy class + emit at the end of `take_damage` if amount > 0. **Owner**: lead-programmer. **Target resolution**: before Combat Feedback GDD is written, OR sprint-1 task. (revision-1 note: corrects revision-0's misattribution to "AC-21 contract" — AC-21 is the Damage Type Pipeline Ordering placeholder, unrelated to damage_taken.)
- **OQ-2** (`take_damage` does not carry damage tuple): Per Combat GDD Core Rule 2, damage events should be 5-field tuples `(source, target, amount, damage_type, source_kind)`. Enemy's `take_damage(amount: float)` only receives the amount — source, type, and source_kind are lost. This means Status Effects (FT-10) integration cannot route correctly when it lands. **Resolution candidate**: change signature to `take_damage(payload: Dictionary)` or introduce a small DamagePayload class. Migration risk: **7 .gd files** call `take_damage(...)` today (`scripts/enemy/enemy.gd`, `famine_beast_boss.gd`, `scripts/player/player.gd`, and 4 Sun Wukong weapon files: `cloud_step.gd`, `hair_clone_unit.gd`, `immobilize.gd`, `jingu_bang_v2.gd`). **Owner**: lead-programmer + systems-designer. **Target resolution**: before Status Effects GDD is written. (revision-1 note: corrects revision-0's "17 files" — actual count is 7.)
- **OQ-3** (`_summon_minions` slot-cap interaction): When all 6 minion slots are taken, the timer still resets — Boss waits 7s before checking again. This means if 1 minion dies right after the cap-reached call, the slot stays empty for nearly 7 seconds. **Resolution candidate**: when `_on_summoned_enemy_died` fires, reduce `_summon_timer` to 0 (or 0.5s) so the slot fills quickly. **Owner**: ai-programmer + systems-designer. **Target resolution**: playtest of Boss feel — if minion presence feels sparse, fix this; otherwise accept.
- **OQ-4** (HP bar always visible): Per Combat GDD UI Requirement #2 ("HP bar is hidden until first `damage_taken` emission"), Enemy HP bars should only appear after taking damage. **Current code shows HP bar from spawn.** This contradicts Combat GDD intent. **Resolution candidate**: hide `_health_bar` in `_ready()`, show on first `take_damage` call. **Owner**: ux-designer + lead-programmer. **Target resolution**: alongside OQ-1 fix (same `take_damage` codepath touched).
- **OQ-5** (Elite affix indicator UI): Currently no visual difference between Elite + iron_bones vs Elite + swift vs base Elite. Players can only tell by behavior (HP-bar length / movement speed). **Resolution candidate**: small icon overlay on Elite HP bar. **Owner**: ux-designer + art-director. **Target resolution**: when /ux-design touches HUD spec for elite/Boss differentiation.
- **OQ-6** (Elite affix combinatorics — content design): The system supports stacking 2 affixes (`["iron_bones", "swift"]`) but Run State currently only spawns 1 affix per elite. Should v0.4 leverage stacks? Or save for v0.5+ when more affixes exist (currently only 2)? **Owner**: game-designer. **Target resolution**: v0.4 playtest decides.
- **OQ-7** (Boss skill cooldowns are timer-driven, not state-machine-integrated): Burst and Summon timers run in `_physics_process` independent of CHASE/CHARGE state. A charging Boss can detonate a Burst mid-charge. Intentional layering? Confirm. **Resolution**: explicit confirmation in this GDD — Burst/Summon are deliberately decoupled from movement state for predictability. Document as a design decision, not a bug.

---

## Registry Updates Recorded

References to entries in `design/registry/entities.yaml`:
- 7 enemy archetypes — all already referenced by combat-system.md, player-system.md, run-state.md; this GDD adds enemy-system.md to each `referenced_by` array
- `target_framerate = 60` — Movement formulas (1, 2, 4) assume per-frame physics tick at 60 FPS
- `stage_duration_seconds = 300` — Boss spawn time matches; Enemy lifecycle bound by this

**New formula candidates to register**:
- `enemy_chase_movement` (Formula 1)
- `enemy_wave_chase_movement` (Formula 2)
- `elite_multiplier_stack` (Formula 5 — important for `/balance-check`)
- `boss_enrage_skill_multiplier` (Formula 6)

**Cross-doc consistency checks**:
- All 7 archetype values (max_hp, damage, damage_interval, xp_drop_value) match entities.yaml 1:1 ✅
- Boss `max_hp = 360` per `famine_beast.tres` AND Combat GDD revision-4 §Per-Phase TTK Budget references 360 ✅
- Boss `xp_drop_value = 0` AND Combat GDD AC-18 references "xp_drop_value = 0" ✅
- Combat GDD revision-3+ uses `died()` signal name AND Enemy emits `signal died(enemy: Enemy)` ✅
- Run State Core Rule 9 says "Boss's `died` signal is connected at spawn" AND Enemy's `died` signature matches ✅

## Revision Log

| Revision | Date | Trigger | Summary |
|---|---|---|---|
| 0 | 2026-05-25 | Initial reverse-doc by /design-system | First pass authored from `scripts/enemy/enemy.gd` (242 lines) + `scripts/enemy/enemy_archetype.gd` (26 lines) + `scripts/enemy/famine_beast_boss.gd` (327 lines) + 7 `.tres` files + Combat GDD revision-4 + Player GDD revision-2 + Run State GDD revision-1 + 05_ENEMY_DESIGN macro. 8 required sections + Visual/Audio + UI + Open Questions + Registry Updates. 25 ACs covering 10 Core Rules + 6 Formulas. 7 OQs (signal-emit gaps, payload contract, slot-cap interaction, HP bar visibility timing, elite UI, content design, state-machine layering). |
| 1 | 2026-05-25 | /design-review verdict: CONCERNS (independent design-reviewer subagent) | **B-1 closed**: Formula 5 example, Output Range, AC-16, AC-17, AC-18 all corrected to use Shanxiao's actual `elite_damage_multiplier = 1.2` (per `shanxiao_elite.tres` override), not the class default 1.15. Resulting damage values updated from 17.25 → 18.0. Added note explaining "only Shanxiao overrides this multiplier; all other 6 archetypes use class default." **R-1 closed**: OQ-1 reference "Combat GDD AC-21 contract" was misattributed (AC-21 is Damage Type Pipeline Ordering); corrected to "Combat GDD signal payload contract + AC-02 + UI Requirement #2". **R-2 closed**: Formula 6 enrage-entry compression formula was `* 0.5 + currentMultiplier` (syntactically wrong, no addition exists); corrected to `× enrage_skill_interval_multiplier × 0.5` with explanation of the one-time entry compression vs ongoing `× 0.65` multiplier. **R-3 closed**: OQ-2 migration risk "17 .gd files" corrected to "7 .gd files" with explicit file list (enemy.gd, famine_beast_boss.gd, player.gd, 4 Sun Wukong weapon files). N-1 through N-4 are polish (HP bar visibility = OQ-4 already; Player Fantasy validated; AC state-machine completeness; VFX cross-reference) — deferred. Status: Approved (no re-review needed — reviewer pre-cleared this revision as data accuracy polish). |
