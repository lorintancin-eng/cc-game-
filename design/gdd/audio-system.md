# Audio System (Future Full Vision)

> **Status**: Approved (revision-1 — addresses 7 RECOMMENDED + 6 NICE-TO-HAVE from /design-review revision-0 CONCERNS)
> **Author**: claude (placeholder; not yet implemented)
> **Last Updated**: 2026-05-27
> **Implements Pillar**: Pillar 3 (`原创神话气质` — Originality) — sound is a major originality vector via Chinese-myth-sourced cues. Audio also contributes heavily to 暗黑志怪压迫感 (atmospheric pressure) as a supporting layer.
> **TR Coverage**: TR-AUDIO-* domain (reserved)
> **Layer**: Polish/Full Vision (NOT IMPLEMENTED IN v0.4)

## Overview

The Audio System will own all game audio: music, SFX, UI cues, ambient. v0.4 ships **without audio implementation** (per Resource Data Framework GDD audit). Future scope:

- 3 audio buses: SFX / Music / UI (all children of `Master`; set in `project.godot` Audio Bus Layout). Master is the mute-everything bus.
- Per-weapon hit SFX (≤0.15s each, distinct per weapon)
- Boss music swap at 5:00
- Demon Seal completion chime
- Level Up panel "悟道" cue
- Player low-HP heartbeat — **trigger owned by Combat Feedback GDD** (subscribes to `health_changed`, evaluates `current_hp/max_hp < 0.25`, emits a `low_hp_state_changed(below_threshold: bool)` signal); **HUD owns the visual heartbeat overlay**; **Audio owns the audio heartbeat layer** (subscribes to the same Combat Feedback signal).
- Worst-case event rate: 160 events/sec (8 active targets × 20 shots/sec — per Combat GDD §Audio handoff)

Reference: Combat GDD §Audio handoff to Audio GDD (rate limits + coalescing requirements).

## Player Fantasy

> "The opening minute is quiet — just my footsteps and the soft chime of XP orbs. By minute 3 the score swells, layered drums under the action. At 4:30 the boss warning crashes in — a deep horn over silence. The 5:00 boss music is pure tension, drums + ghost-voice samples until I land the killing blow and silence falls."

Anti-fantasy: audio that pops, ducks irregularly, or fails to coalesce at high DPS.

## Detailed Rules (Future)

1. **3-bus architecture** (SFX / Music / UI as Master children) — independent volume sliders per bus
2. **Per-weapon SFX** ≤0.15s; played on Combat GDD's `damage_dealt` signal
3. **Music swap on Stage Director phase transitions**: subscribes to `boss_warning_started(lead_time)` → boss-warning crash; `boss_spawned(boss)` → boss-music swap; `stage_cleared(elapsed)` → silence/win cue (signal names per `stage-director.md:97-101`).
4. **Demon Seal completion chime** (gold-tinted, ≤1s) on `seal_completed(seal)` signal from Demon Seal GDD
5. **Level Up "悟道" cue** ≤0.8s on `upgrade_applied(upgrade_id)` from Level Up GDD
6. **SFX coalescing**: when N hit events fire within `sfx_coalesce_window` (default **0.05s = 50ms**, range 0.03–0.1s — see Tuning Knobs), play 1 SFX with louder mix (not N stacked SFX). 50ms tolerates 3 frames of clustering before a new SFX fires.
7. **Ducking**: when Boss music plays, SFX bus ducks -3dB (implementation: bus-level `AudioEffectCompressor` with sidechain on the Music bus, OR scripted `set_bus_volume_db` on phase transition — implementer choice).
8. **Per-bus mute toggle**: each of SFX/Music/UI buses can be individually muted via Settings panel. Master mute (M key, TBD UX) silences all 3 buses. Mute state persists across runs via `user://settings.cfg`.
9. **Audio asset sourcing policy** (per game-concept.md originality rule): all audio assets must be either (a) original works commissioned for this project, or (b) public-domain Chinese-mythology-themed sourced material. Licensed sample libraries permitted only for percussion/instrument-layer use, **not** for distinctive cues (boss music, Demon Seal chime, weapon SFX).

