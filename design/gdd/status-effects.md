# Status Effects System

> **Status**: Designed (revision-0)
> **Author**: claude (reverse-doc from Combat GDD §damage types + scattered status implementations in enemy.gd / weapon code / sun_wukong/immobilize.gd)
> **Last Updated**: 2026-05-25
> **Implements Pillar**: Pillar 2 (build depth — status layered on damage)
> **TR Coverage**: (supports Combat GDD's tick / burn damage types)
> **Layer**: Feature/Vertical Slice (depends on Combat)

## Overview

Status Effects is the **damage-over-time + behavioral-modifier layer** that extends Combat GDD's 4 damage types beyond instant strikes. Currently fragmented in v0.4 code:
- **Flash effect** (Enemy.gd) — receives damage → 0.1s white flash sprite override
- **Burn / Tick** — described in Combat GDD Formula 5 (fixed-step accumulator) but no centralized "status effect" class exists yet
- **Immobilize** (`sun_wukong/immobilize.gd`) — Sun Wukong's 定身术 active skill freezes enemies temporarily
- **Elite affixes** (Iron Bones, Swift) — applied at enemy spawn, stat multipliers; not visually exposed as "status"

This GDD locks the future contract: a centralized `StatusEffect` Resource subclass with apply / tick / expire semantics. Currently NO such service exists. Tech debt tracked in OQ-1.

Reference: Combat GDD damage types + AC-15-17 (burn fixed-step), Sun Wukong v2 design.

## Player Fantasy

Status effects are **the build-defining modifiers** — once the player has Bagua + Thunder Law, they're applying tick damage + burn patches simultaneously. The visual layer (white flash, sprite tinting, slow effect) tells them "this enemy is suffering."

When Status Effects work invisibly, the player feels:
- **Layered DPS** — burn DOT continues after the player has moved on
- **Visible cause-and-effect** — flash on hit, dissolve on death, slow on immobilize

## Detailed Rules

1. **Damage types Combat GDD already covers**: direct, tick (Bagua aura), explosion (Explosive Talisman impact), burn (Thunder Strike after-effect).
2. **Hit flash (Enemy)** — 0.1s white sprite override on `take_damage` (Combat Feedback minimum interval 0.05s).
3. **Immobilize** (Sun Wukong 定身术) — `enemy.set_immobilized(duration)` freezes enemy movement; duration typically 2-3s.
4. **Elite affixes** (Enemy spawn) — stat multipliers applied at `configure_elite(affixes)`. Currently: `iron_bones` (HP × 1.45), `swift` (speed × 1.3). Not visually labeled.
5. **Future StatusEffect base class** (OQ-1):
   ```
   class_name StatusEffect extends Resource
   @export var effect_id: String
   @export var duration: float
   @export var tick_interval: float = 0.0  # 0 = no tick
   @export var on_apply: Callable
   @export var on_tick: Callable
   @export var on_expire: Callable
   ```

### Status Effect Inventory (v0.4)

| Effect | Source | Behavior | Implemented? |
|---|---|---|---|
| Hit Flash | Combat damage event | 0.1s white sprite | ✅ Enemy.gd |
| Burn (tick) | Thunder Strike after-effect | Fixed-step damage over duration | ✅ Combat GDD Formula 5 |
| Bagua tick | Continuous aura | Per-tick damage | ✅ BaguaArrayWeapon |
| Immobilize | Sun Wukong 定身术 | Freeze movement | ✅ sun_wukong/immobilize.gd |
| Iron Bones | Elite affix | HP × 1.45 | ✅ Enemy.gd configure_elite |
| Swift | Elite affix | Speed × 1.3 | ✅ Enemy.gd configure_elite |

## Formulas

### Formula 1: Burn fixed-step accumulator
Per Combat GDD Formula 5: `tick = burn_dps × 0.1s`. Frame-rate independent.

### Formula 2: Elite affix multipliers
```
if "iron_bones" in affixes: enemy.max_hp *= 1.45
if "swift" in affixes: enemy.move_speed *= 1.3
```

### Formula 3: Immobilize duration
```
on cast_immobilize(target, duration):
    target.move_speed_multiplier = 0.0
    queue restore after duration seconds
```

## Edge Cases
- **Stacked immobilize**: subsequent applications refresh duration (not extend) — single-source model
- **Burn patch in same area as Bagua tick**: both apply independently (different damage types per Combat)
- **Elite affix on Boss**: not designed — affixes apply to Shanxiao Elite spawn only

## Dependencies
| Dep | Type | Interface |
|---|---|---|
| **Combat** (C-03) | Hard | Status effects extend damage types |
| **Enemy** (C-04) | Hard | Status applied to enemy state (HP, speed, behavior) |
| **Weapon System** (FT-03) | Hard | Weapons trigger status (Bagua tick, Thunder burn) |
| **Active Skills** (FT-07, future) | Soft | Sun Wukong's 定身术 immobilize |

## Tuning Knobs
| Knob | Range | Default |
|---|---|---|
| Hit flash duration | 0.05 – 0.2s | 0.1s |
| Burn tick interval | engine const | 0.1s |
| Immobilize duration (Sun Wukong) | 1 – 5s | 2.5s (TBD) |
| Iron Bones multiplier | 1.0 – 2.0 | 1.45 |
| Swift multiplier | 1.0 – 2.0 | 1.3 |

## Acceptance Criteria

**AC-01** Enemy takes damage → flash visible 0.1s.
**AC-02** Thunder Strike on ground patch → burn damage applies at 0.1s fixed-step interval for `burn_duration`.
**AC-03** Sun Wukong casts 定身术 on enemy → enemy.move_speed effectively 0 for duration.
**AC-04** Shanxiao Elite spawned with `["iron_bones"]` affix → max_hp × 1.45 applied.
**AC-05** Multiple status effects on same enemy → all apply independently (no exclusivity).
**AC-06** Status effect on DYING enemy → silently dropped (per Combat GDD Core Rule 6).

## Open Questions

- **OQ-1** (Extract StatusEffect Resource service): currently statuses are scattered inline (Enemy.gd flash, BaguaWeapon tick, immobilize.gd, configure_elite). A centralized StatusEffect Resource subclass with apply/tick/expire would unify. **Owner**: systems-designer + lead-programmer. **Target**: v0.5+.
- **OQ-2** (Status visual indicators): players don't currently see "this enemy is burning" or "this enemy is slowed" — only the underlying effect. Add per-status icons / sprite tinting. **Owner**: ux-designer + technical-artist. **Target**: VFX GDD authoring.
- **OQ-3** (Status stacking semantics): refresh-vs-extend? Currently inconsistent. Lock the rule in revision-1.

## Registry Updates

Status effect constants (iron_bones 1.45, swift 1.3) already documented in entities.yaml enemy archetype fields.

## Revision Log

| Rev | Date | Trigger | Summary |
|---|---|---|---|
| 0 | 2026-05-25 | Initial reverse-doc | First pass; v0.4 has 6 status types but no centralized service (scattered inline). 6 ACs. 3 OQs: extract StatusEffect Resource, visual indicators, stacking semantics. |
