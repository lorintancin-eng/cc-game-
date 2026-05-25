# GDScript Coding Rules (Godot 4.x)

These rules apply when editing or creating `.gd` files in this project.
Extracted from MythSurvivor's CODE_STYLE.md; CCGS-aligned.

## Language & Engine

- Gameplay and UI code uses GDScript.
- Target Godot 4.x API (project is pinned to 4.6 — see `docs/engine-reference/godot/VERSION.md`).
- Use typed GDScript wherever feasible.
- Each script should have a single, clear responsibility.

## Naming

Names should be clear, specific, readable.

```gdscript
class_name EnemyStats

@export var max_health: float = 10.0
@export var move_speed: float = 80.0

func apply_damage(amount: float) -> void:
    pass
```

### Files & Folders

- Folders: `snake_case`
- GDScript files: `snake_case.gd`
- Scene files: `snake_case.tscn`
- Resource files: `snake_case.tres` or `snake_case.res`
- Class names: `PascalCase`
- Variables and functions: `snake_case`
- Constants: `UPPER_SNAKE_CASE`
- Signals: `snake_case`, prefer past-tense for completed events

## Script Structure

Preferred order:

1. `class_name`
2. `extends`
3. signals
4. constants
5. exported variables
6. public variables
7. private variables
8. `@onready` references
9. Godot lifecycle methods
10. public methods
11. private helper methods

Example:

```gdscript
class_name ExampleActor
extends CharacterBody2D

signal defeated

const DEFAULT_SPEED: float = 100.0

@export var max_health: float = 10.0

var current_health: float

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
    current_health = max_health

func apply_damage(amount: float) -> void:
    current_health -= amount
    if current_health <= 0.0:
        _defeat()

func _defeat() -> void:
    defeated.emit()
    queue_free()
```

## Type Rules

- Functions should declare return types.
- Variables with non-obvious types should declare types.
- Use `:=` only when inference is clearly correct.
- Avoid `Variant` unless flexibility is genuinely required.
- Prefer typed arrays and dictionaries where Godot 4.x supports them.

## Node References

- Use `@onready` for required child node references.
- Use exported references or `NodePath` when scene designers need to wire dependencies.
- Avoid fragile long paths like `$"../../SomeManager/DeepChild"`.
- Avoid repeated `get_node()` calls in hot paths.

## Signals

- Use signals to decouple systems.
- Name events as things that already happened: `health_changed`, `enemy_defeated`, `level_reached`, `upgrade_selected`.
- Keep signal payloads small and typed when possible.
- Do not use signals as a substitute for clear ownership.

## Data & Balance

- Do not hardcode large content tables in scripts.
- Enemies, weapons, upgrades, waves, and loot prefer Godot `Resource` files or small structured data files.
- Do not copy commercial games' balance values.
- Briefly document non-obvious formulas or tuning assumptions.

## Comments

- Use comments sparingly.
- Comments should explain non-obvious decisions, not syntax.
- Prefer clear naming over explanatory comments.

## Error Handling

- Validate required exported references in `_ready()` if a missing reference would break the scene.
- Use `push_warning()` for recoverable configuration issues.
- Use `push_error()` for illegal state that would prevent correct behavior.
- Core gameplay systems must not fail silently.

## Performance

- Avoid unnecessary allocations in `_process()` and `_physics_process()`.
- Keep collision shapes simple during MVP.
- Avoid expensive scene-tree searches during combat.
- Add object pools only when profiling or observable stutter proves necessity.

## UI Code

- UI scripts present state and forward player choices.
- UI scripts must not own combat, spawning, or progression rules.
- HUD updates should be event-driven.

## Format

- Use indentation consistent with Godot's GDScript editor.
- Keep function length skimmable.
- Split a script when it starts taking on multiple system responsibilities.

## Engine Version Notes

- Project is pinned to Godot 4.6 (LLM cutoff is ~4.3 — always verify post-4.3 API in `docs/engine-reference/godot/VERSION.md` before using).
- Default physics: Jolt Physics (3D); 2D uses Godot Physics 2D.
- Renderer: Forward+ (D3D12 on Windows).
