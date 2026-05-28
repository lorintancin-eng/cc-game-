## Regression tests for Flying Sword pierce (Combat Story 005, AC-06 + AC-07).
##
## The pierce mechanic (scripts/weapon/flying_sword_projectile.gd) lets one
## projectile damage up to `pierce_count` distinct enemies, full damage each,
## hitting any single enemy at most once (dedup by instance_id). This is a
## shipping weapon mechanic with subtle dedup state — exactly the kind of logic
## that breaks silently — yet it had zero automated coverage.
##
## We drive `_on_body_entered` DIRECTLY with mock enemies instead of going
## through Area2D physics collision, so the test is deterministic and headless-
## safe (no physics broadphase, no frame timing). Tests deliberately stay BELOW
## the pierce cap (or simulate the cap by setting _hit_count) so the projectile
## never self-queue_free()s mid-test — avoiding a teardown double-free with GUT's
## autofree (the same class of deferred-error that previously tripped the runner).
##
## Run via:
##   godot --headless --path . -s res://addons/gut/gut_cmdln.gd \
##         -gdir=res://tests/unit/weapon -gexit

extends "res://tests/helpers/test_base.gd"

const FlyingSwordProjectileScript = preload("res://scripts/weapon/flying_sword_projectile.gd")


# Minimal enemy stand-in: a Node2D in the "enemies" group that records the
# damage it receives. Matches the three things _on_body_entered checks:
# is_in_group("enemies"), has_method("take_damage"), get_instance_id().
class MockEnemy extends Node2D:
	var total_damage: float = 0.0
	var hit_count: int = 0

	func take_damage(amount: float) -> void:
		total_damage += amount
		hit_count += 1


func _make_projectile(dmg: float, pierce: int) -> FlyingSwordProjectile:
	var proj: FlyingSwordProjectile = FlyingSwordProjectileScript.new()
	add_child_autofree(proj)  # GUT frees at teardown; tests never self-queue_free
	# Set fields directly rather than launch() — avoids enabling _physics_process
	# (movement / lifetime). We only exercise the hit-resolution path.
	proj.damage = dmg
	proj.pierce_count = pierce
	return proj


func _make_enemy() -> MockEnemy:
	var e := MockEnemy.new()
	e.add_to_group("enemies")
	add_child_autofree(e)
	return e


# ─── AC-06: pierce hits multiple distinct enemies, full damage each ──────

func test_flying_sword_pierce_hits_each_of_three_distinct_enemies() -> void:
	# Arrange — pierce_count = 5 (above the 3 hits so the cap/finish path is not
	# triggered; we are verifying multi-target full damage, not the boundary).
	var proj := _make_projectile(10.0, 5)
	var e1 := _make_enemy()
	var e2 := _make_enemy()
	var e3 := _make_enemy()

	# Act — projectile passes through all three.
	proj._on_body_entered(e1)
	proj._on_body_entered(e2)
	proj._on_body_entered(e3)

	# Assert — each took exactly one full-damage hit (no pierce falloff).
	assert_eq(e1.hit_count, 1, "enemy 1 hit once")
	assert_eq(e2.hit_count, 1, "enemy 2 hit once")
	assert_eq(e3.hit_count, 1, "enemy 3 hit once")
	assert_float_eq(e1.total_damage, 10.0, 0.001, "full damage, no falloff")
	assert_float_eq(e3.total_damage, 10.0, 0.001, "third enemy still full damage")


# ─── AC-07: a single enemy is damaged at most once (dedup by instance_id) ─

func test_flying_sword_pierce_dedups_same_enemy() -> void:
	# Arrange — pierce_count = 3 so capacity is NOT the limiter; only dedup is.
	# _hit_count stays at 1 (one distinct enemy), so no finish/queue_free.
	var proj := _make_projectile(10.0, 3)
	var enemy := _make_enemy()

	# Act — same enemy re-enters the projectile's area multiple times.
	proj._on_body_entered(enemy)
	proj._on_body_entered(enemy)
	proj._on_body_entered(enemy)

	# Assert — damaged exactly once despite three overlap events.
	assert_eq(enemy.hit_count, 1, "same enemy must be damaged at most once")
	assert_float_eq(enemy.total_damage, 10.0, 0.001, "no double-dipping on re-overlap")


# ─── AC-06 edge: pierce capacity guard rejects bodies once exhausted ─────

func test_flying_sword_pierce_rejects_body_when_capacity_exhausted() -> void:
	# Arrange — simulate a projectile already at its pierce cap (2/2) WITHOUT
	# going through the hits that would call _finish()/queue_free(). We test the
	# entry guard (`_hit_count >= pierce_count`) in isolation.
	var proj := _make_projectile(7.0, 2)
	proj._hit_count = 2
	var late_enemy := _make_enemy()

	# Act
	proj._on_body_entered(late_enemy)

	# Assert — rejected; capacity is exhausted.
	assert_eq(late_enemy.hit_count, 0, "at pierce cap, further bodies are rejected")


# ─── Guard: non-enemy bodies are ignored ─────────────────────────────────

func test_flying_sword_pierce_ignores_non_enemy_body() -> void:
	# Arrange — a body with take_damage but NOT in the "enemies" group.
	var proj := _make_projectile(10.0, 3)
	var non_enemy := MockEnemy.new()  # NOT added to "enemies"
	add_child_autofree(non_enemy)

	# Act
	proj._on_body_entered(non_enemy)

	# Assert — ignored; no damage taken.
	assert_eq(non_enemy.hit_count, 0, "non-enemy body must not take pierce damage")
