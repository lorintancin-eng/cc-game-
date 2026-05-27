# Elements / 五行 System (Future v0.5+)

> **Status**: Designed (revision-0 — placeholder for v0.5+ implementation)
> **Author**: claude (placeholder doc; not yet implemented)
> **Last Updated**: 2026-05-25
> **Implements Pillar**: Pillar 2 (build depth via elemental matchups)
> **TR Coverage**: TR-CORE-005 (五行 modifier slot in Combat Formula 1)
> **Layer**: Feature/Full Vision (NOT IMPLEMENTED IN v0.4)

## Overview

The Elements / 五行 System will activate the `element_modifier` slot reserved in Combat Formula 1's damage pipeline. v0.5+ feature. Per 03_CORE §9 element table:

| 元素 | 克 | 怕 |
|---|---|---|
| 金 (metal) | 木 (wood) | 火 (fire) |
| 木 (wood) | 土 (earth) | 金 (metal) |
| 水 (water) | 火 (fire) | 土 (earth) |
| 火 (fire) | 金 (metal) | 水 (water) |
| 土 (earth) | 水 (water) | 木 (wood) |

When matchup is favorable: damage × 1.3 (+30%). Unfavorable: × 0.8 (−20%). Neutral: × 1.0.

v0.4 contract reserved per Combat GDD OQ-4 (Resolution: pre-clamp).

## Player Fantasy

> "I see a Stone Golem (earth) approaching. My Talisman is wood-element — I'll deal +30% damage. But a Ghost Flame (fire) approaches — wood is weak to metal but not fire, so still 1.0×. Strategic element matchups make the build pop."

## Detailed Rules

1. **Every Enemy archetype declares `element: String`** (per Enemy GDD `EnemyArchetype.element`). Currently all "neutral" until v0.5 assigns specific elements.
2. **Every Weapon (or attack) declares its element** — either inherited from character or per-weapon override.
3. **Damage application reads source.element + target.element** → applies modifier table → multiplies into `element_modifier` slot of Combat Formula 1.
4. **5x5 matchup table** (per 03_CORE §9). Symmetric: if A克B (favorable), B怕A (unfavorable).
5. **"neutral" element**: bypasses table — `element_modifier = 1.0` regardless of opponent.

## Formulas

### Formula 1: Matchup lookup
```
matchup_table = {
    ("metal", "wood"): 1.3,   # metal克wood
    ("wood", "earth"): 1.3,
    ("water", "fire"): 1.3,
    ("fire", "metal"): 1.3,
    ("earth", "water"): 1.3,
    # ... reverse pairs at 0.8
}

element_modifier = matchup_table.get((source.element, target.element), 1.0)
```

## Edge Cases
- **Neutral on either side**: returns 1.0
- **Same element on both sides**: returns 1.0 (no advantage)
- **Boss element**: TBD per design (likely fire for Famine Beast?)

## Dependencies
| Dep | Type | Interface |
|---|---|---|
| **Combat** (C-03) | Hard | `element_modifier` slot in Formula 1 (reserved) |
| **Enemy** (C-04) | Hard | `element` field per archetype |
| **Character System** (FT-06) | Hard | `element` field per CharacterBase |
| **Weapon System** (FT-03) | Soft | Future per-weapon element overrides |

## Tuning Knobs
| Knob | Default | Range |
|---|---|---|
| Favorable modifier | 1.3 | 1.1 – 1.5 |
| Unfavorable modifier | 0.8 | 0.5 – 0.9 |
| Neutral modifier | 1.0 (locked) | — |

## Acceptance Criteria

**AC-01** Source=metal vs Target=wood → element_modifier = 1.3.
**AC-02** Source=wood vs Target=metal → element_modifier = 0.8.
**AC-03** Source=neutral vs any → element_modifier = 1.0.
**AC-04** Combat Formula 1 applies element_modifier in correct pipeline position (pre-clamp per Combat OQ-4).
**AC-05** Same element on both sides → element_modifier = 1.0.

## Open Questions

- **OQ-1** (Element assignments per enemy / character): v0.5 needs to design which enemies/characters get which elements. 03_CORE §9 specifies the table but not the assignments.
- **OQ-2** (Visual indicator): how to show "favorable matchup" feedback in HUD or floaters? Owner: ux-designer.
- **OQ-3** (Boss element specificity): which element is Famine Beast? Probably earth (drought metaphor → wood-eaten?) or fire. Owner: game-designer.

## Revision Log

| Rev | Date | Trigger | Summary |
|---|---|---|---|
| 0 | 2026-05-25 | Placeholder GDD for v0.5+ | Documents 5x5 matchup table, element_modifier slot in Combat. NOT IMPLEMENTED in v0.4 — all entities "neutral". Activation in v0.5 will require element assignments + UI work. |
