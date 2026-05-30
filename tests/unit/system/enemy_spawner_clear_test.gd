## Unit tests for EnemySpawner.clear_all_enemies() — used by the multi-stage
## transition (RunDirector) to wipe the previous stage's enemies before the next
## stage's waves begin.
##
## The spawner is kept DETACHED (autofree, not add_child_autofree): its enemy
## children therefore never enter the tree, so Enemy's @onready node refs
## ($DamageArea/$Body/…) are never evaluated and can't crash. queue_free() still
## works on detached nodes (via the SceneTree singleton), so is_queued_for_deletion
## is observable.
##
## Run via:
##   godot --headless --path . -s res://addons/gut/gut_cmdln.gd \
##         -gdir=res://tests/unit/system -gexit

extends "res://tests/helpers/test_base.gd"


func test_clear_all_enemies_frees_them_and_resets_count() -> void:
	var spawner := EnemySpawner.new()
	autofree(spawner)  # detached — children never enter the tree (no @onready eval)
	var enemies: Array[Enemy] = []
	for _i in 3:
		var e := Enemy.new()
		spawner.add_child(e)
		enemies.append(e)
	spawner.current_enemy_count = 3

	spawner.clear_all_enemies()

	assert_eq(spawner.current_enemy_count, 0, "live count reset to 0")
	for e in enemies:
		assert_true(e.is_queued_for_deletion(), "each enemy was queued for deletion")


func test_clear_all_enemies_ignores_non_enemy_children() -> void:
	# The spawner may hold non-Enemy helper children; clear must only touch Enemies.
	var spawner := EnemySpawner.new()
	autofree(spawner)
	var marker := Node2D.new()
	spawner.add_child(marker)
	var enemy := Enemy.new()
	spawner.add_child(enemy)
	spawner.current_enemy_count = 1

	spawner.clear_all_enemies()

	assert_false(marker.is_queued_for_deletion(), "non-Enemy child is left alone")
	assert_true(enemy.is_queued_for_deletion(), "Enemy child is freed")
	assert_eq(spawner.current_enemy_count, 0, "count reset")


func test_clear_all_enemies_on_empty_spawner_is_safe() -> void:
	var spawner := EnemySpawner.new()
	autofree(spawner)
	spawner.current_enemy_count = 0
	spawner.clear_all_enemies()
	assert_eq(spawner.current_enemy_count, 0, "no enemies → still 0, no error")
