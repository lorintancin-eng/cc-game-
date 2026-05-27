# VFX System (Future Full Vision)

> **Status**: Approved (revision-1 — addresses 3 BLOCKERS + 7 RECOMMENDED + 6 NICE-TO-HAVE from /design-review revision-0 NEEDS REVISION)
> **Author**: claude (placeholder; v0.4 has only minimal VFX inline in scenes)
> **Last Updated**: 2026-05-27
> **Implements Pillar**: Pillar 3 (visual identity — 暗黑志怪 palette per `design/style/07_VISUAL_STYLE_GUIDE.md`: 朱砂红 / 青铜金 / 鬼火青光 / 黑红妖气)
> **TR Coverage**: TR-VFX-* domain (reserved — v0.5 implementer must register TR-vfx-001 in `docs/architecture/tr-registry.yaml` before story-readiness checks)
> **Layer**: Polish/Full Vision (MINIMAL IN v0.4)

## Overview

VFX System will own all visual effects: hit feedback, death animations, weapon trails, explosion bursts, boss telegraphs, demon-seal completion glow. v0.4 ships with **minimal VFX** — only basic Polygon2D placeholders for projectiles + simple hit flash (per Combat Feedback GDD). Future: a **GPUParticles2D for transient bursts + CanvasItem shaders for always-on auras** library following `design/style/07_VISUAL_STYLE_GUIDE.md` 暗黑志怪 palette.

Per Combat GDD's reservation: VFX GDD owns the visual-death dissolve timing (≤0.5s budget per AC-22). **`queue_free()` ownership**: on `died` signal, VFX subscribes, plays dissolve for ≤0.5s, then calls `enemy.queue_free()` itself. Enemy does NOT self-`queue_free` on `died` — VFX is authoritative.

Reference: Combat GDD §Visual/Audio + AC-22, Combat Feedback GDD §Dependencies, `design/style/07_VISUAL_STYLE_GUIDE.md`.

## Player Fantasy

> "When my Talisman strikes, a **朱砂红 (cinnabar-red)** burst flares. The Bagua Array glows with pulsing **青铜金 (bronze-gold)** trigrams. Thunder Law cracks down a **鬼火青光 (ghost-fire blue-green)** strike. The Stone Golem's death produces an earth-spray particle burst lasting 0.4s in **黑红妖气 (black-red demonic vapor)**. The Boss telegraph shows a **半透明朱砂 (translucent cinnabar)** danger zone before the charge." (Colors anchored to `design/style/07_VISUAL_STYLE_GUIDE.md` palette to avoid drifting bright/celebratory — the 暗黑志怪 aesthetic favors restraint on saturation.)

Anti-fantasy: flat-color sprites with no flair, no telegraph for boss attacks, death effects so brief they feel arbitrary.

## Detailed Rules (Future)

1. **VFX library organized by category**: hit_burst, death_dissolve, projectile_trail, ground_aoe, boss_telegraph, completion_glow, character_aura
2. **Visual-death dissolve** ≤0.5s budget (per Combat GDD AC-22 — VFX owns this contract)
3. **Hit feedback layer** owned jointly with Combat Feedback GDD (flash, particles, optional shake)
4. **Boss attack telegraphs** (charge danger line, burst warning ring) — critical for fairness
5. **Damage number floaters** (optional) — visual style per Combat GDD §Visual/Audio palette
6. **Color-blind alternative palette** (Combat GDD N-2 hook): `crit_indicator_palette = COLORBLIND_SAFE` activates a **diagonal-stripe overlay on crit-affected sprites + "!" icon prefix on crit damage numbers** (concrete encoding committed per Combat GDD N-2 alternatives "underline / bold weight / icon prefix"). AC-06 tests for the icon prefix specifically.
7. **Photosensitivity rate-limit** (per WCAG 2.3.1 "Three Flashes or Below Threshold"): VFX system never exceeds **3 full-screen luminance flips per second** AND never produces continuous strobe >3 Hz on >25% of screen area. Applies to: hit_burst overlays, death_dissolve flashes, completion_glow pulses, boss_telegraph red flashes. Edge case `Photosensitivity` (below) defines the testable rule; AC-N defends it.

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

