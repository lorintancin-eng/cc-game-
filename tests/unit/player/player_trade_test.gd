## Unit tests for the Player Ghost Market trade execution methods (cost + buff per
## archetype). The pause begin_trade/end_trade glue touches get_tree() and is
## playtest-verified; these cover the testable cost/buff/validation logic.
##
## Run via:
##   godot --headless --path . -s res://addons/gut/gut_cmdln.gd \
##         -gdir=res://tests/unit/player -gexit

extends "res://tests/helpers/test_base.gd"


func _player() -> Player:
	var p := Player.new()
	autofree(p)
	return p


# ─── 血契 Blood Pact ──────────────────────────────────────────────────────

func test_execute_blood_pact_pays_max_hp_and_stacks() -> void:
	var p := _player()
	p.max_hp = 100.0
	p.current_hp = 100.0
	assert_true(p.execute_blood_pact(0), "first blood pact succeeds")
	assert_float_eq(p.max_hp, 85.0, 0.001, "max_hp -15 (trade n=0)")
	assert_float_eq(p.current_hp, 85.0, 0.001, "current_hp clamped to new max")
	assert_eq(p.blood_pact_stacks(), 1, "stack incremented")


func test_execute_blood_pact_below_floor_returns_false() -> void:
	var p := _player()
	p.max_hp = 50.0   # 50 - 15 = 35 < 40 floor → locked
	p.current_hp = 50.0
	assert_false(p.execute_blood_pact(0), "below-floor cost → rejected")
	assert_float_eq(p.max_hp, 50.0, 0.001, "max_hp unchanged on rejection")
	assert_eq(p.blood_pact_stacks(), 0, "no stack on rejection")


func test_execute_blood_pact_rejected_at_stack_cap() -> void:
	var p := _player()
	p.max_hp = 500.0
	p.current_hp = 500.0
	p.execute_blood_pact(0)
	p.execute_blood_pact(1)
	p.execute_blood_pact(2)
	assert_eq(p.blood_pact_stacks(), 3, "3 stacks taken (440 HP remains)")
	assert_false(p.execute_blood_pact(2), "4th rejected at the 3-stack cap")


# ─── 魂典 Soul Codex ──────────────────────────────────────────────────────

func test_execute_soul_codex_spends_xp() -> void:
	var p := _player()
	p.current_xp = 100.0
	# upgrade_id &"" → spend only (no weapon-touching _apply_upgrade in a headless test)
	assert_true(p.execute_soul_codex(0, &""), "affordable → succeeds")
	assert_float_eq(p.current_xp, 40.0, 0.001, "100 - 60 (trade n=0) = 40")


func test_execute_soul_codex_insufficient_xp_returns_false() -> void:
	var p := _player()
	p.current_xp = 40.0
	assert_false(p.execute_soul_codex(0, &""), "40 < 60 cost → rejected")
	assert_float_eq(p.current_xp, 40.0, 0.001, "xp unchanged on rejection")


# ─── 阴债 Yin Debt ────────────────────────────────────────────────────────

func test_execute_yin_debt_grants_timed_speed_buff() -> void:
	var p := _player()
	p.execute_yin_debt()
	assert_float_eq(p._yin_debt_speed_bonus, 0.2, 0.001, "+20% move speed")
	assert_float_eq(p._yin_debt_remaining, 45.0, 0.001, "for 45s")
