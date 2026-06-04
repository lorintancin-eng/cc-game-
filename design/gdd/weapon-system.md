# Weapon System

> **Status**: Approved (revision-0 — first-try PASS, no findings)
> **Author**: claude (reverse-documented from `scripts/weapon/weapon_base.gd` + 6 weapon subclasses + 4 projectile/impact scenes + 04_SKILL_DESIGN.md)
> **Last Updated**: 2026-05-25
> **Implements Pillar**: Pillar 2 (auto-battle + meaningful construction choices — weapons ARE the construction layer)
> **TR Coverage**: TR-wpn-001 (WeaponBase contract), TR-wpn-002 (4 damage types), TR-wpn-003 (per-character pool filter)
> **Layer**: Feature (depends on Combat, Targeting; consumed by Player + Character System)

## Overview

The Weapon System owns **the 6 auto-firing damage delivery mechanisms** that turn Player's positioning into enemy deaths. Each weapon is a `WeaponBase`-extending Node2D child of Player; each implements its own `_try_attack()` per Combat GDD's contract; each pulls from Targeting (Targeting GDD) for target selection (except Bagua Array which is radius-based and bypasses Targeting).

This GDD covers **6 weapons available to all characters via upgrade pool**:
1. **Talisman (追魂符)** — baseline projectile, 1 shot, 12° spread
2. **Flying Sword (飞剑)** — piercing projectile (3 hits default)
3. **Thunder Law (雷法)** — area strike, multi-target (default 1)
4. **Bagua Array (八卦阵)** — rotating tick aura, radius-based
5. **Explosive Talisman (爆裂符)** — projectile + explosion impact
6. **Mountain Seal (山印)** — large radius impact

**Out of scope for this GDD**: Sun Wukong's 4 active-skill weapons (`scripts/weapon/sun_wukong/` subfolder — hair_clone_unit, cloud_step, immobilize, jingu_bang_v2, etc.) are owned by Active Skills GDD (FT-07). They share the `WeaponBase` contract but are triggered by player input (keys 1-4), not auto-cooldown.

