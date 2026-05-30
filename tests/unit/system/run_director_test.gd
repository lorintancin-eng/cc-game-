## Unit tests for RunDirector — the multi-stage run lifecycle owner (ADR-0004).
## Verifies the canonical Stage 1 → Stage 2 sequence, index bookkeeping, and the
## advance / run-complete signals. The live Stage 1→2 transition (resetting the
## StageDirector + healing the player) is a later playtest-gated increment; this
## locks the sequencing LOGIC under CI first.
##
## Run via:
##   godot --headless --path . -s res://addons/gut/gut_cmdln.gd \
##         -gdir=res://tests/unit/system -gexit

extends "res://tests/helpers/test_base.gd"


## RunDirector is a Node — add it to the tree so _ready() builds the default
## sequence and the lifecycle frees cleanly.
func _make_director() -> RunDirector:
	var rd := RunDirector.new()
	add_child_autofree(rd)
	return rd


# ─── default sequence + starting state ───────────────────────────────────

func test_run_starts_on_stage_one() -> void:
	var rd := _make_director()
	assert_eq(rd.get_stage_index(), 0, "a run starts at stage index 0")
	var cfg := rd.get_current_stage_config()
	assert_not_null(cfg, "stage 0 has a config")
	assert_eq(cfg.stage_id, &"stage_1", "stage 0 → Stage 1 荒山古道")


func test_default_sequence_has_two_stages() -> void:
	var rd := _make_director()
	assert_eq(rd.stage_count(), 2, "canonical run = Stage 1 → Stage 2")


func test_stage_one_has_a_next_stage() -> void:
	var rd := _make_director()
	assert_true(rd.has_next_stage(), "Stage 1 is followed by Stage 2")


# ─── advancement ─────────────────────────────────────────────────────────

func test_advance_moves_to_stage_two() -> void:
	var rd := _make_director()
	watch_signals(rd)
	var cfg := rd.advance_to_next_stage()
	assert_eq(rd.get_stage_index(), 1, "now at stage index 1")
	assert_not_null(cfg, "advance returns the new stage's config")
	assert_eq(cfg.stage_id, &"stage_2", "advanced → Stage 2 幽都鬼市")
	assert_signal_emitted(rd, "stage_advanced", "stage_advanced fired")


func test_advance_emits_new_index_and_config() -> void:
	var rd := _make_director()
	watch_signals(rd)
	rd.advance_to_next_stage()
	assert_signal_emitted_with_parameters(rd, "stage_advanced",
		[1, rd.get_current_stage_config()])


func test_stage_two_is_the_final_stage() -> void:
	var rd := _make_director()
	rd.advance_to_next_stage()  # → stage 1 (Stage 2, last)
	assert_false(rd.has_next_stage(), "Stage 2 is the final stage")


func test_advance_past_last_completes_run() -> void:
	var rd := _make_director()
	rd.advance_to_next_stage()              # → final stage
	watch_signals(rd)
	var cfg := rd.advance_to_next_stage()   # attempt to advance past it
	assert_null(cfg, "no config past the final stage")
	assert_eq(rd.get_stage_index(), 1, "index does NOT advance past the last stage")
	assert_signal_emitted(rd, "run_completed", "run_completed fired on final advance")
	assert_signal_not_emitted(rd, "stage_advanced", "no stage_advanced past the end")


# ─── sequence injection + defensive clamp ────────────────────────────────

func test_set_stage_sequence_resets_to_first() -> void:
	var rd := _make_director()
	rd.advance_to_next_stage()  # index → 1
	var seq: Array[StageConfig] = [StageTwoConfig.build()]
	rd.set_stage_sequence(seq)
	assert_eq(rd.get_stage_index(), 0, "a new sequence resets to the first stage")
	assert_eq(rd.stage_count(), 1, "1-stage custom run")
	assert_false(rd.has_next_stage(), "single-stage run has no next")


func test_single_stage_run_completes_without_index_overflow() -> void:
	var rd := _make_director()
	var seq: Array[StageConfig] = [StageOneConfig.build()]
	rd.set_stage_sequence(seq)
	watch_signals(rd)
	assert_null(rd.advance_to_next_stage(), "no next in a single-stage run")
	assert_not_null(rd.get_current_stage_config(), "current config stays valid (clamped)")
	assert_signal_emitted(rd, "run_completed")
