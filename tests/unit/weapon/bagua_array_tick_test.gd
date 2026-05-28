## Regression tests for Bagua Array multi-target tick (Combat Story 006,
## AC-08-A + AC-08-B + Formula 3).
##
## The Bagua Array (scripts/weapon/bagua_array_weapon.gd) is a persistent aura
## that, every `tick_rate` seconds, damages EVERY enemy within `radius` for the
## full weapon damage (no splitting). This multi-target behavior is the core of
## Formula 3 (effective DPS = damage × hits_per_tick / tick_rate) and had no
## automated coverage.
##
## We call `_apply_radius_damage()` directly (one deterministic tick) with the
## weapon's auto-`_process` suppressed, so timing/frame count cannot affect the
## result. Assertions check each SPECIFIC mock enemy's hit_count — never a global
## group count — so stray nodes from other tests cannot perturb the verdict.
##
## Run via:
##   godot --headless --path . -s res://addons/gut/gut_cmdln.gd \
##         -gdir=res://tests/unit/weapon -gexit

extends "res://tests/helpers/test_base.gd"

const BaguaArrayWeaponScript = preload("res://scripts/weapon/bagua_array_weapon.gd")


# Enemy stand-in: Node2D in the "enemies" group that records damage taken.
class MockEnemy extends Node2D:
	var total_damage: float = 0.0
	var hit_count: int = 0

	func take_damage(amount: float) -> void:
		total_damage += amount
		hit_count += 1


func _make_weapon(dmg: float, weapon_radius: float) -> BaguaArrayWeapon:
	var weapon: BaguaArrayWeapon = BaguaArrayWeaponScript.new()
	add_child_autofree(weapon)            # in tree → get_tree() group query works
	weapon.set_process(false)             # suppress the auto-tick; we tick manually
	weapon.global_position = Vector2.ZERO
	weapon.damage = dmg
	weapon.radius = weapon_radius
	return weapon


func _make_enemy_at(pos: Vector2) -> MockEnemy:
	var e := MockEnemy.new()
	e.add_to_group("enemies")
	add_child_autofree(e)
	e.global_position = pos
	return e


# ─── AC-08-A: every enemy inside the radius is damaged on a tick ─────────

func test_bagua_tick_damages_all_enemies_within_radius() -> void:
	# Arrange — radius 82; three enemies at distances 10 / 50 / 80 (all inside).
	var weapon := _make_weapon(12.0, 82.0)
	var e_near := _make_enemy_at(Vector2(10.0, 0.0))
	var e_mid := _make_enemy_at(Vector2(0.0, 50.0))
	var e_edge := _make_enemy_at(Vector2(80.0, 0.0))

	# Act — one deterministic tick.
	weapon._apply_radius_damage()

	# Assert — each in-range enemy took exactly one hit this tick.
	assert_eq(e_near.hit_count, 1, "near enemy damaged")
	assert_eq(e_mid.hit_count, 1, "mid enemy damaged")
	assert_eq(e_edge.hit_count, 1, "edge enemy (inside radius) damaged")


# ─── AC-08-A: full damage to each target, no splitting (Formula 3) ───────

func test_bagua_tick_applies_full_damage_to_each_target() -> void:
	# Arrange
	var weapon := _make_weapon(12.0, 82.0)
	var e1 := _make_enemy_at(Vector2(10.0, 0.0))
	var e2 := _make_enemy_at(Vector2(20.0, 0.0))

	# Act
	weapon._apply_radius_damage()

	# Assert — each gets the FULL 12, not 12/2. Multi-target = parallel full hits.
	assert_float_eq(e1.total_damage, 12.0, 0.001, "target 1 full damage")
	assert_float_eq(e2.total_damage, 12.0, 0.001, "target 2 full damage (not split)")


# ─── AC-08-B: enemies outside the radius take no damage ──────────────────

func test_bagua_tick_ignores_enemy_outside_radius() -> void:
	# Arrange — radius 82; one enemy well outside at distance 200.
	var weapon := _make_weapon(12.0, 82.0)
	var e_far := _make_enemy_at(Vector2(200.0, 0.0))

	# Act
	weapon._apply_radius_damage()

	# Assert
	assert_eq(e_far.hit_count, 0, "enemy beyond radius must not be damaged")


# ─── Repeated ticks accumulate (DPS over time) ───────────────────────────

func test_bagua_repeated_ticks_accumulate_damage() -> void:
	# Arrange
	var weapon := _make_weapon(5.0, 82.0)
	var enemy := _make_enemy_at(Vector2(10.0, 0.0))

	# Act — three discrete ticks.
	weapon._apply_radius_damage()
	weapon._apply_radius_damage()
	weapon._apply_radius_damage()

	# Assert — 3 ticks × 5 = 15 total; one hit per tick.
	assert_eq(enemy.hit_count, 3, "one hit per tick")
	assert_float_eq(enemy.total_damage, 15.0, 0.001, "damage accumulates across ticks")
