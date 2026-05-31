class_name ExperienceOrb
extends Area2D

const MIN_LIFETIME_SECONDS: float = 0.1
const MIN_PICKUP_RADIUS: float = 1.0

@export var xp_value: float = 5.0
@export var lifetime_seconds: float = 30.0
@export var pickup_radius: float = 34.0

var _is_collected: bool = false
var _elapsed_lifetime: float = 0.0


func _ready() -> void:
	add_to_group(&"experience_orbs")  # 供聚灵符(磁铁道具)查找全屏经验球
	lifetime_seconds = maxf(lifetime_seconds, MIN_LIFETIME_SECONDS)
	pickup_radius = maxf(pickup_radius, MIN_PICKUP_RADIUS)
	body_entered.connect(_on_body_entered)
	call_deferred("_try_collect_overlapping_bodies")


func _process(delta: float) -> void:
	if _is_collected:
		return

	_elapsed_lifetime += delta
	if _elapsed_lifetime >= lifetime_seconds:
		queue_free()
		return

	_try_collect_players_in_radius()


func _try_collect_overlapping_bodies() -> void:
	for body in get_overlapping_bodies():
		if body is Node2D:
			_try_collect(body as Node2D, false)


func _on_body_entered(body: Node2D) -> void:
	_try_collect(body, false)


func _try_collect_players_in_radius() -> void:
	for body in get_tree().get_nodes_in_group("player"):
		if body is Node2D:
			_try_collect(body as Node2D, true)


func _try_collect(body: Node2D, require_radius_check: bool) -> void:
	if _is_collected:
		return
	if not body.is_in_group("player"):
		return
	if not body.has_method("gain_experience"):
		return
	if require_radius_check and global_position.distance_squared_to(body.global_position) > _get_pickup_radius_squared(body):
		return

	_is_collected = true
	body.call("gain_experience", xp_value)
	queue_free()


func _get_pickup_radius_squared(body: Node2D) -> float:
	var radius := pickup_radius
	if body.has_method("get_pickup_radius_bonus"):
		radius += maxf(float(body.call("get_pickup_radius_bonus")), 0.0)

	radius = maxf(radius, MIN_PICKUP_RADIUS)
	return radius * radius
