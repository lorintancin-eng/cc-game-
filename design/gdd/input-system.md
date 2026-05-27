# Input System

> **Status**: Designed (revision-0, awaiting independent /design-review)
> **Author**: claude (reverse-documented from `project.godot` [input] section + `scripts/player/player.gd:121` `Input.get_vector` call + ADR-0003 Active Skills planning)
> **Last Updated**: 2026-05-25
> **Implements Pillar**: Pillar 2 (自动战斗与有意义的构筑选择 — Input owns the human-driven half: "玩家主要负责移动和走位,攻击由系统自动触发")
> **TR Coverage**: TR-core-001 (manual movement via WASD / arrow keys)
> **Layer**: Foundation (no upstream dependencies)

## Overview

The Input System is the **player-to-runtime translation layer**. It exposes named "actions" (`move_up`, `move_down`, `move_left`, `move_right`) bound to multiple physical keys (WASD primary + arrow keys secondary). Other systems — primarily Player — read action states each frame via Godot's `Input` singleton; the Input System itself is engine-provided (no custom GDScript needed for MVP), but the *contract* (action names, bindings, deadzone) lives here as a tunable, ADR-amendable surface.

For v0.4 MVP the system is **movement-only**. ADR-0003 (Sun Wukong active skills) defines a future expansion: 4 active-skill keys (`active_skill_1` through `active_skill_4`) bound to number keys 1-4. These bindings are NOT yet in `project.godot` — they will be added when Active Skills GDD (FT-07) is authored and implementation begins.

Reference ADRs: ADR-0001 (Godot 4.x + GDScript) — provides the `Input` singleton; ADR-0003 (Sun Wukong active skills) — defines the future 1/2/3/4 active-skill bindings.

## Player Fantasy

Input is the **invisible substrate** of all player intention. Players don't think about input; they think about *moving*. When the input system works, the player feels:
- **No latency between key press and movement** — pressing W and seeing the character move feel like the same event
- **Equal validity of WASD and arrow keys** — left-hand and right-hand keyboard layouts both work without configuration
- **No diagonal-speed cheat** — pressing W+D doesn't make the character faster than W alone (this is Player System's Formula 1 normalizing the vector, but it depends on Input giving accurate per-axis values)

Anti-fantasy: input lag, ghost inputs after release, or "diagonal feels different than cardinal" — all symptoms of Input layer bugs that would break the *physical-grounded* feeling of the game.

For active-skill players (Sun Wukong v2, planned per ADR-0003): pressing 1/2/3/4 must feel like casting a skill, not like running a state machine. Input → skill activation must happen in the same frame as the keypress (≤16.67ms at 60 FPS).

## Detailed Rules

### Core Rules

1. **All player input flows through Godot's `Input` singleton + Input Map.** No raw keyboard polling, no custom event handling for game controls. The Input Map is the single source of truth for which key triggers which action.

2. **Input actions are the public contract; key bindings are implementation detail.** Other systems (Player, Active Skills future) refer to actions by string name (`"move_up"`), never by raw keycode. This decouples controls from input — rebinding a key changes the Input Map, not gameplay code.

3. **Actions are defined in `project.godot` `[input]` section, NOT created at runtime.** All actions are static, declared in the project config, version-controlled. Runtime action creation (`InputMap.add_action`) is reserved for future settings-menu rebinding (not v0.4).

4. **Per-frame movement query uses `Input.get_vector(neg_x, pos_x, neg_y, pos_y)`** — returns a `Vector2` already deadzone-clamped and (for gamepad) magnitude-normalized in the engine. Player System (`player.gd:121`) uses this exclusively.

5. **Movement input is polled per-frame in `_physics_process()`**; one-shot inputs (future active skills, pause toggle) use `_input(event)` callback for ≤1-frame latency. Polling `Input.is_action_just_pressed()` in `_process()` is acceptable but has up to 1 frame of latency vs `_input`.

6. **Deadzone 0.5 applies to gamepad analog sticks only** — keyboard inputs are binary (pressed/not pressed). The 0.5 deadzone is per-axis (so a stick at (0.4, 0.4) registers as zero on both axes; at (0.6, 0.4) registers as 1.0 on x, 0 on y).

7. **Input is platform-agnostic** — keyboard and gamepad both feed the same action names. Touch is NOT supported in v0.4 (per `.claude/docs/technical-preferences.md` §Input & Platform "Touch Support: None").

### Current Input Map (v0.4)

| Action | Primary Key | Secondary Key | Deadzone | Consumer |
|---|---|---|---|---|
| `move_up` | W (keycode 87) | ↑ (4194320) | 0.5 (gamepad axis Y-) | Player.gd:121 |
| `move_down` | S (83) | ↓ (4194322) | 0.5 (gamepad axis Y+) | Player.gd:121 |
| `move_left` | A (65) | ← (4194319) | 0.5 (gamepad axis X-) | Player.gd:121 |
| `move_right` | D (68) | → (4194321) | 0.5 (gamepad axis X+) | Player.gd:121 |

