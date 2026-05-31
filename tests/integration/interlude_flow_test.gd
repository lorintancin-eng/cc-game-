## Integration smoke for the LIVE multi-stage / Ghost Market wiring — the class of
## bug the .new()-based unit tests can't catch (typed-NodePath @exports not binding
## on the instanced Main.tscn, the transition not firing, the interlude not spawning
## its stalls/portal). It loads the REAL Main.tscn and drives the flow.
##
## Run via:
##   godot --headless --path . -s res://addons/gut/gut_cmdln.gd \
##         -gdir=res://tests/integration -gconfig=res://tests/.gutconfig.json -gexit

extends "res://tests/helpers/test_base.gd"

const MAIN_SCENE := preload("res://scenes/Main.tscn")


func _build_main() -> Node:
	var main := MAIN_SCENE.instantiate()
	add_child_autofree(main)  # runs _ready on StageDirector / RunDirector / TradePanel
	return main


# ─── the NodePath-binding bugs (run_director / trade_panel were null) ─────

func test_main_scene_wiring_resolves() -> void:
	var main := _build_main()
	var sd := main.get_node("StageDirector")
	assert_not_null(sd.run_director, "StageDirector.run_director resolved (export or sibling fallback)")
	assert_not_null(sd.trade_panel, "StageDirector.trade_panel resolved (this was why stalls never opened)")
	var rd := main.get_node("RunDirector")
	assert_not_null(rd.stage_director, "RunDirector.stage_director resolved")


# ─── the transition (clearing a combat stage → the trade interlude) ──────

func test_clearing_combat_stage_advances_into_interlude() -> void:
	var main := _build_main()
	var sd := main.get_node("StageDirector")
	assert_eq(sd.stage_config.stage_id, &"stage_1", "starts on 荒山 (combat)")
	assert_false(sd.stage_config.is_interlude, "荒山 is a combat stage")

	# Simulate the Stage-1 boss dying — the WHOLE live chain must fire:
	# _on_boss_died → stage_advance_requested → RunDirector advances → reset_for_stage.
	sd._on_boss_died(null)

	assert_true(sd.stage_config.is_interlude,
		"after clearing 荒山 the run advances INTO the 鬼市 interlude (not a victory screen)")
	assert_not_null(sd._leave_portal, "the interlude spawned its no-time-limit exit portal")


func test_interlude_spawns_its_stalls() -> void:
	var main := _build_main()
	var sd := main.get_node("StageDirector")
	sd._on_boss_died(null)  # → interlude
	assert_true(sd.stage_config.is_interlude, "in the interlude")

	# Drive past the stall spawn times (2/6/10s) without waiting real seconds.
	sd.elapsed_time = 11.0
	sd._check_trade_stall_spawns()
	assert_eq(sd._fired_stall_count, 3, "the interlude spawned all 3 ghost-merchant stalls")


# ─── interlude has no boss (it's a calm trade room) ──────────────────────

func test_interlude_does_not_spawn_a_boss() -> void:
	var main := _build_main()
	var sd := main.get_node("StageDirector")
	sd._on_boss_died(null)  # → interlude
	assert_false(sd._is_boss_spawned, "no boss queued on entering the interlude")
	# Even at its (failsafe) duration the interlude ends via _end_interlude, not a boss.
	assert_true(sd.stage_config.stage_duration >= 120.0, "no short time limit on the market")