## Formulas

### Formula 1: SFX coalescing
```
const LOUDEN_STEP_DB: float = 1.5  # each coalesced event boosts previous SFX by 1.5 dB

on damage_dealt(source, target, amount, damage_type, source_kind):
    var damage_intensity: float = clampf(amount / 30.0, 0.2, 1.0)  # map Combat amount → 0.2..1.0 volume scalar
    if time_since_last_hit_sfx < sfx_coalesce_window:
        # Coalesce: louden previous SFX player, don't play new
        previous_sfx_player.volume_db = minf(previous_sfx_player.volume_db + LOUDEN_STEP_DB, MAX_COALESCED_DB)
        return
    var player = play_sfx(hit_sfx, volume=damage_intensity)
    previous_sfx_player = player
    time_since_last_hit_sfx = now
```
**`damage_intensity` source**: mapped from Combat GDD's `damage_dealt` payload `amount` field (linear normalization with floor 0.2 / cap 1.0). **`sfx_coalesce_window`** reads the tuning knob (not a magic number).

## Edge Cases
- **Mute toggle**: respects per-bus mute (per Rule 8)
- **Music swap during ambient**: 0.3s crossfade
- **Boss music + Demon Seal pressure overlap**: pressure cue ducks under boss intro (occurs only if player skipped the 2:00 Demon Seal and seal is still active at 5:00 Boss spawn — uncommon but possible)
- **>160 events/sec**: SFX coalescing absorbs

## Dependencies (Future)
| Dep | Type | Interface |
|---|---|---|
| **Combat** (C-03) | Hard | `damage_dealt(source, target, amount, damage_type, source_kind)` → per-weapon hit SFX (Formula 1) |
| **Stage Director** (FT-02) | Hard | `boss_warning_started(lead_time)` → boss-warning crash; `boss_spawned(boss)` → boss-music swap; `stage_cleared(elapsed)` → win cue |
| **Level Up** (FT-05) | Hard | `upgrade_applied(upgrade_id)` for "悟道" cue |
| **Demon Seal** (FT-08) | Hard | `seal_completed(seal)` for chime |
| **Combat Feedback** (P-03) | Hard | `low_hp_state_changed(below_threshold)` → Audio heartbeat layer activates (trigger owned by Combat Feedback, NOT HUD) |

## Tuning Knobs (Future)
| Knob | Range | Default |
|---|---|---|
| SFX bus volume | 0 – 100 | 80 (SFX prominence > music to support combat clarity) |
| Music bus volume | 0 – 100 | 60 |
| UI bus volume | 0 – 100 | 90 (UI loudest — losing UI feedback is worse than losing music) |
| SFX coalesce window (`sfx_coalesce_window`) | 0.03 – 0.1s | 0.05s (50ms = 3 frames @ 60FPS) |
| Music crossfade duration | 0.1 – 1.0s | 0.3s |
| Ducking attenuation (Boss music active) | -6 – 0 dB | -3 dB |
| LOUDEN_STEP_DB (per-coalesce boost) | 0.5 – 3.0 dB | 1.5 dB |
| MAX_COALESCED_DB (boost ceiling) | 0 – 6 dB | 3 dB |

## Acceptance Criteria (Future)

