# Combat System

> **Status**: Designed (pending /design-review)
> **Author**: claude (reverse-documented from existing v0.4-pre-qa code + 03_CORE §10 + 04_SKILL §3)
> **Last Updated**: 2026-05-25
> **Implements Pillar**: Pillar 1 (清晰的生存压力), Pillar 2 (自动战斗与有意义的构筑选择), Pillar 4 (数据驱动迭代)
> **TR Coverage**: TR-core-001, TR-core-005, TR-wpn-001, TR-wpn-002, TR-enemy-002

## Overview

Combat is the central data + signal layer that mediates every damage exchange in MythSurvivor. It is **infrastructure-shaped**, not a feature in itself: weapons declare damage intent, the Combat layer applies it to targets that have HP, and the layer emits the events (`hit`, `died`, `damage_dealt`) that downstream systems (Experience, Combat Feedback, Boss System, HUD) consume. Without Combat, weapons cannot affect enemies and enemies cannot affect the player — but players never "use" Combat directly; they use weapons and feel its effects.

Reference ADRs: ADR-0001 (Godot 4.x + GDScript) constrains the implementation language and the signal-based architecture this system uses.

## Player Fantasy

Combat is **indirect** — players don't think about "the combat system," they think about *being under threat and pushing back*. The fantasy this layer enables:

> "I'm a 修行者 hunted by neon-cold spirits. My talismans and spells fire automatically — my job is to read the battlefield, choose where to stand, and trust that my构筑 is doing its work. Every hit on me costs me time; every kill of mine earns me 修为. The system gets out of my way and lets me feel the pressure curve build."

When Combat works invisibly, the player feels:
- **Tension**: each enemy carries a real threat (damage values matter, HP bars matter)
- **Power**: their构筑 turns into a visible damage stream that scales with升级
- **Clarity**: a hit is unambiguous — the enemy flashes, takes the value, dies on schedule

When Combat fails (silent hits, ghost damage, dropped events), the player feels cheated. The system's success is measured by the *absence* of confusion.

## Detailed Design

### Core Rules

1. **Damage flows in one direction per exchange.** Either a weapon damages an enemy, or an enemy damages the player. Friendly fire does not exist.

2. **Every damage event must be expressible as a `(source, target, amount, damage_type)` tuple.** No implicit damage, no shared mutable state — damage is data passing through signals.

3. **HP is mutable, owned by the target.** Only the target may decrement its own HP in response to a damage event. Other systems request damage, the target applies it.

4. **HP ≤ 0 triggers death.** The target emits `died` (Enemy) or `defeated` (Player); both signals carry enough context for downstream systems (XP drop, game-over screen) to react.

5. **All damage values are configurable per Resource (`.tres`).** No hardcoded damage in `.gd` files except minimum-value safety floors. Tuning is data-driven (TR-data-001 + Pillar 4).

6. **Player invulnerability is time-windowed by `damage_interval` on the enemy side**, not by player state. An enemy that hits the player must wait `damage_interval` seconds before hitting again. This is per-enemy, not global.

### Damage Types

Four damage types are supported. Every weapon must declare which type(s) it produces. Status effects extend this via FT-10 Status Effects (separate GDD).

| Type | Field | Behaviour | Example weapon |
|---|---|---|---|
| **direct** | `damage` | One-shot, applied on hit | Flying Sword, Talisman, Explosive Talisman impact |
| **tick** | `damage` + `tick_rate` | Applied repeatedly at `tick_rate` intervals while target is in zone | Bagua Array (`tick_rate = 0.65s` default) |
| **explosion** | `explosion_damage` + `explosion_radius` | One-shot, applied to all targets within `explosion_radius` of impact point | Explosive Talisman impact, Mountain Seal impact |
| **burn** | `burn_dps` + `burn_duration` | Per-second DPS applied to ground zone for `burn_duration` seconds | Thunder Strike (after-effect) |

Burn and tick are mechanically similar but semantically distinct: **tick** is anchored to a moving aura (weapon-attached), **burn** is anchored to a ground position (terrain).

### States and Transitions

Combat has no global state machine — it is event-driven. Each *participant* (weapon, enemy, player) has its own state, summarised below:

#### Weapon state