### Formula 1: Visual-death timing (per Combat GDD AC-22) — VFX owns `queue_free`
```
on died(payload):
    play_dissolve(payload.enemy, duration=0.5)
    await dissolve_finished_signal      # 0.5s elapsed
    payload.enemy.queue_free()           # VFX authoritative — Enemy does NOT self-free
```
**Ownership contract**: VFX subscribes to `Combat.died`, plays dissolve, then itself calls `queue_free()` on the enemy node. Enemy does NOT self-`queue_free` on `died` — this is the contract Combat AC-22 reserved for VFX GDD to resolve.

### Formula 2: Particle count budget
```
total_particles_at_once <= 200  # performance ceiling at 60 FPS (GPUParticles2D default backend)
per-effect cap = 30 particles
always_on_reserve = 60 particles  # Bagua aura + Demon Seal glow + character_aura exempt from drop rule
transient_pool = 200 - always_on_reserve = 140 particles (newest-wins drop rule applies here only)
```
**Always-on effects** (Bagua aura, Demon Seal glow, character aura) reserve their particles regardless of cap. The newest-wins "drop oldest" rule (Edge Cases) applies only to transient effects (hit_burst, death_dissolve, projectile_trail, ground_aoe, boss_telegraph bursts, completion_glow).

## Edge Cases
- **Effect cap exceeded**: prioritize newer transient effects, drop oldest transient. Always-on effects (Bagua aura, Demon Seal glow, character aura) are exempt from drop and reserve their 60-particle pool (per Formula 2).
- **VFX during pause**: **all VFX freeze** when `get_tree().paused == true`. GPUParticles2D + CPUParticles2D both honor pause via their default `WHEN_NOT_PAUSED` process_mode. CanvasItem shaders pause via `material.set_shader_parameter("paused", true)` hook in the shared base material.
- **Photosensitivity (testable rule per WCAG 2.3.1)**: VFX system MUST NOT exceed **3 luminance flips per second** on the same screen region AND MUST NOT produce continuous strobe at >3 Hz on >25% of screen area. Enforced via a `luminance_change_rate_limiter` service that tracks per-region flash counts in the last 1.0s window and suppresses additional flashes that would push the rate above 3 Hz. AC-N below.

## Dependencies (Future)
| Dep | Type | Interface |
|---|---|---|
| **Combat** (C-03) | Hard | damage_taken, died signals; AC-22 visual-death contract (VFX owns queue_free) |
| **Combat Feedback** (P-03) | Hard | Coordinates flash + dissolve + shake; photosensitivity rate-limit |
| **Stage Director** (FT-02) | Hard | Boss telegraph triggers (4:30 boss_warning, phase transitions) |
| **Demon Seal** (FT-08) | Hard | Sealing + completion VFX; OQ-3 telegraph beacon |
| **Level Up** (FT-05) | Soft | upgrade_applied flash |
| **Weapon System** (FT-03) | Soft | Per-weapon projectile trail keys (Talisman / Bagua / Thunder Law trails) |
| **Boss System** (FT-09) | Soft | Telegraph timing source (charge 0.7s, burst warning 1.05s — match boss-system.md lines 36-37) |

## Tuning Knobs (Future)
| Knob | Range | Default |
|---|---|---|
| Death dissolve duration | **0.2 – 0.5s** | ≤0.5s (HARD CLAMP per Combat AC-22 — wider range removed; 0.5s upper is a memory-leak failure mode if exceeded) |
| Hit burst duration | 0.05 – 0.3s | 0.1s |
| Total particle ceiling | 100 – 500 | 200 |
| Per-effect particle cap | 10 – 60 | 30 |
| Boss telegraph alpha | 0.2 – 0.6 | 0.4 |

## Acceptance Criteria (Future)

