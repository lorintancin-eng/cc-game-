# Menu System UX Spec

> **Status**: Designed (revision-0)
> **Author**: claude (reverse-doc from existing menu scenes: CharacterSelectPanel, LevelUpPanel, GameOverPanel)
> **Last Updated**: 2026-05-25
> **Implements Pillar**: Pillar 1 (clear state transitions), Pillar 5 (MVP — bounded menu set)
> **TR Coverage**: TR-ui-002 (Menu system: main/pause/select/levelup/gameover/settle)
> **Layer**: Presentation (depends on Run State, Player, Stage Director)

## Overview

Menu System is the **state-transition UI layer** — the screens / panels that interrupt or wrap gameplay. v0.4 implements 3 of the 6 planned panels:
- ✅ `CharacterSelectPanel` (run start)
- ✅ `LevelUpPanel` (level-up — owned by Level Up GDD)
- ✅ `GameOverPanel` (player death — death / restart flow)
- 📋 Main Menu (not yet implemented — game starts directly into CharacterSelect)
- 📋 Pause Menu (not yet implemented — ESC has no handler in v0.4)
- 📋 Settlement Screen (post-Boss victory — currently merged into GameOver)

Per Combat GDD UX Flag + Player GDD UI Requirements.

## Player Fantasy

Menus are **the breath between moments of play**. They tell the player where they are in the lifecycle, give clear next-action affordance ("Restart" / "Continue"), and stay out of the way otherwise.

## Detailed Rules

1. **CharacterSelectPanel**: full-screen CanvasLayer, 2 character buttons (修行者 / 弼马温). On selection, configures Player + closes panel.
2. **LevelUpPanel** (per Level Up GDD): 3-button choice, pauses game tree.
3. **GameOverPanel**: on `Player.died`, displays final stats + "再入劫境" restart button.
4. **All panels are CanvasLayer** (independent of camera transform).
5. **Pause is shared concept** owned by Run State (`get_tree().paused`).

### Panel Roster

| Panel | Status | Trigger | Owner |
|---|---|---|---|
| CharacterSelectPanel | ✅ Implemented | Game start | Self |
| LevelUpPanel | ✅ Implemented | `Player.level_reached` | Level Up GDD (FT-05) |
| GameOverPanel | ✅ Implemented | `Player.died` / `stage_failed` | Self |
| Main Menu | 📋 Future | App start (pre-CharacterSelect) | TBD |
| Pause Menu | 📋 Future | ESC keypress | Run State |
| Settlement / Victory | 📋 Future | `stage_cleared` (Boss death) | Self |

## Formulas

### Formula 1: Pause-during-panel pattern
```
on panel.show():
    _was_paused = get_tree().paused
    get_tree().paused = true

on panel.close():
    get_tree().paused = _was_paused
```

Per Level Up GDD Core Rule 1. Shared by Pause Menu, LevelUp, Settlement when authored.

## Edge Cases
- **Multiple panels visible** (e.g. Pause overlapping LevelUp): not currently possible — Run State prevents concurrent pauses.
- **Player dies during Level Up panel**: `Player._is_dead = true`; GameOverPanel takes over (LevelUpPanel destroyed with scene).
- **Character switch mid-run** (impossible v0.4): would orphan run state.

## Dependencies
| Dep | Type | Interface |
|---|---|---|
| **Player** (C-01) | Hard | `died` / `level_reached` |
| **Run State** (F-03) | Hard | Pause coordination |
| **Stage Director** (FT-02) | Hard | `stage_cleared` / `stage_failed` |
| **Level Up & Upgrade Pool** (FT-05) | Hard | LevelUpPanel owned there |

## Tuning Knobs
| Knob | Range | Default | Effect |
|---|---|---|---|
| Panel z-index | scene | varies | Layering order |
| Button text font / size | theme | default | Readability |

## Acceptance Criteria

**AC-01** Game start → CharacterSelectPanel visible AND game tree paused.
**AC-02** Player selects 修行者 → CharacterSelectPanel hides AND game tree unpauses AND Player.character_base set.
**AC-03** Player dies → GameOverPanel appears AND game tree paused AND "Restart" button focused.
**AC-04** Restart button pressed → scene reloads to CharacterSelectPanel.

## Open Questions

- **OQ-1** (Main Menu): app starts directly into CharacterSelect. Should there be a main menu first (Start / Continue / Options / Quit)? **Resolution**: defer; tracker for post-MVP.
- **OQ-2** (Pause Menu): ESC key currently no-ops. Pause menu needs: Continue / Restart / Quit-to-menu. **Resolution**: wire when Pause feature added.
- **OQ-3** (Settlement screen separate from GameOver): victory and defeat currently share GameOverPanel. Should be separate panels for proper celebration. **Resolution**: post-MVP polish.

## Revision Log

| Rev | Date | Trigger | Summary |
|---|---|---|---|
| 0 | 2026-05-25 | Initial reverse-doc | First pass; 3 of 6 panels implemented (CharacterSelect / LevelUp / GameOver). Main Menu / Pause / Settlement deferred. 4 ACs cover implemented panels. 3 OQs for future panels. |
