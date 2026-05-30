class_name TradeStall
extends Area2D

## Ghost Market merchant stall (鬼商摊). An Area2D that wraps the tested
## TradeStallState: it detects the player standing inside (body_entered, like
## DemonSeal) and polls position for the ~1s stationary hold; when the hold
## completes it emits trade_requested. StageDirector owns the rest (builds offers,
## shows the panel, applies the buff, spawns the tide) and drives this stall's
## terminal transitions (mark_spent / return_to_available / notify_boss_spawned).
##
## The state machine + timing rules are unit-tested in TradeStallState; this node
## is the thin live shell (zone + polling + visual).

signal trade_requested(stall: TradeStall)
signal stall_expired(stall: TradeStall)

## Stationary tolerance per frame (px) — movement above this resets the hold.
const HOLD_THRESHOLD_PX: float = 4.0
const FILL_WIDTH: float = 28.0

var _state: TradeStallState
var _player: Node2D = null
var _player_inside: bool = false
var _last_player_pos: Vector2 = Vector2.ZERO

@onready var _glow: Polygon2D = $Glow
@onready var _fill_bar: Node2D = $FillBar
@onready var _fill: Polygon2D = $FillBar/Fill


## Injects the timing knobs from TradeStallConfig before the node enters the tree.
func setup(linger_seconds: float, hold_seconds: float, warm_up_seconds: float) -> void:
	_state = TradeStallState.new(linger_seconds, hold_seconds, warm_up_seconds)


func _ready() -> void:
	if _state == null:
		_state = TradeStallState.new()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_set_available_look(false)
	if _fill_bar != null:
		_fill_bar.visible = false


func _physics_process(delta: float) -> void:
	match _state.state:
		TradeStallState.State.DORMANT:
			if _state.tick_warm_up(delta):
				_set_available_look(true)
		TradeStallState.State.AVAILABLE:
			if _state.tick_linger(delta):
				_expire()
				return
			_update_hold(delta)
		_:
			pass


# ─── StageDirector-driven terminal transitions ───────────────────────────

## A trade was confirmed: terminal SPENT, dissolve.
func mark_spent() -> void:
	_state.on_trade_confirmed()
	_dissolve()


## The player declined (Leave / fuse): back to AVAILABLE, linger continues.
func return_to_available() -> void:
	if _state.state == TradeStallState.State.TRADING:
		_state.on_decline()
		_fill_bar.visible = false


## Step-A abort (player died / stage ended mid-panel): terminal EXPIRED.
func abort_trade() -> void:
	if _state.state == TradeStallState.State.TRADING:
		_state.on_trade_aborted()
		_dissolve()


## Boss spawned: force-expire any AVAILABLE/DORMANT stall.
func notify_boss_spawned() -> void:
	if _state.on_boss_spawned():
		_expire()


# ─── hold-threshold polling ──────────────────────────────────────────────

func _update_hold(delta: float) -> void:
	if not _player_inside or not _can_trade():
		_state.reset_hold()
		_fill_bar.visible = false
		return

	var moved := (_player.global_position - _last_player_pos).length() >= HOLD_THRESHOLD_PX
	_last_player_pos = _player.global_position
	var opened := _state.accumulate_hold(delta, moved)
	_fill_bar.visible = true
	_update_fill(_state.hold_progress_ratio())
	if opened:
		_fill_bar.visible = false
		trade_requested.emit(self)


## Step-1 guards (ghost-market-trade.md): no trade while dead / already trading /
## choosing a level-up upgrade.
func _can_trade() -> bool:
	if _player == null or not is_instance_valid(_player):
		return false
	if bool(_player.get("_is_dead")):
		return false
	if _player.has_method("is_in_trade") and _player.is_in_trade():
		return false
	if bool(_player.get("_is_selecting_upgrade")):
		return false
	return true


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_player = body
	_player_inside = true
	_last_player_pos = body.global_position


func _on_body_exited(body: Node2D) -> void:
	if body != _player:
		return
	_player_inside = false
	_state.reset_hold()
	if _fill_bar != null:
		_fill_bar.visible = false


# ─── visual ──────────────────────────────────────────────────────────────

func _set_available_look(is_available: bool) -> void:
	if _glow != null:
		_glow.visible = is_available


func _update_fill(ratio: float) -> void:
	if _fill == null:
		return
	var w := FILL_WIDTH * clampf(ratio, 0.0, 1.0)
	var left := -FILL_WIDTH * 0.5
	_fill.polygon = PackedVector2Array([
		Vector2(left, -2.0), Vector2(left + w, -2.0),
		Vector2(left + w, 2.0), Vector2(left, 2.0),
	])


func _expire() -> void:
	stall_expired.emit(self)
	_dissolve()


func _dissolve() -> void:
	queue_free()
