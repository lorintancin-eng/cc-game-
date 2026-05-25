class_name DemonSeal
extends Area2D

signal seal_progress_changed(progress_seconds: float, required_seconds: float, is_sealing: bool)
signal seal_completed(demon_seal: Area2D)

const MIN_REQUIRED_SECONDS: float = 0.1

@export var required_seconds: float = 8.0

var progress_seconds: float = 0.0

var _is_completed: bool = false
var _players_in_range: int = 0

@onready var _progress_ring: Line2D = $ProgressRing


func _ready() -> void:
	required_seconds = maxf(required_seconds, MIN_REQUIRED_SECONDS)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_update_progress_ring()
	seal_progress_changed.emit(progress_seconds, required_seconds, false)


func _process(delta: float) -> void:
	if _is_completed or _players_in_range <= 0:
		return

	progress_seconds = minf(progress_seconds + delta, required_seconds)
	_update_progress_ring()
	seal_progress_changed.emit(progress_seconds, required_seconds, true)

	if progress_seconds >= required_seconds:
		_complete_seal()


func is_sealing() -> bool:
	return not _is_completed and _players_in_range > 0


func is_completed() -> bool:
	return _is_completed


func _complete_seal() -> void:
	if _is_completed:
		return

	_is_completed = true
	_players_in_range = 0
	seal_progress_changed.emit(progress_seconds, required_seconds, false)
	seal_completed.emit(self)


func _on_body_entered(body: Node2D) -> void:
	if _is_completed or not body.is_in_group("player"):
		return

	_players_in_range += 1
	seal_progress_changed.emit(progress_seconds, required_seconds, true)


func _on_body_exited(body: Node2D) -> void:
	if _is_completed or not body.is_in_group("player"):
		return

	_players_in_range = maxi(_players_in_range - 1, 0)
	seal_progress_changed.emit(progress_seconds, required_seconds, is_sealing())


func _update_progress_ring() -> void:
	if _progress_ring == null:
		return

	var ratio := clampf(progress_seconds / required_seconds, 0.0, 1.0)
	var point_count := maxi(2, int(48.0 * ratio))
	var points := PackedVector2Array()
	for index in point_count + 1:
		var angle := -PI * 0.5 + TAU * ratio * float(index) / float(point_count)
		points.append(Vector2.RIGHT.rotated(angle) * 44.0)

	_progress_ring.points = points
