## Regression tests for Thunder Law targeting + strike AOE (Combat Story 007/
## Weapon System) — the Cultivator's multi-strike lightning weapon.
##
## Two subtle behaviors under test (scripts/weapon/thunder_law_weapon.gd):
##   1. _find_nearest_targets() — insertion-sorts enemies by distance and keeps
##      the `target_count` NEAREST within attack_range. An off-by-one or bad
##      comparison here silently mis-targets.
##   2. _apply_radius_damage(pos, damaged_ids) — AOE around each strike with a
##      SHARED dedup dict, so an enemy caught by two overlapping strikes in one
##      attack is damaged only once.
##
## Driven directly (no physics/timing); auto-_process suppressed; assertions
## check specific mock enemies (immune to stray group nodes).
##
## Run via:
##   godot --headless --path . -s res://addons/gut/gut_cmdln.gd \
##         -gdir=res://tests/unit/weapon -gexit

extends "res://tests/helpers/test_base.gd"

const ThunderLawWeaponScript = preload("res://scripts/weapon/thunder_law_weapon.gd")


class MockEnemy extends Node2D:
	var total_damage: float = 0.0
	var hit_count: int = 0

	func take_damage(amount: float) -> void:
		total_damage += amount
		hit_count += 1


func _make_weapon(dmg: float, strike_radius: float, range_val: float, targets: int) -> ThunderLawWeapon:
	var weapon: ThunderLawWeapon = ThunderLawWeaponScript.new()
	add_child_autofree(weapon)
	weapon.set_process(false)  # suppress auto-attack; we call methods directly
	weapon.global_position = Vector2.ZERO
	weapon.damage = dmg
	weapon.radius = strike_radius
	weapon.attack_range = range_val
	weapon.target_count = targets
	return weapon


func _make_enemy_at(pos: Vector2) -> MockEnemy:
	var e := MockEnemy.new()
	e.add_to_group("enemies")
	add_child_autofree(e)
	e.global_position = pos
	return e


# ─── _find_nearest_targets: keeps the N nearest in range ─────────────────

func test_thunder_targets_the_nearest_two_of_four() -> void:
	# Arrange — target_count = 2, range 280. Four enemies at 20/40/60/80.
	var weapon := _make_weapon(10.0, 72.0, 280.0, 2)
	var e20 := _make_enemy_at(Vector2(20.0, 0.0))
	var e40 := _make_enemy_at(Vector2(40.0, 0.0))
	var e60 := _make_enemy_at(Vector2(60.0, 0.0))
	var e80 := _make_enemy_at(Vector2(80.0, 0.0))

	# Act
	var targets := weapon._find_nearest_targets()

	# Assert — exactly the two nearest (e20, e40); the farther two excluded.
	assert_eq(targets.size(), 2, "keeps exactly target_count nearest")
	assert_true(targets.has(e20), "nearest (20px) selected")
	assert_true(targets.has(e40), "second-nearest (40px) selected")
	assert_false(targets.has(e60), "third-nearest (60px) excluded")
	assert_false(targets.has(e80), "farthest (80px) excluded")


func test_thunder_ignores_enemies_beyond_attack_range() -> void:
	# Arrange — range 100; one in (50), one out (150).
	var weapon := _make_weapon(10.0, 72.0, 100.0, 3)
	var inside := _make_enemy_at(Vector2(50.0, 0.0))
	var outside := _make_enemy_at(Vector2(150.0, 0.0))

	# Act
	var targets := weapon._find_nearest_targets()

	# Assert
	assert_true(targets.has(inside), "in-range enemy targeted")
	assert_false(targets.has(outside), "out-of-range enemy never targeted")


func test_thunder_returns_empty_when_no_enemies_in_range() -> void:
	var weapon := _make_weapon(10.0, 72.0, 100.0, 3)
	var _far := _make_enemy_at(Vector2(500.0, 0.0))
	var targets := weapon._find_nearest_targets()
	assert_eq(targets.size(), 0, "no in-range enemies → no targets")


# ─── _apply_radius_damage: AOE + shared dedup across strikes ─────────────

func test_thunder_strike_damages_all_within_strike_radius() -> void:
	# Arrange — strike radius 72 centered on (0,0); enemies at 30 (in) and 200 (out).
	var weapon := _make_weapon(15.0, 72.0, 280.0, 1)
	var near := _make_enemy_at(Vector2(30.0, 0.0))
	var far := _make_enemy_at(Vector2(200.0, 0.0))
	var damaged: Dictionary = {}

	# Act
	weapon._apply_radius_damage(Vector2.ZERO, damaged)

	# Assert
	assert_eq(near.hit_count, 1, "enemy inside strike radius damaged")
	assert_float_eq(near.total_damage, 15.0, 0.001, "full strike damage")
	assert_eq(far.hit_count, 0, "enemy outside strike radius unharmed")


func test_thunder_shared_dedup_prevents_double_hit_across_strikes() -> void:
	# Arrange — one enemy at origin; two overlapping strikes share the dedup dict
	# (as _try_attack does across its target loop).
	var weapon := _make_weapon(15.0, 72.0, 280.0, 2)
	var enemy := _make_enemy_at(Vector2(10.0, 0.0))
	var damaged: Dictionary = {}

	# Act — two strikes whose radii both cover the enemy, same dedup dict.
	weapon._apply_radius_damage(Vector2(0.0, 0.0), damaged)
	weapon._apply_radius_damage(Vector2(20.0, 0.0), damaged)

	# Assert — damaged once despite being inside both strikes.
	assert_eq(enemy.hit_count, 1, "shared dedup: enemy hit once across overlapping strikes")
	assert_float_eq(enemy.total_damage, 15.0, 0.001, "no double-dip from overlapping strikes")
