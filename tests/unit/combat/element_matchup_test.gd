## Unit tests for ElementMatchup (scripts/combat/element_matchup.gd) — covers
## Five Phases Story 001 AC-13, AC-14, AC-14b, AC-14c, AC-14d, AC-14e, AC-20.
##
## Exercises all 25 ordered element pairs (5×5), both neutral short-circuits,
## and the invalid-element error path. Pure static function — no nodes, no scene
## tree, no RNG, fully deterministic.
##
## Run via:
##   godot --headless --path . -s res://addons/gut/gut_cmdln.gd \
##         -gtest=res://tests/unit/combat/element_matchup_test.gd -gexit

extends "res://tests/helpers/test_base.gd"

const ElementMatchup = preload("res://scripts/combat/element_matchup.gd")


# ─── AC-13: metal→wood is favorable (1.3) ────────────────────────────────

func test_element_matchup_metal_vs_wood_returns_favorable() -> void:
	# 金克木 — the canonical favorable example from AC-13.
	assert_float_eq(ElementMatchup.modifier("metal", "wood"), 1.3)


# ─── AC-14: metal→fire is unfavorable (0.8) ──────────────────────────────

func test_element_matchup_metal_vs_fire_returns_unfavorable() -> void:
	# 火克金 — metal is the target of fire's overcoming; src=metal is weaker.
	assert_float_eq(ElementMatchup.modifier("metal", "fire"), 0.8)


# ─── AC-14b: each of the remaining 4 favorable pairs returns 1.3 ─────────

func test_element_matchup_wood_vs_earth_returns_favorable() -> void:
	# 木克土
	assert_float_eq(ElementMatchup.modifier("wood", "earth"), 1.3)


func test_element_matchup_earth_vs_water_returns_favorable() -> void:
	# 土克水
	assert_float_eq(ElementMatchup.modifier("earth", "water"), 1.3)


func test_element_matchup_water_vs_fire_returns_favorable() -> void:
	# 水克火
	assert_float_eq(ElementMatchup.modifier("water", "fire"), 1.3)


func test_element_matchup_fire_vs_metal_returns_favorable() -> void:
	# 火克金
	assert_float_eq(ElementMatchup.modifier("fire", "metal"), 1.3)


# ─── AC-14c: each unfavorable mirror returns 0.8 ─────────────────────────

func test_element_matchup_earth_vs_wood_returns_unfavorable() -> void:
	# wood overcomes earth (木克土) → earth attacking wood is unfavorable.
	assert_float_eq(ElementMatchup.modifier("earth", "wood"), 0.8)


func test_element_matchup_water_vs_earth_returns_unfavorable() -> void:
	# earth overcomes water (土克水) → water attacking earth is unfavorable.
	assert_float_eq(ElementMatchup.modifier("water", "earth"), 0.8)


func test_element_matchup_fire_vs_water_returns_unfavorable() -> void:
	# water overcomes fire (水克火) → fire attacking water is unfavorable.
	assert_float_eq(ElementMatchup.modifier("fire", "water"), 0.8)


func test_element_matchup_wood_vs_metal_returns_unfavorable() -> void:
	# metal overcomes wood (金克木) → wood attacking metal is unfavorable.
	assert_float_eq(ElementMatchup.modifier("wood", "metal"), 0.8)


# ─── Same-element pairs: all 5 return 1.0 ────────────────────────────────

func test_element_matchup_metal_vs_metal_returns_neutral() -> void:
	assert_float_eq(ElementMatchup.modifier("metal", "metal"), 1.0)


func test_element_matchup_wood_vs_wood_returns_neutral() -> void:
	assert_float_eq(ElementMatchup.modifier("wood", "wood"), 1.0)


func test_element_matchup_earth_vs_earth_returns_neutral() -> void:
	assert_float_eq(ElementMatchup.modifier("earth", "earth"), 1.0)


func test_element_matchup_water_vs_water_returns_neutral() -> void:
	assert_float_eq(ElementMatchup.modifier("water", "water"), 1.0)


func test_element_matchup_fire_vs_fire_returns_neutral() -> void:
	assert_float_eq(ElementMatchup.modifier("fire", "fire"), 1.0)


# ─── AC-14d: all 10 unrelated ordered pairs return 1.0 ───────────────────
# These are the pairs that are neither favorable, unfavorable, nor same-element.
# Most likely regression path (wrong 0.8/1.3 bleed-through from lookup).

