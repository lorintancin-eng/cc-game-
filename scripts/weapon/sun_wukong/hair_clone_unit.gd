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

## Reference to the Player node that spawned this clone. Set by HairCloneV2.cast().
## Used to look up the Sun Wukong character_base for 火眼金睛 damage modifier.
## If null (or owner is not Sun Wukong), damage modifier defaults to 1.0.
var player_owner: Node = null

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
		# 火眼金睛：对 Boss/Elite +20% (~+55% with stacks). Default 1.0 otherwise.
		target.take_damage(damage * _get_fire_eyes_modifier(target))
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
				enemy_node.take_damage(sweep_damage * _get_fire_eyes_modifier(enemy_node))


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
			enemy_node.take_damage(burst_damage * _get_fire_eyes_modifier(enemy_node))


## 查询火眼金睛伤害修正 (W206) — 同 JinguBangV2._get_fire_eyes_modifier 模式。
## 当 player_owner 是 SunWukong v2 时返回 1.2~1.55；其他情况返回 1.0。
func _get_fire_eyes_modifier(target: Node) -> float:
	if player_owner == null:
		return 1.0
	if not "_character_base" in player_owner:
		return 1.0
	var cb = player_owner._character_base
	if cb == null:
		return 1.0
	if not cb.has_method("get_damage_modifier"):
		return 1.0
	return cb.get_damage_modifier(target)
