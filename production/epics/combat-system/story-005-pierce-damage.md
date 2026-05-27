# Story 005: Pierce Damage (Flying Sword)

> **Epic**: Combat System
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: S (1-2 hours)
> **Manifest Version**: 2026-05-25.1
> **Last Updated**: 2026-05-27

## Context

**GDD**: `design/gdd/combat-system.md`
**Requirement**: `TR-wpn-001` (WeaponBase contract — pierce semantics)

**ADR Governing Implementation**: ADR-0001: Godot 4.x + GDScript
**ADR Decision Summary**: Projectile-based pierce uses `pierce_count` field on projectile; each hit decrements; destruction at 0 remaining.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Use `Area2D.body_entered` for hit detection; track hit set to prevent double-hit on same enemy.

**Control Manifest Rules (Feature Layer)**:
- Required: Weapons inherit from `WeaponBase` (Story 004)
- Guardrail: `pierce_count` capped at 8 in `.tres` (per Combat GDD §Tuning Knobs)

---

## Acceptance Criteria

*From GDD `design/gdd/combat-system.md` + Formula 6:*

- [ ] **AC-06**: Flying Sword projectile with `pierce_count = 3` passes through 4 enemies sequentially → enemies 1-4 take damage (initial + 3 pierces = 4 hits) AND projectile destroyed after 4th hit
- [ ] **AC-07**: Flying Sword projectile with `pierce_count = 0` hits first enemy → that enemy takes damage AND projectile destroyed (no pierce-through)
- [ ] **Formula 6 verification**: Pierce damage is FULL per-hit (no falloff in v0.4); `pierce_falloff = 1.0` constant

---

## Implementation Notes

*Per Combat GDD Formula 6 + Boundary Cases:*

1. Projectile carries `pierce_count` field (number of *additional* pierces beyond first hit):
   ```gdscript
   class_name FlyingSwordProjectile
   extends Area2D

   @export var damage: float = 14.0
   @export var pierce_count: int = 0  # 0 = single-hit; 3 = initial + 3 pierces = 4 hits max
   var _remaining_pierces: int
   var _hit_enemies: Array[Node] = []  # prevent double-hit on same enemy

   func _ready() -> void:
       _remaining_pierces = pierce_count
       body_entered.connect(_on_body_entered)

   func _on_body_entered(body: Node) -> void:
       if not body.is_in_group("enemies"):
           return
       if body in _hit_enemies:
           return  # already hit this enemy — don't double-count pierces
       _hit_enemies.append(body)
       if body.has_method("take_damage"):
           body.take_damage(damage * 1.0)  # pierce_falloff = 1.0 per Formula 6
       _remaining_pierces -= 1
       if _remaining_pierces < 0:
           queue_free()
   ```
2. Boundary semantics per Combat GDD Formula 6 boundary case: `pierce_count = 0` → 1 hit total (initial + 0 pierces). `pierce_count = 3` → 4 hits total. The count tracks *additional* pierces beyond the first hit.
3. `pierce_falloff` slot is reserved (constant 1.0) in v0.4 baseline. Future weapon designs can replace 1.0 with `0.8^(index - 1)` etc. — this story does NOT implement falloff.

---

## Out of Scope

- Projectile visual (Weapon System epic)
- Projectile lifetime expiry (Story 004 — `projectile_lifetime` field)
- Pierce falloff curve (future weapon designs)

---

## QA Test Cases

**AC-06**: 3-pierce hits 4 enemies sequentially
- **Given**: Flying Sword projectile spawned at world (0,0) with `damage = 14.0, pierce_count = 3`; 5 Paper Dolls in a row at x = 50, 100, 150, 200, 250 (all in projectile's path); projectile speed sufficient to pass through all 5
- **When**: Projectile traverses x=0 → x=300
- **Then**: Enemies at x=50, 100, 150, 200 each take 14.0 damage (4 total hits — initial + 3 pierces) AND projectile destroyed after hitting enemy at x=200 AND enemy at x=250 takes 0 damage
- **Edge cases**: Two enemies overlap exact same position → both hit on the same `body_entered` frame, both deducted from pierce count; projectile passes enemy multiple times (shouldn't happen with straight-line motion but with curves) → `_hit_enemies` array prevents double-count

**AC-07**: `pierce_count = 0` → single hit
- **Given**: Flying Sword projectile with `damage = 14.0, pierce_count = 0`; Paper Doll at x=50 in projectile's path
- **When**: Projectile reaches x=50
- **Then**: Paper Doll takes 14.0 damage AND projectile destroyed immediately AND no further enemies in path take damage (projectile no longer exists)
- **Edge cases**: `pierce_count = -1` (designer typo) → still single-hit (defensive: clamp at 0 minimum); enemy dies on hit → still counts as 1 pierce consumed

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/combat/pierce_damage_test.gd` — must exist and pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (damage tuple), Story 004 (WeaponBase)
- Unlocks: Flying Sword full implementation in Weapon System epic