| State | Transition trigger | Next state |
|---|---|---|
| `IDLE` (cooldown_remaining > 0) | `delta` elapses in `_process`, cooldown reaches 0 | `READY` |
| `READY` (cooldown_remaining == 0) | `_try_attack()` returns true | `IDLE` (cooldown_remaining := cooldown) |
| `READY` | `_try_attack()` returns false (no valid target) | `READY` (retry next frame) |

#### Enemy combat state

| State | Transition trigger | Next state |
|---|---|---|
| `ALIVE` (hp > 0) | damage event, hp - amount > 0 | `ALIVE` (hp updated, flash effect 0.1s) |
| `ALIVE` | damage event, hp - amount ≤ 0 | `DYING` |
| `DYING` | death animation + `died` signal emit + XP orb spawn | (removed via `queue_free`) |

Elite enemies apply HP and damage multipliers on spawn (`iron_bones` = HP × 1.45, `swift` = speed × 1.3 — see Enemy GDD when written). Multipliers do not change Combat behaviour, only base values.

#### Player combat state

| State | Transition trigger | Next state |
|---|---|---|
| `ACTIVE` (hp > 0) | damage event from any enemy (subject to enemy's `damage_interval`) | `ACTIVE` if hp > 0, else `DEFEATED` |
| `DEFEATED` | (terminal — Run State system handles the run ending) | — |

### Interactions with Other Systems

| System | Direction | Interface |
|---|---|---|
| **Resource Data Framework** | Combat consumes | Reads weapon `.tres` and enemy `.tres` for damage / hp / cooldown values |
| **Targeting** | Combat depends on | Weapons call `Targeting.find_nearest(position, range)` to pick a target; Combat receives the chosen target via `_try_attack()` |
| **Weapon System** | Weapon → Combat | Each weapon subclass overrides `_try_attack()`; on success, calls into target with damage payload |
| **Enemy** | Combat ↔ Enemy | Combat sends damage; Enemy decrements HP; Enemy emits `died(enemy)` |
| **Status Effects** (FT-10) | Combat dispatches | When damage of type `burn` / `tick` is applied, Combat creates a status effect node on target (separate GDD) |
| **Experience & Progression** | Enemy → Experience | On `died`, Experience system spawns XP orb via `experience_orb_scene` |
| **Combat Feedback** | Combat → Feedback | On hit, Feedback subscribes to enemy flash signal; on death, plays death VFX |
| **HUD** | Combat → HUD | Player HP changes emit `health_changed(current, max)` for HUD to render |

## Formulas

### Damage application formula

Applied every time a weapon hits an enemy or an enemy hits the player.

`new_hp = max(0, current_hp - damage_amount)`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| `current_hp` | hp₀ | float | 0.0 - max_hp | Target HP before damage |
| `damage_amount` | d | float | ≥ 0.0 | Damage payload from weapon (or enemy attack) |
| `new_hp` | hp₁ | float | 0.0 - max_hp | Target HP after damage |

**Output Range:** 0.0 to `max_hp`. HP can never go negative.
**Example:** A 修行者 with `current_hp = 28.0` is hit by a Stone Golem for `12.0` damage → `new_hp = max(0, 28 - 12) = 16.0`.

### Weapon DPS formula(theoretical, before mitigation)

For a weapon with damage `d` and cooldown `c`:

`dps = d / c`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| `d` | damage | float | 0.0 - 200.0 (early-game expectation) | Per-hit damage |
| `c` | cooldown | float | 0.05 - 5.0 | Seconds between attacks (`MIN_COOLDOWN = 0.05`) |

**Output Range:** 0 - 4000 DPS (extreme: 200 damage / 0.05 cooldown).
**Example:** Flying Sword (d=14, c=0.8) → 17.5 dps single-target. With pierce_count=3 → effective dps vs. a tight enemy cluster ≈ 52.5.

### Multi-target weapon effective DPS

For radius/tick/multi-target weapons:

`effective_dps = (d × hits_per_tick) / tick_rate`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| `d` | damage | float | per-tick damage value | |
| `hits_per_tick` | n | int | 1 - 100 (depends on enemy count in radius) | How many enemies the tick caught |
| `tick_rate` | tick_rate | float | 0.05 - 2.0 | Seconds between damage ticks (`MIN_TICK_RATE = 0.05`) |

**Output Range:** dps scales linearly with enemies in radius.
**Example:** Bagua Array (d=4, tick_rate=0.65) hitting 10 enemies → 4 × 10 / 0.65 ≈ 61.5 dps total, 6.15 dps per enemy.

### Damage interval throttle (enemy → player)

An enemy can only damage the player once per `damage_interval` seconds.

`can_hit = (current_time - last_hit_time) ≥ damage_interval`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| `current_time` | t | float | run elapsed seconds | |
| `last_hit_time` | t₀ | float | run elapsed seconds | Last successful hit |
| `damage_interval` | Δ | float | 0.1 - 2.0 (`MIN_DAMAGE_INTERVAL = 0.1`) | Per-enemy throttle |

**Output Range:** boolean.
**Example:** Wandering Soul (`damage_interval = 0.8`) hits at t=10.0, next legal hit at t=10.8.

## Edge Cases

- **If `damage_amount == 0`**: damage signal still fires, but `new_hp` is unchanged. No flash, no death. (Use case: zero-damage "tap" weapons for status-only application — none implemented yet, but the formula admits it.)
- **If `damage_amount > current_hp`**: damage caps at `current_hp` (overkill is not stored). Death triggers normally.
- **If multiple damage events target the same enemy in the same frame**: each is applied sequentially in the order signals arrive. If the first kills the enemy, subsequent damage events still fire on the `DYING` node — they have no effect because HP is already 0, but they do not crash.
- **If a weapon fires and the projectile expires before reaching target**: no damage applied. The weapon is back on cooldown regardless (the cost is the cooldown, not the hit).
- **If `cooldown < MIN_COOLDOWN` (0.05s) is set via tuning**: clamped to 0.05s by `_get_cooldown()`. Designers can request fast firing rate but not infinite.
- **If two enemies share the same instance and one is killed**: only the killed one emits `died` — there is no shared HP pool. (Per current architecture; if a "shared HP" Boss is ever added, that's a separate Boss GDD concern.)
- **If `damage_interval` for an enemy is set below `MIN_DAMAGE_INTERVAL = 0.1`**: clamped to 0.1s. Even the fastest enemy cannot frame-rate-deadlock the player.
- **If an explosion's `explosion_radius` overlaps the player while the explosion is friendly (weapon-sourced)**: player takes 0 damage. Friendly fire does not exist (Core Rule 1).
- **If a `burn` ground patch is on the player's path when the player walks through**: damage is applied at `burn_dps × dt` continuously while in the zone. Same `damage_interval`-style throttle does NOT apply to environmental burn (currently — could be added).
- **If `xp_drop_value = 0` (Boss case)**: enemy still emits `died`, but `Experience` system spawns no XP orb. Boss death triggers victory state via separate signal.

## Dependencies

| Dependency | Type | Direction | Interface |
|---|---|---|---|
| **Resource Data Framework** | Hard | Combat depends on | `.tres` Resource subclasses for weapon and enemy stats |
| **Targeting** | Hard | Combat depends on | `find_nearest(position, range)` and `find_in_radius(position, radius)` |
| **Weapon System** | Hard | Combat is the contract for | All weapons implement `WeaponBase._try_attack()` |
| **Enemy** | Hard | Bidirectional | Enemy's HP is the receiver; Combat's damage signals are the sender |
| **Player** | Hard | Bidirectional | Same as Enemy, in reverse |
| **Status Effects (FT-10)** | Soft | Combat dispatches into | When tick/burn damage types fire, Status Effects creates effect nodes |
| **Experience & Progression** | Soft | Combat events trigger | On `died`, Experience handles XP orb spawn |
| **Combat Feedback (P-03)** | Soft | Combat events trigger | On hit, Feedback handles flash/shake/numbers |
| **HUD** | Soft | Combat events trigger | On `health_changed`, HUD updates HP bar |

**Bidirectional check (per design-docs rule)**:
- Enemy GDD must list "depends on Combat" in its Dependencies. ✅ (will be enforced when Enemy GDD is written)
- Weapon System GDD must list "depends on Combat" in its Dependencies. ✅ (same)
- Experience & Progression GDD must list "soft-depends on Combat (for `died` event)" ✅

## Tuning Knobs

All combat values are tuned via Resource (`.tres`) files. No `.gd` code change needed for balance passes.

| Knob | Owner | Safe Range | Effect at extremes |
|---|---|---|---|
| `WeaponBase.damage` | Per-weapon `.tres` | 1 - 200 | <1 = useless; >200 = trivialises mid-game enemies |
| `WeaponBase.cooldown` | Per-weapon `.tres` | 0.1 - 3.0 | <0.1 = clamped to MIN_COOLDOWN; >3.0 = feels lifeless |
| `WeaponBase.projectile_speed` | Per-weapon `.tres` | 100 - 800 | <100 = miss everything; >800 = invisible bullets |
| `WeaponBase.attack_range` | Per-weapon `.tres` | 50 - 600 | <50 = melee-tight; >600 = trivialises spacing |
| `WeaponBase.projectile_lifetime` | Per-weapon `.tres` | 0.3 - 5.0 | <0.3 = explodes in face; >5.0 = perf cost (orphan projectiles linger) |
| `Enemy.damage_interval` | Per-enemy `.tres` | 0.4 - 1.5 | <0.4 = punishingly fast hits; >1.5 = enemy feels harmless |
| `Enemy.damage` | Per-enemy `.tres` | 3 - 30 | <3 = trivial; >30 = unfair without构筑 |
| `Enemy.max_hp` | Per-enemy `.tres` | 5 - 500 (Boss exception: 5000) | <5 = popcorn; >500 = boring tank |
| `BaguaArrayWeapon.tick_rate` | Bagua `.tres` | 0.2 - 1.5 | <0.2 = perf cost (too many events); >1.5 = feels dead |
| `BaguaArrayWeapon.radius` | Bagua `.tres` | 40 - 180 | <40 = no value; >180 = trivialises positioning |
| `ThunderLawWeapon.target_count` | Thunder `.tres` | 1 - 8 | >8 = visual chaos, perf concerns |
| `FlyingSwordWeapon.pierce_count` | Flying Sword `.tres` | 0 - 8 | >8 = single-shot wipes everything |
| `Elite multipliers` | Per-archetype `.tres` | 1.0 - 2.0 | >2.0 = elite becomes mini-Boss without Boss treatment |

**Interaction warnings**:
- Lowering `cooldown` while keeping `damage` high → exponential DPS growth. Pair these in tuning passes.
- Increasing `attack_range` and `projectile_speed` simultaneously trivialises kiting. Tune them as a pair.
- `tick_rate` lower than the average enemy `damage_interval` makes tick weapons mechanically dominant. Keep them in the same order of magnitude (0.6-0.9s).

## Visual/Audio Requirements

Combat is **infrastructure** — most visuals come from FT-10 Status Effects, P-03 Combat Feedback, and PL-02 VFX. Combat itself only needs:

- **Damage number floaters** (optional, v0.4+): on hit, show the numeric damage value briefly. Read [07_VISUAL_STYLE_GUIDE](style/07_VISUAL_STYLE_GUIDE.md) for暗黑志怪 palette — damage numbers should be off-white with a thin red glow on crits, not modern game blue/yellow.
- **Hit confirmation**: a 0.1-second flash on the target sprite. Owned by Combat Feedback GDD; Combat just dispatches the signal.
- **Death VFX**: small particle burst + sprite dissolve. Owned by VFX GDD; Combat just dispatches `died`.

📌 **Asset Spec** — Visual/Audio requirements above are infrastructure-light. When Combat Feedback GDD or VFX GDD is written, run `/asset-spec system:combat-feedback` then to produce the actual VFX asset specs.

Audio: every hit must have a short SFX cue (≤ 0.15s), distinct per weapon. Owned by Audio GDD (Full Vision tier — not blocking MVP).

## UI Requirements

Combat exposes 2 UI surfaces that HUD consumes:

1. **Player HP bar** — listens for `health_changed(current, max)`; updates instantly (no animation lag beyond ~50ms)
2. **Enemy HP bars** — drawn per-enemy by Enemy node itself, 28×4 px above sprite; only visible after first hit

📌 **UX Flag — Combat System**: HUD HP bar + on-screen damage feedback are UI surfaces. In Phase 4 (Pre-Production), run `/ux-design` to create a UX spec for `design/ux/hud.md` (and possibly `design/ux/damage-numbers.md`) **before** writing epics that touch this UI.

## Acceptance Criteria

- **GIVEN** a 修行者 with `current_hp = 30`, **WHEN** an enemy with `damage = 8` hits, **THEN** `current_hp` becomes 22 and `health_changed(22, 30)` signal fires.
- **GIVEN** an enemy with `max_hp = 14` (Paper Doll), **WHEN** total damage applied across any number of events reaches 14, **THEN** `died(enemy)` fires exactly once and the enemy node is freed within 1 frame.
- **GIVEN** a Flying Sword projectile with `pierce_count = 3`, **WHEN** it passes through 4 enemies, **THEN** the first 3 take damage and the 4th does not.
- **GIVEN** a Bagua Array with `tick_rate = 0.65`, **WHEN** 5 enemies remain in the radius for 2 seconds, **THEN** each enemy receives exactly 3 damage applications (at t=0.0, t=0.65, t=1.30) — or 4 if the entry was at t=0 and exit at t≥1.95.
- **GIVEN** a Stone Golem (`damage = 12`, `damage_interval = 1.0`) in contact with the player, **WHEN** 2.5 seconds pass, **THEN** the player takes damage at t=0.0, t=1.0, t=2.0 (3 hits, never on every frame).
- **GIVEN** the player at `current_hp = 5` and a Stone Golem in contact, **WHEN** the next hit applies, **THEN** `current_hp = 0` AND `defeated` signal fires AND no further enemy damage events apply to the player for the rest of the run.
- **GIVEN** a Famine Beast Boss (`max_hp = 360`, `xp_drop_value = 0`), **WHEN** total weapon damage of 360+ has been applied, **THEN** Boss `died` fires AND no XP orb is spawned AND the Run State system receives the victory trigger.
- **GIVEN** a weapon with `cooldown = 0.01` (below `MIN_COOLDOWN`), **WHEN** the project loads, **THEN** the effective cooldown is `0.05` (clamped, no console error).
- **GIVEN** an Explosive Talisman with `explosion_radius = 80` impacting at position P, **WHEN** 3 enemies are within radius 80 of P, **THEN** all 3 receive `explosion_damage` exactly once each in the same frame.
- **GIVEN** the player walks across a Thunder Strike burn patch (`burn_dps = 6`, `burn_duration = 2.0`), **WHEN** the player is in the patch for 0.5s of the burn's lifetime, **THEN** the player takes ~3 damage (6 dps × 0.5s).

## Open Questions

- **OQ-1** (Combat Feedback overlap): Should `damage_amount = 0` events still trigger the white-flash effect? Currently no — but this could matter for "tap-to-debuff" weapon variants we may add. **Owner**: systems-designer + ux-designer. **Target resolution**: before Combat Feedback GDD is written.
- **OQ-2** (Crit support): The current formula has no crit chance / crit multiplier. Future weapon designs (especially孙悟空's 火眼金睛 +20% vs. elite/Boss) imply crit-like multipliers exist. Where do they live — weapon side, target side, or a separate modifier pipeline? **Owner**: systems-designer. **Target resolution**: when Active Skills GDD is written.
- **OQ-3** (Status pipeline boundary): When a Bagua Array tick applies, does the target ever get a "burn" stack (currently no) — or is "burn" strictly weapon-declared? If we ever want chained effects (tick → burn → explosion), we need a clearer Status Effects integration. **Owner**: systems-designer. **Target resolution**: when Status Effects GDD is written.
- **OQ-4** (五行 / Elements scaling): The 03_CORE §9 element table (gold/wood/water/fire/earth) is meant to apply ±30% / -20% modifiers on top of damage. Where in this damage pipeline does it slot in? Pre-clamp? Post-clamp? **Owner**: systems-designer. **Target resolution**: when Elements GDD is written (v0.5+).

---

## Registry Updates Recorded

This GDD references the following entities/constants that exist in `design/registry/entities.yaml`:

- 7 enemies (`paper_doll`, `wandering_soul`, `fox_spirit`, `ghost_flame`, `stone_golem`, `shanxiao_elite`, `famine_beast`) — `referenced_by` array will be appended with `design/gdd/combat-system.md`
- `target_framerate = 60` — `referenced_by` will gain this GDD
- New formula candidates(to register): `damage_application_formula`, `weapon_dps_formula`, `multi_target_effective_dps`, `damage_interval_throttle`

**Cross-doc consistency**: All numeric values referenced (enemy HP / damage / damage_interval, weapon damage / cooldown, etc.) match the values in `.tres` files and `entities.yaml`. No conflicts surfaced.