### Planned Input Map Additions (per ADR-0003)

| Action | Planned Key | Consumer | Status |
|---|---|---|---|
| `active_skill_1` | 1 (49) | ActiveSkillCharacter.cast_skill(1) (Sun Wukong v2: 毫毛分身 — hair clone) | Not yet in project.godot |
| `active_skill_2` | 2 (50) | ActiveSkillCharacter.cast_skill(2) (Sun Wukong v2: 筋斗云 — cloud step) | Not yet in project.godot |
| `active_skill_3` | 3 (51) | ActiveSkillCharacter.cast_skill(3) (Sun Wukong v2: 七十二变 — 72 transformations) | Not yet in project.godot |
| `active_skill_4` | 4 (52) | ActiveSkillCharacter.cast_skill(4) (Sun Wukong v2: 定身术 — immobilize) | Not yet in project.godot |
| `pause` | ESC (4194305) | Run State.toggle_pause() | Future — when pause is wired |

These will be added to `project.godot` by Active Skills GDD (FT-07) authoring + implementation. They are documented here because Input is the contract owner; the bindings should be reviewed by ux-designer / accessibility-specialist before being committed.

### Gamepad Support (Partial, per technical-preferences)

- Movement: ✅ deadzone-clamped analog stick works via `Input.get_vector` (engine handles)
- Active skills: ⏳ planned mapping is "gamepad face buttons" (A/B/X/Y or PS equivalents); precise mapping TBD with Active Skills GDD
- Pause: ⏳ planned "Start" button
- UI navigation: ⏳ planned D-pad / shoulder triggers; precise mapping TBD with Menu System GDD (FT-22)

## Formulas

### Formula 1: Action-state polling

```
input_vector: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
```

This is engine-provided. Returns a `Vector2` where each axis is in `[-1, 1]` (analog) or `{-1, 0, +1}` (digital keyboard). For analog sticks below deadzone, returns `Vector2.ZERO` on that axis.

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| `input_vector` | v | Vector2 | x ∈ [-1, 1], y ∈ [-1, 1] | Raw direction vector |
| `deadzone` | d | float | 0.0 – 1.0 (default 0.5 per `project.godot`) | Per-axis cutoff below which axis returns 0 |

**Output Range:** for keyboard, `v` is one of 9 discrete vectors (each axis ∈ {-1, 0, +1}). For gamepad, continuous in `[-1, 1]²` with deadzone applied.

**Example:** Player holds W+D on keyboard → `Input.get_vector(...)` returns `(1, -1)` (right, up). Player System Formula 1 normalizes this to `(0.707, -0.707)` before scaling by `move_speed`.

### Formula 2: One-shot input (future, for Active Skills)

```
on _input(event: InputEvent):
    if event.is_action_pressed("active_skill_1"):
        ActiveSkillCharacter.cast_skill(1)
        return
    # ... handle skills 2, 3, 4 similarly
```

`event.is_action_pressed()` returns true exactly once per press (debounced — held key does NOT re-trigger).

**Variables:**

| Variable | Type | Description |
|---|---|---|
| `event` | InputEvent | Engine-delivered event per key transition |
| `is_action_pressed` | bool | True on the frame the key transitions UP → DOWN |

**Latency target (per ADR-0003):** ≤ 1 frame (16.67ms at 60 FPS) from key press to skill activation.

## Edge Cases

- **If a player rebinds a key via OS-level key remapper (e.g. AutoHotkey)**: Godot sees the remapped keycode, not the physical key. Input layer behavior is undefined-but-safe — actions still trigger if the rebinded keycode is registered to one of them.
- **If both WASD and arrow keys are pressed simultaneously** (W and ↑): both feed `move_up`; result is the same as pressing one (action is binary). No double-speed bug.
- **If opposite keys are pressed simultaneously** (W and S): `Input.get_vector` returns Y-axis = 0 (-1 + +1 = 0). Player is stationary on that axis. This is engine-correct, not a bug.
- **If the game loses window focus during a key press**: Godot delivers an "unpressed" event for all currently-held keys. Player stops moving on focus loss. This is desired (prevents runaway character if alt-tab during play).
- **If a gamepad is connected mid-run**: Godot auto-detects via `JOYSTICK_CONNECTION_CHANGED` signal. Action mappings work immediately. No restart required.
- **If gamepad analog stick is at exactly the deadzone boundary** (magnitude == 0.5): per Godot's implementation, magnitude == deadzone is treated as zero. This is an edge precision issue; in practice, sticks rarely land exactly on 0.5.
- **If a key in the Input Map is bound to multiple actions** (e.g. W bound to both `move_up` and a future `pause`): both actions fire on the same press. This is a project config bug; the Input GDD's Acceptance Criteria includes a uniqueness check.
- **If `project.godot` is corrupted or missing the `[input]` section**: Godot launches but all actions return false; Player cannot move. This is unrecoverable in-game — re-clone project. Mitigated by version control: `project.godot` is committed and never edited by runtime.
- **If a future active-skill key (1/2/3/4) is bound but the current character is not an `ActiveSkillCharacter`**: pressing the key should be a no-op (not an error). Player.gd routes to `cast_skill()` only if `CharacterBase is ActiveSkillCharacter` (see Player GDD Dependencies).

