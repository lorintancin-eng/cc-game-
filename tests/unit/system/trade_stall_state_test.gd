## Unit tests for TradeStallState — the Ghost Market stall state machine
## (ghost-market-trade.md revision-1, "States and Transitions"). Drives the
## timers with explicit deltas so every transition + edge case is deterministic.
## Pure RefCounted → no scene tree.
##
## Run via:
##   godot --headless --path . -s res://addons/gut/gut_cmdln.gd \
##         -gdir=res://tests/unit/system -gexit

extends "res://tests/helpers/test_base.gd"


## Builds a stall already warmed-up to AVAILABLE (warm-up 0.5s elapsed).
func _available_stall(linger: float = 25.0, hold: float = 1.0) -> TradeStallState:
	var s := TradeStallState.new(linger, hold, 0.5)
	s.tick_warm_up(1.0)
	return s


# ─── warm-up: DORMANT → AVAILABLE ────────────────────────────────────────

func test_stall_starts_dormant() -> void:
	var s := TradeStallState.new()
	assert_eq(s.state, TradeStallState.State.DORMANT, "stalls spawn DORMANT")


func test_warm_up_transitions_to_available() -> void:
	var s := TradeStallState.new(25.0, 1.0, 0.5)
	assert_false(s.tick_warm_up(0.3), "0.3 < 0.5 warm-up → still DORMANT")
	assert_eq(s.state, TradeStallState.State.DORMANT)
	assert_true(s.tick_warm_up(0.3), "0.6 ≥ 0.5 → AVAILABLE (fires once)")
	assert_eq(s.state, TradeStallState.State.AVAILABLE)


func test_warm_up_is_noop_once_available() -> void:
	var s := _available_stall()
	assert_false(s.tick_warm_up(5.0), "tick_warm_up does nothing in AVAILABLE")
	assert_eq(s.state, TradeStallState.State.AVAILABLE)


# ─── linger: AVAILABLE → EXPIRED ─────────────────────────────────────────

func test_linger_expires_after_duration() -> void:
	var s := _available_stall(25.0)
	for _i in 24:
		assert_false(s.tick_linger(1.0), "still lingering")
	assert_true(s.tick_linger(1.0), "25th second → EXPIRED")
	assert_eq(s.state, TradeStallState.State.EXPIRED)


func test_linger_does_not_tick_while_dormant() -> void:
	var s := TradeStallState.new(25.0, 1.0, 0.5)  # still DORMANT
	assert_false(s.tick_linger(100.0), "linger frozen in DORMANT")
	assert_eq(s.state, TradeStallState.State.DORMANT)


# ─── hold threshold: AVAILABLE → TRADING ─────────────────────────────────

func test_hold_fires_trading_at_threshold() -> void:
	var s := _available_stall(25.0, 1.0)
	assert_false(s.accumulate_hold(0.5, false), "0.5 < 1.0 → not yet")
	assert_true(s.accumulate_hold(0.5, false), "1.0 ≥ 1.0 → TRADING")
	assert_eq(s.state, TradeStallState.State.TRADING)


func test_hold_resets_on_movement() -> void:
	var s := _available_stall(25.0, 1.0)
	s.accumulate_hold(0.8, false)  # progress 0.8
	assert_almost_eq(s.hold_progress_ratio(), 0.8, 0.01, "0.8 accumulated")
	s.accumulate_hold(0.1, true)   # MOVED → reset
	assert_almost_eq(s.hold_progress_ratio(), 0.0, 0.01, "movement reset the fill")
	assert_eq(s.state, TradeStallState.State.AVAILABLE, "no panel — still AVAILABLE")


func test_hold_requires_fresh_full_hold_after_reset() -> void:
	var s := _available_stall(25.0, 1.0)
	s.accumulate_hold(0.9, false)
	s.accumulate_hold(0.1, true)   # reset at 0.9
	assert_false(s.accumulate_hold(0.5, false), "fresh hold from 0 — 0.5 < 1.0")
	assert_eq(s.state, TradeStallState.State.AVAILABLE)
	assert_true(s.accumulate_hold(0.5, false), "0.5 + 0.5 = 1.0 → TRADING")


func test_hold_is_noop_outside_available() -> void:
	var s := TradeStallState.new()  # DORMANT
	assert_false(s.accumulate_hold(5.0, false), "no hold accumulation in DORMANT")
	assert_eq(s.state, TradeStallState.State.DORMANT)


