class_name HairCloneUnit
extends Node2D

## 毫毛分身个体（孙悟空 v2 主动技能 1 召唤物）
##
## 自动寻找最近敌人移动并攻击。
## 寿命到期消失（Lv4 时爆裂）。
##
## 详细：docs/SUN_WUKONG_V2_DESIGN.md §4

@export var damage: float = 8.0
@export var attack_interval: float = 1.5
@export var attack_range: float = 32.0
@export var lifetime: float = 6.0
@export var move_speed: float = 120.0

# Lv3 扇形扫击
@export var sweep_enabled: bool = false
@export var sweep_damage: float = 12.0
@export var sweep_radius: float = 60.0

# Lv4 消失爆裂
@export var burst_enabled: bool = false
@export var burst_damage: float = 30.0
@export var burst_radius: float = 80.0

var _alive_time: float = 0.0
var _attack_cooldown: float = 0.0
var _is_dying: bool = false


func _ready() -> void:
	# 视觉：灰白色小三角剪影
	var visual := Polygon2D.new()
	visual.polygon = PackedVector2Array([
		Vector2(-6, 6),
		Vector2(6, 6),
		Vector2(0, -8),
	])
	visual.color = Color(0.85, 0.85, 0.85, 0.9)
	add_child(visual)


func _process(delta: float) -> void:
	if _is_dying:
		return
	# 寿命推进
	_alive_time += delta
	if _alive_time >= lifetime:
		_die()
		return
	# 攻击 cooldown 推进
	if _attack_cooldown > 0.0:
		_attack_cooldown -= delta
	# 找最近敌人
	var target := _find_nearest_enemy()
	if target == null:
		return
	# 移动 or 攻击
	var dist := global_position.distance_to(target.global_position)
	if dist > attack_range:
		# 移动接近
		var dir: Vector2 = (target.global_position - global_position).normalized()
		global_position += dir * move_speed * delta
	else:
		# 范围内攻击
		if _attack_cooldown <= 0.0:
			_attack(target)
			_attack_cooldown = attack_interval


func _attack(target: Node2D) -> void:
	if not is_instance_valid(target):
		return
	if target.has_method("take_damage"):
		target.take_damage(damage)
	# Lv3 扇形扫击（半径 sweep_radius 范围内所有敌人额外受伤）
	if sweep_enabled:
		var sweep_sq := sweep_radius * sweep_radius
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
				continue
			if enemy == target:
				continue
			if not enemy is Node2D:
				continue
			var enemy_node := enemy as Node2D
			if global_position.distance_squared_to(enemy_node.global_position) > sweep_sq:
				continue
			if enemy_node.has_method("take_damage"):
				enemy_node.take_damage(sweep_damage)


func _find_nearest_enemy() -> Node2D:
	var nearest: Node2D = null
	var nearest_dist_sq: float = INF
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			continue
		if not enemy is Node2D:
			continue
		var enemy_node := enemy as Node2D
		var dist_sq: float = global_position.distance_squared_to(enemy_node.global_position)
		if dist_sq < nearest_dist_sq:
			nearest_dist_sq = dist_sq
			nearest = enemy_node
	return nearest


func _die() -> void:
	if _is_dying:
		return
	_is_dying = true
	# Lv4 消失爆裂
	if burst_enabled:
		_do_burst()
	# 视觉淡出 + queue_free
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_callback(queue_free)


func _do_burst() -> void:
	var burst_sq := burst_radius * burst_radius
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			continue
		if not enemy is Node2D:
			continue
		var enemy_node := enemy as Node2D
		if global_position.distance_squared_to(enemy_node.global_position) > burst_sq:
			continue
		if enemy_node.has_method("take_damage"):
			enemy_node.take_damage(burst_damage)
