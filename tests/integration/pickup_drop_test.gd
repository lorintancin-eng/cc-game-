## 镇妖四宝掉落接线（StageDirector ← EnemySpawner.enemy_killed）。
## Boss/精英 必掉(drop_chance=1.0,确定性)→ 用真实 Main.tscn 验证死亡掉落整链。
##
## Run via:
##   godot --headless --path . -s res://addons/gut/gut_cmdln.gd \
##         -gdir=res://tests/integration -gconfig=res://tests/.gutconfig.json -gexit

extends "res://tests/helpers/test_base.gd"

const MAIN_SCENE := preload("res://scenes/Main.tscn")


func test_boss_death_always_drops_a_pickup() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child_autofree(main)
	var sd := main.get_node("StageDirector")

	var boss := Node2D.new()
	boss.add_to_group(&"bosses")
	add_child_autofree(boss)
	boss.global_position = Vector2(100.0, 100.0)

	var before := get_tree().get_nodes_in_group(&"pickups").size()
	sd._on_enemy_killed_drop(boss)
	var after := get_tree().get_nodes_in_group(&"pickups").size()

	assert_eq(after, before + 1, "Boss 死亡必掉 1 个道具")


func test_drop_spawns_a_valid_pickup_node() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child_autofree(main)
	var sd := main.get_node("StageDirector")

	var elite := Node2D.new()
	elite.set("is_elite", true)  # 注：Node2D 无此属性，下行直接走 bosses 组确保必掉
	elite.add_to_group(&"bosses")
	add_child_autofree(elite)

	sd._on_enemy_killed_drop(elite)

	var pickups := get_tree().get_nodes_in_group(&"pickups")
	assert_true(pickups.size() >= 1, "掉落生成了 pickups 组节点")
	assert_true(pickups[0] is Pickup, "掉落物是 Pickup 类型(脚本已解析)")
