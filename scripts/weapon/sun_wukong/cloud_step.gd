class_name CloudStep
extends Node2D

## 筋斗云（孙悟空 v2 主动技能 2，按键 2）
##
## 朝玩家 facing 方向瞬间冲刺，路径上敌人受伤。
## 4 级成长见 docs/SUN_WUKONG_V2_DESIGN.md §5
##
## 部分高级效果简化（v0.4 v2 MVP）：
## - Lv2 云雾减速：简化为路径敌人 slow 标记（实际生效待 Enemy 支持 buff 系统）
## - Lv4 残影：简化为静态区域，每 0.2s 对范围内敌人 +10 伤害
##
## TODO follow-up: Enemy slow buff infrastructure 完整后补 Lv2 完整减速效果

@export var level: int = 1: set = _apply_level
@export var path_width: float = 40.0

# 等级派生
var _dash_distance: float = 200.0
var _path_damage: float = 25.0
var _mist_enabled: bool = false   # Lv2+
var _invincible_enabled: bool = false  # Lv3+
var _cd_reduction_on_elite: bool = false  # Lv3+
var _afterimage_enabled: bool = false  # Lv4

# W213 升级 bonus（cooldown 通过 active_skill_character.reduce_skill_max_cd 改）
var dash_distance_bonus: float = 0.0
var path_damage_bonus: float = 0.0


func _ready() -> void:
	_apply_level(level)


func _apply_level(lv: int) -> void:
	level = clampi(lv, 1, 4)
	match level:
		1:
			_dash_distance = 200.0
			_path_damage = 25.0
			_mist_enabled = false
			_invincible_enabled = false
			_cd_reduction_on_elite = false
			_afterimage_enabled = false
		2:
			_dash_distance = 280.0
			_path_damage = 25.0
			_mist_enabled = true
			_invincible_enabled = false
			_cd_reduction_on_elite = false
			_afterimage_enabled = false
		3:
			_dash_distance = 280.0
			_path_damage = 25.0
			_mist_enabled = true
			_invincible_enabled = true
			_cd_reduction_on_elite = true
			_afterimage_enabled = false
		4:
			_dash_distance = 320.0
			_path_damage = 30.0
			_mist_enabled = true
			_invincible_enabled = true
			_cd_reduction_on_elite = true
			_afterimage_enabled = true


# 公共接口：W212 时 SunWukong v2 的 _on_cast_skill(1) 调用此方法
func cast(player_node: Node) -> bool:
	if player_node == null or not player_node is Node2D:
		return false
	var player2d := player_node as Node2D
	# 获取 facing
	var facing: Vector2 = Vector2.RIGHT
	if "facing" in player_node:
		facing = player_node.facing
	# 起止位置（base + W213 bonus）
	var start_pos: Vector2 = player2d.global_position
	var end_pos: Vector2 = start_pos + facing * (_dash_distance + dash_distance_bonus)
	# 1. 瞬移玩家
	player2d.global_position = end_pos
	# 2. 路径敌人伤害（矩形检测：起点到终点，宽 path_width）
	_apply_path_damage(start_pos, end_pos, facing)
	# 3. Lv3 无敌（短暂）
	if _invincible_enabled and player_node.has_method("set_invincible"):
		player_node.set_invincible(true)
		get_tree().create_timer(0.3).timeout.connect(func():
			if is_instance_valid(player_node) and player_node.has_method("set_invincible"):
				player_node.set_invincible(false)
		)
	# 4. Lv4 残影（持续 1s）
	if _afterimage_enabled:
		_spawn_afterimage(start_pos, end_pos, facing)
	# 5. 视觉残留（金色线条）
	_spawn_visual(start_pos, end_pos)
	return true


func _apply_path_damage(start_pos: Vector2, end_pos: Vector2, dir: Vector2) -> void:
	var dist := start_pos.distance_to(end_pos)
	var half_width := path_width * 0.5
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			continue
		if not enemy is Node2D:
			continue
		var enemy_node := enemy as Node2D
		var to_enemy: Vector2 = enemy_node.global_position - start_pos
		var along: float = to_enemy.dot(dir)
		if along < 0.0 or along > dist:
			continue
		var perp: float = (to_enemy - dir * along).length()
		if perp > half_width:
			continue
		# 命中（base + W213 bonus）
		if enemy_node.has_method("take_damage"):
			enemy_node.take_damage(_path_damage + path_damage_bonus)


func _spawn_afterimage(start_pos: Vector2, end_pos: Vector2, dir: Vector2) -> void:
	# Lv4 残影：在路径生成持续 1s 的伤害区域，每 0.2s 对范围内敌人 +10
	var afterimage := Node2D.new()
	afterimage.name = "CloudStepAfterimage"
	var mid := (start_pos + end_pos) * 0.5
	afterimage.global_position = mid
	var scene := get_tree().current_scene
	if scene == null:
		afterimage.queue_free()
		return
	scene.add_child(afterimage)
	# 简化：5 次 tick，每次对路径附近敌人 +10
	var tick_count := 5
	var tick_interval := 0.2
	var afterimage_damage := 10.0
	var dist := start_pos.distance_to(end_pos)
	var half_width := path_width * 0.5
	for i in range(tick_count):
		var tick_tween := afterimage.create_tween()
		tick_tween.tween_interval(tick_interval * i)
		tick_tween.tween_callback(func():
			if not is_instance_valid(afterimage):
				return
			for enemy in get_tree().get_nodes_in_group("enemies"):
				if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
					continue
				if not enemy is Node2D:
					continue
				var e := enemy as Node2D
				var to_e: Vector2 = e.global_position - start_pos
				var along: float = to_e.dot(dir)
				if along < 0.0 or along > dist:
					continue
				var perp: float = (to_e - dir * along).length()
				if perp > half_width:
					continue
				if e.has_method("take_damage"):
					e.take_damage(afterimage_damage)
		)
	get_tree().create_timer(1.0).timeout.connect(afterimage.queue_free)


func _spawn_visual(start_pos: Vector2, end_pos: Vector2) -> void:
	# 简单金色线条 0.2s 后消失
	var line := Line2D.new()
	line.width = path_width
	line.default_color = Color(1.0, 0.85, 0.3, 0.6)
	line.points = PackedVector2Array([start_pos, end_pos])
	var scene := get_tree().current_scene
	if scene == null:
		return
	scene.add_child(line)
	var tween := line.create_tween()
	tween.tween_property(line, "modulate:a", 0.0, 0.2)
	tween.tween_callback(line.queue_free)
