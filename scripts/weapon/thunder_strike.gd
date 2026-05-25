class_name ThunderStrike
extends Node2D

const DEFAULT_LIFETIME: float = 0.32
const MIN_LIFETIME: float = 0.05

var radius: float = 72.0
var lifetime: float = DEFAULT_LIFETIME

var _elapsed_time: float = 0.0

@onready var _ring: Line2D = $Ring
@onready var _inner_arc: Line2D = $InnerArc
@onready var _bolt_a: Line2D = $BoltA
@onready var _bolt_b: Line2D = $BoltB
@onready var _core: Polygon2D = $Core


func _ready() -> void:
	_apply_visual_shape()


func _process(delta: float) -> void:
	_elapsed_time += delta
	if _elapsed_time >= lifetime:
		queue_free()
		return

	var alpha := 1.0 - (_elapsed_time / lifetime)
	modulate = Color(1.0, 1.0, 1.0, alpha)
	scale = Vector2.ONE * lerpf(0.92, 1.08, _elapsed_time / lifetime)


func configure(new_radius: float, new_lifetime: float = DEFAULT_LIFETIME) -> void:
	radius = maxf(new_radius, 1.0)
	lifetime = maxf(new_lifetime, MIN_LIFETIME)
	_elapsed_time = 0.0

	if is_node_ready():
		_apply_visual_shape()


func _apply_visual_shape() -> void:
	_ring.points = _build_circle_points(radius, 28)
	_inner_arc.points = _build_arc_points(radius * 0.48, -0.35, 3.65, 12)
	_bolt_a.points = PackedVector2Array([
		Vector2(-radius * 0.18, -radius * 0.95),
		Vector2(radius * 0.05, -radius * 0.34),
		Vector2(-radius * 0.08, -radius * 0.34),
		Vector2(radius * 0.2, radius * 0.3),
	])
	_bolt_b.points = PackedVector2Array([
		Vector2(radius * 0.26, -radius * 0.72),
		Vector2(radius * 0.02, -radius * 0.12),
		Vector2(radius * 0.22, -radius * 0.16),
		Vector2(-radius * 0.18, radius * 0.58),
	])
	_core.polygon = PackedVector2Array([
		Vector2(0.0, -radius * 0.18),
		Vector2(radius * 0.16, 0.0),
		Vector2(0.0, radius * 0.18),
		Vector2(-radius * 0.16, 0.0),
	])


func _build_circle_points(circle_radius: float, segment_count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(segment_count + 1):
		var angle := float(index) / float(segment_count) * PI * 2.0
		points.append(Vector2(cos(angle), sin(angle)) * circle_radius)

	return points


func _build_arc_points(
	arc_radius: float,
	start_angle: float,
	end_angle: float,
	segment_count: int
) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(segment_count + 1):
		var progress := float(index) / float(segment_count)
		var angle := lerpf(start_angle, end_angle, progress)
		points.append(Vector2(cos(angle), sin(angle)) * arc_radius)

	return points
