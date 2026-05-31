class_name QiankunBounceProjectile
extends Area2D

## 环天圈弹射投射物（乾坤圈进化形态）。
##
## 直线飞向目标，命中后**改向次近的未命中敌人**继续飞，弹射至多 bounces 次。
## 单个敌人只命中一次（instance_id 去重）。找不到下一个目标 / 弹射用尽 / 超时即销毁。
## 仅调用 enemy 的公共 API（take_damage / 组），不碰冻结的 enemy.gd。

const MAX_LIFETIME: float = 4.0   # 找不到敌人时的兜底寿命，避免无限飞
const SPIN_SPEED: float = 14.0

var damage: float = 0.0
var speed: float = 0.0
var bounces_remaining: int = 4

var _direction: Vector2 = Vector2.RIGHT
var _hit_ids: Dictionary = {}
var _elapsed: float = 0.0
var _is_spent: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	set_physics_process(false)


func launch(first_target: Node2D, new_damage: float, new_speed: float, new_bounces: int) -> void:
	damage = maxf(new_damage, 0.0)
	speed = maxf(new_speed, 0.0)
	bounces_remaining = maxi(new_bounces, 1)
	_hit_ids.clear()
	_elapsed = 0.0
	_is_spent = false
	if first_target != null and is_instance_valid(first_target):
		_direction = global_position.direction_to(first_target.global_position)
	else:
		_direction = Vector2.RIGHT
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	if _is_spent:
		return
	rotation += SPIN_SPEED * delta
	global_position += _direction * speed * delta
	_elapsed += delta
	if _elapsed >= MAX_LIFETIME:
		_finish()


func _on_body_entered(body: Node2D) -> void:
	if _is_spent or is_queued_for_deletion():
		return
	if not body.is_in_group("enemies") or not body.has_method("take_damage"):
		return
	if _hit_ids.has(body.get_instance_id()):
		return
	_hit_and_redirect(body)


## 命中当前敌人 + 改向次近的未命中敌人（弹射）。直接驱动可测。
func _hit_and_redirect(body: Node2D) -> void:
	_hit_ids[body.get_instance_id()] = true
	body.call("take_damage", damage)
	bounces_remaining -= 1
	if bounces_remaining <= 0:
		_finish()
		return
	var next := _find_next_target()
	if next == null:
		_finish()
		return
	_direction = global_position.direction_to(next.global_position)


## 最近的、尚未命中过的敌人；无则返回 null。
func _find_next_target() -> Node2D:
	var nearest: Node2D = null
	var nearest_distance_squared := INF
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not enemy is Node2D:
			continue
		var enemy_node := enemy as Node2D
		if enemy_node.is_queued_for_deletion():
			continue
		if not enemy_node.has_method("take_damage"):
			continue
		if _hit_ids.has(enemy_node.get_instance_id()):
			continue
		var distance_squared := global_position.distance_squared_to(enemy_node.global_position)
		if distance_squared < nearest_distance_squared:
			nearest = enemy_node
			nearest_distance_squared = distance_squared
	return nearest


func _finish() -> void:
	if _is_spent:
		return
	_is_spent = true
	set_physics_process(false)
	queue_free()