## Dependencies

| Dependency | Type | Direction | Interface |
|---|---|---|---|
| **(none — Foundation)** | — | — | Foundation layer; depends on Godot 4.6 engine only (ADR-0001) |

**Downstream consumers (Hard — they cannot function without this contract):**

| Consumer | Status | What they consume |
|---|---|---|
| **Player** (C-01, Approved GDD) | ✅ Currently consuming | `Input.get_vector("move_left", "move_right", "move_up", "move_down")` in `_physics_process()` |
| **Active Skills** (FT-07, future GDD) | ⏳ Will consume planned 1/2/3/4 keys | `Input.is_action_pressed("active_skill_<N>")` |
| **Menu System** (FT-22, future GDD) | ⏳ Will consume pause + UI nav | `Input.is_action_pressed("pause")`, etc. |
| **Run State** (F-03, Approved GDD) | ⏳ Soft — pause toggle | `Input.is_action_pressed("pause")` (when wired) |

**Bidirectional check:**
- Player GDD lists Input as Hard dependency at "Input (F-01) | Hard | Player depends on | Reads `move_up/down/left/right` action states each `_physics_process()`" ✅
- Active Skills GDD (future) MUST list Input as Hard dependency when authored
- Menu System GDD (future) MUST list Input as Soft dependency for pause/nav

## Tuning Knobs

| Knob | Owner | Design-safe range | Default | Effect at extremes |
|---|---|---|---|---|
| `deadzone` (per-action) | `project.godot` `[input]` | 0.2 – 0.8 | 0.5 | <0.2 = stick drift may register as movement; >0.8 = analog precision lost (player must push stick nearly all the way) |
| Action name set | `project.godot` `[input]` | static (no runtime adds) | 4 movement actions | Adding more actions is a project-level change requiring ADR if it affects gameplay contract |
| Key bindings per action | `project.godot` `[input]` | designer choice | WASD + arrows | Removing one of (WASD, arrows) breaks the cross-handed accessibility convention |
| Polling cadence | Godot engine | engine-controlled | 60 Hz (matches `_physics_process`) | Cannot be tuned without engine modification |

**Interaction warnings**:
- Removing arrow-key bindings to "simplify" the Input Map breaks left-handed and small-hands accessibility — keep both WASD and arrow bindings.
- Adding a new action with the same key binding as an existing action causes both to fire simultaneously — see Edge Cases.
- For gamepad-only games, deadzone tuning matters more; for this PC-first game, the 0.5 default is safe.

## Acceptance Criteria

### AC group: Action contract

**AC-01** **GIVEN** `project.godot` `[input]` section, **WHEN** the game launches, **THEN** the following 4 actions are registered: `move_up`, `move_down`, `move_left`, `move_right` (verified via `InputMap.has_action("move_up")` etc.).

**AC-02** **GIVEN** each movement action, **WHEN** inspected, **THEN** each is bound to AT LEAST one keyboard key (WASD or arrow). No movement action may have zero bindings.

**AC-03** **GIVEN** the Input Map, **WHEN** scanned for binding conflicts, **THEN** no two actions share the same key binding (e.g. W must not be bound to both `move_up` and `pause`).

### AC group: Movement input behavior (Formula 1)

**AC-04** **GIVEN** Player at standstill, **WHEN** W key is held, **THEN** `Input.get_vector("move_left", "move_right", "move_up", "move_down")` returns `(0, -1)` (down is positive Y in Godot 2D, so up is -Y).

