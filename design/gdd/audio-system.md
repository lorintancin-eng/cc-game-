# Audio System (Future Full Vision)

> **Status**: Designed (revision-0 — placeholder for post-v0.5 implementation)
> **Author**: claude (placeholder; not yet implemented)
> **Last Updated**: 2026-05-25
> **Implements Pillar**: Pillar 3 (题材方向 — sound is the largest contributor to 暗黑志怪压迫感)
> **TR Coverage**: TR-AUDIO-* domain (reserved)
> **Layer**: Polish/Full Vision (NOT IMPLEMENTED IN v0.4)

## Overview

The Audio System will own all game audio: music, SFX, UI cues, ambient. v0.4 ships **without audio implementation** (per Resource Data Framework GDD audit). Future scope:

- 3 audio buses: SFX / Music / UI (set in `project.godot` Audio Bus Layout)
- Per-weapon hit SFX (≤0.15s each, distinct per weapon)
- Boss music swap at 5:00
- Demon Seal completion chime
- Level Up panel "悟道" cue
- Player low-HP heartbeat (HUD-coordinated)
- Worst-case event rate: 160 events/sec (8 active targets × 20 shots/sec — per Combat GDD §Audio handoff)

Reference: Combat GDD §Audio handoff to Audio GDD (rate limits + coalescing requirements).

## Player Fantasy

> "The opening minute is quiet — just my footsteps and the soft chime of XP orbs. By minute 3 the score swells, layered drums under the action. At 4:30 the boss warning crashes in — a deep horn over silence. The 5:00 boss music is pure tension, drums + ghost-voice samples until I land the killing blow and silence falls."

Anti-fantasy: audio that pops, ducks irregularly, or fails to coalesce at high DPS.

## Detailed Rules (Future)

1. **3-bus architecture** (SFX / Music / UI) — independent volume sliders per bus
2. **Per-weapon SFX** ≤0.15s; played on Combat GDD's `damage_dealt` signal
3. **Music swap on Stage Director phase transitions** (e.g. 4:30 boss-warning crash)
4. **Demon Seal completion chime** (gold-tinted, ≤1s)
5. **Level Up "悟道" cue** ≤0.8s
6. **SFX coalescing**: when N hit events fire within 16.67ms, play 1 SFX with louder mix (not N stacked SFX)
7. **Ducking**: when Boss music plays, SFX bus ducks -3dB

## Formulas

### Formula 1: SFX coalescing
```
on hit_event:
    if time_since_last_hit_sfx < 0.05:
        # Coalesce: louden previous SFX, don't play new
        return
    play_sfx(hit_sfx, volume=damage_intensity)
    time_since_last_hit_sfx = now
```

## Edge Cases
- **Mute toggle**: respects per-bus mute
- **Music swap during ambient**: 0.3s crossfade
- **Boss music + Demon Seal pressure overlap**: pressure cue ducks under boss intro
- **>160 events/sec**: SFX coalescing absorbs

## Dependencies (Future)
| Dep | Type | Interface |
|---|---|---|
| **Combat** (C-03) | Hard | damage_dealt signal for hit SFX |
| **Stage Director** (FT-02) | Hard | Phase transition events for music swap |
| **Level Up** (FT-05) | Hard | upgrade_applied for "悟道" cue |
| **Demon Seal** (FT-08) | Hard | seal_completed for chime |
| **HUD** (P-01) | Hard | Low-HP heartbeat coordination |

## Tuning Knobs (Future)
| Knob | Range | Default |
|---|---|---|
| SFX bus volume | 0 – 100 | 80 |
| Music bus volume | 0 – 100 | 60 |
| UI bus volume | 0 – 100 | 90 |
| SFX coalesce window | 0.03 – 0.1s | 0.05s |
| Music crossfade duration | 0.1 – 1.0s | 0.3s |

## Acceptance Criteria (Future)

**AC-01** Weapon hit → ≤0.15s SFX plays.
**AC-02** Boss spawn (5:00) → music crossfades to boss track in 0.3s.
**AC-03** 8 enemies hit in 0.05s → SFX coalesces (single louder cue, not 8 stacked).
**AC-04** Low-HP (<25%) → heartbeat ambient layer activates.
**AC-05** Demon Seal completes → gold-tinted chime ≤1s.
**AC-06** Mute toggle → all 3 buses silenced; gameplay still works.

## Open Questions

- **OQ-1** (Audio asset sourcing): all original or use licensed library? Per originality policy, prefer original or public-domain Chinese-myth sourced.
- **OQ-2** (Adaptive music vs static loops): adaptive (layered intensity) is harder but more impactful.
- **OQ-3** (Voice acting / chinese sound design): TBD.

## Revision Log

| Rev | Date | Trigger | Summary |
|---|---|---|---|
| 0 | 2026-05-25 | Placeholder GDD for post-v0.5 | Documents future audio architecture. NOT IMPLEMENTED in v0.4. Defines 3-bus contract, per-weapon SFX requirements, SFX coalescing rule (per Combat GDD §Audio handoff), 6 ACs for future implementation. |