**AC-01** **GIVEN** `Combat.died(payload)` fires, **WHEN** VFX subscriber runs, **THEN** `play_dissolve(payload.enemy, 0.5)` is invoked AND after 0.5s elapses VFX calls `payload.enemy.queue_free()` (VFX owns the call; Enemy does NOT self-free).
**AC-02** **GIVEN** Talisman fires, **WHEN** projectile spawns, **THEN** projectile node has a Trail2D child active for the projectile's lifetime AND the trail uses the 朱砂红 palette key from style guide (visual confirmation = screenshot + lead sign-off per coding-standards.md evidence table).
**AC-03** **GIVEN** Boss charge windup begins (per boss-system.md line 36), **WHEN** the telegraph fires, **THEN** a translucent danger line node is added for exactly 0.7s before the charge phase advances.
**AC-04** **GIVEN** `DemonSeal.seal_completed(seal)` fires, **WHEN** VFX subscriber runs, **THEN** completion_glow effect spawns with duration 0.6s ± 1 frame.
**AC-05** **GIVEN** 200+ transient particles attempted within one frame, **WHEN** Formula 2 budget enforced, **THEN** newest transient particles displayed up to 140-particle cap AND oldest transient particles dropped first AND always-on effects (Bagua aura, Demon Seal glow, character aura) remain visible regardless.
**AC-06** **GIVEN** `crit_indicator_palette = COLORBLIND_SAFE`, **WHEN** a crit damage event fires, **THEN** the damage number floater has a "!" icon prefix AND the affected sprite shows a diagonal-stripe overlay (concrete encoding committed in Rule 6).
**AC-07** **GIVEN** VFX system active, **WHEN** any 1-second window measured, **THEN** no more than 3 luminance flips occur on the same screen region AND no continuous strobe >3 Hz on >25% screen area (per WCAG 2.3.1 photosensitivity rule from Edge Cases).
**AC-08** **GIVEN** a single VFX emitter, **WHEN** more than 30 particles attempted by that emitter, **THEN** emitter is clamped to 30 particles AND `push_warning("VFX per-effect cap exceeded")` is logged.

## Open Questions

- **OQ-1** (Particles2D vs Shader-driven VFX): **Tentative resolution**: GPUParticles2D for transient bursts (hit_burst, death_dissolve, projectile_trail, completion_glow); CanvasItem shaders for always-on auras (Bagua aura, Demon Seal glow, character_aura). Finalize during v0.5 implementation.
- **OQ-2** (VFX asset sourcing): per originality policy, prefer original sprites/textures.
- **OQ-3** (Performance profiling): VFX is the most likely perf bottleneck after 50+ enemies. Profile after Polish phase.
- **OQ-4** (Reduced-motion accessibility): a `reduced_motion = true` setting should disable Bagua aura rotation, freeze always-on auras, suppress non-critical particle bursts. **Owner**: accessibility-specialist + ux-designer. **Target**: v0.5 accessibility GDD authoring.

## Revision Log

| Rev | Date | Trigger | Summary |
|---|---|---|---|
| 0 | 2026-05-25 | Placeholder GDD for post-v0.4 | Documents 10-effect VFX inventory + budget rules. v0.4 has minimal VFX. AC-01 inherited from Combat AC-22 (visual-death timing). 6 ACs total. 3 OQs (Particles2D vs shader, asset sourcing, perf profiling). |
| 1 | 2026-05-27 | /design-review revision-0 NEEDS REVISION (3 BLOCKERS + 7 RECOMMENDED + 6 NICE-TO-HAVE) | **B-1 closed**: Formula 1 ownership disambiguated — VFX subscribes to `died`, plays dissolve, then calls `enemy.queue_free()` (Enemy does NOT self-free). **B-2 closed**: photosensitivity rate-limit numerical: ≤3 luminance flips/sec/region per WCAG 2.3.1; AC-07 defends. **B-3 closed**: color-blind alternative encoding committed to "!" icon prefix + diagonal-stripe sprite overlay (concrete per Combat N-2 alternatives). **R-1 closed**: always-on effects (60-particle reserve) exempt from newest-wins drop rule. **R-2 closed**: Death dissolve range hard-clamped 0.2-0.5s (was 0.2-1.0s — wider range silently violated Combat AC-22). **R-3 closed**: tentative resolution to OQ-1 (GPUParticles2D for transient / CanvasItem shader for auras). **R-4 closed**: Player Fantasy colors re-anchored to 朱砂/青铜/鬼火青光/黑红妖气 palette keys per 07_VISUAL_STYLE_GUIDE.md. **R-5 closed**: ACs reformulated to logic-testable (duration, signal observable) + visual-evidence claims separated. **R-6 closed**: AC-07 added defending photosensitivity edge case. **R-7 closed**: Dependencies table added Weapon System + Boss System (per systems-index declaration). **N-1 closed**: style guide path fixed to `design/style/07_VISUAL_STYLE_GUIDE.md`. **N-2 closed**: OQ-4 added for reduced-motion. **N-3 closed**: AC-08 added defending per-effect 30-particle cap with warning. **N-4 closed**: pause behavior committed to "all VFX freeze" with concrete mechanism. |
