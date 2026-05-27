# HUD UX Spec

> **Status**: Approved (revision-1 — addresses 5 BLOCKERS + 5 RECOMMENDED + 5 NICE-TO-HAVE from /design-review revision-0 MAJOR REVISION)
> **Author**: claude (reverse-doc from `scripts/ui/hud.gd` + `scenes/ui/HUD.tscn` + dependent GDD signal contracts)
> **Last Updated**: 2026-05-27
> **Implements Pillar**: Pillar 1 (清晰的生存压力 — HUD makes pressure legible at a glance)
> **TR Coverage**: TR-ui-001 (HUD displays HP/Level/XP/Timer/Kill)
> **Layer**: Presentation (depends on Player, Experience, Run State, Stage Director, ActiveSkillCharacter)

## Overview

HUD is the **always-visible state readout** — a CanvasLayer overlay rendering 6 stats labels (HP / Level / XP / Run Timer / Kill Count / Stage Status) + an EnergyPanel (per-character energy bar) + 4 SkillPanel slots (Sun Wukong v2 cooldowns). Subscribes to Player + EnemySpawner + StageDirector + ActiveSkillCharacter signals via @onready node references and exposed paths.

Reference: Combat GDD UI Requirements, Player GDD signals, ActiveSkillCharacter signal contract, Stage Director timer signal.

## Player Fantasy

HUD is **always-visible, low-clutter, glance-readable**. The player's eyes flick to HP when an enemy gets close, to Level when XP fills, to Timer when the boss warning chime plays. Outside those glances, HUD stays in peripheral vision via low-contrast text + restrained palette. Threshold-event cues (boss warning, low-HP heartbeat, upgrade acknowledgment toast) animate briefly to draw the eye when state changes; otherwise the HUD does not animate. Pillar 1 target: HP must be readable at ≤50ms eye-flick.

## Detailed Rules

1. **CanvasLayer** — independent of camera transform. Renders at fixed screen positions.
2. **6 always-visible stats labels** (top-left panel): HP `current/max`, Level `境界 N`, XP `current/required`, Time `MM:SS/05:00`, Kills `镇妖数 N`, Stage Status (boss warning / clear / fail).
3. **EnergyPanel** (visible only if character has energy bar): label + ProgressBar + value label. Default hidden for 修行者.
4. **SkillPanel** (visible only for ActiveSkillCharacter — Sun Wukong v2): 4 cooldown indicators (ColorRect + Label). Updates via `skill_cooldown_changed` signal.
5. **Signal subscriptions** (one-way upstream → HUD):
   - `Player.health_changed(current, max)` → HP label
   - `Player.experience_changed(current_xp, to_next, level)` → XP label
   - `Player.level_reached(level)` → Level label
   - `Player.upgrade_applied(upgrade_id)` → brief 1.5s upgrade-chosen acknowledgment toast (per Player GDD line 98)
   - `EnemySpawner.enemy_defeated(count)` → Kills label
   - `StageDirector.stage_time_changed(elapsed, duration)` → Time label
   - `StageDirector.boss_warning_started(lead_time)` → Stage Status: "妖王将至"
   - `StageDirector.boss_spawned(boss)` → instantiate Boss HP bar at top-screen AND wire it to `boss.damage_taken` for HP tracking (per run-state.md line 324, Combat AC-22 contract)
   - `StageDirector.demon_seal_progress_changed(progress, required, is_sealing)` → Demon Seal progress bar (per stage-director.md line 93, run-state.md line 325)
   - `StageDirector.stage_cleared(elapsed) / stage_failed` → HUD pauses tree + dispatches to GameOverPanel.show_*() (HUD is the dispatcher per Menu System GDD revision-1)
   - `ActiveSkillCharacter.skill_cooldown_changed(slot, remaining, max_cd, unlocked)` → 4 skill icons
   - `CombatFeedback.low_hp_state_changed(below_threshold)` → activate/deactivate red-tint heartbeat overlay (HUD owns the VISUAL; Combat Feedback owns the TRIGGER per Combat Feedback GDD Rule 6)

### Information Architecture

| Zone | Element | Priority | Glanceability target |
|---|---|---|---|
| Top-left | HP + Level + XP (vertical stack) | **highest** | HP at ≤50ms eye-flick |
| Top-center | Time + Boss Warning Status | high | "妖王将至" must read in ≤200ms when triggered |
| Top-right | Kills (镇妖数) | medium | informational |
| Bottom-right | SkillPanel (4 slots, Sun Wukong only) | medium | cooldown ready-state must read in ≤100ms |
| Bottom-left | EnergyPanel (character-conditional) | medium | per-character readability |
| Top-center overlay (z+1) | Boss HP bar (when boss spawned) | high | full-bar at glance |
| World-space at seal | Demon Seal progress bar (or HUD top-center overlay) | high | "is sealing" state legible |
| Full-screen overlay (z+2) | Low-HP red tint + heartbeat pulse | highest | always-on signal when <25% HP |
| Center-screen toast (z+3, 1.5s) | Upgrade acknowledgment | low | brief positive confirmation |

