# Story 001: EnemyArchetype Resource Loading

> **Epic**: Enemy System | **Status**: Ready | **Layer**: Core | **Type**: Logic | **Estimate**: S
> **Manifest Version**: 2026-05-25.1 | **Last Updated**: 2026-05-27

## Context

**GDD**: `design/gdd/enemy-system.md` (r1) | **Requirement**: TR-enemy-001
**ADR**: ADR-0001 | **Risk**: LOW

**Control Manifest (Core Layer)**:
- Required: `.tres` Resource subclasses for every content type (Enemy, Weapon, etc.)
- Required: Enemy archetype: base `Enemy` class + per-enemy `.tres` (TR-ENEMY-001)
- Forbidden: Mutating shared `Resource` instances at runtime (use `.duplicate(true)`)

## Acceptance Criteria

- [ ] **AC-01**: Enemy spawned without `archetype` → uses defaults (move_speed=90, max_hp=24, damage=8, damage_interval=0.8, xp_drop_value=5.0)
- [ ] **AC-02**: Enemy with `paper_doll.tres` attached → max_hp=14, damage=5, move_speed=86, body_scale=0.82, xp_drop_value=3.5 (matches entities.yaml)
- [ ] **AC-03**: All 7 archetype `.tres` files load without parse errors AND each declares all 19 fields per EnemyArchetype schema
- [ ] **AC-04**: Archetype values stored at spawn → cannot be mutated at runtime via shared reference (each Enemy instance copies values on `_ready()`)

## Implementation Notes

```gdscript
class_name Enemy extends CharacterBody2D

@export var archetype: EnemyArchetype = null

# Defaults — used only if archetype is null (dev/debug)
var max_hp: float = 24.0
var current_hp: float
var damage: float = 8.0
var move_speed: float = 90.0
var damage_interval: float = 0.8
var xp_drop_value: float = 5.0

func _ready() -> void:
    if archetype != null:
        max_hp = archetype.max_hp
        damage = archetype.damage
        move_speed = archetype.move_speed
        damage_interval = archetype.damage_interval
        xp_drop_value = archetype.xp_drop_value
        # ... rest of 19 fields
    current_hp = max_hp
```

## QA Test Cases

**AC-01**: Defaults applied without archetype
- Given: Enemy.tscn instance with `archetype = null`
- When: `_ready()` runs
- Then: `max_hp == 24.0` AND `current_hp == 24.0` AND `damage == 8.0` AND `move_speed == 90.0`

**AC-02**: Paper Doll archetype override
- Given: Enemy.tscn with `archetype = preload("res://resources/enemies/paper_doll.tres")`
- When: `_ready()` runs
- Then: max_hp=14, damage=5, move_speed=86, body_scale=0.82, xp_drop_value=3.5 (matches `entities.yaml:102-126`)

**AC-03**: All 7 archetypes load
- Given: ResourceLoader.load for each of 7 .tres files in `resources/enemies/`
- When: Loaded
- Then: All loads succeed (no parse errors) AND each Resource has all 19 EnemyArchetype fields populated

**AC-04**: No shared-reference mutation
- Given: Two Paper Doll Enemy instances sharing same archetype Resource
- When: Instance A's `max_hp` is mutated to 50
- Then: Instance B's `max_hp` remains 14 (each copied on spawn — no shared reference)

## Test Evidence
`tests/unit/enemy/archetype_loading_test.gd` — must pass.

## Dependencies
- Depends on: Resource Data Framework epic (defines `.tres` pattern)
- Unlocks: All other Enemy stories
