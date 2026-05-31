class_name QiankunDiscProjectile
extends Area2D

## 乾坤圈投射物 — 自动锁定回旋两段（哪吒 W203）。
##
## 朝目标飞出 out_distance，然后回旋飞回 owner（玩家）。去程 / 回程各自对每个敌人
## 命中一次 → 同一敌人最多 2 段伤害。回到 owner 附近或 owner 失效则销毁。
## 伤害走单参 take_damage(amount)。

const RETURN_CATCH_DISTANCE: float = 18.0
const PHASE_OUT: int = 0
const PHASE_RETURN: int = 1

var damage: float = 0.0
var speed: float = 0.0
var out_distance: float = 200.0
var spin_speed: float = 12.0

var _direction: Vector2 = Vector2.RIGHT
var _owner_node: Node2D = null
var _phase: int = PHASE_OUT
var _start_position: Vector2 = Vector2.ZERO
var _hit_this_phase: Dictionary = {}
var _is_launched: bool = false
var _is_spent: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	if not _is_launched:
		return

	rotation += spin_speed * delta

	if _phase == PHASE_OUT:
		global_position += _direction * speed * delta
		if global_position.distance_to(_start_position) >= out_distance:
			_switch_to_return()
	else:
		if _owner_node == null or not is_instance_valid(_owner_node):
			_finish()
			return
		var to_owner := _owner_node.global_position - global_position
		if to_owner.length() <= RETURN_CATCH_DISTANCE:
			_finish()
			return
		global_position += to_owner.normalized() * speed * delta


func launch(
	new_direction: Vector2,
	new_damage: float,
	new_speed: float,
	new_out_distance: float,
	owner_node: Node2D
) -> void:
	if new_direction.length_squared() <= 0.0001:
		_direction = Vector2.RIGHT
	else:
		_direction = new_direction.normalized()

	damage = maxf(new_damage, 0.0)
	speed = maxf(new_speed, 0.0)
	out_distance = maxf(new_out_distance, 1.0)
	_owner_node = owner_node
	_phase = PHASE_OUT
	_start_position = global_position
	_hit_this_phase.clear()
	_is_launched = true
	_is_spent = false
	set_physics_process(true)


func _switch_to_return() -> void:
	_phase = PHASE_RETURN
	_hit_this_phase.clear()  # 回程可再次命中同一敌人（去/回各一次）


func _on_body_entered(body: Node2D) -> void:
	if _is_spent or is_queued_for_deletion():
		return
	if not body.is_in_group("enemies"):
		return
	if not body.has_method("take_damage"):
		return

	var instance_id := body.get_instance_id()
	if _hit_this_phase.has(instance_id):
		return

	_hit_this_phase[instance_id] = true
	body.call("take_damage", damage)


func _finish() -> void:
	if _is_spent:
		return

	_is_spent = true
	_is_launched = false
	set_physics_process(false)
	queue_free()