### Accessibility Hooks (reserved — values TBD; hooks declared so values can be wired without GDD revision)

| Hook | Purpose | Default | Future spec owner |
|---|---|---|---|
| `font_scale` | text scaling | 1.0 (range 0.8 – 1.5) | accessibility-specialist |
| `colorblind_palette` enum | non-color visual differentiation on HP low-HP cue, boss warning, cooldown indicators | `STANDARD` (alt: `COLORBLIND_SAFE` uses shape modifiers per VFX GDD revision-1 — "!" prefix + diagonal-stripe overlay) | accessibility-specialist |
| `localization_strings` ResourcePath | i18n indirection for 4 Chinese labels ("气血", "境界", "镇妖数", "妖王将至") + Sun Wukong skill names | Chinese-only (hardcoded literals in v0.4) | localization-lead |
| `reduced_motion` toggle | gates heartbeat animation, boss warning flash, cooldown-ready pulse | false | accessibility-specialist |
| `tts_screen_reader` toggle | future TTS hooks for HP / level / boss warning announcements | false (no TTS in v0.4) | accessibility-specialist |

## Formulas

### Formula 1: HP bar color cue (HUD-owned VISUAL; Combat Feedback owns TRIGGER)
```
# Combat Feedback subscribes to Player.health_changed, evaluates threshold,
# emits CombatFeedback.low_hp_state_changed(below_threshold). HUD reacts.

on CombatFeedback.low_hp_state_changed(below_threshold: bool):
    if below_threshold:
        _start_heartbeat_overlay()    # red tint + heartbeat pulse
    else:
        _stop_heartbeat_overlay()
```
**Ownership note** (resolved from revision-0 contradiction with Combat Feedback GDD line 33):
- **Combat Feedback** owns the trigger condition + signal emission
- **HUD** owns the red-tint overlay + heartbeat visual rendering
- **Audio** (future) owns the heartbeat ambient sound layer

### Formula 2: Cooldown ratio display
```
if max_cd <= 0.0:
    fill_ratio = 1.0       # treat zero / negative max_cd as "ready" (defensive)
else:
    fill_ratio = clampf((max_cd - remaining) / max_cd, 0.0, 1.0)
```
0.0 = just cast (full cooldown filled); 1.0 = ready. Negative `max_cd` should never occur (push_error if seen) but defaults to ready.

### Formula 3: Time format
```
mm = floor(elapsed / 60)
ss = floor(elapsed % 60)
display = "%02d:%02d" % [mm, ss]
```

## Edge Cases
- **Character without energy bar (修行者)**: EnergyPanel hidden.
- **Character without active skills (modern v0.4 except Sun Wukong)**: SkillPanel hidden.
- **Signal arrives during Level Up panel pause**: HUD still updates (CanvasLayer not paused; subscribers fire normally).
- **Boss spawn at 5:00**: stage_status changes to indicate Boss phase; Boss HP bar instantiates at top-center overlay.
- **Boss HP bar lifecycle**: persists from `boss_spawned` until `stage_cleared` (boss died) OR `stage_failed` (player died). Auto-freed on either.
- **Low-HP heartbeat re-entry**: if HP recovers above 25% then drops again, Combat Feedback re-emits `low_hp_state_changed(true)` and HUD re-activates the overlay.
- **Upgrade toast during boss warning**: both can be visible simultaneously; toast renders at z+3 (above boss warning text).

## Dependencies
| Dep | Type | Interface |
|---|---|---|
| **Player** (C-01) | Hard | `health_changed / experience_changed / level_reached / upgrade_applied` |
| **EnemySpawner** (FT-01) | Hard | `enemy_defeated(count)` |
| **Stage Director** (FT-02) | Hard | `stage_time_changed / boss_warning_started / boss_spawned / demon_seal_progress_changed / stage_cleared / stage_failed` |
| **ActiveSkillCharacter** (FT-06) | Soft | `skill_cooldown_changed` |
| **Demon Seal** (FT-08) | Soft (indirect) | Subscribes to Stage Director's RELAYED `demon_seal_progress_changed` (NOT seal's own signal — seal is dynamically spawned) |
| **Combat Feedback** (P-03) | Hard | `low_hp_state_changed(below_threshold)` → HUD activates red-tint heartbeat overlay |
| **Menu System** (P-02) | Hard | HUD dispatches `stage_cleared / stage_failed` → GameOverPanel.show_*() |

## Tuning Knobs
| Knob | Range | Default | Effect |
|---|---|---|---|
| Panel layout (CanvasLayer) | scene | top-left | Visual hierarchy |
| Label font / size | theme | default | Readability |
| Low-HP threshold | hardcoded 0.25 | 0.25 | <0.25 = no warning; >0.5 = always panicked |

## Acceptance Criteria

