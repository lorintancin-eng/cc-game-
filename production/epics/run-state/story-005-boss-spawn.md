# Story 005: Boss Spawn at 5:00 + Boss-Phase Spawner Clamp

> **Epic**: Run State | **Status**: Ready | **Layer**: Foundation | **Type**: Integration | **Estimate**: S

## Context

**GDD**: `design/gdd/run-state.md` + `design/gdd/boss-system.md` (r1)
**Requirement**: TR-enemy-003 (Boss spawn at 5:00; defeat triggers victory)
**ADR**: ADR-0001 | **Risk**: LOW

## Acceptance Criteria

- [ ] **AC-13**: At `elapsed_time = 300.0` (stage_duration) → FamineBeastBoss instantiated at random angle, 420 px from Player AND `boss_spawned(boss)` emit (one-shot)
- [ ] **AC-14**: Boss spawn triggers `_apply_boss_phase_spawn_pressure()` → spawner clamped to `spawn_interval ≥ 2.5, max_enemies ≤ 8`
- [ ] **AC-15**: Boss uses canonical archetype values (max_hp=360, damage=18, etc.) — NOT Stage Director's dead-code 260/16 exports (per C-B2 resolution)

## Implementation Notes

```gdscript
signal boss_spawned(boss)

@export var boss_spawn_distance: float = 420.0
@export var boss_phase_spawn_interval: float = 2.5
@export var boss_phase_max_enemies: int = 8

var _is_boss_spawned: bool = false

func _process(delta: float) -> void:
    # ... existing ...
    if not _is_boss_spawned and elapsed_time >= stage_duration:
        _spawn_boss()

func _spawn_boss() -> void:
    _is_boss_spawned = true
    var boss = famine_beast_boss_scene.instantiate()
    # Boss uses its archetype-driven values per FamineBeastBoss._ready() (NOT the dead-code exports here)
    var angle := randf() * TAU
    boss.global_position = _player.global_position + Vector2.RIGHT.rotated(angle) * boss_spawn_distance
    get_tree().current_scene.add_child(boss)
    boss.died.connect(_on_boss_died)
    _apply_boss_phase_spawn_pressure()
    boss_spawned.emit(boss)

func _apply_boss_phase_spawn_pressure() -> void:
    var cfg := _get_wave_config(_current_wave_index)
    var clamped_interval = maxf(cfg.interval, boss_phase_spawn_interval)
    var clamped_max = mini(cfg.max, boss_phase_max_enemies)
    enemy_spawner.apply_wave_config(clamped_interval, clamped_max, cfg.pool, cfg.weights)

# DEAD-CODE EXPORTS (per C-B2 resolution — Stage Director's 260/16/70/1.8 only apply if boss.archetype == null,
# which never happens in shipping FamineBeastBoss.tscn — canonical values are 360/18/68/1.7 from archetype)
```

## QA Test Cases

**AC-13**: Boss spawn at 5:00
- Given: StageDirector with `_is_boss_spawned = false`
- When: `elapsed_time` crosses 300.0
- Then: FamineBeastBoss instantiated AND position is 420 px from Player at random angle AND `boss_spawned.emit(boss)` called once

**AC-14**: Boss-phase spawner clamp
- Given: Boss just spawned
- When: `_apply_boss_phase_spawn_pressure()` runs
- Then: `enemy_spawner.apply_wave_config` called with interval ≥ 2.5 AND max ≤ 8

**AC-15**: Canonical archetype values
- Given: FamineBeastBoss instance
- When: `_ready()` completes
- Then: `max_hp == 360` (from archetype, NOT 260 from Stage Director exports)
- Edge (C-B2 closed): Even if Stage Director's `boss_max_hp = 260` export is set, boss.max_hp from .tres is the value used

## Test Evidence
`tests/integration/run-state/boss_spawn_test.gd`

## Dependencies
- Depends on: Story 002 (wave config), Story 004 (elite spawns precede)
- Cross-coordinates: Enemy epic Story 006 (Boss state machine)
