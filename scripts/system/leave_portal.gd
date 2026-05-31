class_name LeavePortal
extends Area2D

## A walk-in EXIT for the Ghost Market interlude (no time limit). The player stands
## in it briefly to advance to the next combat stage, so they can linger + trade for
## as long as they like and leave when ready. Spawned + wired by StageDirector for
## interludes only. Presence-based (overlap polling), like TradeStall/DemonSeal.

signal leave_requested(portal: LeavePortal)

const HOLD_SECONDS: float = 0.6
const FILL_WIDTH: float = 36.0

var _hold: float = 0.0
var _done: bool = false

@onready var _fill_bar: Node2D = $FillBar
@onready var _fill: Polygon2D = $FillBar/Fill


func _ready() -> void:
	if _fill_bar != null:
		_fill_bar.visible = false


func _physics_process(delta: float) -> void:
	if _done:
		return
	var player := _player_in_zone()
	# Don't trigger while a trade panel is open (the player is mid-deal, not leaving).
	if player == null or (player.has_method("is_in_trade") and player.is_in_trade()):
		_hold = 0.0
		if _fill_bar != null:
			_fill_bar.visible = false
		return

	_hold += delta
	if _fill_bar != null:
		_fill_bar.visible = true
	_update_fill(_hold / HOLD_SECONDS)
	if _hold >= HOLD_SECONDS:
		_done = true
		if _fill_bar != null:
			_fill_bar.visible = false
		leave_requested.emit(self)


func _player_in_zone() -> Node2D:
	for body in get_overlapping_bodies():
		if body.is_in_group(&"player"):
			return body as Node2D
	return null


func _update_fill(ratio: float) -> void:
	if _fill == null:
		return
	var w := FILL_WIDTH * clampf(ratio, 0.0, 1.0)
	var left := -FILL_WIDTH * 0.5
	_fill.polygon = PackedVector2Array([
		Vector2(left, -3.0), Vector2(left + w, -3.0),
		Vector2(left + w, 3.0), Vector2(left, 3.0),
	])
