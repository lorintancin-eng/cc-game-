## Unit tests for LevelUpPanel option-label composition (Story 011 UI half).
##
## Scope: the pure `_compose_option_text` helper — the headless-safe, colour-blind-safe
## carrier of element identity (glyph tag 【火】) and the 相生 proximity hint line. The
## per-element colour fill / modulate is a screenshot-gated visual enhancement and is
## NOT asserted here (it needs a rendered frame). We call the method on a bare instance
## without adding it to the tree, so _ready()/@onready node lookups never run.
extends GutTest


func _make_panel() -> LevelUpPanel:
	var panel := LevelUpPanel.new()
	autofree(panel)
	return panel


func test_level_up_panel_text_includes_element_glyph_for_fire() -> void:
	# Arrange
	var panel := _make_panel()

	# Act
	var text := panel._compose_option_text("fire", "追魂符威力 +10", "伤害提高 10。", false)

	# Assert — fire options are tagged with the 火 glyph in a bracket prefix
	assert_string_contains(text, "【火】",
			"a fire upgrade label must carry the 火 element glyph tag")


func test_level_up_panel_text_omits_glyph_for_neutral() -> void:
	# Arrange
	var panel := _make_panel()

	# Act
	var text := panel._compose_option_text("neutral", "悟道", "随机感悟。", false)

	# Assert — neutral has no 五行 glyph, so no bracket tag is prepended
	assert_false(text.begins_with("【"),
			"a neutral upgrade must not be prefixed with an element glyph tag")


func test_level_up_panel_text_shows_resonance_hint_when_activating() -> void:
	# Arrange
	var panel := _make_panel()

	# Act
	var text := panel._compose_option_text("wood", "气血上限 +20", "提高生命上限。", true)

	# Assert — a pick that triggers a combo appends the 相生 hint line
	assert_string_contains(text, "相生",
			"an option that would trigger a combo must show the 相生 hint")


func test_level_up_panel_text_no_hint_when_not_activating() -> void:
	# Arrange
	var panel := _make_panel()

	# Act
	var text := panel._compose_option_text("water", "雷法施放 -10%", "出手更快。", false)

	# Assert — non-triggering options carry no 相生 hint line
	assert_false(text.contains("相生"),
			"an option that does not trigger a combo must not show the 相生 hint")
