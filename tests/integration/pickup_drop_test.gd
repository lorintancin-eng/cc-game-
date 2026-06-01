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


func test_enemy_killed_SIGNAL_drops_via_live_connection() -> void:
	# 关键：走真实的 EnemySpawner.enemy_killed 信号连接（不是直接调方法），
	# 验证 StageDirector._ready 真的把掉落接上了 spawner。
	var main := MAIN_SCENE.instantiate()
	add_child_autofree(main)
	var sd := main.get_node("StageDirector")
	var spawner := main.get_node_or_null("EnemySpawner")

	assert_not_null(spawner, "Main 有 EnemySpawner")
	assert_eq(sd._enemy_spawner, spawner, "StageDirector 解析到 EnemySpawner(掉落连接目标)")
	assert_true(spawner.enemy_killed.is_connected(sd._on_enemy_killed_drop),
		"StageDirector 已连上 enemy_killed(否则游戏里永不掉落)")

	var boss := Node2D.new()
	boss.add_to_group(&"bosses")
	add_child_autofree(boss)
	var before := get_tree().get_nodes_in_group(&"pickups").size()
	spawner.enemy_killed.emit(boss)  # 经信号链
	var after := get_tree().get_nodes_in_group(&"pickups").size()
	assert_eq(after, before + 1, "emit enemy_killed → 掉落道具(连接生效)")
