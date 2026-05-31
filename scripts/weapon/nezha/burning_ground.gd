class_name BurningGround
extends Node2D

## 火尖枪·灼烧地面（哪吒 W201 附带）。
##
## 火尖枪投射物到期 / 穿透耗尽时在其位置留下一小片灼烧区，持续 lifetime 秒，
## 每 tick_interval 对范围内敌人 take_damage(dot_per_tick)。仅 DoT，无束缚 / 减速。
## 距离判定用 group 迭代 + 距离平方；仅调用 enemy 公共 API（take_damage）。

var radius: float = 40.0
var dot_per_tick: float = 2.0
var tick_interval: float = 0.4
var lifetime: float = 1.5

var _elapsed: float = 0.0
var _tick_remaining: float = 0.0


func _ready() -> void:
	if _tick_remaining <= 0.0:
		_tick_remaining = tick_interval


func setup(pos: Vector2, r: float, dot: float, tick: float, life: float) -> void:
	global_position = pos
	radius = maxf(r, 1.0)
	dot_per_tick = maxf(dot, 0.0)
	tick_interval = maxf(tick, 0.05)
	lifetime = maxf(life, 0.1)
	_tick_remaining = tick_interval
	scale = Vector2(radius, radius)  # 单位圆视觉按半径缩放（不影响逻辑判定）


func _physics_process(delta: float) -> void:
	_elapsed += delta
	_tick_remaining -= delta
	if _tick_remaining <= 0.0:
		_tick_remaining = tick_interval
		_apply_dot()
	if _elapsed >= lifetime:
		queue_free()


func _apply_dot() -> void:
	var radius_squared := radius * radius
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not enemy is Node2D:
			continue
		var enemy_node := enemy as Node2D
		if enemy_node.is_queued_for_deletion():
			continue
		if global_position.distance_squared_to(enemy_node.global_position) > radius_squared:
			continue
		if enemy_node.has_method("take_damage"):
			enemy_node.call("take_damage", dot_per_tick)