**AC-01** **GIVEN** Player active, **WHEN** `health_changed(80, 100)` emits, **THEN** HP label shows `"气血 80/100"` (Chinese prefix "气血 " is from localization table lookup, hardcoded literal in v0.4).
**AC-02** **GIVEN** Player active, **WHEN** `level_reached(5)` emits, **THEN** Level label shows `"境界 5"`.
**AC-03** **GIVEN** stage in progress, **WHEN** `stage_time_changed(125, 300)` emits, **THEN** Time label shows `"02:05 / 05:00"`.
**AC-04** **GIVEN** boss warning phase, **WHEN** `boss_warning_started(30.0)` emits, **THEN** Stage Status displays `"妖王将至"` AND the text briefly animates to draw the eye.
**AC-05** **GIVEN** Sun Wukong is active, **WHEN** `skill_cooldown_changed(0, 1.5, 5.0, true)` emits, **THEN** SkillSlot1 shows `fill_ratio = (5.0 − 1.5) / 5.0 = 0.7` (70% cooled — 30% remaining is darkened/blocked overlay).
**AC-06** **GIVEN** 修行者 character active, **WHEN** scene loads, **THEN** EnergyPanel is hidden AND SkillPanel is hidden.
**AC-07** **GIVEN** 弼马温 character active, **WHEN** scene loads, **THEN** EnergyPanel hidden (Sun Wukong uses cooldowns not energy) AND SkillPanel visible with 4 slots.
**AC-08** **GIVEN** stage in progress, **WHEN** `demon_seal_progress_changed(4.0, 8.0, true)` emits via Stage Director's relayed signal, **THEN** HUD's Demon Seal progress bar shows 50% fill.
**AC-09** **GIVEN** stage in progress, **WHEN** `boss_spawned(boss)` emits, **THEN** Boss HP bar instantiates at top-center overlay AND subscribes to `boss.damage_taken` for HP tracking.
**AC-10** **GIVEN** Player at HP=20/100 (below 25% threshold), **WHEN** Combat Feedback emits `low_hp_state_changed(true)`, **THEN** HUD activates red-tint heartbeat overlay within 1 frame.
**AC-11** **GIVEN** Player applies an upgrade, **WHEN** `upgrade_applied("UPGRADE_TALISMAN_DAMAGE")` emits, **THEN** HUD shows a 1.5s acknowledgment toast at center-screen overlay (z+3).
**AC-12** **GIVEN** stage in progress AND Level Up panel is open (`get_tree().paused == true`), **WHEN** `health_changed(60, 100)` emits, **THEN** HP label updates to `"气血 60/100"` without delay (CanvasLayer ignores pause; subscribers fire normally).
**AC-13** **GIVEN** stage in progress, **WHEN** `stage_cleared(elapsed)` emits, **THEN** HUD transitions to victory dispatch within 0.5s (HUD pauses tree, calls `GameOverPanel.show_stage_clear()`). Same flow on `stage_failed`.

## Open Questions

- **OQ-1** (HUD UX design polish): current HUD is functional but text-heavy. Future visual pass for 暗黑志怪 aesthetic. Owner: ux-designer + art-director.
- **OQ-2** (Damage number floaters): per Combat GDD, optional v0.4+ feature. Not currently implemented in HUD. Owner: ux-designer.
- **OQ-3** (Color-blind palette): per Combat GDD N-2 / Player GDD OQ-N. Owner: accessibility-specialist.

## Revision Log

| Rev | Date | Trigger | Summary |
|---|---|---|---|
| 0 | 2026-05-25 | Initial reverse-doc | First pass from `hud.gd` + HUD.tscn. CanvasLayer with 6 labels + EnergyPanel (hidden default) + SkillPanel (4 slots, Sun Wukong only). 7 ACs covering signal-driven label updates + character-conditional panel visibility. |
| 1 | 2026-05-27 | /design-review revision-0 MAJOR REVISION (5 BLOCKERS + 5 RECOMMENDED + 5 NICE-TO-HAVE) | **B-1 closed**: added `demon_seal_progress_changed` subscription + AC-08 (subscribes to Stage Director's RELAYED signal, not the seal's own). **B-2 closed**: added `boss_spawned` subscription + Boss HP bar + AC-09. **B-3 closed**: added `upgrade_applied` subscription + 1.5s toast + AC-11. **B-4 closed**: heartbeat ownership contradiction with Combat Feedback resolved via 3-way split — Combat Feedback owns trigger (`low_hp_state_changed` signal), HUD owns visual overlay rendering, Audio owns sound layer. AC-10 added. **B-5 closed**: Accessibility Hooks subsection added with 5 reserved hooks (font_scale, colorblind_palette, localization_strings, reduced_motion, tts_screen_reader). **R-1 closed**: Formula 2 max_cd ≤ 0 guard added with defensive 1.0 default + push_error. **R-2 closed**: Player Fantasy reconciled — "always-visible, low-clutter, glance-readable" with threshold animation rule. **R-3 closed**: AC-13 added for stage_cleared/failed → GameOverPanel dispatch. **R-4 closed**: AC-12 added for HUD-during-pause behavior. **R-5 closed**: Information Architecture subsection added (zone × priority × glanceability targets). **N-4 closed**: AC-05 fill_ratio worked out explicitly (0.7 = 70% cooled). |
