# Demon Seal System

> **Status**: Designed (revision-0, awaiting independent /design-review)
> **Author**: claude (reverse-doc from `scripts/system/demon_seal.gd` + Stage Director GDD demon_seal_* hooks + 06_LEVEL_DESIGN.md §4)
> **Last Updated**: 2026-05-25
> **Implements Pillar**: Pillar 1 (Risk/reward beat at 2:00 — survival pressure intensified by player choice)
> **TR Coverage**: TR-core-006 (Demon Seal contract)
> **Layer**: Feature/Vertical Slice (depends on Stage Director, Player)

## Overview

Demon Seal is the **2:00 risk/reward beat** — at 2 minutes into the run, Stage Director spawns a DemonSeal `Area2D` at random position 200-280 px from Player. When Player enters the seal's collision shape, an 8-second sealing timer counts up. Sealing while inside the area triggers Stage Director's "pressure mode" (interval ×0.65, max +6 enemies). On completion: 8 ExperienceOrbs spawn in a 54-px ring at the seal's position (per Stage Director Formula 4).

Reference: Stage Director GDD (owns spawn timing + reward), 06_LEVEL_DESIGN.md §4 (designer flavor).

## Player Fantasy

> "A glowing stone appears 250 px from me. I could ignore it and just survive the wave. But the run is going well — I'm at full HP. I sprint to the seal. The world gets MORE dangerous — spawns ramp up. 5 seconds in, three Fox Spirits cut off my retreat path. I tank one hit, take another, watching the progress ring fill... 8 seconds, complete! 8 XP orbs burst out around me. I scoop them up, level up twice. Run is now ahead of schedule."

Anti-fantasy: seals that are trivially safe (no risk), or always-lethal (no reward). The 0.65× spawn pressure must produce a meaningful but survivable challenge.

## Detailed Rules

1. **DemonSeal extends Area2D** with collision shape (radius implicit in scene, ~44 px). Single instance per run, spawned at 2:00 by Stage Director.
2. **Sealing requires Player inside Area2D**: `body_entered` increments `_players_in_range`; `body_exited` decrements (with floor 0). `is_sealing()` returns true when `_players_in_range > 0` AND not completed.
3. **Progress accumulates only while sealing** (Formula 1): `progress_seconds += delta` if `is_sealing()`. If Player exits, progress is NOT reset — sealing pauses until re-entry.
4. **Required time = 8.0s** (clamped MIN 0.1). Configurable via Stage Director GDD tuning (`demon_seal_required_seconds`).
5. **Completion is one-shot**: `_is_completed = true` after `progress_seconds >= required_seconds`. Subsequent `_process` returns early.
6. **Two signals**: `seal_progress_changed(progress, required, is_sealing)` per frame while sealing OR on entry/exit; `seal_completed(seal)` once on completion.
7. **Visual progress ring** (Line2D): radius 44 px, 48 points at full progress, arc-fills clockwise from top.

### Interactions

| System | Interface |
|---|---|
| **Stage Director** (FT-02, Approved) | Spawns DemonSeal at 2:00; subscribes to both signals; pressure-mode reconfig + reward orb spawn |
| **Player** (C-01, Approved) | Player's collision triggers `body_entered`/`body_exited` |
| **Experience & Progression** (FT-04, Approved) | Stage Director's reward orbs (not Demon Seal itself) |
| **HUD** (P-01, future) | Subscribes to `seal_progress_changed` for progress UI |

## Formulas

### Formula 1: Progress accumulation
```
on _process(delta):
    if _is_completed or _players_in_range <= 0: return
    progress_seconds = min(progress_seconds + delta, required_seconds)
    seal_progress_changed.emit(progress_seconds, required_seconds, true)
    if progress_seconds >= required_seconds: _complete_seal()
```

### Formula 2: Visual progress ring
```
ratio = clamp(progress_seconds / required_seconds, 0, 1)
point_count = max(2, int(48 * ratio))
ring points: arc from top (-π/2) sweeping clockwise by TAU * ratio
radius = 44 px
```