# ─── boss suppression ────────────────────────────────────────────────────

func test_boss_spawn_expires_available_stall() -> void:
	var s := _available_stall()
	assert_true(s.on_boss_spawned(), "AVAILABLE → EXPIRED on boss spawn")
	assert_eq(s.state, TradeStallState.State.EXPIRED)


func test_boss_spawn_expires_dormant_stall() -> void:
	var s := TradeStallState.new()
	assert_true(s.on_boss_spawned(), "DORMANT → EXPIRED on boss spawn")
	assert_eq(s.state, TradeStallState.State.EXPIRED)


func test_boss_spawn_noop_while_trading() -> void:
	# A trade in progress isn't interrupted by the boss-suppress check (the panel
	# owns its own stage-end abort path via on_trade_aborted).
	var s := _available_stall(25.0, 1.0)
	s.accumulate_hold(1.0, false)  # → TRADING
	assert_false(s.on_boss_spawned(), "boss-suppress is a no-op mid-trade")
	assert_eq(s.state, TradeStallState.State.TRADING)


# ─── trade resolution ────────────────────────────────────────────────────

func test_trade_confirmed_goes_spent() -> void:
	var s := _available_stall(25.0, 1.0)
	s.accumulate_hold(1.0, false)
	s.on_trade_confirmed()
	assert_eq(s.state, TradeStallState.State.SPENT, "confirmed trade → SPENT (terminal)")
	assert_true(s.is_terminal())


func test_trade_aborted_goes_expired() -> void:
	# Step-A abort (player died / stage ended mid-panel).
	var s := _available_stall(25.0, 1.0)
	s.accumulate_hold(1.0, false)
	s.on_trade_aborted()
	assert_eq(s.state, TradeStallState.State.EXPIRED, "aborted trade → EXPIRED, no side effects")


# ─── decline preserves linger (the key anti-exploit timing rule) ─────────

func test_decline_returns_to_available_and_preserves_linger() -> void:
	var s := _available_stall(25.0, 1.0)
	for _i in 10:
		s.tick_linger(1.0)            # linger 25 → 15
	assert_almost_eq(s.linger_remaining(), 15.0, 0.01, "linger ticked to 15")
	s.accumulate_hold(1.0, false)     # → TRADING
	assert_eq(s.state, TradeStallState.State.TRADING)
	s.on_decline()
	assert_eq(s.state, TradeStallState.State.AVAILABLE, "decline → AVAILABLE")
	assert_almost_eq(s.linger_remaining(), 15.0, 0.01,
		"linger CONTINUES from 15 — NOT reset to 25 (anti-exploit)")


func test_decline_resets_hold_progress() -> void:
	var s := _available_stall(25.0, 1.0)
	s.accumulate_hold(1.0, false)     # → TRADING (progress reset to 0 on entry)
	s.on_decline()
	assert_almost_eq(s.hold_progress_ratio(), 0.0, 0.01, "hold fill reset after decline")


func test_linger_still_expires_after_decline() -> void:
	var s := _available_stall(25.0, 1.0)
	for _i in 24:
		s.tick_linger(1.0)            # linger → 1
	s.accumulate_hold(1.0, false)     # → TRADING
	s.on_decline()                    # → AVAILABLE, linger still 1
	assert_true(s.tick_linger(1.5), "remaining 1s linger expires the declined stall")
	assert_eq(s.state, TradeStallState.State.EXPIRED)


# ─── injection + queries ─────────────────────────────────────────────────

func test_custom_timings_via_injection() -> void:
	# DI: a config could shorten the hold to 0.5s.
	var s := TradeStallState.new(15.0, 0.5, 0.0)
	s.tick_warm_up(0.01)              # 0 warm-up → AVAILABLE immediately
	assert_eq(s.state, TradeStallState.State.AVAILABLE)
	assert_true(s.accumulate_hold(0.5, false), "injected 0.5s hold fires at 0.5")


func test_is_terminal_only_for_spent_and_expired() -> void:
	var s := TradeStallState.new()
	assert_false(s.is_terminal(), "DORMANT not terminal")
	s.tick_warm_up(1.0)
	assert_false(s.is_terminal(), "AVAILABLE not terminal")
	s.accumulate_hold(1.0, false)
	assert_false(s.is_terminal(), "TRADING not terminal")
	s.on_trade_confirmed()
	assert_true(s.is_terminal(), "SPENT is terminal")
