# HUD UX Spec

> **Status**: Designed (revision-0)
> **Author**: claude (reverse-doc from `scripts/ui/hud.gd` + `scenes/ui/HUD.tscn` + dependent GDD signal contracts)
> **Last Updated**: 2026-05-25
> **Implements Pillar**: Pillar 1 (清晰的生存压力 — HUD makes pressure legible at a glance)
> **TR Coverage**: TR-ui-001 (HUD displays HP/Level/XP/Timer/Kill)
> **Layer**: Presentation (depends on Player, Experience, Run State, Stage Director, ActiveSkillCharacter)

## Overview

HUD is the **always-visible state readout** — a CanvasLayer overlay rendering 6 stats labels (HP / Level / XP / Run Timer / Kill Count / Stage Status) + an EnergyPanel (per-character energy bar) + 4 SkillPanel slots (Sun Wukong v2 cooldowns). Subscribes to Player + EnemySpawner + StageDirector + ActiveSkillCharacter signals via @onready node references and exposed paths.

Reference: Combat GDD UI Requirements, Player GDD signals, ActiveSkillCharacter signal contract, Stage Director timer signal.

## Player Fantasy

HUD is invisible until you need it. The player's eyes flick to HP when an enemy gets close, to Level when XP fills, to Timer when the boss warning chime plays. Outside those glances, HUD fades into peripheral vision.

## Detailed Rules

1. **CanvasLayer** — independent of camera transform. Renders at fixed screen positions.
2. **6 always-visible stats labels** (top-left panel): HP `current/max`, Level `境界 N`, XP `current/required`, Time `MM:SS/05:00`, Kills `镇妖数 N`, Stage Status (boss warning / clear / fail).
3. **EnergyPanel** (visible only if character has energy bar): label + ProgressBar + value label. Default hidden for 修行者.
4. **SkillPanel** (visible only for ActiveSkillCharacter — Sun Wukong v2): 4 cooldown indicators (ColorRect + Label). Updates via `skill_cooldown_changed` signal.
5. **Signal subscriptions** (one-way Player→HUD):
   - `Player.health_changed(current, max)` → HP label
   - `Player.experience_changed(current_xp, to_next, level)` → XP label
   - `Player.level_reached(level)` → Level label
   - `EnemySpawner.enemy_defeated(count)` → Kills label
   - `StageDirector.stage_time_changed(elapsed, duration)` → Time label
   - `StageDirector.boss_warning_started(lead_time)` → Stage Status: "妖王将至"
   - `StageDirector.stage_cleared/failed` → game-over flow trigger
   - `ActiveSkillCharacter.skill_cooldown_changed(slot, remaining, max_cd, unlocked)` → 4 skill icons

## Formulas

### Formula 1: HP bar color cue
```
if current_hp / max_hp < 0.25:
    apply "low-HP" visual (heartbeat / red tint — owned by Combat Feedback GDD)
```

### Formula 2: Cooldown ratio display
```
fill_ratio = (max_cd - remaining) / max_cd if max_cd > 0 else 1.0
```
0.0 = just cast (full cooldown); 1.0 = ready.

### Formula 3: Time format
```
mm = floor(elapsed / 60)
ss = floor(elapsed % 60)
display = "%02d:%02d" % [mm, ss]
```

## Edge Cases
- **Character without energy bar (修行者)**: EnergyPanel hidden.
- **Character without active skills (modern v0.4 except Sun Wukong)**: SkillPanel hidden.
- **Signal arrives during Level Up panel pause**: HUD still updates (CanvasLayer not paused).
- **Boss spawn at 5:00**: stage_status changes to indicate Boss phase.

## Dependencies
| Dep | Type | Interface |
|---|---|---|
| **Player** (C-01) | Hard | health/experience/level signals |
| **EnemySpawner** (FT-01) | Hard | enemy_defeated count |
| **Stage Director** (FT-02) | Hard | stage_time_changed + boss/cleared/failed signals |
| **ActiveSkillCharacter** (FT-06) | Soft | skill_cooldown_changed |
| **Combat Feedback** (P-03, future) | Soft | Low-HP heartbeat overlay |

## Tuning Knobs
| Knob | Range | Default | Effect |
|---|---|---|---|
| Panel layout (CanvasLayer) | scene | top-left | Visual hierarchy |
| Label font / size | theme | default | Readability |
| Low-HP threshold | hardcoded 0.25 | 0.25 | <0.25 = no warning; >0.5 = always panicked |

## Acceptance Criteria

**AC-01** Player health_changed(80, 100) → HP label shows "气血 80/100".
**AC-02** Player level_reached(5) → Level label shows "境界 5".
**AC-03** stage_time_changed(125, 300) → Time label shows "02:05 / 05:00".
**AC-04** boss_warning_started(30.0) → Stage Status displays "妖王将至".
**AC-05** ActiveSkillCharacter skill_cooldown_changed(0, 1.5, 5.0, true) → SkillSlot1 shows 30% cooldown filled.
**AC-06** 修行者 character active → EnergyPanel hidden + SkillPanel hidden.
**AC-07** 弼马温 character active → EnergyPanel hidden (Sun Wukong uses cooldowns not energy) + SkillPanel visible with 4 slots.

## Open Questions

- **OQ-1** (HUD UX design polish): current HUD is functional but text-heavy. Future visual pass for 暗黑志怪 aesthetic. Owner: ux-designer + art-director.
- **OQ-2** (Damage number floaters): per Combat GDD, optional v0.4+ feature. Not currently implemented in HUD. Owner: ux-designer.
- **OQ-3** (Color-blind palette): per Combat GDD N-2 / Player GDD OQ-N. Owner: accessibility-specialist.

## Revision Log

| Rev | Date | Trigger | Summary |
|---|---|---|---|
| 0 | 2026-05-25 | Initial reverse-doc | First pass from `hud.gd` + HUD.tscn. CanvasLayer with 6 labels + EnergyPanel (hidden default) + SkillPanel (4 slots, Sun Wukong only). 7 ACs covering signal-driven label updates + character-conditional panel visibility. |
