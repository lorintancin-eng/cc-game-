# Menu System UX Spec

> **Status**: Approved (revision-1 — addresses 3 BLOCKERS + 4 RECOMMENDED + 5 NICE-TO-HAVE from /design-review revision-0 CONCERNS)
> **Author**: claude (reverse-doc from existing menu scenes: CharacterSelectPanel, LevelUpPanel, GameOverPanel, plus code-truth audit of scripts/ui/*.gd)
> **Last Updated**: 2026-05-27
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

1. **CharacterSelectPanel**: full-screen CanvasLayer, 2 character buttons (修行者 / 弼马温). On selection, **instantiates the chosen character scene as Main's child with `name = "Player"`** (the panel does NOT set a `Player.character_base` field — the character node IS the Player after this point); rebinds HUD's and StageDirector's `_player` references; reconnects `died` signal; then `queue_free`'s itself (per `character_select_panel.gd:25-55`).
2. **LevelUpPanel** (per Level Up GDD): 3-button choice. **Pause is owned by Player** (per Level Up GDD Core Rule 1, `level_up_pool.md:38`) — Player sets `get_tree().paused = true` when panel opens and restores on selection.
3. **GameOverPanel**: **passive view**. Trigger and pause ownership belong to **HUD** (`scripts/ui/hud.gd:220-260`). HUD subscribes to `StageDirector.stage_cleared` AND `StageDirector.stage_failed` (per `run-state.md:248` contract); HUD calls `game_over_panel.show_summary(...)` or `show_stage_clear(...)` AND sets `get_tree().paused = true`. The GameOverPanel itself only renders the final stats + "再入劫境" restart button + grabs initial focus.
4. **All panels are CanvasLayer** (independent of camera transform) and run with `process_mode = WHEN_PAUSED` (per `level_up_panel.gd:5` and `game_over_panel.gd:5`).
5. **Pause is a shared concept** but owned by **whichever system triggered the panel** (Player owns LevelUp pause; HUD owns GameOver pause; Main scene-load implicitly pauses at startup before CharacterSelect). Run State does NOT arbitrate panel-stacking in v0.4 — see Edge Cases.

### Menu Navigation Input Contract

| Panel | Open input | Close input | Initial focus | Back-out allowed? |
|---|---|---|---|---|
| CharacterSelectPanel | (auto at Main scene load) | (auto on character pick) | first character button | ❌ no — commit-only |
| LevelUpPanel | (auto on `Player.level_reached`) | (auto on option pick) | first option button (`level_up_panel.gd:43` `_option_buttons[0].grab_focus()`) | ❌ no — must pick 1 of 3 |
| GameOverPanel | (auto on `stage_cleared` / `stage_failed` via HUD) | (auto on restart) | "再入劫境" restart button (`game_over_panel.gd:34` `_restart_button.grab_focus()`) | ❌ no — Restart only |
| Pause Menu (future) | `pause` action (TBD wiring — OQ-2) | `ui_cancel` OR Continue button | Continue button | ✅ yes (Continue closes) |

**ESC-handling policy (v0.4)**: ESC is **unbound** in `project.godot` `[input]` (verified — no `pause` / `ui_cancel` action defined yet). All 3 implemented panels are **commit-only** — no back-out without selection. When Pause Menu is wired (OQ-2), ESC will be bound to a `pause` action consumed globally by Run State; per-panel ESC override is not planned.

**Gamepad coverage status**: Implemented panels use Godot's default `ui_*` navigation actions (Up/Down/Enter/Space) which auto-route gamepad d-pad + A button. Full gamepad mapping is `⏳ planned` per Input GDD line 73-75.

**Localization hooks**: All hardcoded Chinese strings ("再入劫境", "修行者", "弼马温", LevelUp option labels) flow through Godot's `tr()` translation table when localization is added post-MVP. v0.4 ships with literal strings. Per OQ-4 below.

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

### Formula 1: Pause-during-panel pattern (ASPIRATIONAL — for future Pause Menu / Settlement)
```
on panel.show():
    _was_paused = get_tree().paused
    get_tree().paused = true

on panel.close():
    get_tree().paused = _was_paused
```

**Note**: NO currently-implemented panel uses this formula literally:
- **LevelUpPanel** pause is owned by Player (per Level Up GDD CR-1).
- **CharacterSelectPanel** pause is owned by Main scene-load (game tree starts paused before scene runs first frame; CharacterSelect appears in paused state).
- **GameOverPanel** pause is owned by HUD (`hud.gd:260`: `get_tree().paused = true`).

The formula is the planned shared contract for Pause Menu + future Settlement panels.

## Edge Cases
- **Multiple panels visible** (e.g. Pause overlapping LevelUp): currently impossible because Pause Menu and Settlement are unimplemented. Run State does NOT define panel-stacking arbitration in v0.4. When Pause Menu is authored (OQ-2), panel-stacking ownership must be resolved — owner: ux-designer + game-designer.
- **Player dies during Level Up panel**: `Player._is_dead = true`; HUD's `_on_player_died` (via `stage_failed` route) calls `game_over_panel.show_summary()`; LevelUpPanel is destroyed with scene reload on restart.
- **Character switch mid-run** (impossible v0.4): would orphan run state. CharacterSelect is commit-only per Input Contract.
- **ESC pressed in v0.4**: no-op (action unbound in `project.godot`). Per Input Contract.
- **Restart with Pause Menu unimplemented**: `reload_current_scene()` returns to a freshly-loaded `Main.tscn` (CharacterSelect visible). When Main Menu is added (OQ-1), the restart-target decision needs revisiting — currently `reload_current_scene` would skip a future Main Menu. See OQ-5.

## Dependencies
| Dep | Type | Interface |
|---|---|---|
| **Player** (C-01) | Hard | `died` / `level_reached` signals (consumed by HUD which dispatches to panels) |
| **Run State** (F-03) | Hard | `get_tree().paused` shared resource (no panel-stacking arbitration in v0.4) |
| **Stage Director** (FT-02) | Hard | `stage_cleared(elapsed) / stage_failed` → HUD trigger for GameOverPanel |
| **Level Up & Upgrade Pool** (FT-05) | Hard | LevelUpPanel owned there; pause owned by Player CR-1 |
| **Input** (F-01) | Hard | `ui_accept / ui_cancel / ui_up / ui_down` default actions; future `pause` action |
| **Character System** (FT-06) | Hard | CharacterSelectPanel instantiates character scene as Main's child |
| **HUD** (P-01) | Hard | HUD dispatches `stage_cleared/failed` → GameOverPanel.show_*; HUD owns GameOver pause |

## Tuning Knobs
| Knob | Range | Default | Effect |
|---|---|---|---|
| Panel z-index | scene | varies | Layering order |
| Button text font / size | theme | default | Readability |
| LevelUp option focus delay | 0 – 0.5s | 0s | Prevents accidental restart-on-button-mash |
| GameOver restart focus delay | 0 – 0.5s | 0s | Same |
| Panel fade-in duration | 0 – 0.5s | 0s (instant) | Future polish |
| `font_scale` accessibility hook | 0.8 – 1.5 | 1.0 | Text scaling (reserved — OQ-4) |

## Acceptance Criteria

**AC-01** **GIVEN** Main.tscn loads at app start, **WHEN** scene root `_ready` runs, **THEN** CharacterSelectPanel is visible AND `get_tree().paused == true` (paused state established by Main scene initialization).

**AC-02** **GIVEN** CharacterSelectPanel visible, **WHEN** Player clicks 修行者 button, **THEN** (a) the 修行者 character scene is instantiated as Main's child with `name = "Player"`; (b) HUD's `_player` reference is rebound; (c) StageDirector's `_player` reference is rebound; (d) the chosen character's `died` signal is reconnected to `StageDirector._on_player_died`; (e) CharacterSelectPanel `queue_free`'s itself. **(Note: the panel does NOT itself unpause the tree — `get_tree().paused` is managed externally by Run State / Stage Director when the run actually begins.)**

**AC-03** **GIVEN** Player is alive in a run, **WHEN** `StageDirector.stage_failed` emits (or `stage_cleared`), **THEN** HUD's `_on_player_died` / `_on_stage_cleared` handler (a) calls `game_over_panel.show_summary(...)` or `show_stage_clear(...)`; (b) sets `get_tree().paused = true`; (c) the "再入劫境" restart button grabs focus.

**AC-04** **GIVEN** GameOverPanel visible, **WHEN** Restart button pressed, **THEN** `get_tree().reload_current_scene()` is invoked AND `get_tree().paused` is set to `false` AND the reloaded scene starts in the same initial state as a fresh app launch (CharacterSelectPanel visible AND tree paused per AC-01). **(Note: when Main Menu is added per OQ-1, the restart-target decision needs revisiting — currently `reload_current_scene` would skip a future Main Menu. Tracked in OQ-5.)**

**AC-05** **GIVEN** LevelUpPanel show_choices is called, **WHEN** the panel is added to the scene tree, **THEN** the first option button has keyboard focus (per `level_up_panel.gd:43` `_option_buttons[0].grab_focus()`) AND Up/Down navigate between the 3 options AND Enter/Space activates.

**AC-06** **GIVEN** GameOverPanel `show_summary` is called, **WHEN** the panel is shown, **THEN** the "再入劫境" restart button has keyboard focus (per `game_over_panel.gd:34` `_restart_button.grab_focus()`).

**AC-07** **GIVEN** v0.4 with no `pause` action bound in `project.godot`, **WHEN** ESC key is pressed, **THEN** no panel opens, no action fires, no error logged (verified silent no-op).

## Open Questions

- **OQ-1** (Main Menu): app starts directly into CharacterSelect. Should there be a main menu first (Start / Continue / Options / Quit)? **Resolution**: defer; tracker for post-MVP.
- **OQ-2** (Pause Menu): ESC key currently no-ops. Pause menu needs: Continue / Restart / Quit-to-menu. **Resolution**: wire when Pause feature added.
- **OQ-3** (Settlement screen separate from GameOver): victory and defeat currently share GameOverPanel. Should be separate panels for proper celebration. **Resolution**: post-MVP polish.

- **OQ-4** (Localization / i18n): all UI strings (button labels, panel titles, restart button "再入劫境", character names "修行者" / "弼马温", LevelUp option labels) are hardcoded literals in v0.4 scenes/scripts. When localization is added (post-MVP), strings must flow through Godot's `tr()` translation table; this implies a per-string ID convention and a `translations/*.po` directory. **Owner**: ux-designer + producer. **Target**: when /localization-design runs.

- **OQ-5** (Restart-target with Main Menu unimplemented): `get_tree().reload_current_scene()` from GameOverPanel reloads Main.tscn (which instances CharacterSelect first). When Main Menu (OQ-1) is added, restart should target Main Menu, not Main.tscn directly. **Resolution**: when OQ-1 lands, refactor restart to a named target rather than `reload_current_scene`.

## Revision Log

| Rev | Date | Trigger | Summary |
|---|---|---|---|
| 0 | 2026-05-25 | Initial reverse-doc | First pass; 3 of 6 panels implemented (CharacterSelect / LevelUp / GameOver). Main Menu / Pause / Settlement deferred. 4 ACs cover implemented panels. 3 OQs for future panels. |
| 1 | 2026-05-27 | /design-review revision-0 CONCERNS (3 BLOCKERS + 4 RECOMMENDED + 5 NICE-TO-HAVE) | **B-1 closed**: rewrote Detailed Rule 3 / Panel Roster row / AC-03 to honor code-truth — HUD owns GameOverPanel trigger + pause (not GameOverPanel listening to `Player.died` directly). **B-2 closed**: added "Menu Navigation Input Contract" subsection with per-panel input/focus/back-out matrix + ESC policy + gamepad status + localization hooks. **B-3 closed**: AC-04 rewritten in GIVEN/WHEN/THEN with code-accurate `reload_current_scene()` mechanism + OQ-5 for Main Menu future. **R-1 closed**: Formula 1 marked ASPIRATIONAL with explicit note that no implemented panel uses it literally. **R-2 closed**: Edge Case "Multiple panels" updated — Run State does NOT arbitrate panel-stacking in v0.4. **R-3 closed**: AC-02 split into 5 atomic sub-assertions matching `character_select_panel.gd:25-55` code path. **R-4 closed**: OQ-4 added for localization. **N-3 closed**: AC-05/AC-06 added for focus-grab on panel appear. **N-4 closed**: back-path policy added to Input Contract (commit-only for v0.4). |
