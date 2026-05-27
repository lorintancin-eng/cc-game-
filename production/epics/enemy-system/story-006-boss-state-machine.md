# Story 006: FamineBeastBoss State Machine + Telegraphs

> **Epic**: Enemy System | **Status**: Ready | **Layer**: Core | **Type**: Logic | **Estimate**: M

## Context

**GDD**: `design/gdd/boss-system.md` (r1) + `design/gdd/enemy-system.md`
**Requirement**: TR-enemy-003 (Boss spawn + victory)
**ADR**: ADR-0001 | **Risk**: MEDIUM (4-state machine + 3 telegraphed skills + Enrage)

**Cross-doc**: Boss System GDD r1 has 22 Tuning Knobs + 10 ACs. This story implements the BossState enum + Charge state cycle.

## Acceptance Criteria

- [ ] **AC-19**: FamineBeastBoss extends Enemy AND added to `bosses` group on `_ready` AND `xp_drop_value` forced to 0
- [ ] **AC-20**: BossState enum: `CHASE`, `CHARGE_WINDUP`, `CHARGE`, `CHARGE_RECOVERY` — transitions:
  - CHASE → CHARGE_WINDUP when `_charge_timer ≤ 0` (telegraph appears, velocity = 0)
  - CHARGE_WINDUP → CHARGE after 0.7s (charge_speed = 390 in `_charge_direction`)
  - CHARGE → CHARGE_RECOVERY after 0.55s (velocity = 0)
  - CHARGE_RECOVERY → CHASE after 0.35s
- [ ] **AC-21**: Boss is interrupt-immune (Rule 10) — taking damage during CHARGE_WINDUP / CHARGE / CHARGE_RECOVERY does NOT transition out

## Implementation Notes

Per Boss System GDD r1 Rule 4 + Formula 5 (telegraph timings):
```gdscript
class_name FamineBeastBoss extends Enemy

enum BossState { CHASE, CHARGE_WINDUP, CHARGE, CHARGE_RECOVERY }

@export var charge_cooldown: float = 4.8
@export var charge_windup_time: float = 0.7
@export var charge_duration: float = 0.55
@export var charge_recovery_time: float = 0.35
@export var charge_speed: float = 390.0
@export var charge_warning_length: float = 240.0

var _state: int = BossState.CHASE
var _state_timer: float = 0.0
var _charge_timer: float = 0.0
var _charge_direction: Vector2 = Vector2.RIGHT

@onready var _charge_telegraph: Line2D = $ChargeTelegraph

func _ready() -> void:
    super._ready()
    add_to_group("bosses")
    xp_drop_value = 0.0
    _charge_telegraph.visible = false

func _physics_process(delta: float) -> void:
    if _is_dead: return
    match _state:
        BossState.CHASE: _process_chase(delta)
        BossState.CHARGE_WINDUP: _process_charge_windup(delta)
        BossState.CHARGE: _process_charge(delta)
        BossState.CHARGE_RECOVERY: _process_charge_recovery(delta)
    _try_damage_player()

func _process_chase(delta: float) -> void:
    _charge_timer -= delta
    if _charge_timer <= 0.0:
        _start_charge_windup(); return
    velocity = global_position.direction_to(_player.global_position) * move_speed
    move_and_slide()

func _start_charge_windup() -> void:
    _state = BossState.CHARGE_WINDUP
    _state_timer = charge_windup_time
    _charge_timer = charge_cooldown
    _charge_direction = global_position.direction_to(_player.global_position)
    _charge_telegraph.visible = true
    _charge_telegraph.points = PackedVector2Array([Vector2.ZERO, _charge_direction * charge_warning_length])
```

## QA Test Cases

**AC-19**: Boss `_ready` setup
- Given: FamineBeastBoss instance with famine_beast archetype
- When: `_ready()` runs
- Then: `is_in_group("bosses") == true` AND `xp_drop_value == 0.0` AND `max_hp == 360` (canonical archetype value per C-B2)

**AC-20**: Full state cycle
- Given: Boss in CHASE state with `_charge_timer = 0.0`
- When: `_physics_process` runs
- Then: Transitions CHASE → CHARGE_WINDUP (telegraph visible, velocity=0) → after 0.7s → CHARGE (velocity = charge_direction × 390) → after 0.55s → CHARGE_RECOVERY → after 0.35s → CHASE

**AC-21**: Interrupt-immunity
- Given: Boss in CHARGE_WINDUP at t=0.3 (mid-windup)
- When: `take_damage(50)` fires
- Then: Boss takes 50 damage AND `_state` REMAINS `CHARGE_WINDUP` AND `_state_timer` continues counting down

## Test Evidence
`tests/unit/enemy/boss_state_machine_test.gd`

## Dependencies
- Depends on: Story 001, 003 (Enemy base + take_damage)
- Cross-coordinates: Combat epic Story 010 (Boss death triggers stage_cleared)
