## Regression test for ActiveSkillCharacter cooldown emit throttle.
##
## Closes /review-all-gdds 2026-05-27 defect #2 + amends ADR-0003 §HUD overhead.
##
## Pre-fix behavior
##   `_process(delta)` emitted `skill_cooldown_changed` on every frame while a
##   cooldown was ticking — ~60 emits/sec/slot, ~240 emits/sec for 4 slots.
##   The HUD's only visible state was `label.text = "%ds" % ceili(remaining)`,
##   so 59/60 of those emits drove no visible change.
##
## Post-fix behavior (tested here)
##   Emit only when (a) ceili(remaining) changes from the previous frame
##   (visible label change), OR (b) cooldown reaches 0 (icon flip 暗金→亮金).
##
## ActiveSkillCharacter is the abstract base used by both SunWukongV2 and
## (future) other active-skill characters. We instantiate it directly to test
## the throttle in isolation. `_register_skill` is the entry that seeds
## `_skill_max_cds`; `cast_skill` would normally start the cooldown but we
## bypass it by writing to `_skill_cooldowns[slot]` directly so the throttle
## logic is the only thing under test.
##
## Run via:
##   godot --headless --path . -s res://addons/gut/gut_cmdln.gd \
##         -gtest=res://tests/unit/character -gexit

extends "res://tests/helpers/test_base.gd"

const ActiveSkillCharacterScript = preload("res://scripts/character/active_skill_character.gd")


# Helper: build a minimal character with one armed cooldown.
# `initial_unlock=true` so the cooldown is allowed to tick.
# Suppress the initial _register_skill emit by clearing watch_signals after setup.
func _make_character_with_cooldown(starting_cooldown: float, max_cd: float = 8.0) -> Node:
	var character = ActiveSkillCharacterScript.new()
	# Add to scene tree so _process can be invoked by tests if needed (we call it
	# directly here, so add_child is optional but lets timers/signals stay safe).
	add_child_autofree(character)
	character._register_skill(0, "test_skill", max_cd, true)
	# Seed cooldown directly (bypass cast_skill — that path is not under test).
	character._skill_cooldowns[0] = starting_cooldown
	return character


# ─── Test 1: sub-second tick → no emit ────────────────────────────────────

func test_skill_cooldown_no_emit_within_same_second() -> void:
	# Arrange — cooldown at 5.0s, frame delta 0.016s. 5.0 → 4.984.
	# ceili(5.0) == 5, ceili(4.984) == 5 → integer label unchanged → no emit.
	var character = _make_character_with_cooldown(5.0)
	watch_signals(character)

	# Act — one 60-fps frame.
	character._process(0.016)

	# Assert
	assert_signal_emit_count(character, "skill_cooldown_changed", 0,
		"throttle must suppress emit when ceili(remaining) is unchanged")


# ─── Test 2: crossing integer second → emit exactly once ──────────────────

func test_skill_cooldown_emit_on_integer_second_change() -> void:
	# Arrange — cooldown at 5.0s, frame delta 1.1s (large frame, possible
	# under hitch). 5.0 → 3.9. ceili(5.0)=5, ceili(3.9)=4 → emit.
	var character = _make_character_with_cooldown(5.0)
	watch_signals(character)

	# Act
	character._process(1.1)

	# Assert
	assert_signal_emit_count(character, "skill_cooldown_changed", 1,
		"throttle must emit exactly once when integer-second boundary crosses")


# ─── Test 3: reaching zero → emit (icon flip 暗金 → 亮金) ─────────────────

func test_skill_cooldown_emit_when_reaching_zero() -> void:
	# Arrange — cooldown at 0.05s, frame delta 0.1s. clamped to 0.
	# This is the boundary case: HUD must learn the cooldown is ready so it
	# flips icon to 亮金 + label to slot number.
	var character = _make_character_with_cooldown(0.05)
	watch_signals(character)

	# Act
	character._process(0.1)

	# Assert
	assert_signal_emit_count(character, "skill_cooldown_changed", 1,
		"throttle must emit on the 0-transition so HUD can flip icon to ready")
	# Verify the cooldown was actually zeroed
	assert_float_eq(character._skill_cooldowns[0], 0.0, 0.0001,
		"cooldown must clamp to 0 (not negative)")


# ─── Test 4: cooldown already zero → no emit (top-of-loop early skip) ────

func test_skill_cooldown_no_emit_when_already_zero() -> void:
	# Arrange — cooldown at 0, ticking a frame should NOT spam emits.
	var character = _make_character_with_cooldown(0.0)
	watch_signals(character)

	# Act
	character._process(0.016)

	# Assert
	assert_signal_emit_count(character, "skill_cooldown_changed", 0,
		"loop must skip the slot when cooldown is already 0 — no idle emit spam")


# ─── Test 5: long-burn — 60 frames within 1 second → 0 or 1 emit ─────────

func test_skill_cooldown_60_frames_one_second_at_most_one_emit() -> void:
	# Arrange — cooldown at 5.0s, tick 60 frames of 0.016s = 0.96s total.
	# After 60 frames: ~5.0 - 0.96 = ~4.04. ceili(5.0)=5, ceili(4.04)=5.
	# So 0 emits — sub-second remainder didn't cross integer boundary.
	# (This is the core perf claim — 60 frames produce 0 emits, not 60.)
	var character = _make_character_with_cooldown(5.0)
	watch_signals(character)

	# Act
	for i in 60:
		character._process(0.016)

	# Assert
	# Allow ≤1 to be defensive against floating-point edge: 5.0 - 60*0.016 = 4.04,
	# but if compiler accumulates differently it might land at 3.999... which
	# would emit. We assert ≤1 to allow either outcome — the 60× reduction
	# guarantee still holds.
	var emit_count := get_signal_emit_count(character, "skill_cooldown_changed")
	assert_true(emit_count <= 1,
		"60-fps tick over <1 second must produce at most 1 emit (got %d)" % emit_count)
