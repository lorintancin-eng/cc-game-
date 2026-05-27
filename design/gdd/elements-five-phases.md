# Elements / 五行 System (Future v0.5+)

> **Status**: Approved (revision-1 — addresses 2 BLOCKERS + 4 RECOMMENDED from /design-review revision-0 CONCERNS)
> **Author**: claude (placeholder doc; not yet implemented)
> **Last Updated**: 2026-05-27
> **Implements Pillar**: Supports Pillar 2 (`自动战斗与有意义的构筑选择` — Elements add an elemental-matchup build-choice dimension; game-concept.md does not name 五行 in pillar text but the system is consistent with build-depth intent)
> **TR Coverage**: Reserved — no TR-ID assigned yet. Activation in v0.5 requires registering `TR-elements-001` in `docs/architecture/tr-registry.yaml`. Slot reservation in Combat is informally tracked at Combat GDD OQ-4 resolution (pre-clamp pipeline position).
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

1. **Every Enemy archetype declares `element: String`** — **RESERVED FIELD**: Not yet in Enemy GDD's 19-field EnemyArchetype schema (enemy-system.md lines 81-103). v0.5 implementer must (a) amend Enemy GDD with `element: String = "neutral"` row + add forward-dependency note, and (b) update all 7 archetype `.tres` resources. Until then, all enemies are implicitly "neutral".

**Element string vocabulary (closed set)**: lowercase identifiers from `{neutral, metal, wood, water, fire, earth}`. Any other value → `push_error()` + treated as neutral. Character GDD line 207 declares the same set canonically; this GDD restates it for clarity.
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

**Algorithmic statement (canonical form)** — equivalent to the lookup table but avoids enumerating 10 ordered pairs:
```
favorable_set = {(metal,wood), (wood,earth), (water,fire), (fire,metal), (earth,water)}

if "neutral" in (source.element, target.element): return 1.0
if (source.element, target.element) in favorable_set: return 1.3
if (target.element, source.element) in favorable_set: return 0.8  # reverse pair = unfavorable
return 1.0  # same element or unrelated pair
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
**AC-04** **GIVEN** current_hp=10, raw_damage=8, source_modifier=1.0, crit_multiplier=1.0, element_modifier=1.3, pierce_falloff=1.0, **WHEN** damage is applied via Combat Formula 1, **THEN** final_damage = 8 × 1.0 × 1.0 × 1.3 × 1.0 = 10.4 AND new_hp = max(0, 10 − 10.4) = 0 (clamp applied AFTER element multiplier per Combat OQ-4 pre-clamp resolution).
**AC-05** Same element on both sides → element_modifier = 1.0.

## Open Questions

- **OQ-1** (Element assignments per enemy / character): v0.5 needs to design which enemies/characters get which elements. 03_CORE §9 specifies the table but not the assignments.
- **OQ-2** (Visual indicator): how to show "favorable matchup" feedback in HUD or floaters? Owner: ux-designer. **Target**: v0.5 HUD/Combat Feedback GDD revision when Elements activates.
- **OQ-3** (Boss element specificity): which element is Famine Beast? Probably earth (drought metaphor → wood-eaten?) or fire. Owner: game-designer.

## Revision Log

| Rev | Date | Trigger | Summary |
|---|---|---|---|
| 0 | 2026-05-25 | Placeholder GDD for v0.5+ | Documents 5x5 matchup table, element_modifier slot in Combat. NOT IMPLEMENTED in v0.4 — all entities "neutral". Activation in v0.5 will require element assignments + UI work. |
| 1 | 2026-05-27 | /design-review revision-0 CONCERNS (2 BLOCKERS + 4 RECOMMENDED) | **B-1 closed**: explicitly marked `element` field as RESERVED (not yet in Enemy GDD 19-field schema); v0.5 implementer must amend Enemy GDD. Added closed-set vocabulary `{neutral, metal, wood, water, fire, earth}` with push_error guard. **B-2 closed**: dropped incorrect TR-CORE-005 reference (that TR is the 60FPS performance requirement, unrelated); marked TR-elements-001 as v0.5 registration task. **R-1 closed**: Formula 1 expanded with algorithmic statement avoiding the "...reverse pairs at 0.8" hand-wave. **R-3 closed**: AC-04 rewritten in GIVEN/WHEN/THEN form with concrete worked example showing pre-clamp pipeline position observably. **R-4 closed**: Pillar 2 citation softened from "build depth via elemental matchups" to "supports Pillar 2 build-choice dimension" with disclosure that game-concept.md does not name 五行 in pillar text. **N-4 closed**: OQ-2 given target ("v0.5 HUD revision when Elements activates"). |