Reference: Combat GDD §Detailed Rules (WeaponBase contract), Targeting GDD (find_nearest pattern), 04_SKILL_DESIGN.md (designer notes on weapon flavors), ADR-0003 (Sun Wukong's active-skill exception).

## Player Fantasy

Weapons are the **personality of the build**. Each one has a distinct silhouette and rhythm — once a player sees a Bagua Array spinning around their character, they know what kind of run they're committing to.

> "I unlock Flying Sword and watch it line up enemies, punching through 4 in a row — finally, AoE that respects walls of paper dolls. I add Bagua Array and now I have a constant pulse of damage on top of the burst pattern. By minute 4, I've stacked Thunder Law for multi-target burst, and I can see three distinct DPS sources layered together — projectile, tick, instant-radius. I AM this construction."

When weapons work invisibly, the player feels:
- **Differentiated tools** — every weapon does something the others don't (pierce ≠ AoE ≠ tick ≠ instant strike)
- **Layered DPS** — multiple weapons feel additive, not redundant
- **Visible decision-making** — when a Stone Golem appears, the player knows which weapon to lean on
- **Upgrade impact** — a `+10 damage` upgrade visibly amplifies a specific weapon's role

Anti-fantasy: weapons that all feel like reskinned Talismans, upgrades that don't visibly change behavior, weapons that fire-and-miss because Targeting is wrong.

## Detailed Rules

### Core Rules

1. **All weapons inherit from `WeaponBase`** (`scripts/weapon/weapon_base.gd`, `extends Node2D`). Base class owns: per-frame cooldown countdown (`_process(delta)`), abstract `_try_attack() -> bool` override, base export fields (damage 8.0, cooldown 0.9s, projectile_speed 360 px/s, attack_range 280 px, projectile_lifetime 1.2s).

2. **`_try_attack()` returns bool** — true = attack fired (cooldown resets), false = no valid target (retry next frame). Per Combat GDD Core Rule 2 + WeaponBase line 17-22.

3. **Weapons are scene-embedded as Player children** — each character's `Player.tscn` instantiates 6 weapon nodes; only those listed in CharacterBase.initial_weapon_id are enabled at spawn, others stay disabled until `UPGRADE_UNLOCK_<weapon>` is applied.

4. **Damage tuple contract** — when a weapon hits, it calls `enemy.take_damage(amount)` directly (current v0.4 — see Combat GDD's `damage_dealt` signal contract for the planned source-side signal). Per Targeting GDD: every weapon's hit goes through enemy's `take_damage` method (eligibility checked by `has_method`).

5. **Each weapon has a defining mechanic** (not just stat differences):
   | Weapon | Damage Type | Target Selection | Defining Mechanic |
   |---|---|---|---|
   | Talisman | direct | nearest 1 | Baseline — projectile homing-light |
   | Flying Sword | direct | nearest 1 | **Pierce** — 1 projectile, hits N+1 enemies in line |
   | Thunder Law | direct | K-nearest | **Multi-target** — instant strike on K closest |
   | Bagua Array | tick | radius around Player | **Aura** — rotating, continuous, radius-based |
   | Explosive Talisman | direct + explosion | nearest 1 | **AoE on impact** — projectile + radius damage |
   | Mountain Seal | direct (radius impact) | nearest 1 | **Heavy slam** — large radius (118 px), slow cooldown |

6. **Weapon-specific exports extend WeaponBase**:
   - Talisman: projectile_scene, projectile_count, projectile_spread_degrees
   - Flying Sword: + pierce_count
   - Thunder Law: radius (72), target_count (1), strike_scene
   - Bagua Array: radius (82), tick_rate (0.65), rotation_speed (2.4)
   - Explosive Talisman: projectile_scene + explosion_radius (58), explosion_damage (14)
   - Mountain Seal: radius (118), impact_scene

   **Note (v0.5)**: `WeaponBase` additionally gains an `element: String` export (default per the Five Phases Element Assignments table below), used by the Five Phases Synergy System for 相生 combo inventory counting and 相克 matchup lookups. See "Five Phases Element Assignments (v0.5)" below and `elements-five-phases.md`.

7. **Upgrade-driven differentiation**: every weapon has 3-5 upgrade IDs in Player.gd's `UPGRADE_*` constants (e.g. UPGRADE_TALISMAN_DAMAGE, _COOLDOWN, _COUNT, _SPEED). Player GDD's `_apply_upgrade` match statement (line 710+) hardcodes the deltas (per Player GDD OQ-6 — tech debt). Upgrade pool filter (per TR-wpn-003) shows weapon-specific upgrades only if the weapon is currently equipped/unlocked.

8. **Targeting bypass for radius weapons**: Bagua Array does NOT use Targeting's `find_nearest` — it iterates `get_tree().get_nodes_in_group("enemies")` directly in `_apply_radius_damage()`. Per Targeting GDD §"What Targeting Does NOT Provide" — radius weapons are intentional area-effects.

### v0.4 Weapon Defaults

| Weapon | damage | cooldown | range | Special |
|---|---|---|---|---|
| Talisman | 8.0 (WeaponBase default) | 0.9 | 280 | projectile_speed 360, lifetime 1.2 |
| Flying Sword | 8.0 (override likely in Player.tscn) | 0.9 | 280 | pierce_count 3, 1 projectile, 10° spread |
| Thunder Law | 8.0 | 0.9 | 280 | radius 72, target_count 1 |
| Bagua Array | 8.0 (interpreted as per-tick damage) | 0.9 (unused — aura is continuous) | 82 (radius) | tick_rate 0.65s, rotation_speed 2.4 |
| Explosive Talisman | 8.0 (direct) | 0.9 | 280 | explosion_radius 58, explosion_damage 14 |
| Mountain Seal | 8.0 | 0.9 (likely longer in scene override) | 280 | radius 118 (large impact) |

**Note**: actual values for each weapon instance are set in `Player.tscn`'s weapon nodes — these are WeaponBase class defaults that scenes override.

### Five Phases Element Assignments (v0.5)

| Weapon | Element |
|---|---|
| 符箓 Talisman | fire |
| 飞剑 Flying Sword | metal |
| 雷法 Thunder Law | water |
| 八卦阵 Bagua Array | earth |
| 爆裂符 Explosive Talisman | fire |
| 山印 Mountain Seal | earth |

Source of truth: elements-five-phases.md §Element Assignments. Each weapon declares one immutable element via a new `element: String` export field. Distribution: Fire×2, Earth×2, Metal×1, Water×1, Wood×0 (Wood comes from player attribute upgrades, not weapons).

### Interactions with Other Systems

| System | Direction | Interface |
|---|---|---|
| **Combat** (C-03, Approved) | Weapon → Combat | Weapons follow Combat GDD's damage tuple contract; calls `enemy.take_damage(amount)` |
| **Targeting** (C-05, Approved) | Weapon → Targeting | 5 of 6 weapons call `_find_nearest_enemy()` (per-weapon duplication, see Targeting OQ-1); Bagua bypasses |
| **Player** (C-01, Approved) | Player owns Weapon nodes | Weapons are Player's children; Player applies upgrades via `_apply_upgrade` match |
| **Resource Data Framework** (F-02, Approved) | Weapons read | (currently scene-embedded; future migration to `resources/weapons/*.tres` per Resource Data GDD OQ + Weapon System OQ-2) |
| **Character System** (FT-06, future) | Character → Weapon | `CharacterBase.initial_weapon_id` enables/disables weapons per character |
| **Enemy** (C-04, Approved) | Weapon → Enemy | Calls `enemy.take_damage(amount)` |
| **Combat Feedback** (P-03, future) | Weapon → Feedback | Hit produces `damage_taken` (Enemy's signal); weapons don't emit feedback directly |
| **Level Up & Upgrade Pool** (FT-05, future) | Upgrade → Weapon | Pool applies weapon-specific upgrade IDs that mutate weapon node state |

## Formulas

### Formula 1: Cooldown countdown (inherited from WeaponBase)

```
on _process(delta):
    _cooldown_remaining = max(_cooldown_remaining - delta, 0.0)
    if _cooldown_remaining > 0.0: return
    
    _try_attack()                    # subclass override
    _cooldown_remaining = _get_cooldown()
```

Cooldown floor: `MIN_COOLDOWN = 0.05` (per WeaponBase line 4). Per Combat GDD Formula 2.

### Formula 2: Single-shot weapon DPS (Talisman, Flying Sword, Thunder Law, Explosive Talisman, Mountain Seal)

```
single_target_dps = damage / max(MIN_COOLDOWN, cooldown)
```

Delegated to Combat GDD Formula 2. Each weapon's effective DPS varies by:
- Talisman: 8.0 / 0.9 ≈ 8.9 DPS
- Flying Sword: 8.0 / 0.9 ≈ 8.9 DPS × pierce_count (3) effective ≈ 26.7 DPS vs. clustered enemies
- Thunder Law: 8.0 / 0.9 × target_count (1) ≈ 8.9 DPS (multi-target if target_count > 1)
- Explosive Talisman: 8.0 + 14.0 explosion ≈ 22 DPS vs. cluster
- Mountain Seal: 8.0 / cooldown × enemies_in_radius_118 (variable)

### Formula 3: Bagua Array effective DPS (tick weapon)

```
per_enemy_dps = damage / max(MIN_TICK_RATE, tick_rate)
total_dps = per_enemy_dps × enemies_in_radius
```

Per Combat GDD Formula 3. At defaults (damage 8, tick_rate 0.65, radius 82):
- per_enemy_dps = 8 / 0.65 ≈ 12.3 DPS per enemy
- 5 enemies in radius → 61.5 DPS total

### Formula 4: Explosion AoE math

```
on impact at point P:
    apply direct damage to projectile_target (= 8 default)
    for enemy in get_tree().get_nodes_in_group("enemies"):
        if global_position.distance_squared_to(enemy.position) <= explosion_radius²:
            enemy.take_damage(explosion_damage)        # = 14 default
```

Explosion hits ALL enemies in radius simultaneously. Damage is independent of direct hit damage.

### Formula 5: Projectile lifetime

```
projectile spawned at weapon position with velocity
on _process(delta):
    _elapsed += delta
    if _elapsed >= projectile_lifetime:
        queue_free()      # no damage, no impact event
    else if pierce_count >= 0 AND has hit pierce_count + 1 enemies:
        queue_free()
```

Projectile expires by time OR by pierce count exhaustion (Flying Sword). Talisman uses time only (no pierce contract — destroys on first hit per its own logic).

## Edge Cases

- **If a weapon's `_try_attack()` returns false** (no target in range): cooldown does NOT reset; the weapon retries next frame. This prevents wasted-shot effects when enemies briefly leave range.
- **If `cooldown < MIN_COOLDOWN = 0.05`**: clamped via `_get_cooldown()` (WeaponBase line 36-37). 20 Hz cap.
- **If `attack_range < MIN_ATTACK_RANGE = 1.0`**: clamped. Effectively no targets — weapon never fires.
- **If Bagua's `tick_rate < MIN_TICK_RATE = 0.05`**: clamped.
- **If projectile passes through DYING enemy** (Combat GDD Core Rule 6): no damage applied (DYING is inert).
- **If pierce_count = 0**: hits 1 enemy then projectile destroys (per Combat GDD Formula 6 + AC-07).
- **If multiple projectiles spawned in same frame** (Talisman count > 1 with spread): each spawns at slight angle offset, each tracks independently.
- **If Bagua Array tick fires while Player is moving rapidly**: aura visual rotates with Player; tick range is calculated from Player position each frame (continuous, not snapshot).
- **If Thunder Law's target_count > enemies_in_range**: only `enemies_in_range` targets are hit (no error).
- **If two Mountain Seal impacts occur at same position**: each emits its own impact scene, damage applies twice. No deduplication.
- **If weapon node is removed mid-attack** (rare — character switch): `_process` stops, no orphan projectiles. (Projectiles, once spawned, are scene-rooted, not weapon-children.)

## Dependencies

| Dependency | Type | Direction | Interface |
|---|---|---|---|
| **Combat** (C-03, Approved) | Hard | Weapon implements Combat contract | WeaponBase + damage tuple |
| **Targeting** (C-05, Approved) | Hard | 5/6 weapons depend on | `_find_nearest_enemy()` per-weapon copies (Targeting OQ-1 tech debt) |
| **Player** (C-01, Approved) | Hard | Player owns weapon nodes | Weapons are children of Player; Player applies upgrades |
| **Enemy** (C-04, Approved) | Hard | Weapon → Enemy | Calls `enemy.take_damage(amount)` |
| **Resource Data Framework** (F-02, Approved) | Soft (currently) | Weapon parameters | Currently scene-embedded; future migration tracked in OQ-2 |
| **Character System** (FT-06, future) | Hard | Bidirectional | CharacterBase enables/disables weapons per character |
| **Level Up & Upgrade Pool** (FT-05, future) | Soft | Upgrade → Weapon | Upgrade application mutates weapon state |
| **Combat Feedback** (P-03, future) | Soft | Indirect | Weapon hit → Enemy.damage_taken → Feedback subscribes |
| **Five Phases Synergy** (elements-five-phases.md) | Hard | Depended-on-by | Provides per-weapon `element` (immutable String export); Five Phases reads it for 相生 combo inventory counting + 相克 matchup lookups |

**Bidirectional check:**
- Combat GDD lists Weapon System as Hard contract ✅
- Targeting GDD lists 5 weapon implementations of `_find_nearest_enemy()` ✅
- Player GDD owns weapon child nodes + applies upgrades ✅
- Five Phases Synergy (elements-five-phases.md) consumes per-weapon `element` ✅

## Tuning Knobs

| Knob | Owner | Design-safe range | Default | Effect at extremes |
|---|---|---|---|---|
| `WeaponBase.damage` | Per-weapon scene | 1 – 200 | 8 | Combat GDD-owned; affects all weapon DPS |
| `WeaponBase.cooldown` | Per-weapon scene | 0.1 – 3.0 | 0.9 | Combat GDD-owned |
| `WeaponBase.projectile_speed` | Per-weapon scene | 100 – 800 | 360 | Combat GDD-owned |
| `WeaponBase.attack_range` | Per-weapon scene | 50 – 600 | 280 | Combat GDD-owned |
| `WeaponBase.projectile_lifetime` | Per-weapon scene | 0.3 – 5.0 | 1.2 | Combat GDD-owned |
| `FlyingSword.pierce_count` | FlyingSword scene | 0 – 8 | 3 | Combat GDD-owned |
| `FlyingSword.projectile_count` | FlyingSword scene | 1 – 8 | 1 | More = visual chaos |
| `Thunder.target_count` | Thunder scene | 1 – 8 | 1 | Combat GDD-owned |
| `Thunder.radius` | Thunder scene | 40 – 180 | 72 | (per Combat GDD §Tuning) |
| `Bagua.tick_rate` | Bagua scene | 0.6 – 1.5 (recommended) | 0.65 | Combat GDD-owned |
| `Bagua.radius` | Bagua scene | 40 – 180 | 82 | Combat GDD-owned |
| `Bagua.rotation_speed` | Bagua scene | 1.0 – 5.0 | 2.4 | Visual; doesn't affect DPS |
| `Explosive.explosion_radius` | Explosive scene | 30 – 150 | 58 | Combat GDD-owned |
| `Explosive.explosion_damage` | Explosive scene | 5 – 80 | 14 | Combat GDD-owned |
| `Explosive.projectile_count` | Explosive scene | 1 – 8 | 1 | More = chaos |
| `Mountain Seal.radius` | MountainSeal scene | 60 – 200 | 118 | Biggest single-strike radius |
| `Talisman.projectile_count` | Talisman scene | 1 – 8 | 1 | More = spam |
| `*.projectile_spread_degrees` | Per-weapon | 0 – 45 | 10-12 | Spread for multi-projectile shots |

Most weapon knobs are owned by Combat GDD §Tuning Knobs as the canonical range source — this GDD references them. Per-weapon scene overrides values per character build.

## Acceptance Criteria

**AC-01** **GIVEN** WeaponBase instance, **WHEN** `_process(delta)` ticks down `_cooldown_remaining` to ≤ 0, **THEN** subclass's `_try_attack()` is called AND cooldown resets to `_get_cooldown()`.

**AC-02** **GIVEN** Talisman with `damage=8`, `cooldown=0.9`, **WHEN** 1 enemy in range, **THEN** within 0.9s a projectile is fired toward nearest enemy AND on hit applies 8 damage.

**AC-03** **GIVEN** Flying Sword with `pierce_count=3`, **WHEN** projectile passes through 5 enemies in a line, **THEN** the first 4 take damage (initial hit + 3 pierces) AND the 5th does not.

**AC-04** **GIVEN** Thunder Law with `target_count=3`, `radius=72`, **WHEN** 5 enemies are in radius, **THEN** Thunder strikes apply damage to exactly 3 (nearest) AND emit 3 ThunderStrike visuals.

**AC-05** **GIVEN** Bagua Array with `damage=8`, `tick_rate=0.65`, `radius=82`, **WHEN** 4 enemies remain in radius for 2 seconds, **THEN** each enemy receives 4 ticks (at t=0, 0.65, 1.30, 1.95) of 8 damage each = 32 damage each.

**AC-06** **GIVEN** Explosive Talisman with `explosion_radius=58`, `explosion_damage=14`, **WHEN** projectile impacts at point P, **THEN** all enemies within 58 px of P take 14 damage AND the projectile's target takes the base damage too.

**AC-07** **GIVEN** Mountain Seal with `radius=118`, **WHEN** `_try_attack()` fires, **THEN** impact scene spawns at nearest enemy position AND all enemies within 118 px take damage.

**AC-08** **GIVEN** a weapon's `cooldown = 0.01` (below MIN_COOLDOWN), **WHEN** weapon ticks, **THEN** effective cooldown is clamped to 0.05 (20 Hz max).

**AC-09** **GIVEN** `_try_attack()` returns false (no valid target), **WHEN** next frame, **THEN** `_cooldown_remaining` is NOT reset AND weapon retries immediately.

**AC-10** **GIVEN** Player is at world (0, 0) AND Bagua Array radius=82, **WHEN** an enemy enters at (60, 60) (distance ~85, just outside radius), **THEN** that enemy is NOT hit (squared distance > radius²).

**AC-11** **GIVEN** an UPGRADE_TALISMAN_DAMAGE upgrade is applied via Player's level-up panel, **WHEN** `_apply_upgrade` runs, **THEN** Talisman weapon's `damage` field is incremented by +10.0 (per Player GDD AC-13 — hardcoded delta per OQ-6).

**AC-12** **GIVEN** CharacterBase.initial_weapon_id = "talisman", **WHEN** character spawn, **THEN** Talisman weapon is enabled AND the other 5 weapons (Flying Sword, Thunder Law, Bagua Array, Explosive Talisman, Mountain Seal) are disabled until their UNLOCK upgrade is applied.

## Open Questions

- **OQ-1** (WeaponBase damage defaults may not match Player.tscn instances): WeaponBase declares `damage = 8.0` as class default. Player.tscn likely overrides per-weapon. Need to verify scene-embedded values for each weapon — they may differ from the 8.0 default. **Resolution candidate**: read Player.tscn weapon node export values; document actual shipping defaults per weapon. **Owner**: systems-designer + lead-programmer. **Target**: revision-1 after Player.tscn inspection.
- **OQ-2** (Weapon `.tres` migration per Resource Data GDD): currently weapon parameters live in `Player.tscn` weapon child nodes (scene-embedded). Resource Data GDD's compliance audit marks this as "PARTIAL". **Resolution candidate**: extract to `resources/weapons/*.tres` (WeaponConfig Resource subclass with damage / cooldown / etc.); each weapon scene loads from .tres. Enables per-character weapon tuning + designer-tunable balance. **Owner**: systems-designer + lead-programmer. **Target**: pre-v0.5 polish.
- **OQ-3** (Sun Wukong active-skill weapons separately covered): the `scripts/weapon/sun_wukong/` subfolder (cloud_step, hair_clone, immobilize, jingu_bang_v2, etc.) implements active-skill weapons triggered by 1-4 keys (per ADR-0003). These share WeaponBase but are scope of Active Skills GDD (FT-07). **Resolution**: when FT-07 lands, cross-reference how active skills extend WeaponBase vs override the cooldown-driven attack model.
- **OQ-4** (Targeting refactor coordination with Weapon System): per Targeting GDD OQ-1, the 5 per-weapon `_find_nearest_enemy()` copies should be extracted to a Targeting singleton. This refactor lives at the boundary of Weapon and Targeting — the Weapon System GDD authoring is the natural co-fold-in point for this work. **Resolution candidate**: when Targeting service is extracted, refactor all 5 weapons in the same sprint. **Owner**: lead-programmer. **Target**: post-v0.4.
- **OQ-5** (Upgrade pool DPS impact analysis): each weapon has 3-5 upgrade IDs; stacking them all maximally pushes DPS far above design-safe ranges. Combat GDD §Tuning Knobs warns about 5.0× source_modifier ceiling — need an explicit playtest validation that 7-level upgrade stacks don't break TTK budgets. **Owner**: game-designer + qa-lead. **Target**: post-v0.4 playtest.

## Registry Updates Recorded

**Consider registering** (cross-weapon constants in entities.yaml):
- `min_cooldown = 0.05` (already in entities.yaml? verify)
- `min_attack_range = 1.0`
- `min_projectile_lifetime = 0.05`
- `min_tick_rate = 0.05`

These are engine-side floors that don't currently appear in entities.yaml but are referenced by multiple GDDs.

**Cross-doc consistency**:
- Combat GDD §Tuning Knobs is authoritative for damage/cooldown/range/etc. ranges ✅
- Targeting GDD lists weapons as consumers (5 implementations of find_nearest) ✅
- Player GDD references upgrade IDs and `_apply_upgrade` deltas ✅
- 04_SKILL_DESIGN.md provides designer-flavor notes per weapon (style guide, not contract)

## Revision Log

| Revision | Date | Trigger | Summary |
|---|---|---|---|
| 0 | 2026-05-25 | Initial reverse-doc | First pass from WeaponBase + 6 weapon subclasses (Talisman, Flying Sword, Thunder Law, Bagua Array, Explosive Talisman, Mountain Seal) + 4 projectile/impact scenes. Excludes Sun Wukong active-skill weapons (FT-07 scope). 8 required CCGS sections + Open Questions + Registry Updates. Documents WeaponBase contract, per-weapon defining mechanic table, 5 formulas (cooldown, single-shot DPS, Bagua tick DPS, explosion AoE, projectile lifetime). 12 ACs cover cooldown countdown, each weapon's signature mechanic, MIN_COOLDOWN clamp, no-target retry, upgrade application, character-init weapon enabling. 5 OQs include weapon defaults verification (OQ-1), `.tres` migration (OQ-2), Sun Wukong scope (OQ-3), Targeting refactor coordination (OQ-4), upgrade stack DPS analysis (OQ-5). |
| 1 | 2026-06-02 | Five Phases dependency propagation | Propagated Five Phases dependency: added `element` export field + 6 weapon element assignments. Additive only. |
