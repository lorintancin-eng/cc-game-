# Combat Feedback System

> **Status**: Approved (revision-1 — addresses 2 BLOCKERS + 5 RECOMMENDED + 4 NICE-TO-HAVE from /design-review revision-0 MAJOR REVISION)
> **Author**: claude (reverse-doc from Enemy.gd flash + Combat GDD Visual/Audio §)
> **Last Updated**: 2026-05-27
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
2. **Minimum flash interval** (per Combat GDD Visual/Audio): 0.05s between consecutive flashes **on same target** (prevents strobe at high DPS, accessibility consideration). **Per-target state required** — see Formula 1.
3. **Death VFX** (per Combat GDD AC-22): dissolve animation ≤0.5s before queue_free. VFX GDD owns the timing.
4. **Screen shake** (future): triggered on Boss/elite hits or explosions. Combat GDD reserves API; Camera GDD will own the shake math.
5. **Damage number floaters** (optional v0.4+): rise + fade ~0.5s; off-white text with red glow on crits (Combat GDD §Visual/Audio). **Coalescing**: when >1 floater would spawn within 0.05s on the same target, sum the damage and spawn a single floater showing the total (mirror Audio GDD's coalescing pattern for the visual layer).
6. **Low-HP heartbeat trigger** (Combat Feedback owns the TRIGGER, HUD owns the VISUAL, Audio owns the SOUND LAYER): Combat Feedback subscribes to `health_changed`, evaluates `current_hp/max_hp < 0.25`, and emits `low_hp_state_changed(below_threshold: bool)` signal. HUD subscribes to this signal to render the red-tint heartbeat overlay; Audio subscribes to it to fade in the heartbeat ambient layer. **Ownership resolution** (per cross-doc fix vs HUD revision-0 line 41 and Audio revision-0 line 19 contradiction).
7. **Hit-stop / time freeze on heavy hits**: explicitly NOT in v0.4 scope. Not currently a planned future feature — would require Combat System core changes (time-scale on hit-frame). Out of scope unless added as Open Question post-playtest.
8. **Photosensitivity reduce-effects toggle** (reserved, future): a player setting `feedback_intensity ∈ {DEFAULT, REDUCED, OFF}` will (when Accessibility GDD lands) gate flash intensity, floater spawn, and shake. Combat Feedback reserves the toggle field; Accessibility GDD will define the per-level effects.

## Formulas

### Formula 1: Flash interval throttle (PER-TARGET)
```
# State stored per-target (e.g. as an Enemy field `last_flash_time`)
on damage_taken(target, amount):
    if amount <= 0.0: return                       # mirrors Combat AC-19 (zero-damage suppression)
    if time_now - target.last_flash_time < 0.05:   # PER-TARGET, NOT global
        return
    target.flash(0.1)
    target.last_flash_time = time_now
```
**CRITICAL**: `last_flash_time` MUST be keyed on `target` (stored as an Enemy field or dict-keyed by `target.get_instance_id()`), NOT a single global. A global would suppress ~80% of legitimate cross-target flashes at 4-8 enemy density. The per-target rule is the contract Combat GDD §Visual/Audio established.

### Formula 2: Screen shake (future API placeholder)
```
on Combat.shake_event(intensity, duration):
    Camera.shake(intensity, duration)   # Camera GDD owns the math
```

## Edge Cases
- **Multiple weapons hit same enemy same frame**: per-target flash interval throttle prevents strobe; cross-target flashes are NOT throttled (independent throttles per target)
- **Boss death**: special VFX (larger dissolve, possibly camera pulse) — VFX GDD owns the boss-specific dissolve variant
- **Player low-HP visual**: **trigger is Combat Feedback's** (emits `low_hp_state_changed`); HUD owns the red-tint visual rendering; Audio owns the heartbeat sound layer. Three-system split.
- **Saturation case** (160 events/sec per Combat GDD line 474): flash throttle handles per-target; floater coalescing (Rule 5) handles per-target spawn rate; shake is rate-limited per Camera GDD's future API.
- **VFX during pause**: flash timer freezes with `get_tree().paused == true` (Tween/Timer pause). Damage number floaters freeze. Screen shake (future) freezes.
- **Hit on already-DYING enemy**: per Combat Core Rule 6 silent-drop, the `damage_taken` signal does NOT fire, so no flash plays. Defensive: even if signal fires, Combat Feedback ignores `target.is_dying`.

## Dependencies
| Dep | Type | Interface |
|---|---|---|
| **Combat** (C-03) | Hard | Subscribes to `damage_taken / died / health_changed` signals (health_changed needed for low-HP trigger Rule 6) |
| **Enemy** (C-04) | Soft | Per-enemy flash implementation + per-target `last_flash_time` field |
| **Camera** (C-02) | Soft | Future shake API |
| **HUD** (P-01) | Hard | Combat Feedback emits `low_hp_state_changed(below_threshold)` → HUD renders red-tint heartbeat overlay |
| **Audio** (PL-01, future) | Hard | Audio subscribes to `low_hp_state_changed` → activates heartbeat ambient sound layer; also subscribes to `damage_dealt` for hit SFX |
| **VFX** (PL-02, future) | Soft | Death animations (VFX owns `queue_free` per AC-22) |

## Tuning Knobs
| Knob | Range | Default |
|---|---|---|
| Hit flash duration | 0.05 – 0.2s | 0.1s |
| Min interval between flashes | 0.03 – 0.1s | 0.05s |
| Visual-death dissolve duration | 0.2 – 1.0s | ≤0.5s |
| Future screen shake intensity | 0 – 12 px | TBD |
| Future damage number lifetime | 0.3 – 1.0s | 0.5s |

## Acceptance Criteria

**AC-01** **GIVEN** Enemy at full HP, **WHEN** `damage_taken(target, amount > 0)` fires, **THEN** sprite tints white for 0.1s.
**AC-02** **GIVEN** Enemy A at full HP, **WHEN** Enemy A receives 2 hits within 0.03s, **THEN** only 1 flash plays on Enemy A (per-target minimum interval throttle).
**AC-03** **GIVEN** Enemy A receives damage at t=0.00 AND Enemy B receives damage at t=0.02, **WHEN** flash subscribers run, **THEN** BOTH enemies flash (cross-target throttles are independent — proves Formula 1's per-target keying).
**AC-04** **GIVEN** Enemy dies, **WHEN** `died` fires, **THEN** dissolve VFX plays for ≤0.5s before VFX calls `queue_free()` on the enemy (per Combat GDD AC-22; VFX-owned per VFX GDD revision-1).
**AC-05** **GIVEN** Boss hits player, **WHEN** `damage_dealt(source=boss, ...)` fires, **THEN** (future) `Camera.shake(intensity, duration)` is invoked via Combat Feedback's shake-trigger pipeline.
**AC-06** **GIVEN** Player HP/max ratio drops below 0.25, **WHEN** Combat Feedback observes `health_changed`, **THEN** `low_hp_state_changed(true)` emits AND HUD activates red-tint heartbeat overlay AND Audio activates heartbeat ambient layer (within 1 frame).
**AC-07** **GIVEN** Enemy at current_hp = 24, **WHEN** a `damage_amount = 0` event fires (status-only probe path), **THEN** no `damage_taken` emits per Combat AC-19 AND no flash plays AND `target.last_flash_time` is unchanged.
**AC-08** **GIVEN** 4 damage events fire on Enemy A within 0.05s, **WHEN** Rule 5 coalescing applies, **THEN** exactly 1 damage number floater spawns showing summed damage (not 4 stacked floaters).

## Open Questions

- **OQ-1** (Centralize Combat Feedback service): currently scattered inline (Enemy.gd flash, no shake yet, no floaters). Future service: `combat_feedback.gd` AutoLoad subscribes to Combat signals → routes to per-effect implementations.
- **OQ-2** (Damage number floater priority): v0.4+ optional. Visual style: 暗黑志怪 palette (off-white with red glow). Need ux-designer + technical-artist input.
- **OQ-3** (Screen shake interaction with accessibility): per Combat GDD §photosensitivity advisory — shake at high DPS density could be a strobe risk. Combat Feedback service must rate-limit shake too. Owner: accessibility-specialist.

## Revision Log

| Rev | Date | Trigger | Summary |
|---|---|---|---|
| 0 | 2026-05-25 | Initial reverse-doc | First pass; only hit flash is implemented today. Screen shake + damage floaters + heartbeat all reserved future. 5 ACs (2 implemented, 3 future). 3 OQs: centralize service, damage floater spec, accessibility for shake. |
| 1 | 2026-05-27 | /design-review revision-0 MAJOR REVISION (2 BLOCKERS + 5 RECOMMENDED + 4 NICE-TO-HAVE) | **B-1 closed**: Formula 1 per-target throttle bug fixed — `last_flash_time` now keyed on `target` (per-Enemy field), not a global; AC-03 added to defend cross-target independence. **B-2 closed**: heartbeat ownership contradiction with HUD GDD resolved via 3-way split — Combat Feedback owns TRIGGER (emits `low_hp_state_changed`), HUD owns VISUAL (red-tint overlay), Audio owns SOUND (heartbeat layer). Cross-doc fix to hud.md + audio-system.md propagated. **R-1 closed**: floater coalescing rule added (Rule 5); AC-08 added. **R-2 closed**: `health_changed` subscription added to Combat dependency Interface column. **R-3 closed**: Rule 7 added — hit-stop explicitly NOT in v0.4 scope. **R-4 closed**: AC-07 added defending Combat AC-19 zero-damage suppression. **R-5 closed**: Rule 8 reserves `feedback_intensity` toggle for future Accessibility GDD. **N-2 closed**: Edge Cases expanded — pause behavior, saturation case, dying enemy. |
