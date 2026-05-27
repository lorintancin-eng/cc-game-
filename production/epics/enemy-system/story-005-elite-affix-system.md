# Story 005: Elite Affix System (iron_bones + swift)

> **Epic**: Enemy System | **Status**: Ready | **Layer**: Core | **Type**: Logic | **Estimate**: M

## Context

**GDD**: `design/gdd/enemy-system.md` (r1) | **Requirement**: TR-enemy-001
**ADR**: ADR-0001 | **Risk**: LOW

## Acceptance Criteria

- [ ] **AC-15**: Shanxiao Elite with `elite_affixes = ["iron_bones"]` → `max_hp = 110 × 1.25 × 1.45 = 199.375` (general elite + iron_bones stacked)
- [ ] **AC-16**: Shanxiao Elite with `["iron_bones", "swift"]` → max_hp=199.375 AND move_speed=72 × 1.25 × 1.3 = 117 AND damage = 15 × 1.15 = 17.25
- [ ] **AC-17**: Affix application order is deterministic: general elite multipliers FIRST, then per-affix multipliers stack on top
- [ ] **AC-18**: Affixes applied at spawn ONLY — `configure_elite(affixes)` is idempotent; cannot mutate runtime

## Implementation Notes

Per Enemy GDD r1 Formula 5 + iron_bones/swift constants:
```gdscript
func configure_elite(affixes: Array[String]) -> void:
    if archetype == null: return
    is_elite = true
    # General elite multipliers FIRST
    max_hp = archetype.max_hp * archetype.elite_health_multiplier  # ×1.25
    damage = archetype.damage * archetype.elite_damage_multiplier  # ×1.15
    move_speed = archetype.move_speed * archetype.elite_speed_multiplier  # ×1.05
    # Per-affix multipliers stack on top
    if "iron_bones" in affixes:
        max_hp *= archetype.iron_bones_health_multiplier  # ×1.45
    if "swift" in affixes:
        move_speed *= archetype.swift_speed_multiplier  # ×1.3
    current_hp = max_hp
    elite_affixes = affixes
```

**Note**: per Enemy GDD r1 Core Rule 7, multipliers are per-archetype (in `.tres`), NOT global constants. This enables per-archetype tuning (e.g. a fragile elite could use 1.6 HP multiplier).

## QA Test Cases

**AC-15**: Shanxiao + iron_bones
- Given: Shanxiao Elite archetype (max_hp=110, elite_health_multiplier=1.25, iron_bones_health_multiplier=1.45)
- When: `configure_elite(["iron_bones"])`
- Then: `max_hp == 199.375` AND `current_hp == 199.375`
- Worked: 110 × 1.25 × 1.45 = 199.375 ✓

**AC-16**: Combined affixes
- Given: Same archetype + `["iron_bones", "swift"]`
- When: `configure_elite(...)`
- Then: max_hp=199.375 AND move_speed = 72 × 1.25 × 1.3 = 117 AND damage = 15 × 1.15 = 17.25

**AC-17**: Order determinism
- Given: Same archetype + affixes
- When: configure_elite called with `["swift", "iron_bones"]` vs `["iron_bones", "swift"]`
- Then: Result IDENTICAL (general multipliers apply first regardless of order)

**AC-18**: Idempotency
- Given: Elite configured with `["iron_bones"]`
- When: configure_elite called again with same affixes
- Then: max_hp NOT multiplied again (would produce 199.375 × 1.45 = 289 if double-applied — must NOT happen)

## Test Evidence
`tests/unit/enemy/elite_affix_test.gd`

## Dependencies
- Depends on: Story 001 (archetype loading)