func test_element_matchup_metal_vs_water_returns_neutral() -> void:
	assert_float_eq(ElementMatchup.modifier("metal", "water"), 1.0)


func test_element_matchup_metal_vs_earth_returns_neutral() -> void:
	assert_float_eq(ElementMatchup.modifier("metal", "earth"), 1.0)


func test_element_matchup_wood_vs_water_returns_neutral() -> void:
	assert_float_eq(ElementMatchup.modifier("wood", "water"), 1.0)


func test_element_matchup_wood_vs_fire_returns_neutral() -> void:
	assert_float_eq(ElementMatchup.modifier("wood", "fire"), 1.0)


func test_element_matchup_earth_vs_metal_returns_neutral() -> void:
	assert_float_eq(ElementMatchup.modifier("earth", "metal"), 1.0)


func test_element_matchup_earth_vs_fire_returns_neutral() -> void:
	assert_float_eq(ElementMatchup.modifier("earth", "fire"), 1.0)


func test_element_matchup_water_vs_metal_returns_neutral() -> void:
	assert_float_eq(ElementMatchup.modifier("water", "metal"), 1.0)


func test_element_matchup_water_vs_wood_returns_neutral() -> void:
	assert_float_eq(ElementMatchup.modifier("water", "wood"), 1.0)


func test_element_matchup_fire_vs_wood_returns_neutral() -> void:
	assert_float_eq(ElementMatchup.modifier("fire", "wood"), 1.0)


func test_element_matchup_fire_vs_earth_returns_neutral() -> void:
	assert_float_eq(ElementMatchup.modifier("fire", "earth"), 1.0)


# ─── AC-14e: neutral on either side short-circuits to 1.0 ────────────────

func test_element_matchup_neutral_as_src_returns_one() -> void:
	# neutral src — no overcoming cycle applies regardless of target.
	assert_float_eq(ElementMatchup.modifier("neutral", "fire"), 1.0)


func test_element_matchup_neutral_as_tgt_returns_one() -> void:
	# neutral tgt — no overcoming cycle applies regardless of source.
	assert_float_eq(ElementMatchup.modifier("metal", "neutral"), 1.0)


func test_element_matchup_neutral_vs_neutral_returns_one() -> void:
	# Both sides neutral — still 1.0 (degenerate but valid).
	assert_float_eq(ElementMatchup.modifier("neutral", "neutral"), 1.0)


# ─── AC-20: invalid element → push_error + returns 1.0 ───────────────────
# GUT 9.x tracks push_error calls per-test. assert_push_error_count(1) both
# verifies the error was emitted AND marks it as consumed, preventing GUT
# from reporting it as an "unexpected error" that fails the test.

func test_element_matchup_invalid_src_returns_neutral_and_fires_error() -> void:
	# "lightning" is not in the closed element set.
	# Contract: push_error fires exactly once AND return value is 1.0.
	var result: float = ElementMatchup.modifier("lightning", "wood")
	assert_float_eq(result, 1.0,
		0.001,
		"invalid src must return 1.0 (treated as neutral)")
	assert_push_error_count(1, "invalid src must emit exactly one push_error")


func test_element_matchup_invalid_tgt_returns_neutral_and_fires_error() -> void:
	# tgt is invalid.
	var result: float = ElementMatchup.modifier("metal", "shadow")
	assert_float_eq(result, 1.0,
		0.001,
		"invalid tgt must return 1.0 (treated as neutral)")
	assert_push_error_count(1, "invalid tgt must emit exactly one push_error")


func test_element_matchup_empty_string_src_returns_neutral_and_fires_error() -> void:
	# Empty string is not in the closed element set.
	var result: float = ElementMatchup.modifier("", "fire")
	assert_float_eq(result, 1.0,
		0.001,
		"empty string src must return 1.0 (treated as neutral)")
	assert_push_error_count(1, "empty-string src must emit exactly one push_error")


func test_element_matchup_empty_string_tgt_returns_neutral_and_fires_error() -> void:
	var result: float = ElementMatchup.modifier("metal", "")
	assert_float_eq(result, 1.0,
		0.001,
		"empty string tgt must return 1.0 (treated as neutral)")
	assert_push_error_count(1, "empty-string tgt must emit exactly one push_error")
