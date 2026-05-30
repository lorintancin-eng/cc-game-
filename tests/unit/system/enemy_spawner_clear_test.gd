## Unit tests for EnemySpawner.clear_all_enemies() — used by the multi-stage
## transition (RunDirector) to wipe the previous stage's enemies before the next
## stage's waves begin.
##
## Run via:
##   godot --headless --path . -s res://addons/gut/gut_cmdln.gd \
##         -gdir=res://tests/unit/system -gexit

extends "res://tests/helpers/test_base.gd"


# A bare Enemy.new() would run Enemy._ready / _physics_process, which touch
# @onready child nodes that don't exist on a script-only instance and crash.
# StubEnemy is still `is Enemy` (so clear_all_enemies acts on it) but inert.
class StubEnemy extends Enemy:
	func _ready() -> void:
		pass
	func _physics_process(_delta: float) -> void:
		pass
	func _process(_delta: float) -> void:
		pass


func test_clear_all_enemies_frees_them_and_resets_count() -> void:
	var spawner := EnemySpawner.new()
	add_child_autofree(spawner)
	var enemies: Array[Enemy] = []
	for _i in 3:
		var e := StubEnemy.new()
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
	add_child_autofree(spawner)
	var marker := Node2D.new()
	spawner.add_child(marker)
	var enemy := StubEnemy.new()
	spawner.add_child(enemy)
	spawner.current_enemy_count = 1

	spawner.clear_all_enemies()

	assert_false(marker.is_queued_for_deletion(), "non-Enemy child is left alone")
	assert_true(enemy.is_queued_for_deletion(), "Enemy child is freed")
	assert_eq(spawner.current_enemy_count, 0, "count reset")


func test_clear_all_enemies_on_empty_spawner_is_safe() -> void:
	var spawner := EnemySpawner.new()
	add_child_autofree(spawner)
	spawner.current_enemy_count = 0
	spawner.clear_all_enemies()
	assert_eq(spawner.current_enemy_count, 0, "no enemies → still 0, no error")