## Edge Cases
- **Player exits mid-seal**: progress paused; `is_sealing()` returns false; emits with `is_sealing=false`. On re-entry, resumes from saved progress.
- **Two Players in range** (impossible in v0.4 single-player): both contribute to `_players_in_range`; sealing still 1× rate. Edge case for future coop.
- **`required_seconds < 0.1`**: clamped MIN. Defensive.
- **DemonSeal exists when Player dies**: Stage Director sets `_set_demon_seal_pressure_active(false)` on `stage_failed`; seal stays in scene but progress stops.
- **DemonSeal exists when Boss spawns** (Stage Director OQ-3): edge case — seal would overlap with Boss pressure clamp. Tracked in Stage Director GDD.

## Dependencies
| Dep | Type | Interface |
|---|---|---|
| **Stage Director** (FT-02) | Hard Bidirectional | Owns spawn + subscribes to signals |
| **Player** (C-01) | Hard | `body_entered`/`body_exited` |
| **Godot Area2D** | Hard (engine) | Collision detection |

## Tuning Knobs
| Knob | Range | Default | Effect |
|---|---|---|---|
| `required_seconds` | 4 – 16 | 8.0 | <4 = trivial; >16 = punishing |
| `MIN_REQUIRED_SECONDS` | locked | 0.1 | engine floor |
| Visual progress ring radius | scene-embedded | 44 px | matches Area2D collision |

## Acceptance Criteria

**AC-01** **GIVEN** DemonSeal at world (200, 0) AND Player walks into Area2D, **WHEN** `body_entered` fires, **THEN** `_players_in_range = 1` AND `seal_progress_changed(0.0, 8.0, true)` emits.

**AC-02** **GIVEN** Player in DemonSeal range continuously for 8 seconds, **WHEN** 8 seconds elapse, **THEN** `progress_seconds = 8.0` AND `_is_completed = true` AND `seal_completed(self)` emits.

**AC-03** **GIVEN** Player at progress 4.0s exits the seal area, **WHEN** `body_exited` fires, **THEN** `_players_in_range = 0` AND `seal_progress_changed(4.0, 8.0, false)` emits AND `_process` early-returns on next tick (progress doesn't accumulate).

**AC-04** **GIVEN** Player re-enters the seal at progress 4.0s, **WHEN** `body_entered` fires, **THEN** sealing resumes from 4.0s (NOT reset to 0).

**AC-05** **GIVEN** DemonSeal `_is_completed = true`, **WHEN** Player re-enters area, **THEN** `_players_in_range` does NOT increment (early return guards) AND no progress accumulation.

**AC-06** **GIVEN** non-Player Node2D in Area2D, **WHEN** `body_entered` fires, **THEN** `_players_in_range` does NOT increment (per `is_in_group("player")` guard).

**AC-07** **GIVEN** `required_seconds = 0.05` (below MIN), **WHEN** `_ready()` runs, **THEN** clamped to 0.1.

**AC-08** **GIVEN** progress at 50% (4.0/8.0), **WHEN** `_update_progress_ring()` runs, **THEN** ring has 24 points (48 × 0.5) forming a half-arc from top (-π/2) sweeping to π/2.

## Open Questions

- **OQ-1** (Multi-seal support): v0.4 spawns 1 seal per run. Future could spawn 2+ at different times. **Resolution**: defer; current design.
- **OQ-2** (Cancel UX): if Player commits to sealing then realizes risk too high, they can just walk out. No additional cancel UX needed.
- **OQ-3** (Visual telegraph radius): the spawn ring (200-280 px from Player) doesn't visually announce to Player. Should there be a beacon-effect on spawn? **Resolution**: ux-designer to decide; HUD/VFX GDD scope.

## Registry Updates

- `demon_seal_required_seconds = 8` (already registered in entities.yaml — Stage Director GDD)
- `demon_seal_spawn_time = 120` (already registered)

## Revision Log

| Rev | Date | Trigger | Summary |
|---|---|---|---|
| 0 | 2026-05-25 | Initial reverse-doc | First pass from `demon_seal.gd` (88 lines) + Stage Director hooks. 8 sections + 8 ACs. Stage Director owns spawn + reward; Demon Seal owns sealing state machine + progress ring visual. |
