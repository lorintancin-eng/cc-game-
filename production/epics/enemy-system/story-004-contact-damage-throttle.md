# Story 004: Contact Damage Throttle (Enemy → Player)

> **Epic**: Enemy System | **Status**: Ready | **Layer**: Core | **Type**: Logic | **Estimate**: M

## Context

**GDD**: `design/gdd/enemy-system.md` (r1) | **Requirement**: TR-enemy-002
**ADR**: ADR-0001 | **Risk**: LOW

**Cross-doc**: Combat epic Story 007 also implements throttle from Combat's perspective. This story is Enemy-side implementation.

## Acceptance Criteria

- [ ] **AC-12**: Wandering Soul (damage=8, damage_interval=0.8) in contact with player AND `_damage_cooldown = 0` → `_try_damage_player()` → `Player.take_damage(8)` called once AND `_damage_cooldown = 0.8`
- [ ] **AC-13**: Same Wandering Soul in continuous contact from t=0 to t=1.5s → exactly 2 hits at t=0 and t=0.8 (NOT 3 — only 1.5s elapsed, third hit would be at t=1.6)
- [ ] **AC-14**: Two different enemies (Wandering Soul + Paper Doll) in contact → both apply damage independently per Combat Core Rule 9

## Implementation Notes

```gdscript
const MIN_DAMAGE_INTERVAL: float = 0.1

var _damage_cooldown: float = 0.0
var _damage_targets: Array[Node] = []  # players in contact

func _physics_process(delta: float) -> void:
    # ... movement code ...
    _damage_cooldown = maxf(_damage_cooldown - delta, 0.0)
    _try_damage_player()

func _try_damage_player() -> void:
    if _is_dead or _damage_cooldown > 0.0: return
    if _damage_targets.is_empty(): return
    var target := _damage_targets[0]  # one player per session
    if target.has_method("take_damage"):
        target.take_damage(damage)
        _damage_cooldown = maxf(damage_interval, MIN_DAMAGE_INTERVAL)

func _on_damage_area_body_entered(body: Node) -> void:
    if body.is_in_group("player"):
        _damage_targets.append(body)

func _on_damage_area_body_exited(body: Node) -> void:
    _damage_targets.erase(body)
```

**Spawn-grace rule** (per Combat GDD Formula 4): `_damage_cooldown = 0` on `_ready` — enemy can hit immediately on first contact.

## QA Test Cases

**AC-12**: First-contact damage
- Given: Wandering Soul spawned at world (100, 0), Player at (100, 0) — overlapping contact
- When: Frame 1 of `_physics_process`
- Then: `Player.take_damage(8)` called once AND `_damage_cooldown == 0.8`

**AC-13**: Throttled repeat
- Given: Wandering Soul + Player in continuous contact from t=0
- When: Run simulation for 1.5s at 60 FPS
- Then: Player took damage at t=0 and t=0.8 (exactly 2 hits) AND NOT at t=0.4 (throttled) AND NOT at t=1.6 (still in cooldown)

**AC-14**: Independent per-enemy throttles (Core Rule 9)
- Given: Wandering Soul AND Paper Doll both contacting player, both with `_damage_cooldown = 0`
- When: Both `_try_damage_player()` runs same frame
- Then: Player takes 8 + 5 = 13 damage AND each enemy's `_damage_cooldown` reset to its own `damage_interval`

## Test Evidence
`tests/unit/enemy/contact_damage_test.gd`

## Dependencies
- Depends on: Story 003 (take_damage of player)
- Cross-coordinates: Combat epic Story 007 (same throttle from Combat side)
