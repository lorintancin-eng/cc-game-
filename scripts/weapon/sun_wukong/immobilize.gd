class_name Immobilize
extends Node2D

## 定身术（孙悟空 v2 主动技能 4，按键 4）
##
## 范围内敌人短暂定身。
## 4 级成长见 docs/SUN_WUKONG_V2_DESIGN.md §7
##
## v0.4 MVP 简化：
## - 定身实现为周期性强制 velocity = Vector2.ZERO
## - Boss 简化为也完全定身（v0.4.x 加 stun_until 字段后再做"定妖印"差异化）
## - 精英减半 / 高速打断冲刺 等差异化效果 TODO

@export var level: int = 1: set = _apply_level

# 等级派生
var _radius: float = 150.0
var _duration: float = 1.0
var _vuln_bonus: float = 0.0  # Lv3+ 被定身敌人额外伤害倍率（待 enemy buff 系统）
var _burst_enabled: bool = false  # Lv3+ 结束爆裂
var _burst_damage: float = 35.0
var _burst_radius: float = 100.0
var _can_break_elite: bool = false  # Lv4

# W213 升级 bonus
var radius_bonus: float = 0.0
var duration_bonus: float = 0.0
var burst_damage_bonus: float = 0.0

var _active_immobilizations: Array = []  # [{enemy, end_time}, ...]


func _ready() -> void:
	_apply_level(level)


func _apply_level(lv: int) -> void:
	level = clampi(lv, 1, 4)
	match level:
		1:
			_radius = 150.0
			_duration = 1.0
			_vuln_bonus = 0.0
			_burst_enabled = false
			_can_break_elite = false
		2:
			_radius = 200.0
			_duration = 1.3
			_vuln_bonus = 0.0
			_burst_enabled = false
			_can_break_elite = false
		3:
			_radius = 200.0
			_duration = 1.3
			_vuln_bonus = 0.3
			_burst_enabled = true
			_burst_radius = 100.0
			_burst_damage = 35.0
			_can_break_elite = false
		4:
			_radius = 280.0
			_duration = 1.8
			_vuln_bonus = 0.3
			_burst_enabled = true
			_burst_radius = 100.0
			_burst_damage = 35.0
			_can_break_elite = true


# 每帧维护已定身敌人列表（持续期间锁定 velocity）
func _physics_process(_delta: float) -> void:
	if _active_immobilizations.is_empty():
		return
	var now := Time.get_ticks_msec() / 1000.0
	var to_remove: Array = []
	for entry in _active_immobilizations:
		var enemy = entry["enemy"]
		var end_time: float = entry["end_time"]
		if not is_instance_valid(enemy):
			to_remove.append(entry)
			continue
		if now >= end_time:
			to_remove.append(entry)
			continue
		# 强制 velocity 归零（每帧）
		if "velocity" in enemy:
			enemy.set("velocity", Vector2.ZERO)
	for e in to_remove:
		_active_immobilizations.erase(e)


# 公共接口：W212 SunWukong v2 的 _on_cast_skill(3) 调用
func cast(player_node: Node) -> bool:
	if player_node == null or not player_node is Node2D:
		return false
	var center: Vector2 = (player_node as Node2D).global_position
	var radius_sq := (_radius + radius_bonus) * (_radius + radius_bonus)
	var end_time := Time.get_ticks_msec() / 1000.0 + (_duration + duration_bonus)
	# 收集范围内敌人
	var caught: Array = []
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			continue
		if not enemy is Node2D:
			continue
		var enemy_node := enemy as Node2D
		if center.distance_squared_to(enemy_node.global_position) > radius_sq:
			continue
		# Lv4 才能打断精英（其他等级跳过精英）
		var is_elite: bool = enemy.get("is_elite") if "is_elite" in enemy else false
		if is_elite and not _can_break_elite:
			# Lv1-3 对精英定身时间减半（含 bonus）
			_active_immobilizations.append({
				"enemy": enemy_node,
				"end_time": Time.get_ticks_msec() / 1000.0 + (_duration + duration_bonus) * 0.5,
			})
			caught.append(enemy_node)
			continue
		_active_immobilizations.append({
			"enemy": enemy_node,
			"end_time": end_time,
		})
		caught.append(enemy_node)
	# Lv3+ 结束爆裂（在定身 duration 结束后触发；含 W213 duration_bonus）
	if _burst_enabled and not caught.is_empty():
		get_tree().create_timer(_duration + duration_bonus).timeout.connect(_do_burst.bind(caught))
	return true


func _do_burst(caught_enemies: Array) -> void:
	# 对原定身位置或当前位置的敌人造成爆裂伤害
	var burst_sq := _burst_radius * _burst_radius
	for enemy in caught_enemies:
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			continue
		if not enemy is Node2D:
			continue
		var enemy_node := enemy as Node2D
		# 对当前敌人位置周围的所有敌人造成爆裂伤害
		for nearby in get_tree().get_nodes_in_group("enemies"):
			if not is_instance_valid(nearby) or nearby.is_queued_for_deletion():
				continue
			if not nearby is Node2D:
				continue
			var nearby_node := nearby as Node2D
			if enemy_node.global_position.distance_squared_to(nearby_node.global_position) > burst_sq:
				continue
			if nearby_node.has_method("take_damage"):
				nearby_node.take_damage(_burst_damage + burst_damage_bonus)
		# 只对第一个敌人触发一次爆裂（避免多个敌人重复爆）
		break
