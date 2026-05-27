# Story 002: Wave Config Sequence (5 Waves)

> **Epic**: Run State | **Status**: Ready | **Layer**: Foundation | **Type**: Integration | **Estimate**: M

## Context

**GDD**: `design/gdd/run-state.md` | **Requirement**: TR-core-002
**ADR**: ADR-0001 | **Risk**: LOW

**Tech debt note**: Wave configs are HARDCODED in match statement (per Run State GDD Rule 5 + OQ-3) — violates Pillar 4. v0.4 ships this way; future sprint extracts to `.tres`.

## Acceptance Criteria

- [ ] **AC-04**: Wave config index advances at exact phase boundaries:
  - 0:00-1:00: Wave 0 (interval 1.35s, max 18, pool [PaperDoll, WanderingSoul])
  - 1:00-2:00: Wave 1 (interval 1.08s, max 24, +FoxSpirit +GhostFlame)
  - 2:00-3:00: Wave 2 (interval 0.90s, max 32, +StoneGolem)
  - 3:00-4:30: Wave 3 (interval 0.72s, max 42)
  - 4:30-5:00: Wave 4 (interval 0.55s, max 56 — boss-warning phase)
- [ ] **AC-05**: At each phase boundary → `EnemySpawner.apply_wave_config(interval, max, pool, weights)` is called
- [ ] **AC-06**: Wave 4 → boss_warning_started(30.0) emits AT 4:30 (one-shot)

## Implementation Notes

Per Run State GDD Formula 2 + Stage Phase Timeline:
```gdscript
signal boss_warning_started(lead_time: float)

@export var boss_warning_lead_time: float = 30.0

var _current_wave_index: int = -1

func _get_wave_config_index() -> int:
    if elapsed_time < 60.0: return 0
    elif elapsed_time < 120.0: return 1
    elif elapsed_time < 180.0: return 2
    elif elapsed_time < 270.0: return 3  # extends through 4:30
    else: return 4  # 270.0+ = boss warning phase

func _get_wave_config(index: int) -> Dictionary:
    match index:
        0: return {"interval": 1.35, "max": 18, "pool": ["PaperDoll", "WanderingSoul"], "weights": [3.0, 4.0]}
        1: return {"interval": 1.08, "max": 24, "pool": ["PaperDoll", "WanderingSoul", "FoxSpirit", "GhostFlame"], "weights": [...]}
        2: return {"interval": 0.90, "max": 32, "pool": [...+ "StoneGolem"], "weights": [...]}
        3: return {"interval": 0.72, "max": 42, "pool": [...], "weights": [...]}
        4: return {"interval": 0.55, "max": 56, "pool": [...], "weights": [...]}
        _: return {}

func _process(delta: float) -> void:
    # ... (Story 001 clock code)
    var new_index := _get_wave_config_index()
    if new_index != _current_wave_index:
        _current_wave_index = new_index
        _apply_current_wave_config()
        if new_index == 4:
            boss_warning_started.emit(boss_warning_lead_time)  # 30s before boss

func _apply_current_wave_config(force_apply: bool = false) -> void:
    var cfg := _get_wave_config(_current_wave_index)
    # Apply demon-seal pressure multipliers if active (Story 004)
    var interval = cfg.interval
    var max_enemies = cfg.max
    if _is_demon_seal_pressure_active:
        interval *= demon_seal_pressure_interval_multiplier  # × 0.65
        max_enemies += demon_seal_pressure_max_enemy_bonus  # + 6
    enemy_spawner.apply_wave_config(interval, max_enemies, cfg.pool, cfg.weights)
```

## QA Test Cases

**AC-04**: Phase boundary transitions
- Given: StageDirector running
- When: `elapsed_time` crosses 60.0, 120.0, 180.0, 270.0
- Then: `_current_wave_index` advances 0 → 1 → 2 → 3 → 4 at those exact times

**AC-05**: Spawner config applied at each boundary
- Given: Mock EnemySpawner with `apply_wave_config` spy
- When: Wave index changes
- Then: `apply_wave_config` called with the new wave's interval/max/pool/weights

**AC-06**: Boss warning one-shot
- Given: elapsed_time approaching 270.0
- When: elapsed_time crosses 270.0
- Then: `boss_warning_started.emit(30.0)` called ONCE (not on subsequent frames)

## Test Evidence
`tests/integration/run-state/wave_config_test.gd`

## Dependencies
- Depends on: Story 001 (clock)
- Cross-coordinates: Enemy Spawning epic (apply_wave_config API)
