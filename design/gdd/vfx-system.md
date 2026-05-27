# VFX System (Future Full Vision)

> **Status**: Designed (revision-0 — placeholder for post-v0.4 implementation)
> **Author**: claude (placeholder; v0.4 has only minimal VFX inline in scenes)
> **Last Updated**: 2026-05-25
> **Implements Pillar**: Pillar 3 (visual identity — 暗黑志怪 palette)
> **TR Coverage**: TR-VFX-* domain (reserved)
> **Layer**: Polish/Full Vision (MINIMAL IN v0.4)

## Overview

VFX System will own all visual effects: hit feedback, death animations, weapon trails, explosion bursts, boss telegraphs, demon-seal completion glow. v0.4 ships with **minimal VFX** — only basic Polygon2D placeholders for projectiles + simple hit flash (per Combat Feedback GDD). Future: a Particles2D + Shader-based VFX library following 07_VISUAL_STYLE_GUIDE.md 暗黑志怪 palette.

Per Combat GDD's reservation: VFX GDD owns the visual-death dissolve timing (≤0.5s budget per AC-22).

Reference: Combat GDD §Visual/Audio + AC-22, Combat Feedback GDD §Dependencies, 07_VISUAL_STYLE_GUIDE.md.

## Player Fantasy

> "When my Talisman strikes, a yellow burst flares. The Bagua Array glows with pulsing trigrams. Thunder Law cracks down a luminescent strike. The Stone Golem's death produces an earth-spray particle burst lasting 0.4s. The Boss telegraph shows a translucent danger zone before the charge."

Anti-fantasy: flat-color sprites with no flair, no telegraph for boss attacks, death effects so brief they feel arbitrary.

## Detailed Rules (Future)

1. **VFX library organized by category**: hit_burst, death_dissolve, projectile_trail, ground_aoe, boss_telegraph, completion_glow, character_aura
2. **Visual-death dissolve** ≤0.5s budget (per Combat GDD AC-22 — VFX owns this contract)
3. **Hit feedback layer** owned jointly with Combat Feedback GDD (flash, particles, optional shake)
4. **Boss attack telegraphs** (charge danger line, burst warning ring) — critical for fairness
5. **Damage number floaters** (optional) — visual style per Combat GDD §Visual/Audio palette
6. **Color-blind alternative palette** (Combat GDD N-2 hook): `crit_indicator_palette = COLORBLIND_SAFE` toggles non-color visual differentiation

### Effect Inventory (Planned)

| Effect | Trigger | Duration | Description |
|---|---|---|---|
| Hit burst | damage_taken | 0.1-0.2s | Per-weapon-style spark |
| Death dissolve | died | ≤0.5s | Sprite fade + particle puff |
| Projectile trail | weapon fire | per-projectile lifetime | Color-coded per weapon |
| Bagua aura | always-on | continuous | Rotating trigram |
| Thunder strike | thunder hit | 0.3s | Sky-to-ground bolt |
| Demon Seal glow | sealing in progress | continuous | Soft pulse around ring |
| Demon Seal completion | seal_completed | 0.6s | Gold burst + rays |
| Boss telegraph (charge) | windup phase | 0.7s | Translucent danger line |
| Boss telegraph (burst) | warning phase | 1.05s | Ring expand |
| Level Up flash | upgrade_applied | 0.4s | Soft white pulse around player |

## Formulas

### Formula 1: Visual-death timing (per Combat GDD AC-22)
```
on died(payload):
    play_dissolve(payload.enemy, duration=0.5)
    # actual queue_free MUST complete within 0.5s
```

### Formula 2: Particle count budget
```
total_particles_at_once <= 200  # performance ceiling at 60 FPS
per-effect cap = 30 particles
```

## Edge Cases
- **Effect cap exceeded**: prioritize newer effects, drop oldest
- **VFX during pause**: most VFX freeze with `get_tree().paused`
- **Photosensitivity**: per Combat GDD advisory + Combat Feedback OQ — rate-limit shake/strobe

## Dependencies (Future)
| Dep | Type | Interface |
|---|---|---|
| **Combat** (C-03) | Hard | damage_taken, died signals |
| **Combat Feedback** (P-03) | Hard | Coordinates flash + dissolve + shake |
| **Stage Director** (FT-02) | Hard | Boss telegraph triggers |
| **Demon Seal** (FT-08) | Hard | Sealing + completion VFX |
| **Level Up** (FT-05) | Soft | upgrade_applied flash |

## Tuning Knobs (Future)
| Knob | Range | Default |
|---|---|---|
| Death dissolve duration | 0.2 – 1.0s | ≤0.5s (Combat AC-22) |
| Hit burst duration | 0.05 – 0.3s | 0.1s |
| Total particle ceiling | 100 – 500 | 200 |
| Per-effect particle cap | 10 – 60 | 30 |
| Boss telegraph alpha | 0.2 – 0.6 | 0.4 |

## Acceptance Criteria (Future)

**AC-01** Enemy dies → dissolve plays for ≤0.5s before queue_free (Combat AC-22).
**AC-02** Talisman fires → projectile has yellow trail visible across screen.
**AC-03** Boss charge windup → translucent danger line displayed for 0.7s.
**AC-04** Demon Seal completes → gold burst + ray VFX for 0.6s.
**AC-05** 200+ particles attempted → newest 200 displayed, older drop.
**AC-06** Color-blind toggle on → crit visual uses shape differentiation, not color.

## Open Questions

- **OQ-1** (Particles2D vs Shader-driven VFX): Particles2D is easier, shader-driven gives finer control. Mix based on effect type.
- **OQ-2** (VFX asset sourcing): per originality policy, prefer original sprites/textures.
- **OQ-3** (Performance profiling): VFX is the most likely perf bottleneck after 50+ enemies. Profile after Polish phase.

## Revision Log

| Rev | Date | Trigger | Summary |
|---|---|---|---|
| 0 | 2026-05-25 | Placeholder GDD for post-v0.4 | Documents 10-effect VFX inventory + budget rules. v0.4 has minimal VFX. AC-01 inherited from Combat AC-22 (visual-death timing). 6 ACs total. 3 OQs (Particles2D vs shader, asset sourcing, perf profiling). |
