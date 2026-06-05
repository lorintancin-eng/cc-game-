class_name BaguaArrayWeapon
extends WeaponBase

const MIN_RADIUS: float = 1.0
const MIN_TICK_RATE: float = 0.05
const MIN_ROTATION_SPEED: float = 0.0

@export var radius: float = 82.0
@export var tick_rate: float = 0.65
@export var rotation_speed: float = 2.4

var _tick_remaining: float = 0.0
var _visual_root: Node2D
var _outer_ring: Line2D
var _inner_ring: Line2D
var _spokes: Line2D
var _applied_visual_radius: float = -1.0


func _ready() -> void:
	_ensure_visual_nodes()
	_apply_visual_shape()


func _process(delta: float) -> void:
	_update_visual(delta)

	_tick_remaining = maxf(_tick_remaining - delta, 0.0)
	if _tick_remaining > 0.0:
		return

	_apply_radius_damage()
	_tick_remaining = _get_tick_rate()


func _update_visual(delta: float) -> void:
	if _visual_root == null:
		return

	_visual_root.rotation += _get_rotation_speed() * delta
	if not is_equal_approx(_get_radius(), _applied_visual_radius):
		_apply_visual_shape()


func _apply_radius_damage() -> void:
	var attack_radius := _get_radius()
	var attack_radius_squared := attack_radius * attack_radius
	var attack_damage := _get_damage()

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not enemy is Node2D:
			continue
		if not enemy.has_method("take_damage"):
			continue

		var enemy_node := enemy as Node2D
		if enemy_node.is_queued_for_deletion():
			continue
		if global_position.distance_squared_to(enemy_node.global_position) > attack_radius_squared:
			continue

		# Story 005: weapon-side 相克 matchup multiplier per ticked enemy.
		var final_damage := attack_damage * ElementMatchup.modifier(element, WeaponBase.element_of(enemy_node))
		enemy_node.call("take_damage", final_damage)


func _get_radius() -> float:
	return maxf(radius, MIN_RADIUS)


func _get_tick_rate() -> float:
	return maxf(tick_rate, MIN_TICK_RATE)


func _get_rotation_speed() -> float:
	return maxf(rotation_speed, MIN_ROTATION_SPEED)


func _ensure_visual_nodes() -> void:
	if _visual_root != null:
		return

	_visual_root = Node2D.new()
	_visual_root.name = "ArrayVisual"
	add_child(_visual_root)

	_outer_ring = _create_line("OuterRing", 2.2, Color(0.9, 0.68, 0.28, 0.72), true)
	_inner_ring = _create_line("InnerRing", 1.5, Color(0.3, 0.92, 0.74, 0.62), true)
	_spokes = _create_line("Spokes", 1.4, Color(0.92, 0.88, 0.62, 0.74), false)


func _create_line(line_name: String, line_width: float, color: Color, is_closed: bool) -> Line2D:
	var line := Line2D.new()
	line.name = line_name
	line.width = line_width
	line.default_color = color
	line.closed = is_closed
	_visual_root.add_child(line)
	return line


func _apply_visual_shape() -> void:
	if _outer_ring == null or _inner_ring == null or _spokes == null:
		return

	var array_radius := _get_radius()
	_outer_ring.points = _build_circle_points(array_radius, 48)
	_inner_ring.points = _build_circle_points(array_radius * 0.58, 32)

	var spoke_points := PackedVector2Array()
	for index in range(8):
		var angle := float(index) / 8.0 * TAU
		var direction := Vector2(cos(angle), sin(angle))
		spoke_points.append(direction * array_radius * 0.34)
		spoke_points.append(direction * array_radius)
		spoke_points.append(Vector2.ZERO)

	_spokes.points = spoke_points
	_applied_visual_radius = array_radius


func _build_circle_points(circle_radius: float, segment_count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(segment_count + 1):
		var angle := float(index) / float(segment_count) * TAU
		points.append(Vector2(cos(angle), sin(angle)) * circle_radius)

	return points
