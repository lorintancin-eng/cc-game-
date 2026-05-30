## Unit tests for Player.heal() — the heal API used by the multi-stage run
## transition (RunDirector heals +40% max_hp when advancing to the next stage).
## Instantiates the Player SCRIPT directly; heal only does arithmetic +
## _update_health_bar (null-guarded when detached) + a signal emit.
##
## Run via:
##   godot --headless --path . -s res://addons/gut/gut_cmdln.gd \
##         -gdir=res://tests/unit/player -gexit

extends "res://tests/helpers/test_base.gd"


func _make_player(max_hp: float, current_hp: float) -> Player:
	var player := Player.new()
	autofree(player)
	player.max_hp = max_hp
	player.current_hp = current_hp
	return player


func test_heal_restores_hp() -> void:
	var p := _make_player(120.0, 50.0)
	p.heal(40.0)
	assert_float_eq(p.current_hp, 90.0, 0.001, "50 + 40 = 90")


func test_heal_clamps_to_max_hp() -> void:
	var p := _make_player(120.0, 100.0)
	p.heal(40.0)
	assert_float_eq(p.current_hp, 120.0, 0.001, "100 + 40 clamped to max 120 (no overheal)")


func test_heal_is_noop_when_dead() -> void:
	var p := _make_player(120.0, 30.0)
	p._is_dead = true
	p.heal(40.0)
	assert_float_eq(p.current_hp, 30.0, 0.001, "a dead player cannot be healed")


func test_heal_is_noop_for_non_positive_amount() -> void:
	var p := _make_player(120.0, 30.0)
	p.heal(0.0)
	assert_float_eq(p.current_hp, 30.0, 0.001, "0 heal is a no-op")
	p.heal(-10.0)
	assert_float_eq(p.current_hp, 30.0, 0.001, "negative heal is a no-op (never damages)")


func test_heal_emits_health_changed() -> void:
	var p := _make_player(120.0, 50.0)
	watch_signals(p)
	p.heal(40.0)
	assert_signal_emitted_with_parameters(p, "health_changed", [90.0, 120.0])


func test_heal_forty_percent_transition_case() -> void:
	# The canonical RunDirector transition: heal +40% of max_hp on clearing a stage.
	# Uses the playtest screenshot's values (32/120 at Stage-1 boss death).
	var p := _make_player(120.0, 32.0)
	p.heal(p.max_hp * 0.4)  # +48
	assert_float_eq(p.current_hp, 80.0, 0.001, "32 + 48 (40% of 120) = 80")
