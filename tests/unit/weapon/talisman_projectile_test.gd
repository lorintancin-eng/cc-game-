## Regression tests for Talisman projectile (Weapon System) — the Cultivator's
## starting weapon (单体直线追魂符). Single-target: the projectile damages the
## first enemy it overlaps, then despawns.
##
## Under test (scripts/weapon/talisman_projectile.gd::_on_body_entered):
##   - damages an enemy body once, then self-finishes (_has_hit guard)
##   - ignores non-enemy bodies and bodies without take_damage
##
## Driven directly (no physics signal); projectile added via add_child_autoqfree
## (it self-queue_free()s on hit; queue_free is idempotent so teardown is a safe
## no-op).
##
## Run via:
##   godot --headless --path . -s res://addons/gut/gut_cmdln.gd \
##         -gdir=res://tests/unit/weapon -gexit

extends "res://tests/helpers/test_base.gd"

const TalismanProjectileScript = preload("res://scripts/weapon/talisman_projectile.gd")


class MockEnemy extends Node2D:
	var total_damage: float = 0.0
	var hit_count: int = 0

	func take_damage(amount: float) -> void:
		total_damage += amount
		hit_count += 1


func _make_projectile(dmg: float) -> TalismanProjectile:
	var proj: TalismanProjectile = TalismanProjectileScript.new()
	add_child_autoqfree(proj)  # self-queue_free()s on hit; qfree idempotent
	proj.damage = dmg
	return proj


func _make_enemy() -> MockEnemy:
	var e := MockEnemy.new()
	e.add_to_group("enemies")
	add_child_autofree(e)
	return e


# ─── single-target damage on contact ─────────────────────────────────────

func test_talisman_projectile_damages_enemy_on_contact() -> void:
	var proj := _make_projectile(9.0)
	var enemy := _make_enemy()

	proj._on_body_entered(enemy)

	assert_eq(enemy.hit_count, 1, "enemy damaged once on contact")
	assert_float_eq(enemy.total_damage, 9.0, 0.001, "full talisman damage")


# ─── _has_hit guard: only the first body is damaged ──────────────────────

func test_talisman_projectile_hits_only_once() -> void:
	# A single talisman is single-target: after hitting one enemy it is spent,
	# so a second overlapping enemy must NOT be damaged.
	var proj := _make_projectile(9.0)
	var first := _make_enemy()
	var second := _make_enemy()

	proj._on_body_entered(first)
	proj._on_body_entered(second)

	assert_eq(first.hit_count, 1, "first enemy damaged")
	assert_eq(second.hit_count, 0, "second enemy NOT damaged — projectile is spent")


# ─── guards: non-enemy bodies are ignored ────────────────────────────────

func test_talisman_projectile_ignores_non_enemy_body() -> void:
	var proj := _make_projectile(9.0)
	var non_enemy := MockEnemy.new()  # has take_damage but NOT in "enemies"
	add_child_autofree(non_enemy)

	proj._on_body_entered(non_enemy)

	assert_eq(non_enemy.hit_count, 0, "non-enemy body must not be damaged")