**AC-01** **GIVEN** weapon hit fires, **WHEN** `Combat.damage_dealt` emits, **THEN** SFX `play` call is invoked within 1 frame AND SFX clip `length` property ≤0.15s.
**AC-02** **GIVEN** `StageDirector.boss_spawned(boss)` fires at 5:00, **WHEN** music subsystem subscribes, **THEN** music crossfades to boss track over 0.3s ± 1 frame.
**AC-03** **GIVEN** 8 enemies hit in 0.05s window, **WHEN** Formula 1 evaluates, **THEN** exactly 1 SFX plays AND its volume_db has been boosted by 7 × LOUDEN_STEP_DB (clamped to MAX_COALESCED_DB) — single louder cue, not 8 stacked SFX.
**AC-04** **GIVEN** Player HP/max ratio drops below 0.25, **WHEN** Combat Feedback emits `low_hp_state_changed(true)`, **THEN** Audio heartbeat ambient layer activates within 1 frame.
**AC-05** **GIVEN** `DemonSeal.seal_completed(seal)` fires, **WHEN** Audio subscriber runs, **THEN** gold-tinted chime SFX plays with clip length ≤1s.
**AC-06** **GIVEN** mute toggle activated (Master mute), **WHEN** any audio event fires, **THEN** all 3 buses (SFX/Music/UI) output 0 dB AND gameplay logic continues unaffected.
**AC-07** **GIVEN** Boss music playing AND ducking active, **WHEN** ducking applied, **THEN** SFX bus volume = base_volume − 3 dB AND restores within 0.3s of music transition off.
**AC-08** **GIVEN** any audio asset in `assets/audio/`, **WHEN** /asset-audit runs (or manual review), **THEN** distinctive cues (boss music, Demon Seal chime, all weapon SFX) trace to original commission OR public-domain Chinese-myth sourced material per Rule 9 originality policy.

## Open Questions

- **OQ-1** (Audio asset commissioning workflow): the policy is locked in Rule 9 (original commission OR public-domain Chinese-myth sourced; licensed allowed only for percussion/instrument-layer non-distinctive use). The commissioning workflow + budget + per-cue prioritization remains TBD. **Owner**: producer + audio-director. **Target**: pre-v0.5 (audio implementation kickoff).
- **OQ-2** (Adaptive music vs static loops): adaptive (layered intensity) is harder but more impactful.
- **OQ-3** (Voice acting / chinese sound design): TBD.

## Revision Log

| Rev | Date | Trigger | Summary |
|---|---|---|---|
| 0 | 2026-05-25 | Placeholder GDD for post-v0.5 | Documents future audio architecture. NOT IMPLEMENTED in v0.4. Defines 3-bus contract, per-weapon SFX requirements, SFX coalescing rule (per Combat GDD §Audio handoff), 6 ACs for future implementation. |
| 1 | 2026-05-27 | /design-review revision-0 CONCERNS (0 BLOCKERS + 7 RECOMMENDED + 6 NICE-TO-HAVE) | **R-1 closed**: Rule 6 / Formula 1 / AC-03 internal contradiction resolved — coalesce window unified to 0.05s (50ms = 3 frames). **R-2 closed**: Formula 1 pseudocode completed — `damage_intensity` defined as `clampf(amount/30.0, 0.2, 1.0)`; loudening logic explicit (`LOUDEN_STEP_DB = 1.5`, capped at `MAX_COALESCED_DB = 3`); `sfx_coalesce_window` reads tuning knob. **R-3 closed**: low-HP heartbeat owner-mismatch resolved — Combat Feedback owns the trigger (subscribes to `health_changed`, emits `low_hp_state_changed`); Audio subscribes to Combat Feedback (not HUD). Dependencies table updated. **R-4 closed**: mute-toggle contract added as Rule 8 (per-bus + Master, persist via `user://settings.cfg`). **R-5 closed**: originality policy promoted from OQ-1 to Rule 9 (Detailed Rules); OQ-1 narrowed to commissioning workflow. **R-6 closed**: Stage Director signal names enumerated explicitly (boss_warning_started / boss_spawned / stage_cleared). **R-7**: requires systems-index.md:55 dependency list update (Combat, Stage Director, Level Up, Demon Seal, Combat Feedback — drops "Experience" which is not a dep) — tracked as cross-doc fix. **N-1 closed**: volume defaults justified (SFX > Music for combat clarity; UI loudest for input gating). **N-2 closed**: AC-07 added for ducking rule. **N-3 closed**: Master bus parent clarified. **N-4 closed**: Pillar 3 citation references game-concept's actual pillar text `原创神话气质`. **N-5 closed**: Edge case "Boss + Demon Seal overlap" given trigger condition. |
