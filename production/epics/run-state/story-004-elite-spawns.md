# Story 004: Elite Spawns at 3:00 + 4:00

> **Epic**: Run State | **Status**: Ready | **Layer**: Foundation | **Type**: Integration | **Estimate**: S

## Context

**GDD**: `design/gdd/run-state.md` | **Requirement**: TR-core-002
**ADR**: ADR-0001 | **Risk**: LOW

## Acceptance Criteria

- [ ] **AC-11**: At `elapsed_time = 180.0` → first Elite (Shanxiao + iron_bones affix) spawns 420 px from Player → `elite_spawned(elite, ["iron_bones"])` emit (one-shot)
- [ ] **AC-12**: At `elapsed_time = 240.0` → second Elite (Shanxiao + swift affix) spawns 420 px from Player → `elite_spawned(elite, ["swift"])` emit (one-shot)

## Implementation Notes

```gdscript
signal elite_spawned(elite, affixes: Array[String])

@export var first_elite_spawn_time: float = 180.0
@export var second_elite_spawn_time: float = 240.0
@export var elite_spawn_distance: float = 420.0

var _first_elite_spawned: bool = false
var _second_elite_spawned: bool = false

func _process(delta: float) -> void:
    # ... existing clock + demon seal checks ...
    if not _first_elite_spawned and elapsed_time >= first_elite_spawn_time:
        _spawn_first_elite()
    if not _second_elite_spawned and elapsed_time >= second_elite_spawn_time:
        _spawn_second_elite()

func _spawn_first_elite() -> void:
    _first_elite_spawned = true
    enemy_spawner.spawn_elite_at(SHANXIAO_ARCHETYPE, _random_spawn_position(), ["iron_bones"])
    elite_spawned.emit(<elite_node>, ["iron_bones"])

# Same pattern for _spawn_second_elite with "swift"
```

## QA Test Cases

**AC-11**: First elite at 3:00
- Given: StageDirector with `_first_elite_spawned = false`
- When: `elapsed_time` crosses 180.0
- Then: `spawn_elite_at(SHANXIAO, position, ["iron_bones"])` called ONCE on spawner AND `elite_spawned.emit(elite, ["iron_bones"])` ONCE

**AC-12**: Second elite at 4:00
- Given: `_second_elite_spawned = false`
- When: `elapsed_time` crosses 240.0
- Then: Same pattern with `["swift"]` affix

## Test Evidence
`tests/integration/run-state/elite_spawn_test.gd`

## Dependencies
- Depends on: Story 001
- Cross-coordinates: Enemy Spawning epic
