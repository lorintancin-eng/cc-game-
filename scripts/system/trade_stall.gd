class_name TradeStall
extends Area2D

## Ghost Market merchant stall (鬼商摊). An Area2D that wraps the tested
## TradeStallState: it detects the player standing inside (overlap polling, like
## DemonSeal) and accumulates a ~1s in-zone hold; when it completes it emits
## trade_requested. StageDirector owns the rest (offers, panel, buff, tide) and
## drives this stall's terminal transitions.
##
## Presence-based hold (NOT "stand perfectly still"): the player + enemies share a
## collision layer and physically push each other, so a swarm makes strict
## stillness unachievable — staying in the zone for 1s is the robust, DemonSeal-
## proven rule. Leaving the zone resets the hold.

signal trade_requested(stall: TradeStall)
signal stall_expired(stall: TradeStall)

const FILL_WIDTH: float = 28.0

var _state: TradeStallState

@onready var _glow: Polygon2D = $Glow
@onready var _fill_bar: Node2D = $FillBar
@onready var _fill: Polygon2D = $FillBar/Fill


## Injects the timing knobs from TradeStallConfig before the node enters the tree.
func setup(linger_seconds: float, hold_seconds: float, warm_up_seconds: float) -> void:
	_state = TradeStallState.new(linger_seconds, hold_seconds, warm_up_seconds)


func _ready() -> void:
	if _state == null:
		_state = TradeStallState.new()
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

func mark_spent() -> void:
	_state.on_trade_confirmed()
	_dissolve()


func return_to_available() -> void:
	if _state.state == TradeStallState.State.TRADING:
		_state.on_decline()
		if _fill_bar != null:
			_fill_bar.visible = false


func abort_trade() -> void:
	if _state.state == TradeStallState.State.TRADING:
		_state.on_trade_aborted()
		_dissolve()


func notify_boss_spawned() -> void:
	if _state.on_boss_spawned():
		_expire()


# ─── in-zone hold (presence-based) ───────────────────────────────────────

func _update_hold(delta: float) -> void:
	var player := _player_in_zone()
	if player == null or not _can_trade(player):
		_state.reset_hold()
		if _fill_bar != null:
			_fill_bar.visible = false
		return

	# moved=false: presence-based (swarm-push-proof). The state machine still
	# resets the fill if the player leaves the zone (player becomes null above).
	var opened := _state.accumulate_hold(delta, false)
	if _fill_bar != null:
		_fill_bar.visible = true
	_update_fill(_state.hold_progress_ratio())
	if opened:
		if _fill_bar != null:
			_fill_bar.visible = false
		print("[TradeStall] hold complete → opening trade panel")
		trade_requested.emit(self)


## Robust presence check: polls overlapping bodies for a player-group node (no
## reliance on body_entered timing). Returns the player Node2D or null.
func _player_in_zone() -> Node2D:
	for body in get_overlapping_bodies():
		if body.is_in_group(&"player"):
			return body as Node2D
	return null


## Step-1 guards (ghost-market-trade.md): no trade while dead / already trading /
## choosing a level-up upgrade.
func _can_trade(player: Node2D) -> bool:
	if bool(player.get("_is_dead")):
		return false
	if player.has_method("is_in_trade") and player.is_in_trade():
		return false
	if bool(player.get("_is_selecting_upgrade")):
		return false
	return true


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
