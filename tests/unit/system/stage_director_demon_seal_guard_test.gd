## Regression test for StageDirector._on_demon_seal_completed OQ-4 guard.
##
## Bug (surfaced by /review-all-gdds 2026-05-27 + Demon Seal GDD OQ-4):
##   When the player died mid-seal, the DemonSeal's seal_completed signal
##   could still fire (race condition between Player.died and seal tick).
##   StageDirector would then spawn 8 XP orbs on the corpse's location AND
##   emit demon_seal_completed, causing HUD to display "镇妖碑封印完成" on
##   the game-over screen.
##
## Fix: add `if _is_stage_failed or _is_stage_cleared: return` guard at the
## top of `_on_demon_seal_completed`, after the dedup `_is_demon_seal_completed`
## check.
##
## This test instantiates StageDirector directly via `.new()` so `_ready()`
## does NOT fire (no node paths, no enemy spawner, no scene tree dependency).
## We assert only the guard's effect on internal state + signal emission.
##
## Run via:
##   godot --headless --path . -s res://addons/gut/gut_cmdln.gd \
##         -gtest=res://tests/unit/system -gexit

extends "res://tests/helpers/test_base.gd"

const StageDirectorScript = preload("res://scripts/system/stage_director.gd")


# ─── Test 1: stage failed → no completion side effects ───────────────────

func test_stage_director_demon_seal_completed_skips_when_stage_failed() -> void:
	# Arrange — director is alive but the run has already failed (player died).
	var director = StageDirectorScript.new()
	director._is_stage_failed = true
	var mock_seal = Area2D.new()
	mock_seal.global_position = Vector2(100.0, 100.0)
	watch_signals(director)

	# Act — DemonSeal signals completion late (race condition repro).
	director._on_demon_seal_completed(mock_seal)

	# Assert — guard must reject: internal flag stays false, signal not emitted.
	assert_false(director._is_demon_seal_completed,
		"_is_demon_seal_completed must stay false when stage already failed")
	assert_signal_not_emitted(director, "demon_seal_completed",
		"demon_seal_completed must NOT fire when stage failed (HUD would mis-display)")

	mock_seal.free()
	director.free()


# ─── Test 2: stage cleared → no completion side effects ──────────────────

func test_stage_director_demon_seal_completed_skips_when_stage_cleared() -> void:
	# Arrange — boss already killed (stage cleared) before the seal completes.
	# Edge case: player rushed the boss, then a stale seal tick fires.
	var director = StageDirectorScript.new()
	director._is_stage_cleared = true
	var mock_seal = Area2D.new()
	mock_seal.global_position = Vector2(100.0, 100.0)
	watch_signals(director)

	# Act
	director._on_demon_seal_completed(mock_seal)

	# Assert
	assert_false(director._is_demon_seal_completed,
		"_is_demon_seal_completed must stay false when stage already cleared")
	assert_signal_not_emitted(director, "demon_seal_completed",
		"demon_seal_completed must NOT fire when stage cleared")

	mock_seal.free()
	director.free()


# ─── Test 3: happy path — no failure flags → completion proceeds ─────────

func test_stage_director_demon_seal_completed_proceeds_when_run_active() -> void:
	# Arrange — neither failed nor cleared; the normal sealing path.
	var director = StageDirectorScript.new()
	director._is_stage_failed = false
	director._is_stage_cleared = false
	director._is_demon_seal_completed = false
	# NOTE: We skip the orb-spawn part by replacing experience_orb_scene with
	# null. _spawn_demon_seal_reward will push_warning and bail, but the
	# completion flag + signal must still fire (the guard does NOT block
	# the happy path).
	director.experience_orb_scene = null
	var mock_seal = Area2D.new()
	mock_seal.global_position = Vector2(50.0, 50.0)
	watch_signals(director)

	# Act
	director._on_demon_seal_completed(mock_seal)

	# Assert — completion flag flips, signal fires.
	assert_true(director._is_demon_seal_completed,
		"_is_demon_seal_completed must flip true on happy path")
	assert_signal_emit_count(director, "demon_seal_completed", 1,
		"demon_seal_completed must fire exactly once on happy path")

	mock_seal.free()
	director.free()


# ─── Test 4: dedup — second completion call is idempotent ────────────────

func test_stage_director_demon_seal_completed_dedupes_repeat_calls() -> void:
	# Arrange — pre-existing dedup guard (`if _is_demon_seal_completed: return`).
	# Test it still works (no regression from the new guard).
	var director = StageDirectorScript.new()
	director._is_demon_seal_completed = true   # already completed
	var mock_seal = Area2D.new()
	watch_signals(director)

	# Act
	director._on_demon_seal_completed(mock_seal)

	# Assert
	assert_signal_not_emitted(director, "demon_seal_completed",
		"demon_seal_completed must NOT fire a second time")

	mock_seal.free()
	director.free()
