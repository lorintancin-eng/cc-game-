class_name TalismanProjectile
extends Area2D

const MIN_DIRECTION_LENGTH: float = 0.001

var damage: float = 0.0
var speed: float = 0.0
var max_distance: float = 0.0
var lifetime: float = 0.0

## Five Phases element of the firing weapon (Story 005). Set by the weapon on spawn.
var element: String = "neutral"

var _direction: Vector2 = Vector2.RIGHT
var _elapsed_time: float = 0.0
var _start_position: Vector2 = Vector2.ZERO
var _has_hit: bool = false
var _is_launched: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	if not _is_launched:
		return

	global_position += _direction * speed * delta
	_elapsed_time += delta

	var distance_squared := global_position.distance_squared_to(_start_position)
	if _elapsed_time >= lifetime or distance_squared >= max_distance * max_distance:
		queue_free()


func launch(
	new_direction: Vector2,
	new_damage: float,
	new_speed: float,
	new_max_distance: float,
	new_lifetime: float
) -> void:
	if new_direction.length_squared() <= MIN_DIRECTION_LENGTH * MIN_DIRECTION_LENGTH:
		_direction = Vector2.RIGHT
	else:
		_direction = new_direction.normalized()

	damage = maxf(new_damage, 0.0)
	speed = maxf(new_speed, 0.0)
	max_distance = maxf(new_max_distance, 1.0)
	lifetime = maxf(new_lifetime, 0.05)
	_elapsed_time = 0.0
	_start_position = global_position
	_has_hit = false
	_is_launched = true
	rotation = _direction.angle()
	set_physics_process(true)


func _on_body_entered(body: Node2D) -> void:
	if _has_hit:
		return
	if not body.is_in_group("enemies"):
		return
	if not body.has_method("take_damage"):
		return

	_has_hit = true
	# Story 005: weapon-side 相克 matchup — multiply by ElementMatchup before delivery.
	var final_damage := damage * ElementMatchup.modifier(element, WeaponBase.element_of(body))
	body.call("take_damage", final_damage)
	queue_free()
