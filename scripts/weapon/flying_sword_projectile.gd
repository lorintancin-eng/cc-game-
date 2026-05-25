class_name FlyingSwordProjectile
extends Area2D

const MIN_DIRECTION_LENGTH: float = 0.001
const MIN_LIFETIME: float = 0.05

var damage: float = 0.0
var speed: float = 0.0
var lifetime: float = 0.0
var pierce_count: int = 1

var _direction: Vector2 = Vector2.RIGHT
var _elapsed_time: float = 0.0
var _hit_count: int = 0
var _hit_instance_ids: Dictionary = {}
var _is_spent: bool = false
var _is_launched: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	if not _is_launched:
		return

	global_position += _direction * speed * delta
	_elapsed_time += delta

	if _elapsed_time >= lifetime:
		_finish()


func launch(
	new_direction: Vector2,
	new_damage: float,
	new_speed: float,
	new_lifetime: float,
	new_pierce_count: int
) -> void:
	if new_direction.length_squared() <= MIN_DIRECTION_LENGTH * MIN_DIRECTION_LENGTH:
		_direction = Vector2.RIGHT
	else:
		_direction = new_direction.normalized()

	damage = maxf(new_damage, 0.0)
	speed = maxf(new_speed, 0.0)
	lifetime = maxf(new_lifetime, MIN_LIFETIME)
	pierce_count = maxi(new_pierce_count, 1)
	_elapsed_time = 0.0
	_hit_count = 0
	_hit_instance_ids.clear()
	_is_spent = false
	_is_launched = true
	rotation = _direction.angle()
	set_physics_process(true)


func _on_body_entered(body: Node2D) -> void:
	if _is_spent or is_queued_for_deletion() or _hit_count >= pierce_count:
		return
	if not body.is_in_group("enemies"):
		return
	if not body.has_method("take_damage"):
		return

	var instance_id := body.get_instance_id()
	if _hit_instance_ids.has(instance_id):
		return

	_hit_instance_ids[instance_id] = true
	_hit_count += 1
	body.call("take_damage", damage)

	if _hit_count >= pierce_count:
		_finish()


func _finish() -> void:
	if _is_spent:
		return

	_is_spent = true
	_is_launched = false
	set_physics_process(false)
	queue_free()
