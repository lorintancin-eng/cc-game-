class_name CelestialSilkZone
extends Node2D

## 混天绫·束缚领域（哪吒 W202）。
##
## 在指定位置展开一片红绫领域，持续 lifetime 秒：
##   - 普通 / 精英敌人：每帧 velocity 归零（**束缚**，复用定身术成熟模式）
##   - Boss：每帧 velocity ×BOSS_SLOW_FACTOR（**减速**但不冻结，避免 trivial 化）
##   - 每 tick_interval 对领域内敌人造成 dot_per_tick **持续伤害**（take_damage）
## 到期自动消失。
##
## 仅调用 enemy 的公共 API（velocity 字段 / take_damage），不修改冻结的 enemy.gd。
## 距离判定用 group 迭代 + 距离平方（同八卦阵），不依赖物理 Area 重叠。

const BOSS_SLOW_FACTOR: float = 0.5

var radius: float = 90.0
var dot_per_tick: float = 4.0
var tick_interval: float = 0.5
var lifetime: float = 3.0

var _elapsed: float = 0.0
var _tick_remaining: float = 0.0


func _ready() -> void:
	if _tick_remaining <= 0.0:
		_tick_remaining = tick_interval


## 由武器调用：放置位置、半径、每 tick 伤害、tick 间隔、持续时间。
func setup(pos: Vector2, r: float, dot: float, tick: float, life: float) -> void:
	global_position = pos
	radius = maxf(r, 1.0)
	dot_per_tick = maxf(dot, 0.0)
	tick_interval = maxf(tick, 0.05)
	lifetime = maxf(life, 0.1)
	_tick_remaining = tick_interval
	scale = Vector2(radius, radius)  # Silk 为单位圆，按半径缩放视觉（不影响逻辑距离判定）


func _physics_process(delta: float) -> void:
	_elapsed += delta
	_apply_movement_control()

	_tick_remaining -= delta
	if _tick_remaining <= 0.0:
		_tick_remaining = tick_interval
		_apply_dot()

	if _elapsed >= lifetime:
		queue_free()


func _enemies_in_radius() -> Array:
	var result: Array = []
	var radius_squared := radius * radius
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not enemy is Node2D:
			continue
		var enemy_node := enemy as Node2D
		if enemy_node.is_queued_for_deletion():
			continue
		if global_position.distance_squared_to(enemy_node.global_position) > radius_squared:
			continue
		result.append(enemy_node)
	return result


## 普通/精英敌束缚（velocity 归零）；Boss 减速（velocity ×0.5）。每帧调用。
func _apply_movement_control() -> void:
	for enemy in _enemies_in_radius():
		if not "velocity" in enemy:
			continue
		if enemy.is_in_group("bosses"):
			enemy.set("velocity", (enemy.get("velocity") as Vector2) * BOSS_SLOW_FACTOR)
		else:
			enemy.set("velocity", Vector2.ZERO)


## 领域内敌人持续伤害。每 tick_interval 调用一次。
func _apply_dot() -> void:
	for enemy in _enemies_in_radius():
		if enemy.has_method("take_damage"):
			enemy.call("take_damage", dot_per_tick)
