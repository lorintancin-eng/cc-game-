## Unit tests for 寒露凝锋 frost slow (Story 009 / 金生水) — the target-owned core.
##
## Per the 2026-06-06 decision, frost_slow is OWNED BY THE ENEMY (not a central
## Status Effects registry): the Enemy holds `_frost_slow_factor` + `_frost_slow_remaining`,
## exposes apply_frost_slow(factor, duration) (refresh-only), ticks it down, and applies
## the factor to its own movement via _effective_move_speed(). This is race-free (each
## enemy guards its own state) and honors ADR-0006 R-3's refresh-only intent.
##
## Covers: factor → effective speed, expiry restores full speed, partial tick,
## refresh-only (no intensity compounding incl. simultaneous multi-weapon hits, R-3),
## zero-duration no-op, Formula-6 scaled duration (1.5–3.0s).
##
## (The weapon-side apply — every weapon hit calling apply_frost_slow when 金生水 is
## active — is the remaining wiring piece, deferred to the next run; this file proves
## the target-owned mechanism the decision selected.)
##
## Instantiation: Enemy.new() (no _ready / no scene tree) — the frost methods are pure
## (no @onready deps). autofree() teardown.

extends "res://tests/helpers/test_base.gd"


func _make_enemy(speed: float) -> Enemy:
	var e := Enemy.new()
	autofree(e)
	e.move_speed = speed
	return e


# ─── factor → effective speed ────────────────────────────────────────────────

func test_frost_slow_applies_factor_to_effective_speed() -> void:
	# Arrange
	var e := _make_enemy(100.0)

	# Act
	e.apply_frost_slow(0.7, 1.5)

	# Assert — 0.7 factor → 70 effective speed
	assert_float_eq(e.frost_slow_factor(), 0.7, 0.001, "frost factor set to 0.7")
	assert_float_eq(e._effective_move_speed(), 70.0, 0.001, "100 × 0.7 = 70")


# ─── expiry restores full speed ──────────────────────────────────────────────

func test_frost_slow_expires_restores_full_speed() -> void:
	# Arrange
	var e := _make_enemy(100.0)
	e.apply_frost_slow(0.7, 1.5)

	# Act — tick the full duration
	e._tick_frost_slow(1.5)

	# Assert — restored
	assert_float_eq(e.frost_slow_factor(), 1.0, 0.001, "expired → factor 1.0")
	assert_float_eq(e._effective_move_speed(), 100.0, 0.001, "full speed restored")


func test_frost_slow_partial_tick_keeps_slow() -> void:
	# Arrange
	var e := _make_enemy(100.0)
	e.apply_frost_slow(0.7, 1.5)

	# Act — half the duration
	e._tick_frost_slow(0.5)

	# Assert — still slowed
	assert_float_eq(e.frost_slow_factor(), 0.7, 0.001, "still slowed mid-duration")


# ─── refresh-only (no intensity compounding) ─────────────────────────────────

func test_frost_slow_refresh_only_does_not_compound_intensity() -> void:
	# Arrange — slow active with 0.5s left
	var e := _make_enemy(100.0)
	e.apply_frost_slow(0.7, 1.5)
	e._tick_frost_slow(1.0)

	# Act — a second hit re-applies
	e.apply_frost_slow(0.7, 1.5)

	# Assert — factor stays 0.7 (NOT 0.49); duration refreshed to full 1.5
	assert_float_eq(e.frost_slow_factor(), 0.7, 0.001, "intensity never compounds")
	e._tick_frost_slow(1.0)
	assert_float_eq(e.frost_slow_factor(), 0.7, 0.001, "refreshed duration → still slowed after 1.0s")


func test_frost_slow_simultaneous_reapply_no_compound() -> void:
	# Arrange — R-3: two weapon hits the same frame both apply
	var e := _make_enemy(100.0)

	# Act
	e.apply_frost_slow(0.7, 1.5)
	e.apply_frost_slow(0.7, 1.5)

	# Assert — no stacking (still 0.7, not 0.49)
	assert_float_eq(e.frost_slow_factor(), 0.7, 0.001, "simultaneous hits don't compound")
	assert_float_eq(e._effective_move_speed(), 70.0, 0.001, "still 70, not 49")


# ─── guards + Formula 6 duration ─────────────────────────────────────────────

func test_frost_slow_zero_duration_is_noop() -> void:
	# Arrange + Act
	var e := _make_enemy(100.0)
	e.apply_frost_slow(0.7, 0.0)

	# Assert — no slow applied
	assert_float_eq(e.frost_slow_factor(), 1.0, 0.001, "0 duration → no slow")
	assert_float_eq(e._effective_move_speed(), 100.0, 0.001, "full speed")


func test_frost_slow_scaled_duration_holds_to_cap() -> void:
	# Arrange — Formula 6: duration scales 1.5 → 3.0 (cap at steps=5)
	var e := _make_enemy(100.0)
	e.apply_frost_slow(0.7, 3.0)

	# Act + Assert — still slowed at 2.5s of a 3.0s slow, expires after
	e._tick_frost_slow(2.5)
	assert_float_eq(e.frost_slow_factor(), 0.7, 0.001, "still slowed at 2.5s of 3.0s")
	e._tick_frost_slow(0.5)
	assert_float_eq(e.frost_slow_factor(), 1.0, 0.001, "expires at 3.0s")
