## Unit tests for StageDirector.reset_for_stage() — the mid-run stage swap that
## powers the multi-stage transition (ADR-0004, 荒山→鬼市). Verifies the progression
## flags + clock reset and the new config is applied.
##
## The StageDirector SCRIPT is instantiated WITHOUT being added to the tree, so
## _ready() (which resolves _player/_enemy_spawner + connects signals) does NOT
## run. With _enemy_spawner null, reset_for_stage's spawner-touching steps are
## guarded no-ops — leaving the pure state-reset + config-apply logic under test.
##
## Run via:
##   godot --headless --path . -s res://addons/gut/gut_cmdln.gd \
##         -gdir=res://tests/unit/system -gexit

extends "res://tests/helpers/test_base.gd"


## A "dirty" director mid-Stage-1 (boss dead, clock maxed, flags set), ready to be
## reset for the next stage.
func _dirty_director() -> StageDirector:
	var director := StageDirector.new()
	autofree(director)
	director.stage_config = StageOneConfig.build()
	director.elapsed_time = 300.0
	director._is_boss_warning_started = true
	director._is_boss_spawned = true
	director._is_stage_cleared = true
	director._is_demon_seal_completed = true
	director._fired_elite_events.resize(2)  # Stage 1 has 2 elite events
	return director


func test_reset_clears_progression_flags_and_clock() -> void:
	var d := _dirty_director()
	d.reset_for_stage(StageTwoConfig.build())
	assert_float_eq(d.elapsed_time, 0.0, 0.001, "clock reset to 0")
	assert_false(d._is_boss_spawned, "boss-spawned flag cleared")
	assert_false(d._is_boss_warning_started, "boss-warning flag cleared")
	assert_false(d._is_stage_cleared, "stage-cleared flag cleared")
	assert_false(d._is_stage_failed, "stage-failed flag cleared")
	assert_false(d._is_demon_seal_completed, "demon-seal-completed flag cleared")


func test_reset_swaps_in_the_new_stage_config() -> void:
	var d := _dirty_director()
	d.reset_for_stage(StageTwoConfig.build())
	assert_eq(d.stage_config.stage_id, &"stage_2", "config swapped to Stage 2")
	assert_float_eq(d.stage_duration, 180.0, 0.001, "stage_duration applied from Stage 2 config")
	assert_not_null(d.boss_scene, "boss_scene applied (Ghost Market Judge)")


func test_reset_resizes_fired_elite_events_for_new_config() -> void:
	# Stage 1 has 2 elite events; Stage 2 has 1. The parallel tracking array must
	# be re-sized to the NEW config and re-zeroed.
	var d := _dirty_director()
	d.reset_for_stage(StageTwoConfig.build())
	assert_eq(d._fired_elite_events.size(), 1, "resized to Stage 2's 1 elite event")
	assert_false(d._fired_elite_events[0], "re-zeroed (event not yet fired)")


func test_reset_marks_demon_seal_spawned_when_new_stage_has_none() -> void:
	# Stage 2 has no Demon Seal (demon_seal_config null) → it must be flagged
	# already-spawned so the _process spawn check is skipped.
	var d := _dirty_director()
	d.reset_for_stage(StageTwoConfig.build())
	assert_true(d._is_demon_seal_spawned, "no-seal stage marks demon seal spawned")


func test_reset_emits_stage_time_changed_at_zero() -> void:
	var d := _dirty_director()
	watch_signals(d)
	d.reset_for_stage(StageTwoConfig.build())
	assert_signal_emitted_with_parameters(d, "stage_time_changed", [0.0, 180.0])
