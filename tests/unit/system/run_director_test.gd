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


# Stub StageDirector that records the reset_for_stage call without running the
# real (tree-coupled) reset. IS-A StageDirector so it satisfies the typed export.
class StubStageDirector extends StageDirector:
	var reset_config: StageConfig = null
	func reset_for_stage(new_config: StageConfig) -> void:
		reset_config = new_config


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


func test_default_sequence_is_seven_interleaved_stages() -> void:
	var rd := _make_director()
	# 4 combat stages + 3 trade interludes, alternating.
	assert_eq(rd.stage_count(), 7, "荒山 / interlude / 幽都 / interlude / 再临 / interlude / 深渊")


func test_stage_one_has_a_next_stage() -> void:
	var rd := _make_director()
	assert_true(rd.has_next_stage(), "Stage 1 is followed by the trade interlude")


# ─── advancement ─────────────────────────────────────────────────────────

func test_advance_enters_interlude_then_combat() -> void:
	var rd := _make_director()
	watch_signals(rd)
	var cfg1 := rd.advance_to_next_stage()
	assert_eq(rd.get_stage_index(), 1, "index 1")
	assert_true(cfg1.is_interlude, "index 1 is the trade interlude (between combat stages)")
	assert_eq(cfg1.stage_id, &"interlude", "interlude id")
	var cfg2 := rd.advance_to_next_stage()
	assert_eq(cfg2.stage_id, &"stage_2", "index 2 → 幽都 combat stage (判官)")
	assert_false(cfg2.is_interlude, "幽都 is a combat stage")
	assert_signal_emitted(rd, "stage_advanced", "stage_advanced fired")


func test_advance_emits_new_index_and_config() -> void:
	var rd := _make_director()
	watch_signals(rd)
	rd.advance_to_next_stage()
	assert_signal_emitted_with_parameters(rd, "stage_advanced",
		[1, rd.get_current_stage_config()])


func test_combat_stages_alternate_with_interludes() -> void:
	var rd := _make_director()
	# Indices 0/2/4/6 = combat, 1/3/5 = interludes.
	var is_interlude := []
	for i in range(7):
		is_interlude.append(rd.get_current_stage_config().is_interlude)
		if rd.has_next_stage():
			rd.advance_to_next_stage()
	assert_eq(is_interlude, [false, true, false, true, false, true, false],
		"combat / interlude alternation")


func test_remix_combat_stages_escalate_difficulty() -> void:
	var rd := _make_director()
	for _i in 4:
		rd.advance_to_next_stage()  # index 4 = 荒山·再临 (first remix combat stage)
	var s3 := rd.get_current_stage_config()
	assert_eq(s3.stage_id, &"stage_3", "index 4 is the first remix combat stage")
	assert_true(s3.difficulty_multiplier > 1.0, "remix escalates difficulty (>1.0)")


func test_advance_past_last_completes_run() -> void:
	var rd := _make_director()
	for _i in 6:
		rd.advance_to_next_stage()  # → index 6 (幽都·深渊, final)
	assert_false(rd.has_next_stage(), "index 6 is the final stage")
	watch_signals(rd)
	var cfg := rd.advance_to_next_stage()   # attempt to advance past it
	assert_null(cfg, "no config past the final stage")
	assert_eq(rd.get_stage_index(), 6, "index does NOT advance past the last stage")
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


# ─── transition orchestration (the live Stage 1→2 glue) ──────────────────

func test_stage_advance_request_advances_and_resets_the_director() -> void:
	# Simulates StageDirector emitting stage_advance_requested (Stage-1 boss dead,
	# next stage exists): RunDirector must advance its sequence AND drive the
	# director's reset_for_stage onto the new config.
	var rd := RunDirector.new()
	var stub := StubStageDirector.new()
	autofree(stub)
	rd.stage_director = stub
	add_child_autofree(rd)  # _ready connects to stub.stage_advance_requested

	rd._on_stage_advance_requested()

	assert_eq(rd.get_stage_index(), 1, "advanced to index 1")
	assert_not_null(stub.reset_config, "stage_director.reset_for_stage was called")
	assert_eq(stub.reset_config.stage_id, &"interlude",
		"reset onto the trade interlude (index 1, between combat stages)")


func test_stage_advance_with_no_director_is_safe() -> void:
	# Defensive: a null stage_director must not crash the advance (heal still runs
	# via the player group, which is empty here → also a safe no-op).
	var rd := _make_director()
	rd._on_stage_advance_requested()
	assert_eq(rd.get_stage_index(), 1, "still advances the sequence")