**AC-05** **GIVEN** Player at standstill, **WHEN** W AND D are held simultaneously, **THEN** `Input.get_vector(...)` returns `(1, -1)` (raw, NOT normalized — normalization is Player System Formula 1's responsibility).

**AC-06** **GIVEN** Player at standstill, **WHEN** W AND S are pressed simultaneously, **THEN** `Input.get_vector(...)` returns `(0, 0)` on the Y axis (opposing inputs cancel).

**AC-07** **GIVEN** a key is held, **WHEN** the game window loses focus, **THEN** the next frame `Input.is_action_pressed("move_up")` returns false (engine auto-releases on focus loss).

### AC group: Cross-binding equivalence

**AC-08** **GIVEN** WASD is the primary binding and arrow keys are the secondary binding, **WHEN** a player uses ONLY arrow keys, **THEN** all 4 movement actions function identically to WASD usage (no behavior difference).

### AC group: Gamepad (partial support)

**AC-09** **GIVEN** a gamepad is connected, **WHEN** the left analog stick is pushed past deadzone 0.5, **THEN** `Input.get_vector(...)` returns the stick's `(x, y)` clamped to the unit circle.

**AC-10** **GIVEN** the left analog stick is at magnitude exactly 0.5 (deadzone boundary), **WHEN** `Input.get_vector(...)` is queried, **THEN** the result is `Vector2.ZERO` (deadzone is exclusive lower bound per Godot engine behavior).

### AC group: Reserved placeholders (activate when Active Skills GDD lands)

**AC-11** (reserved — activates when Active Skills GDD adds 1/2/3/4 bindings) **GIVEN** an `ActiveSkillCharacter` is the current Player.character, **WHEN** key 1 is pressed, **THEN** `_input(event)` callback fires with `event.is_action_pressed("active_skill_1") == true` AND `ActiveSkillCharacter.cast_skill(1)` is invoked within the same frame.

**AC-12** (reserved) **GIVEN** the current Player.character is NOT an `ActiveSkillCharacter` (e.g. 修行者), **WHEN** key 1 is pressed, **THEN** no skill is cast AND no error fires (graceful no-op).

## Open Questions

- **OQ-1** (Settings menu rebinding): v0.4 has no rebinding UI; all bindings are hard-coded in `project.godot`. Should v1.0 include a Settings menu where players rebind keys? **Resolution candidate**: yes for accessibility (left-hand-only players, RSI mitigation), but not until Menu System GDD is authored. **Owner**: ux-designer + accessibility-specialist. **Target**: Settings GDD (post-MVP).
- **OQ-2** (Touch input): `.claude/docs/technical-preferences.md` declares "Touch Support: None" for MVP. If mobile port is ever considered, virtual joystick / tap-to-move would be added here. **Resolution candidate**: deferred unless platform target changes. **Owner**: technical-director. **Target**: only if mobile platform is approved.
- **OQ-3** (Gamepad active-skill button mapping): Currently planned as 1/2/3/4 keys; for gamepad players, the mapping is TBD (face buttons A/B/X/Y? shoulder buttons?). **Resolution candidate**: when Active Skills GDD is authored, include both keyboard and gamepad bindings in the same ADR amendment. **Owner**: ux-designer + game-designer. **Target**: Active Skills GDD (FT-07).
- **OQ-4** (Pause key conflict potential): If a future action uses ESC for something else (e.g. close menu), pause+menu-close would conflict. Current design: ESC = pause AND close-menu (context-sensitive based on Run State). Document this convention in Run State GDD when pause is wired. **Owner**: ux-designer. **Target**: when Run State pause is implemented.
- **OQ-5** (Input prediction / buffer for active skills): For Sun Wukong v2's combo potential, should active-skill keypresses buffer for ~50ms after a transition (e.g. casting 1 then immediately 2 — both fire) or strictly sequential (2nd press queues until 1st animation completes)? **Resolution candidate**: strict sequential for v0.4-v0.5 simplicity; revisit if playtest reveals input-eating frustration. **Owner**: game-designer + gameplay-programmer. **Target**: Active Skills GDD.

---

## Registry Updates Recorded

This GDD adds no new entries to `design/registry/entities.yaml` (Input is a contract / project-config GDD, not a content GDD). The action names (`move_up`, etc.) are project-level constants in `project.godot`, not registry-tracked entities.

**Cross-doc consistency**: This GDD's existence is referenced by:
- Player GDD (Approved) — Hard dependency
- Active Skills GDD (future) — will be Hard dependency when authored
- Menu System GDD (future) — will be Soft dependency
- Run State GDD (Approved) — Soft dependency (pause action, when wired)

## Revision Log

| Revision | Date | Trigger | Summary |
|---|---|---|---|
| 0 | 2026-05-25 | Initial reverse-doc by /design-system | First pass authored from `project.godot` [input] section (4 movement actions verified) + `player.gd:121` `Input.get_vector` call + ADR-0003 future 1/2/3/4 active-skill bindings. 8 required CCGS sections + Open Questions + Registry Updates. Documents current v0.4 state (movement-only) AND planned ADR-0003 additions (active skills) with clear "Not yet in project.godot" markers. Foundation-layer GDD, no Visual/Audio (no rendering), no UI Requirements (no UI surface). |
