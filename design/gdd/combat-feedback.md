# Combat Feedback System

> **Status**: Designed (revision-0)
> **Author**: claude (reverse-doc from Enemy.gd flash + Combat GDD Visual/Audio §)
> **Last Updated**: 2026-05-25
> **Implements Pillar**: Pillar 1 (clear pressure feedback)
> **TR Coverage**: TR-enemy-002 (combat feedback signal contract)
> **Layer**: Presentation (depends on Combat, Enemy)

## Overview

Combat Feedback is the **visual + audio response** to Combat events. Currently scattered:
- **Hit flash** on Enemy (0.1s white) — implemented in Enemy.gd
- **Death dissolve** — Visual-death timing per Combat GDD AC-22 (≤0.5s, VFX GDD-owned)
- **Screen shake** on heavy hits — NOT implemented (Combat GDD reserved)
- **Damage number floaters** — optional v0.4+, NOT implemented

This GDD locks the contract for the future centralized service.

Reference: Combat GDD §Visual/Audio + AC-22 (visual-death timing), Enemy GDD (hit flash mechanism).

## Player Fantasy

Combat feedback tells the player **whether a hit happened**. White flash = confirmed damage. Screen shake = "that was big". Damage numbers = "I'm getting stronger". Without these, the player feels like they're inputting actions into a void.

## Detailed Rules

1. **Hit flash** (existing, Enemy-side): on `damage_taken`, sprite tints white for 0.1s.
2. **Minimum flash interval** (per Combat GDD Visual/Audio): 0.05s between consecutive flashes on same target (prevents strobe at high DPS, accessibility consideration).
3. **Death VFX** (per Combat GDD AC-22): dissolve animation ≤0.5s before queue_free. VFX GDD owns the timing.
4. **Screen shake** (future): triggered on Boss/elite hits or explosions. Combat GDD reserves API; Camera GDD will own the shake math.
5. **Damage number floaters** (optional v0.4+): rise + fade ~0.5s; off-white text with red glow on crits (Combat GDD §Visual/Audio).
6. **Low-HP heartbeat** (HUD-driven, future): when `current_hp < 0.25 × max_hp`.

## Formulas

### Formula 1: Flash interval throttle
```
last_flash_time = 0.0
on damage_taken(target, amount):
    if time_now - last_flash_time < 0.05: return
    target.flash(0.1)
    last_flash_time = time_now
```

### Formula 2: Screen shake (future API placeholder)
```
on Combat.shake_event(intensity, duration):
    Camera.shake(intensity, duration)   # Camera GDD owns the math
```

## Edge Cases
- **Multiple weapons hit same enemy same frame**: flash interval throttle prevents strobe
- **Boss death**: special VFX (larger dissolve, possibly camera pulse)
- **Player low-HP visual**: heartbeat by HUD, not by Combat Feedback

## Dependencies
| Dep | Type | Interface |
|---|---|---|
| **Combat** (C-03) | Hard | Subscribes to damage_taken / died signals |
| **Enemy** (C-04) | Soft | Per-enemy flash implementation |
| **Camera** (C-02) | Soft | Future shake API |
| **VFX** (PL-02, future) | Soft | Death animations |
| **Audio** (PL-01, future) | Soft | Hit SFX cues |

## Tuning Knobs
| Knob | Range | Default |
|---|---|---|
| Hit flash duration | 0.05 – 0.2s | 0.1s |
| Min interval between flashes | 0.03 – 0.1s | 0.05s |
| Visual-death dissolve duration | 0.2 – 1.0s | ≤0.5s |
| Future screen shake intensity | 0 – 12 px | TBD |
| Future damage number lifetime | 0.3 – 1.0s | 0.5s |

## Acceptance Criteria

**AC-01** Enemy receives damage → sprite tints white for 0.1s.
**AC-02** Enemy receives 2 hits within 0.03s → only 1 flash plays (per minimum interval throttle).
**AC-03** Enemy dies → dissolve VFX plays for ≤0.5s before queue_free (per Combat GDD AC-22).
**AC-04** Boss hits player → (future) screen shake triggers via Camera.shake API.
**AC-05** Player HP drops below 25% max → (future) HUD heartbeat overlay activates.

## Open Questions

- **OQ-1** (Centralize Combat Feedback service): currently scattered inline (Enemy.gd flash, no shake yet, no floaters). Future service: `combat_feedback.gd` AutoLoad subscribes to Combat signals → routes to per-effect implementations.
- **OQ-2** (Damage number floater priority): v0.4+ optional. Visual style: 暗黑志怪 palette (off-white with red glow). Need ux-designer + technical-artist input.
- **OQ-3** (Screen shake interaction with accessibility): per Combat GDD §photosensitivity advisory — shake at high DPS density could be a strobe risk. Combat Feedback service must rate-limit shake too. Owner: accessibility-specialist.

## Revision Log

| Rev | Date | Trigger | Summary |
|---|---|---|---|
| 0 | 2026-05-25 | Initial reverse-doc | First pass; only hit flash is implemented today. Screen shake + damage floaters + heartbeat all reserved future. 5 ACs (2 implemented, 3 future). 3 OQs: centralize service, damage floater spec, accessibility for shake. |
