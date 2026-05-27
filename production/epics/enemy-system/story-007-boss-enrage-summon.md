# Story 007: Boss Enrage + Summon + Burst Skills

> **Epic**: Enemy System | **Status**: Ready | **Layer**: Core | **Type**: Integration | **Estimate**: M

## Context

**GDD**: `design/gdd/boss-system.md` (r1) | **Requirement**: TR-enemy-003
**ADR**: ADR-0001 | **Risk**: MEDIUM (Enrage = defining mechanic per Boss System r1 B-1 resolution)

## Acceptance Criteria

- [ ] **AC-22**: Boss HP / max_hp ≤ 0.3 (108/360) → `_enter_enrage()` fires ONCE: move_speed × 1.35; charge_speed × 1.35; all 3 skill timers × 0.5; body color → Color(0.78, 0.14, 0.08, 1.0); `_enraged_aura.visible = true`
- [ ] **AC-23**: Enrage is ONE-WAY — `_is_enraged` flag; re-entering `take_damage` after enraged does NOT re-trigger
- [ ] **AC-24**: Burst skill: 1.05s warning (translucent red poly radius 58) → detonation (18 dmg to player if within radius) → 0.18s linger
- [ ] **AC-25**: Summon skill: spawns 2 enemies per cast, alternating **Paper Doll + Wandering Soul** (per Boss r1 B-2 fix); cap at summon_max_alive=6

## Implementation Notes

Per Boss System GDD r1 Rule 7 + Formula 4 + Formula 3:
```gdscript
@export var enrage_health_ratio: float = 0.3
@export var enrage_speed_multiplier: float = 1.35
@export var enrage_skill_interval_multiplier: float = 0.65
@export var burst_warning_time: float = 1.05
@export var burst_radius: float = 58.0
@export var burst_damage: float = 18.0
@export var burst_linger_time: float = 0.18
@export var summon_batch_count: int = 2
@export var summon_max_alive: int = 6

const PAPER_DOLL_ARCHETYPE: Resource = preload("res://resources/enemies/paper_doll.tres")
const WANDERING_SOUL_ARCHETYPE: Resource = preload("res://resources/enemies/wandering_soul.tres")

var _is_enraged: bool = false
var _summoned_enemies: Array[Enemy] = []

func take_damage(amount: float) -> void:
    super.take_damage(amount)
    if _is_dead or _is_enraged: return
    if current_hp / max_hp <= enrage_health_ratio:
        _enter_enrage()

func _enter_enrage() -> void:
    _is_enraged = true
    move_speed *= enrage_speed_multiplier
    charge_speed *= enrage_speed_multiplier
    _charge_timer = minf(_charge_timer, charge_cooldown * enrage_skill_interval_multiplier * 0.5)
    _burst_timer = minf(_burst_timer, burst_cooldown * enrage_skill_interval_multiplier * 0.5)
    _summon_timer = minf(_summon_timer, summon_cooldown * enrage_skill_interval_multiplier * 0.5)
    _body.color = Color(0.78, 0.14, 0.08, 1.0)
    _enraged_aura.visible = true

func _summon_minions() -> void:
    var available_slots := summon_max_alive - _summoned_enemies.size()
    if available_slots <= 0: return
    var spawn_count := mini(summon_batch_count, available_slots)
    var base_count := _summoned_enemies.size()
    for index in spawn_count:
        var archetype := PAPER_DOLL_ARCHETYPE
        if (base_count + index) % 2 == 1:
            archetype = WANDERING_SOUL_ARCHETYPE
        # ... spawn enemy with archetype
```

## QA Test Cases

**AC-22**: Enrage trigger at 30% HP
- Given: Boss at HP=200 (above 108 threshold = 30% of 360)
- When: `take_damage(95)` brings HP to 105 (below 108)
- Then: `_is_enraged == true` AND `move_speed == archetype.move_speed × 1.35` AND body color = Color(0.78, 0.14, 0.08, 1.0) AND `_enraged_aura.visible == true`

**AC-23**: One-way Enrage
- Given: Boss already enraged (`_is_enraged == true`)
- When: `take_damage(50)` fires (HP drops further)
- Then: `_enter_enrage` early-returns; move_speed NOT multiplied a second time

**AC-24**: Burst skill detonation
- Given: Boss in CHASE; `_burst_timer ≤ 0`
- When: `_start_burst_marker()` fires
- Then: Burst marker spawns at player's position-at-cast → after 1.05s warning → detonation (player within radius 58 takes 18 dmg) → marker visible 0.18s more → queue_free

**AC-25**: Summon archetypes
- Given: Boss CHASE; `_summon_timer ≤ 0`; `_summoned_enemies` empty
- When: `_summon_minions()` fires
- Then: 2 enemies spawned — first is Paper Doll (index 0), second is Wandering Soul (index 1) AND `_summoned_enemies.size() == 2`
- Edge: `_summoned_enemies.size() == 6` (cap) → no new spawn this cycle; one summon dies → `_summoned_enemies` removes via signal → next cast can spawn again

## Test Evidence
`tests/integration/enemy/boss_enrage_summon_test.gd`

## Dependencies
- Depends on: Story 006 (BossState machine)
