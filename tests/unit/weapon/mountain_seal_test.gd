## Regression tests for Mountain Seal (Weapon System) — the Cultivator's
## heavy large-radius slam (radius 118, slow cooldown).
##
## Under test (scripts/weapon/mountain_seal_weapon.gd):
##   - _find_nearest_enemy() — picks the single nearest enemy in attack_range
##   - _apply_radius_damage(pos) — full damage to every enemy within the large
##     seal radius centered on the target
##
## Driven directly (no physics/timing); auto-_process suppressed; assertions
## check specific mock enemies (immune to stray group nodes). No queue_free path
## is exercised (the weapon never self-frees), so add_child_autofree is safe.
##
## Run via:
##   godot --headless --path . -s res://addons/gut/gut_cmdln.gd \
##         -gdir=res://tests/unit/weapon -gexit

extends "res://tests/helpers/test_base.gd"

const MountainSealWeaponScript = preload("res://scripts/weapon/mountain_seal_weapon.gd")


class MockEnemy extends Node2D:
	var total_damage: float = 0.0
	var hit_count: int = 0

	func take_damage(amount: float) -> void:
		total_damage += amount
		hit_count += 1


func _make_weapon(dmg: float, seal_radius: float, range_val: float) -> MountainSealWeapon:
	var weapon: MountainSealWeapon = MountainSealWeaponScript.new()
	add_child_autofree(weapon)
	weapon.set_process(false)
	weapon.global_position = Vector2.ZERO
	weapon.damage = dmg
	weapon.radius = seal_radius
	weapon.attack_range = range_val
	return weapon


func _make_enemy_at(pos: Vector2) -> MockEnemy:
	var e := MockEnemy.new()
	e.add_to_group("enemies")
	add_child_autofree(e)
	e.global_position = pos
	return e


# ─── _find_nearest_enemy: nearest in range, null otherwise ───────────────

func test_mountain_seal_targets_nearest_enemy() -> void:
	var weapon := _make_weapon(20.0, 118.0, 280.0)
	var _far := _make_enemy_at(Vector2(200.0, 0.0))
	var near := _make_enemy_at(Vector2(40.0, 0.0))

	var target := weapon._find_nearest_enemy()
	assert_eq(target, near, "nearest in-range enemy chosen")


func test_mountain_seal_no_target_when_all_out_of_range() -> void:
	var weapon := _make_weapon(20.0, 118.0, 100.0)
	var _far := _make_enemy_at(Vector2(300.0, 0.0))
	assert_null(weapon._find_nearest_enemy(), "no in-range enemy → null target")


# ─── _apply_radius_damage: large-radius full-damage slam ─────────────────

func test_mountain_seal_slam_damages_all_within_large_radius() -> void:
	# Arrange — radius 118; three enemies at 30 / 90 / 115 (all inside).
	var weapon := _make_weapon(20.0, 118.0, 280.0)
	var e30 := _make_enemy_at(Vector2(30.0, 0.0))
	var e90 := _make_enemy_at(Vector2(0.0, 90.0))
	var e115 := _make_enemy_at(Vector2(115.0, 0.0))

	# Act — slam centered on origin.
	weapon._apply_radius_damage(Vector2.ZERO)

	# Assert — every in-radius enemy takes full seal damage.
	assert_eq(e30.hit_count, 1, "near enemy slammed")
	assert_eq(e90.hit_count, 1, "mid enemy slammed")
	assert_eq(e115.hit_count, 1, "edge enemy (inside 118) slammed")
	assert_float_eq(e30.total_damage, 20.0, 0.001, "full seal damage")


func test_mountain_seal_slam_ignores_enemy_outside_radius() -> void:
	# Arrange — radius 118; enemy just outside at 130.
	var weapon := _make_weapon(20.0, 118.0, 280.0)
	var outside := _make_enemy_at(Vector2(130.0, 0.0))

	# Act
	weapon._apply_radius_damage(Vector2.ZERO)

	# Assert
	assert_eq(outside.hit_count, 0, "enemy beyond seal radius unharmed")
