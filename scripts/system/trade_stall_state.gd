class_name TradeStallState
extends RefCounted

## Pure state machine for a Ghost Market stall (ghost-market-trade.md
## revision-1, "States and Transitions"). No Area2D, no scene tree, no signals —
## just the transition rules + the warm-up / linger / hold-threshold timers, so
## every timing edge case (hold resets on movement, linger continues across a
## decline, boss force-expires) is unit-tested deterministically under CI.
##
## The live TradeStall (Area2D) node OWNS one of these and drives it: it polls
## player position to derive `moved`, calls tick_* each physics frame, and reacts
## to the returned/observed state. The thin shell + the tested core mirror the
## pattern used for the Ghost Market Judge boss.
##
## Timing knobs are injected (DI, not hardcoded) from TradeStallConfig; the
## defaults are the GDD defaults.

enum State { DORMANT, AVAILABLE, TRADING, SPENT, EXPIRED }

const DEFAULT_WARM_UP_SECONDS: float = 0.5
const DEFAULT_LINGER_SECONDS: float = 25.0
const DEFAULT_HOLD_SECONDS: float = 1.0

var state: State = State.DORMANT

var _warm_up_seconds: float
var _linger_seconds: float
var _hold_seconds: float

var _warm_up_remaining: float
var _linger_remaining: float
var _hold_progress: float = 0.0


func _init(p_linger_seconds: float = DEFAULT_LINGER_SECONDS,
		p_hold_seconds: float = DEFAULT_HOLD_SECONDS,
		p_warm_up_seconds: float = DEFAULT_WARM_UP_SECONDS) -> void:
	_linger_seconds = p_linger_seconds
	_hold_seconds = p_hold_seconds
	_warm_up_seconds = p_warm_up_seconds
	_warm_up_remaining = p_warm_up_seconds
	_linger_remaining = p_linger_seconds


# ─── DORMANT → AVAILABLE (warm-up) ───────────────────────────────────────

## Counts down the DORMANT warm-up; transitions to AVAILABLE when it elapses.
## Returns true on the frame the transition happens. No-op outside DORMANT.
func tick_warm_up(delta: float) -> bool:
	if state != State.DORMANT:
		return false
	_warm_up_remaining -= delta
	if _warm_up_remaining <= 0.0:
		state = State.AVAILABLE
		return true
	return false


# ─── AVAILABLE → EXPIRED (linger) ────────────────────────────────────────

## Counts down the AVAILABLE linger; transitions to EXPIRED when it elapses.
## Only ticks in AVAILABLE — while TRADING (tree paused) the linger is frozen,
## so it "continues" from where it was after a decline. Returns true on expiry.
func tick_linger(delta: float) -> bool:
	if state != State.AVAILABLE:
		return false
	_linger_remaining -= delta
	if _linger_remaining <= 0.0:
		state = State.EXPIRED
		return true
	return false


# ─── AVAILABLE → TRADING (hold threshold) ────────────────────────────────

## Accumulates the stationary-hold progress while the player stands inside the
## zone. `moved` (position delta ≥ threshold this frame) resets progress to 0.
## Transitions to TRADING and returns true once an uninterrupted hold reaches
## the threshold. No-op outside AVAILABLE.
func accumulate_hold(delta: float, moved: bool) -> bool:
	if state != State.AVAILABLE:
		return false
	if moved:
		_hold_progress = 0.0
		return false
	_hold_progress += delta
	if _hold_progress >= _hold_seconds:
		_hold_progress = 0.0
		state = State.TRADING
		return true
	return false


## Resets the hold fill to 0 (player left the zone — no saved progress on
## re-entry, per the anti-exploit rule). Safe to call anytime.
func reset_hold() -> void:
	_hold_progress = 0.0


# ─── forced / event transitions ──────────────────────────────────────────

## Boss spawned: any AVAILABLE stall is force-expired and no further trading is
## possible. No-op (returns false) if already terminal or mid-trade.
func on_boss_spawned() -> bool:
	if state == State.AVAILABLE or state == State.DORMANT:
		state = State.EXPIRED
		return true
	return false


## A trade offer was confirmed (TRADING → SPENT, terminal).
func on_trade_confirmed() -> void:
	if state != State.TRADING:
		push_error("TradeStallState.on_trade_confirmed called from state %d" % state)
		return
	state = State.SPENT


## The player declined (Leave button or fuse auto-close): TRADING → AVAILABLE.
## The linger is NOT reset (it continues); the hold fill IS reset.
func on_decline() -> void:
	if state != State.TRADING:
		push_error("TradeStallState.on_decline called from state %d" % state)
		return
	state = State.AVAILABLE
	_hold_progress = 0.0


## Step-A abort while the panel is open (player died / stage ended mid-trade):
## TRADING → EXPIRED, no side effects (the caller skips spend/buff/tide).
func on_trade_aborted() -> void:
	if state != State.TRADING:
		push_error("TradeStallState.on_trade_aborted called from state %d" % state)
		return
	state = State.EXPIRED


# ─── queries ─────────────────────────────────────────────────────────────

func is_terminal() -> bool:
	return state == State.SPENT or state == State.EXPIRED

func hold_progress_ratio() -> float:
	return clampf(_hold_progress / _hold_seconds, 0.0, 1.0) if _hold_seconds > 0.0 else 0.0

func linger_remaining() -> float:
	return _linger_remaining
