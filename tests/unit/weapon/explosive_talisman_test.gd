## Regression tests for Explosive Talisman (Combat / Weapon System).
##
## Mechanic per design/gdd/weapon-system.md (line 59 + Formula lines 142-145):
## "direct + explosion" — on impact the directly-hit enemy takes `damage`, AND
## every enemy within `explosion_radius` (including the directly-hit one, which
## sits at the epicenter) takes `explosion_damage`. So the primary target takes
## damage + explosion_damage; splash victims take explosion_damage only. This
## direct+splash double-application on the primary is INTENTIONAL (GDD-confirmed),
## not a bug — these tests lock it in.
##
## We call _explode(epicenter, direct_body) directly. The projectile is added via
## add_child_autoqfree (it self-queue_free()s in _explode; queue_free is idempotent
## so the teardown free is a safe no-op). impact_scene is nulled so no VFX node
## leaks. Assertions check specific mock enemies (immune to stray group nodes).
##
## Run via:
##   godot --headless --path . -s res://addons/gut/gut_cmdln.gd \
##         -gdir=res://tests/unit/weapon -gexit

extends "res://tests/helpers/test_base.gd"

const ExplosiveTalismanProjectileScript = preload("res://scripts/weapon/explosive_talisman_projectile.gd")


class MockEnemy extends Node2D:
	var total_damage: float = 0.0
	var hit_count: int = 0

	func take_damage(amount: float) -> void:
		total_damage += amount
		hit_count += 1


func _make_projectile(direct_dmg: float, expl_dmg: float, expl_radius: float) -> ExplosiveTalismanProjectile:
	var proj: ExplosiveTalismanProjectile = ExplosiveTalismanProjectileScript.new()
	add_child_autoqfree(proj)        # self-queue_free()s in _explode; qfree is idempotent
	proj.impact_scene = null         # no VFX node spawned in tests
	proj.global_position = Vector2.ZERO
	proj.damage = direct_dmg
	proj.explosion_damage = expl_dmg
	proj.explosion_radius = expl_radius
	return proj


func _make_enemy_at(pos: Vector2) -> MockEnemy:
	var e := MockEnemy.new()
	e.add_to_group("enemies")
	add_child_autofree(e)
	e.global_position = pos
	return e


# ─── direct + splash on the primary target (GDD-confirmed) ───────────────

func test_explosive_direct_target_takes_direct_plus_explosion() -> void:
	# Arrange — direct 8, explosion 14, radius 58. Primary at epicenter.
	var proj := _make_projectile(8.0, 14.0, 58.0)
	var primary := _make_enemy_at(Vector2.ZERO)

	# Act — direct hit on `primary` at the epicenter.
	proj._explode(Vector2.ZERO, primary)

	# Assert — direct (8) + splash (14) = 22, applied as two separate hits.
	assert_eq(primary.hit_count, 2, "primary takes direct hit + splash hit")
	assert_float_eq(primary.total_damage, 22.0, 0.001, "8 direct + 14 explosion")


# ─── splash damages other enemies in radius (explosion only) ─────────────

func test_explosive_splash_damages_nearby_enemies() -> void:
	# Arrange — no direct body (timeout explosion); two enemies inside radius 58.
	var proj := _make_projectile(8.0, 14.0, 58.0)
	var e1 := _make_enemy_at(Vector2(20.0, 0.0))
	var e2 := _make_enemy_at(Vector2(0.0, 40.0))

	# Act
	proj._explode(Vector2.ZERO, null)

	# Assert — each splash victim takes explosion_damage once (no direct).
	assert_eq(e1.hit_count, 1, "splash victim 1 hit once")
	assert_eq(e2.hit_count, 1, "splash victim 2 hit once")
	assert_float_eq(e1.total_damage, 14.0, 0.001, "explosion_damage only")
	assert_float_eq(e2.total_damage, 14.0, 0.001, "explosion_damage only")


# ─── enemies beyond the explosion radius are unharmed ────────────────────

func test_explosive_ignores_enemies_outside_radius() -> void:
	# Arrange — radius 58; one enemy well outside at 200.
	var proj := _make_projectile(8.0, 14.0, 58.0)
	var far := _make_enemy_at(Vector2(200.0, 0.0))

	# Act
	proj._explode(Vector2.ZERO, null)

	# Assert
	assert_eq(far.hit_count, 0, "enemy beyond explosion radius unharmed")


# ─── _has_exploded guard: explosion happens at most once ─────────────────

func test_explosive_does_not_explode_twice() -> void:
	# Arrange
	var proj := _make_projectile(8.0, 14.0, 58.0)
	var enemy := _make_enemy_at(Vector2(20.0, 0.0))

	# Act — first explosion applies splash; second call must early-return.
	proj._explode(Vector2.ZERO, null)
	proj._explode(Vector2.ZERO, null)

	# Assert — only one splash application despite two _explode calls.
	assert_eq(enemy.hit_count, 1, "_has_exploded guard prevents a second explosion")
