# Camera System

> **Status**: Designed (revision-0, awaiting independent /design-review)
> **Author**: claude (reverse-documented from `scenes/player/Player.tscn` Camera2D node + Main.tscn scene structure)
> **Last Updated**: 2026-05-25
> **Implements Pillar**: Pillar 1 (清晰的生存压力 — the camera frame is the player's window into the threat ring), Pillar 2 (positioning matters — camera must always show enough of the surrounding battlefield to make movement decisions readable)
> **TR Coverage**: (none direct — camera supports TR-core-001 movement legibility)
> **Layer**: Core (depends on Player for follow target)

## Overview

The Camera System is a single `Camera2D` node parented under Player. Godot's scene-tree transform inheritance does all the work: Player moves, Camera moves with it. No custom GDScript exists. The "system" is essentially **a node + 2 configuration values** (`enabled = true`, `zoom = Vector2(1.15, 1.15)`) — but it deserves a GDD because every framing decision (zoom, shake, look-ahead) becomes a player-feel decision, and this is the contract owner for those decisions.

For v0.4 MVP, the camera is **deliberately static** in feature scope: 1.15× zoom (slightly above 1:1 to keep player visually prominent against the暗黑志怪 background); follows Player exactly with zero lag; no shake, no zoom-out-during-Boss, no look-ahead. These features are deferred to OQ list — first ensure the core feels good before adding effects.

Reference ADRs: ADR-0001 (Godot 4.x + GDScript) — Camera2D is engine-provided.

## Player Fantasy

The camera is the player's window onto the妖物潮 — its job is to **disappear**. When the camera works invisibly, the player feels:
- **Centered grounding** — Player is always at screen center; they don't fight the camera to know where they are
- **Enough peripheral awareness** — at 1.15× zoom on a 1280×720 baseline, the visible playfield is ~1113×626 — enough to read enemy approach from 8 directions
- **Smooth motion** — no jitter, no camera lag artifacts during high-DPS combat

Anti-fantasy: camera shake on every hit at high DPS density would obliterate clarity (per Combat GDD's Accessibility note about minimum flash interval — the same principle applies to camera shake). Pixel-snapping artifacts during diagonal movement would feel "cheap."

## Detailed Rules

### Core Rules

1. **The camera is parented to Player.** Transform inheritance handles follow behavior automatically. No `_process`-driven follow code, no smoothing parameters, no offset variables in v0.4.

2. **`Camera2D.enabled = true`** is the activation flag. When Player.tscn instantiates, the camera takes over as the current viewport camera. No explicit `make_current()` call needed.

3. **`Camera2D.zoom = Vector2(1.15, 1.15)`** is the v0.4 framing default. This scales rendered content *up* by 15% — i.e., the player sees a smaller area more zoomed-in. This was tuned in v0.2 to keep Player visually prominent (not lost in a sea of small enemies).

4. **The camera does NOT compensate for window resolution changes** at runtime. Resolution is determined at game start by `project.godot` window settings; mid-run resolution changes (rare on PC) require a Run State restart to take effect cleanly.

5. **No screen shake in v0.4.** Combat Feedback GDD (P-03) is the future owner of shake events (see Combat GDD Edge Cases mention of "elite/Boss adds screen-shake"); the Camera System exposes a future API surface for that GDD to call when authored.

6. **No look-ahead, zoom-out-on-large-encounter, or boss-framing in v0.4.** Deferred to OQ list.

### v0.4 Configuration

| Property | Value | Source |
|---|---|---|
| Parent node | Player (in `scenes/player/Player.tscn`) | Scene file inspector |
| Type | `Camera2D` | Godot built-in |
| `enabled` | `true` | Player.tscn line ~30 |
| `zoom` | `Vector2(1.15, 1.15)` | Player.tscn line ~30 |
| `position_smoothing_enabled` | (Godot default — false) | implicit |
| `position_smoothing_speed` | (Godot default — 5.0) | implicit, unused |
| `limit_left/right/top/bottom` | (Godot defaults — int-min/max) | unbounded |
| `drag_*` | (Godot defaults — disabled) | unbounded |
| `rotation_smoothing_enabled` | (Godot default — false) | unused |

### Interactions with Other Systems

| System | Direction | Interface |
|---|---|---|
| **Player** (C-01, Approved) | Camera depends on Player | Camera is Player's child node; transform inheritance handles follow |
| **Main.tscn scene** | Camera takes over viewport | `enabled = true` makes it the active viewport camera at scene load |
| **Combat Feedback** (P-03, future) | Combat Feedback → Camera | Future shake API — when Combat Feedback GDD lands, it will define `Camera.shake(intensity, duration)` |
| **Boss System** (FT-09, Approved indirectly via Combat) | Boss → Camera (future) | Future zoom-out / framing-shift on Boss spawn — currently no API; deferred |
| **Run State** (F-03, Approved) | Run State → Camera | When run ends, Run State may freeze camera at last position for game-over fade |

## Formulas

### Formula 1: Visible playfield area (function of zoom)

```
visible_width  = base_resolution_width  / zoom.x
visible_height = base_resolution_height / zoom.y
```

**Variables:**

| Variable | Type | Range | Description |
|---|---|---|---|
| `base_resolution_width` | int | 1280 (project.godot default — verify in actual settings) | Window/viewport pixel width |
| `base_resolution_height` | int | 720 (project.godot default) | Window/viewport pixel height |
| `zoom.x`, `zoom.y` | float | 0.5 – 2.0 (design-safe) | Camera zoom factor (>1 = zoomed in, <1 = zoomed out) |

**Output Range:** at the v0.4 default `zoom = (1.15, 1.15)` on 1280×720 base: `visible = (1113, 626)` pixels of playable area shown.

**Example:** if a future "Boss-framing" feature drops zoom to 0.85 during Boss fights, the visible area becomes `(1506, 847)` — 35% more area, which makes the Boss readable without forcing the player to back away.

### Formula 2: Future shake displacement (placeholder for Combat Feedback GDD)

```
camera_offset = Vector2(
    rng.randf_range(-intensity, intensity),
    rng.randf_range(-intensity, intensity)
) × shake_falloff(time_since_shake_start, duration)
```

Reserved as a placeholder — Combat Feedback GDD (P-03) will own the actual formula. v0.4 has no implementation.

## Edge Cases

- **If Camera2D's `enabled` flag is false** (e.g. forgot to enable on a new character scene): the engine falls back to the previous active camera, OR a default debug camera, OR shows nothing visible (depending on context). The Player.tscn currently sets `enabled = true`; new character variants must do the same.
- **If a player resizes the game window**: Godot updates the viewport but the camera doesn't reframe — the visible area scales with window size, which on aspect-ratio change can hide or reveal more playfield. v0.4 acceptance is "supported but no explicit handling"; future may add letterboxing.
- **If the Player node is deleted mid-run** (e.g. during a transition bug): the Camera2D goes with it. The screen freezes on the last-rendered frame until a new active camera takes over. Currently no such transition exists; Run State owns the run-end fade and respects camera state.
- **If a character variant (孙悟空, future 哪吒) has a different optimal zoom** (e.g. larger character model = needs more zoom-out): CharacterBase could expose a `camera_zoom_override` field. Currently not implemented; OQ for future expansion.
- **If a future camera shake fires when the player is at the edge of the visible map**: the shake offset could reveal beyond-playfield emptiness. Should clamp shake to keep playfield in view — future Combat Feedback GDD owns this rule.
- **If `zoom.x != zoom.y`** (asymmetric zoom): produces a stretched render. v0.4 contract: `zoom.x` MUST equal `zoom.y`. If asymmetric, treat as an authoring bug.

## Dependencies

| Dependency | Type | Direction | Interface |
|---|---|---|---|
| **Player** (C-01) | Hard | Camera depends on Player | Transform inheritance — Camera2D is a child node |
| **Godot 4.6 engine** | Hard | (implicit) | Provides Camera2D node, viewport, render pipeline |

**Downstream consumers:**

| Consumer | Status | Interface |
|---|---|---|
| **Run State** (F-03, Approved) | Soft | Run State may freeze/release camera on run-end |
| **Combat Feedback** (P-03, future) | Soft | Will own future shake API |
| **Boss System** (FT-09, via Combat) | Soft | Future Boss-framing if added |
| **HUD** (P-01, future) | Independent — HUD is a separate CanvasLayer, NOT affected by Camera zoom | HUD renders at fixed screen position regardless of camera state |

**Bidirectional check:**
- Player GDD lists Camera at "Camera (C-02) | Soft | Camera depends on Player | Camera is a child node; transform inheritance only" ✅
- Player GDD OQ-4 acknowledges Camera may need a separate GDD if features grow (this GDD's existence resolves that OQ-4)

## Tuning Knobs

| Knob | Owner | Design-safe range | Default | Effect at extremes |
|---|---|---|---|---|
| `Camera2D.zoom` (per-character potentially) | Player.tscn scene | 0.7 – 1.5 | (1.15, 1.15) | <0.7 = playfield too wide, Player feels small; >1.5 = tunnel vision, can't see incoming enemies |
| `Camera2D.enabled` | Player.tscn | bool | true | false = no camera follows, debug-only |
| `position_smoothing_enabled` | Player.tscn | bool | false (Godot default) | true would lag camera behind Player — feels worse in this game's fast-pace |
| Future `shake_intensity` | Combat Feedback GDD (when written) | 0 – 12 px | n/a | not implemented in v0.4 |
| Future `boss_zoom_override` | Boss System (if added) | 0.7 – 1.0 | n/a | not implemented in v0.4 |

**Interaction warnings**:
- Don't enable `position_smoothing` without playtesting — fast-pace auto-battle reveals smoothing lag as "camera feels behind"
- Don't set asymmetric `zoom.x != zoom.y` — produces stretched render
- Don't add multiple `Camera2D` nodes in the same scene with `enabled = true` — undefined which becomes active

## Acceptance Criteria

### AC group: Camera follow

**AC-01** **GIVEN** Player is at world position (0, 0), **WHEN** Player moves to world position (200, -100), **THEN** the Camera2D is also at world position (200, -100) (verified via Player.get_node("Camera2D").global_position).

**AC-02** **GIVEN** Player is moving at 180 px/s, **WHEN** observed frame-by-frame at 60 FPS, **THEN** Camera position matches Player position every frame (zero lag — `position_smoothing_enabled = false`).

### AC group: Zoom configuration

**AC-03** **GIVEN** Player.tscn instantiation, **WHEN** the camera is queried, **THEN** `Camera2D.zoom == Vector2(1.15, 1.15)` (v0.4 default).

**AC-04** **GIVEN** the default zoom and 1280×720 viewport, **WHEN** visible area is computed via Formula 1, **THEN** visible playfield is approximately (1113, 626) px (within ±1 px tolerance for integer math).

### AC group: Activation

**AC-05** **GIVEN** Main.tscn loads with Player as a child, **WHEN** the scene tree is ready, **THEN** `Camera2D.enabled == true` AND the Godot viewport reports Camera2D as the current camera.

**AC-06** **GIVEN** there is only one `Camera2D` node in the active scene tree, **WHEN** the scene loads, **THEN** no warning fires about multiple active cameras (engine guard).

### AC group: Window resize behavior (informational)

**AC-07** **GIVEN** the player resizes the game window from 1280×720 to 1920×1080, **WHEN** the resize completes, **THEN** Camera continues to follow Player AND the visible playfield area scales accordingly (Formula 1 with new resolution). No crash, no camera reset.

### AC group: Reserved placeholders

**AC-08** (reserved — activates when Combat Feedback GDD adds shake): **GIVEN** Combat Feedback calls `Camera.shake(intensity, duration)`, **WHEN** the function fires, **THEN** Camera position oscillates around Player position for `duration` seconds with `intensity`-amplitude offsets, then returns exactly to Player.global_position.

## Open Questions

- **OQ-1** (Future: per-character zoom): Should each CharacterBase expose a `camera_zoom_override` field so 孙悟空 (smaller sprite) feels different from 盘古 (larger sprite, hypothetical)? **Resolution candidate**: yes, add as `CharacterBase.camera_zoom: float = 1.15` (default = current value) when Character System GDD (FT-06) is written. **Owner**: ux-designer + game-designer. **Target**: Character System GDD.
- **OQ-2** (Boss-framing zoom-out): Should the camera zoom out by ~15-20% when Boss spawns to reveal Boss arena? Per Combat GDD Pressure Curve, Boss fight is the most-readable moment of the run — zoom-out would help. **Resolution candidate**: yes, but only after Combat Feedback GDD owns shake first (don't pile camera features simultaneously). **Owner**: ux-designer. **Target**: post-Combat Feedback.
- **OQ-3** (Screen shake intensity cap to prevent strobe at high DPS): Per Combat GDD Accessibility note (0.05s min flash interval), shake should also have a minimum interval between consecutive shakes on the same Camera. If 8 weapons fire simultaneously, do they all shake (chaotic) or only the highest-intensity one wins (clean)? **Resolution candidate**: highest-intensity-wins with rate-limit; defined in Combat Feedback GDD. **Owner**: ux-designer + accessibility-specialist. **Target**: Combat Feedback GDD authoring.
- **OQ-4** (Letterboxing for ultra-wide monitors): if a player plays on 3440×1440, the visible playfield becomes much wider than designed. Should the engine letterbox at 16:9 aspect to preserve design intent? **Resolution candidate**: yes — `project.godot` `display/window/stretch/aspect = "keep"` setting. Verify in v1.0 polish. **Owner**: technical-director. **Target**: pre-release polish.

---

## Registry Updates Recorded

This GDD adds no new entries to `design/registry/entities.yaml` (Camera is a Player child, not a separate content entity). Camera `zoom` is documented here as the canonical owner — if it's ever referenced from another GDD, register it as a constant in `entities.yaml`.

**Cross-doc consistency**: This GDD's existence resolves Player GDD OQ-4 (Camera coupling). It is referenced by:
- Player GDD (Approved) — Camera as Soft dependency
- Future Combat Feedback GDD — shake API definition target
- Future Boss System GDD — possible Boss-framing zoom

## Revision Log

| Revision | Date | Trigger | Summary |
|---|---|---|---|
| 0 | 2026-05-25 | Initial reverse-doc by /design-system | First pass authored from Player.tscn Camera2D node (enabled=true, zoom=(1.15,1.15)) + Main.tscn scene tree structure. 8 required CCGS sections (Visual/Audio + UI not applicable for Camera — no rendering surface beyond viewport, no UI). v0.4 contract is minimal — no code, just node configuration. Future features (shake, boss-framing, per-character zoom, letterbox) all in OQ list, each pointing to the owning future GDD. Resolves Player GDD OQ-4. |
