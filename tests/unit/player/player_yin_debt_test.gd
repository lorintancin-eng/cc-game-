## Unit tests for Player's Yin Debt (阴债) timed speed buff — the Ghost Market
## trade that grants +move-speed for a duration (separate from _speed_multiplier
## so it never clashes with 七十二变). Pure field logic → no scene tree needed.
##
## Run via:
##   godot --headless --path . -s res://addons/gut/gut_cmdln.gd \
##         -gdir=res://tests/unit/player -gexit

extends "res://tests/helpers/test_base.gd"


func _player() -> Player:
	var p := Player.new()
	autofree(p)
	return p


func test_apply_sets_bonus_and_duration() -> void:
	var p := _player()
	p.apply_yin_debt_speed(0.2, 45.0)
	assert_float_eq(p._yin_debt_speed_bonus, 0.2, 0.001, "+20% bonus set")
	assert_float_eq(p._yin_debt_remaining, 45.0, 0.001, "45s duration set")


func test_tick_counts_down_but_keeps_bonus_while_active() -> void:
	var p := _player()
	p.apply_yin_debt_speed(0.2, 45.0)
	p._tick_yin_debt(10.0)
	assert_float_eq(p._yin_debt_remaining, 35.0, 0.001, "10s elapsed")
	assert_float_eq(p._yin_debt_speed_bonus, 0.2, 0.001, "bonus still active mid-duration")


func test_tick_clears_bonus_on_expiry() -> void:
	var p := _player()
	p.apply_yin_debt_speed(0.2, 45.0)
	p._tick_yin_debt(45.0)
	assert_float_eq(p._yin_debt_remaining, 0.0, 0.001, "expired")
	assert_float_eq(p._yin_debt_speed_bonus, 0.0, 0.001, "bonus cleared at expiry")


func test_tick_with_no_buff_is_noop() -> void:
	var p := _player()
	p._tick_yin_debt(10.0)
	assert_float_eq(p._yin_debt_speed_bonus, 0.0, 0.001, "no bonus to clear")
	assert_float_eq(p._yin_debt_remaining, 0.0, 0.001, "remaining stays 0")


func test_reapply_refreshes_not_stacks() -> void:
	var p := _player()
	p.apply_yin_debt_speed(0.2, 45.0)
	p._tick_yin_debt(40.0)              # remaining 5
	p.apply_yin_debt_speed(0.2, 45.0)  # re-buff
	assert_float_eq(p._yin_debt_remaining, 45.0, 0.001, "refreshed to full, not added to 5")
	assert_float_eq(p._yin_debt_speed_bonus, 0.2, 0.001, "bonus refreshed, not doubled")


func test_negative_inputs_clamped() -> void:
	var p := _player()
	p.apply_yin_debt_speed(-0.5, -10.0)
	assert_float_eq(p._yin_debt_speed_bonus, 0.0, 0.001, "negative bonus clamped to 0")
	assert_float_eq(p._yin_debt_remaining, 0.0, 0.001, "negative duration clamped to 0")
