class_name MountainSealImpact
extends Node2D

const DEFAULT_LIFETIME: float = 0.42
const MIN_LIFETIME: float = 0.05

var radius: float = 118.0
var lifetime: float = DEFAULT_LIFETIME

var _elapsed_time: float = 0.0

@onready var _outer_ring: Line2D = $OuterRing
@onready var _inner_ring: Line2D = $InnerRing
@onready var _seal: Polygon2D = $Seal


func _ready() -> void:
	_apply_visual_shape()


func _process(delta: float) -> void:
	_elapsed_time += delta
	if _elapsed_time >= lifetime:
		queue_free()
		return

	var progress := _elapsed_time / lifetime
	modulate = Color(1.0, 1.0, 1.0, 1.0 - progress)
	scale = Vector2.ONE * lerpf(0.72, 1.08, progress)


func configure(new_radius: float, new_lifetime: float = DEFAULT_LIFETIME) -> void:
	radius = maxf(new_radius, 1.0)
	lifetime = maxf(new_lifetime, MIN_LIFETIME)
	_elapsed_time = 0.0

	if is_node_ready():
		_apply_visual_shape()


func _apply_visual_shape() -> void:
	_outer_ring.points = _build_circle_points(radius, 36)
	_inner_ring.points = _build_circle_points(radius * 0.62, 28)
	_seal.polygon = PackedVector2Array([
		Vector2(0.0, -radius * 0.28),
		Vector2(radius * 0.26, -radius * 0.12),
		Vector2(radius * 0.2, radius * 0.22),
		Vector2(0.0, radius * 0.32),
		Vector2(-radius * 0.2, radius * 0.22),
		Vector2(-radius * 0.26, -radius * 0.12),
	])


func _build_circle_points(circle_radius: float, segment_count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(segment_count + 1):
		var angle := float(index) / float(segment_count) * TAU
		points.append(Vector2(cos(angle), sin(angle)) * circle_radius)

	return points
